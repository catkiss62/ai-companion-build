import 'commission_thread.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../ai/chat_api_provider.dart';
import '../ai/deepseek_client.dart';
import '../ai/final_reply_failure_policy.dart';
import '../ai/final_reply_route.dart';
import '../ai/first_channel_model.dart';
import '../ai/generation_cancellation.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';
import '../storage/secure_config.dart';
import 'agent_native_tool_accumulator.dart';
import 'commission_workspace.dart';
import 'research_commission.dart';

enum CommissionPhase { planning, tool, composing }

class CommissionSession {
  static bool explicitRecall(String text) =>
      RegExp(r'(工作区|委托|调研报告|插件报告|上次.*调研|上次.*项目)').hasMatch(text) &&
      RegExp(r'(记得|还在|进度|刚才|继续|上次|之前|查到|做到|报告|结果|哪些|什么)').hasMatch(text);
  static bool followup(String text) => RegExp(
    r'^(?:那[，, ]*)?(?:第[一二三四五六七八九十0-9]+个|上一个|下一个|刚才(?:查|找|读|说的项目)|(?:这个|那个|还有哪些)(?:项目|仓库|插件|报告|工具)|(?:继续|接着)(?:查|搜|找|筛|调研))',
  ).hasMatch(text.trim());

  static Future<String> run({
    required CommissionWorkspace workspace,
    required String goal,
    required DeepSeekClient client,
    required AppDatabase db,
    required SecureConfig config,
    required GenerationCancellationToken cancel,
    required void Function(String) progress,
    String? previousTask,
    bool recentContext = false,
    bool Function()? chatBusy,
    void Function(CommissionPhase)? onPhase,
    void Function(String)? onRecordCreated,
  }) async {
    if (!await db.brainWorkAllowed()) throw StateError('当前设备暂停工作');
    final key = await config.readApiKey();
    if (key == null || key.isEmpty) throw StateError('请先配置第一通道');
    final endpoint = await config.readEndpoint();
    final model = await FirstChannelModel.read(db);
    final effort = await FirstChannelModel.readEffort(db);
    final id = const Uuid().v7();
    final name = '任务-$id.json';
    final files = await workspace.list();
    final context = <Map<String, Object?>>[];
    final documents = files
        .where((n) => n.endsWith('.md') && !n.startsWith('停用'))
        .toList();
    if (documents.isNotEmpty)
      context.add({
        'role': 'user',
        'content':
            '工作区文件索引（需要时用工具读取）：${jsonEncode(documents.take(160).toList())}',
      });
    String? threadId;
    if (previousTask != null) {
      final rows = await workspace.conversation(previousTask);
      if (rows.isEmpty) throw StateError('委托记录已删除');
      threadId = CommissionThread.key(rows.last);
      context.addAll(CommissionThread.history(rows));
      if (rows.last['state'] != 'completed' && rows.last['evidence'] != null) {
        context.add({
          'role': 'user',
          'content':
              '上一轮中断前的工具回执：${_clip(jsonEncode(rows.last['evidence']), 5000)}',
        });
      }
    } else if (recentContext || explicitRecall(goal) || followup(goal)) {
      for (final row in (await workspace.recent()).reversed) {
        context.add({
          'role': 'user',
          'content':
              '近期委托：${row['goal']}\n交付：${_clip(row['answer']?.toString() ?? '', 4000)}',
        });
      }
    }
    final record = <String, Object?>{
      'id': id,
      'threadId': threadId ?? id,
      'goal': goal,
      'at': DateTime.now().millisecondsSinceEpoch,
      'state': 'running',
    };
    Future<void> save() => workspace.write(name, jsonEncode(record));
    cancel.throwIfCancelled();
    if (!recentContext) {
      await save();
      CommissionWorkspace.writingTasks.add(name);
      onRecordCreated?.call(name);
    }
    Future<ResearchPlan> streamRequest(
      List<Map<String, Object?>> messages, {
      bool finalAnswer = false,
      bool relay = false,
      FinalReplyRoute? route,
    }) async {
      if (!await db.brainWorkAllowed()) throw StateError('当前设备暂停工作');
      cancel.throwIfCancelled();
      final output = StringBuffer(),
          reasoning = StringBuffer(),
          acc = AgentNativeToolCallAccumulator();
      String finish = '';
      final provider = relay
          ? await config.readChatProvider()
          : ChatApiProvider.deepSeek;
      final stream = client.streamChat(
        apiKey: relay ? (await config.readFinalReplyApiKey() ?? '') : key,
        endpoint: relay ? await config.readFinalReplyEndpoint() : endpoint,
        model: model,
        modelName: relay ? await config.readFinalReplyModel() : null,
        requestProvider: provider,
        effort: relay
            ? provider.normalizeEffort(
                ReasoningEffort.fromApiName(
                  await db.getSetting('reasoning_effort'),
                ),
              )
            : effort,
        messages: messages,
        tools: finalAnswer ? const [] : ResearchCommission.tools,
        cancellationToken: cancel,
        finalReplyRoute: route,
        thirdChannelSecure: config,
        thirdChannelCurrent: db.brainWorkAllowed,
        usageLane: finalAnswer
            ? 'commission_final_reply'
            : ResearchCommission.lane,
        usageExecutionId: id,
      );
      await for (final delta in stream) {
        cancel.throwIfCancelled();
        output.write(delta.content);
        reasoning.write(delta.reasoning);
        acc.addAll(delta.toolCallDeltas);
        finish = delta.finishReason ?? finish;
      }
      if (FinalReplyFailurePolicy.isIncompleteFinishReason(finish))
        throw StateError('回答未完成');
      return (
        content: output.toString(),
        reasoning: reasoning.toString(),
        toolCalls: acc.build(),
        finishReason: finish,
      );
    }

    bool limited = false;
    Future<ResearchPlan> request(
      List<Map<String, Object?>> messages, {
      bool finalAnswer = false,
      bool relay = false,
      FinalReplyRoute? route,
    }) async {
      for (var attempt = 0; ; attempt++) {
        while (limited && (chatBusy?.call() ?? false)) {
          cancel.throwIfCancelled();
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        try {
          return await streamRequest(
            messages,
            finalAnswer: finalAnswer,
            relay: relay,
            route: route,
          );
        } on DeepSeekException catch (error) {
          if (error.statusCode != 429 || attempt >= 2) rethrow;
          limited = true;
          progress('通道限流，稍后重试');
          await cancelWithToken(
            Future<void>.delayed(Duration(seconds: 1 << attempt)),
            cancel,
          );
        }
      }
    }

    final steps = <String>[];
    void reportStep(String text) {
      if (steps.isEmpty || steps.last != text) steps.add(text);
      record['steps'] = steps;
      progress(text);
    }

    try {
      final report = recentContext
          ? <String, Object?>{
              'mode': 'recent_work_lookup',
              'instruction': '仅根据可核实的近期交付回答；缺少细节时请说明。',
            }
          : await ResearchCommission.run(
              goal: goal,
              context: context,
              workspace: workspace,
              cancellation: cancel,
              plan: (messages) {
                onPhase?.call(CommissionPhase.planning);
                reportStep('正在规划');
                return request(messages);
              },
              progress: (s, success) {
                if (success == null) onPhase?.call(CommissionPhase.tool);
                reportStep(s);
              },
              checkpoint: (items) async {
                record['evidence'] = items;
                await save();
              },
            );
      cancel.throwIfCancelled();
      onPhase?.call(CommissionPhase.composing);
      reportStep('正在整理结果');
      final messages = <Map<String, Object?>>[
        {
          'role': 'system',
          'content':
              '你是用户的 AI 伴侣小鲸鱼。用自然中文交付这次委托；工具资料只作证据，给出可核实的链接或文件名；如实说明未执行、限流或未读正文。当前仅能读写工作区文档和检索 GitHub。询问手机目录时，区分通用查找建议和本机核实结果。',
        },
        ...context,
        {'role': 'user', 'content': goal},
        {'role': 'user', 'content': '本次调研数据：${jsonEncode(report)}'},
      ];
      final provider = await config.readChatProvider();
      final relay =
          provider.isGeminiRelay &&
          (await config.readFinalReplyApiKey() ?? '').isNotEmpty;
      final route = FinalReplyRoute(secondChannelEnabled: relay);
      String answer;
      try {
        answer = (await request(
          messages,
          finalAnswer: true,
          relay: relay,
          route: route,
        )).content.trim();
        if (answer.isEmpty) throw StateError('回复为空');
      } catch (_) {
        cancel.throwIfCancelled();
        if (!relay) rethrow;
        route.recordFailure('secondary_failed');
        answer = (await request(messages, finalAnswer: true)).content.trim();
      }
      if (answer.isEmpty) throw StateError('未收到正文');
      cancel.throwIfCancelled();
      record.addAll({
        'state': 'completed',
        'answer': answer,
        'at': DateTime.now().millisecondsSinceEpoch,
      });
      if (!recentContext) await save();
      return answer;
    } catch (_) {
      record['state'] = cancel.isCancelled ? 'stopped' : 'interrupted';
      if (!recentContext) await save();
      rethrow;
    } finally {
      CommissionWorkspace.writingTasks.remove(name);
    }
  }

  static String _clip(String s, int n) => s.length <= n ? s : s.substring(0, n);
}
