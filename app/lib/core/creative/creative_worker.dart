import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../agent/agent_native_tool_accumulator.dart';
import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../diagnostics/model_usage_telemetry.dart';
import '../storage/secure_config.dart';
import 'creative_contract.dart';
import 'creative_store.dart';
import 'creative_workspace.dart';

class CreativeWorker {
  CreativeWorker(this.db, {this.clientFactory, DateTime Function()? now})
      : now = now ?? DateTime.now;
  final DeepSeekClient Function(Future<bool> Function() abort)? clientFactory;
  final DateTime Function() now;
  final AppDatabase db;
  static const lease = 'creative_worker_lease_until';
  static const preview = MethodChannel('ai_companion/creative_preview');
  static const maxModelTurns = 24;
  static const maxFailures = 6;

  static Timer startPolling(AppDatabase db) {
    var running = false;
    final worker = CreativeWorker(db);
    return Timer.periodic(const Duration(seconds: 5), (_) async {
      if (running) return;
      running = true;
      try { await worker.runOnce(); } catch (_) {} finally { running = false; }
    });
  }

  /// One model turn plus its durable tools. Chat has its own client and lease;
  /// an ordinary message neither cancels nor restarts this authorized work.
  Future<void> runOnce() async {
    if (!await db.brainWorkAllowed()) return;
    final store = CreativeStore(db);
    final candidates = (await store.list(pendingOnly: true)).reversed.where(
        (w) => (w['retry_at'] as num? ?? 0) <= now().millisecondsSinceEpoch).toList();
    if (candidates.isEmpty ||
        !await db.tryAcquireLocalLease(lease, holdFor: const Duration(minutes: 6))) return;
    DeepSeekClient? client;
    try {
      var work = await store.get(candidates.first['id'] as String);
      if (!CreativeContract.active.contains(work['status'])) return;
      final fence = await db.captureBrainWorkFence(leaseKey: lease);
      if (fence == null) return;
      final id = work['id'] as String;
      var agent = CreativeContract.decode(await db.getSetting(CreativeWorkspace.key(id)));
      Future<bool> current() async => await db.brainWorkFenceCurrent(fence) &&
          jsonEncode(await store.get(id)) == jsonEncode(work);
      Future<void> checkpoint(Map<String, dynamic> patch,
          {Map<String, String> extra = const {}}) async {
        CreativeWorkspace.validate(agent, id);
        final after = {...work, ...patch,
          'agent_step': (work['agent_step'] as num? ?? 0).toInt() + 1};
        if (!await store.write(work, after, fence: fence, extra: {
          ...extra, CreativeWorkspace.key(id): jsonEncode(agent),
        })) throw const BrainWorkInvalidated();
        work = after;
      }
      void feedback(Map<String, Object?> receipt) {
        agent['feedback'] = [...(agent['feedback'] as List? ?? []), receipt]
            .reversed.take(8).toList().reversed.toList();
      }
      List<Object?> traces(Map<String, Object?> event) =>
          [...(work['agent_trace'] as List? ?? []), {'at': now().millisecondsSinceEpoch, ...event}]
              .reversed.take(16).toList().reversed.toList();
      var finishReason = '';
      var contentCharacters = 0;
      var reasoningCharacters = 0;
      var argumentCharacters = 0;
      DeepSeekUsageEvent? usage;
      final watch = Stopwatch()..start();
      try {
        if (agent.isEmpty || agent['request_id'] != work['request_id']) {
          final source = (work['draft'] as String? ?? '').isNotEmpty ? work['draft'] : work['current'];
          final html = source is String && source.isNotEmpty
              ? await db.getSetting('${CreativeContract.sourcePrefix}$source') ?? '' : '';
          agent = CreativeWorkspace.create(id, work['request_id'] as String, html: html);
          final original = await store.originalRequest(work);
          await checkpoint({'original_request': original, 'agent_version': 1,
            'status': 'queued', 'note': html.isEmpty ? '正在构思作品' : '从已保存的作品继续制作'});
        }
        CreativeWorkspace.validate(agent, id);
        if ((agent['pending'] as List).isEmpty) {
          final attempts = (work['attempts'] as num? ?? 0).toInt();
          if (attempts >= maxModelTurns) {
            await checkpoint({'status': 'paused', 'note': _savedNote(agent, '本次制作已到自动运行上限'), 'retry_at': 0});
            return;
          }
          final apiKey = await SecureConfig.instance.readApiKey();
          if (apiKey == null || apiKey.isEmpty) {
            await checkpoint({'status': 'paused', 'note': '请先设置 DeepSeek API', 'retry_at': 0});
            return;
          }
          if (agent['request_inflight'] == true) {
            agent['recovery'] = '上次请求没有完整返回，未执行其不完整工具。请从现有文件继续，不要重写已完成的部分。';
          }
          CreativeWorkspace.compact(agent);
          agent['request_inflight'] = true;
          await checkpoint({'status': 'building', 'attempts': attempts + 1,
            'note': CreativeWorkspace.files(agent).isEmpty ? '正在构思和制作' : '正在继续制作与检查', 'retry_at': 0});
          client = clientFactory?.call(() async => !await current()) ?? DeepSeekClient(
            abortWhen: () async => !await current(),
            onUsage: (event) async {
              usage = event;
              if (await db.brainWorkFenceCurrent(fence)) await ModelUsageTelemetry.record(db, event);
            });
          final content = StringBuffer();
          final reasoning = StringBuffer();
          final calls = AgentNativeToolCallAccumulator();
          Future<void> collect() async {
            await for (final delta in client!.streamChat(
              apiKey: apiKey, endpoint: await SecureConfig.instance.readEndpoint(),
              model: DeepSeekModelProfile.fromApiName(work['model'] as String?),
              effort: ReasoningEffort.fromApiName(work['effort'] as String?),
              thinking: true, maxTokens: agent['larger_output'] == true ? 128000 : 64000,
              requestTimeout: const Duration(seconds: 180),
              usageLane: 'creative_build', usageExecutionId: '$id:${work['agent_step']}',
              messages: CreativeWorkspace.messages(agent, work), tools: CreativeWorkspace.tools,
            )) {
              content.write(delta.content); reasoning.write(delta.reasoning);
              calls.addAll(delta.toolCallDeltas);
              contentCharacters += delta.content.length;
              reasoningCharacters += delta.reasoning.length;
              for (final call in delta.toolCallDeltas) { argumentCharacters += call.argumentsFragment.length; }
              if (delta.finishReason != null) finishReason = delta.finishReason!;
              if (contentCharacters + reasoningCharacters + argumentCharacters > 600000 || calls.length > 8) {
                throw const _CreativeResponseError('response_too_large');
              }
            }
          }
          await collect().timeout(const Duration(minutes: 4));
          if (!await current()) throw const BrainWorkInvalidated();
          agent['request_inflight'] = false;
          if (finishReason == 'length') {
            agent['larger_output'] = true;
            throw const _CreativeResponseError('length');
          }
          if (finishReason != 'tool_calls' || calls.isEmpty) {
            throw _CreativeResponseError(finishReason.isEmpty ? 'incomplete_stream' : 'missing_tool_calls');
          }
          final built = calls.build(limit: 8);
          if (built.map((c) => c.id).toSet().length != built.length) {
            throw const _CreativeResponseError('duplicate_tool_id');
          }
          agent['history'] = [...(agent['history'] as List), {
            'role': 'assistant', 'content': content.toString(),
            'reasoning_content': reasoning.toString(),
            'tool_calls': built.map((c) => c.toAssistantMap()).toList(),
          }];
          agent['pending'] = built.map((c) => {
            'id': c.id, 'name': c.name, 'arguments': c.arguments,
          }).toList();
          agent['next_tool'] = 0;
          agent['recovery'] = '';
          // Receipt before effects: after a process loss the tools below resume
          // without requesting this already completed model turn again.
          await checkpoint({'agent_trace': traces({
            'kind': 'model', 'finish_reason': finishReason,
            'content_characters': contentCharacters, 'reasoning_characters': reasoningCharacters,
            'argument_characters': argumentCharacters, 'tool_count': built.length,
            'elapsed_ms': watch.elapsedMilliseconds,
            if (usage != null) 'input_tokens': usage!.inputTokens,
            if (usage != null) 'output_tokens': usage!.outputTokens,
          })});
        }

        final pending = List<Map<String, dynamic>>.from(
            (agent['pending'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
        for (var i = agent['next_tool'] as int; i < pending.length; i++) {
          if (!await current()) throw const BrainWorkInvalidated();
          final call = pending[i];
          final name = call['name'] as String;
          final snapshot = jsonEncode(agent);
          Map<String, Object?> result;
          var patch = <String, dynamic>{'status': 'building', 'note': '正在继续制作'};
          var extra = <String, String>{};
          var published = false;
          try {
            final args = CreativeContract.decode(call['arguments'] as String);
            switch (name) {
              case 'work_plan':
                if (args['title'] is! String || (args['title'] as String).trim().isEmpty ||
                    args['plan'] is! String || args['intro'] is! String ||
                    !{'companion', 'local'}.contains(args['interaction'])) {
                  throw const FormatException('计划需要 title、intro、plan 和 interaction(companion/local)');
                }
                agent['plan'] = {'plan': CreativeContract.clip(args['plan'], 2400), 'interaction': args['interaction']};
                agent['verification'] = <String, Object?>{};
                patch.addAll({'title': CreativeContract.clip(args['title'], 60),
                  'intro': CreativeContract.clip(args['intro'], 180), 'note': '正在实现作品构思'});
                result = {'ok': true, 'saved_plan': agent['plan']};
              case 'work_read':
                result = {'ok': true, ...CreativeWorkspace.read(agent, args)};
              case 'work_write':
              case 'work_patch':
                result = {'ok': true, ...CreativeWorkspace.edit(agent, args, patch: name == 'work_patch')};
                patch['note'] = name == 'work_patch' ? '正在修改作品细节' : '正在编写作品';
                if ((CreativeWorkspace.files(agent)['index.html'] ?? '').trim().isNotEmpty) {
                  final html = CreativeWorkspace.assemble(agent);
                  final hash = CreativeContract.hash(html);
                  patch['draft'] = hash;
                  extra['${CreativeContract.sourcePrefix}$hash'] = html;
                }
              case 'work_preview':
                final checks = _checks(args['checks']);
                final html = CreativeWorkspace.assemble(agent);
                final hash = CreativeContract.hash(html);
                await checkpoint({'status': 'checking', 'note': '正在后台试玩', 'draft': hash},
                  extra: {'${CreativeContract.sourcePrefix}$hash': html});
                final observed = await preview.invokeMapMethod<String, dynamic>('preview', {
                  'html': html, 'checks': checks,
                }).timeout(const Duration(seconds: 30));
                if (!await current()) throw const BrainWorkInvalidated();
                final errors = (observed?['errors'] as List? ?? ['未收到试玩结果'])
                    .map((e) => CreativeContract.clip(e, 300)).take(12).toList();
                final companion = (agent['plan'] as Map?)?['interaction'] == 'companion';
                final choices = (observed?['choose_count'] as num? ?? 0).toInt();
                final reveals = (observed?['reveal_count'] as num? ?? 0).toInt();
                if (companion && (choices < 1 || reveals < 1)) {
                  errors.add('互动作品需要实际完成 companion.choose 和 reveal 的试玩回合，不能只检查标题或随机对手');
                }
                final ok = observed?['ok'] == true && errors.isEmpty;
                var cover = '';
                final path = observed?['screenshot'];
                if (ok && path is String) {
                  final file = File(path);
                  if (await file.exists() && await file.length() < 180000) cover = base64Encode(await file.readAsBytes());
                }
                agent['verification'] = {'hash': hash, 'ok': ok, 'checks': checks,
                  'choose_count': choices, 'reveal_count': reveals, 'cover': cover};
                result = {'ok': ok, 'hash': hash, 'errors': errors,
                  'choose_count': choices, 'reveal_count': reveals,
                  'page_text': CreativeContract.clip(observed?['page_text'], 1800),
                  'elements': CreativeContract.clip(jsonEncode(observed?['elements'] ?? []), 3000)};
                patch.addAll({'errors': errors, 'note': ok ? '试玩通过，正在完成作品' : '试玩发现问题，正在修复'});
              case 'work_finish':
                if (i != pending.length - 1) throw const FormatException('work_finish 必须是本轮最后一个调用');
                final html = CreativeWorkspace.assemble(agent);
                final hash = CreativeContract.hash(html);
                final verified = agent['verification'] as Map? ?? {};
                final plan = agent['plan'] as Map? ?? {};
                if (plan['interaction'] == null || verified['ok'] != true || verified['hash'] != hash) {
                  throw const FormatException('请先明确体验计划，并对当前版本完成 work_preview；修改后的版本需要重新试玩');
                }
                if (plan['interaction'] == 'companion' &&
                    ((verified['choose_count'] as num? ?? 0) < 1 || (verified['reveal_count'] as num? ?? 0) < 1)) {
                  throw const FormatException('尚未验证真实伴侣互动路径');
                }
                final versions = <String>{hash, ...(work['versions'] as List? ?? []).whereType<String>()}.take(3).toList();
                patch.addAll({'current': hash, 'draft': '', 'versions': versions,
                  'status': 'ready', 'note': '做好了，可以打开试玩',
                  'cover': verified['cover'] ?? '', 'errors': <Object?>[],
                  'updated': now().millisecondsSinceEpoch, 'retry_at': 0});
                extra['${CreativeContract.sourcePrefix}$hash'] = html;
                result = {'ok': true, 'published': true, 'hash': hash};
                published = true;
              default:
                throw const FormatException('未知工具，请使用工作区提供的工具');
            }
          } on BrainWorkInvalidated { rethrow;
          } on MissingPluginException { rethrow;
          } on PlatformException { rethrow;
          } catch (error) {
            agent = CreativeContract.decode(snapshot);
            patch = {'status': 'building', 'note': '正在修正制作步骤'};
            extra = {};
            result = {'ok': false, 'error': error is FormatException
                ? CreativeContract.clip(error.message, 300) : '工具参数或执行错误：${error.runtimeType}'};
          }
          final failures = result['ok'] == true ? 0 : (agent['failures'] as num? ?? 0).toInt() + 1;
          agent['failures'] = failures;
          agent['next_tool'] = i + 1;
          agent['history'] = [...(agent['history'] as List), {
            'role': 'tool', 'tool_call_id': call['id'], 'content': jsonEncode(result),
          }];
          final receipt = {...result};
          // Large file reads are already in the current exchange. The compact
          // continuation keeps a receipt, not another copy of the source.
          if (receipt.containsKey('content')) receipt['content'] = '(内容已返回；需要时重新读取文件)';
          feedback({'tool': name, ...receipt});
          if (agent['next_tool'] == pending.length) {
            agent['pending'] = <Object?>[]; agent['next_tool'] = 0;
            CreativeWorkspace.compact(agent);
          }
          if (!published && failures >= maxFailures) {
            patch.addAll({'status': 'paused', 'note': _savedNote(agent, '连续修复未完成，已暂停'), 'retry_at': 0});
          }
          patch['agent_trace'] = traces({'kind': 'tool', 'tool': name, 'ok': result['ok'] == true,
            'files': CreativeWorkspace.files(agent).length});
          // File effects, tool receipt and cursor are one transaction. Replaying
          // after a process exit cannot append the same chunk twice.
          await checkpoint(patch, extra: extra);
          if (published || failures >= maxFailures) {
            await store.collectUnusedSources();
            return;
          }
        }
        await store.collectUnusedSources();
      } on BrainWorkInvalidated {
        // Stop/delete/import wins. An old loop must not write a failure over it.
      } catch (error) {
        client?.close();
        if (!await current()) return;
        if (agent.isEmpty) return;
        agent['request_inflight'] = false;
        final failures = (agent['failures'] as num? ?? 0).toInt() + 1;
        agent['failures'] = failures;
        final statusCode = error is DeepSeekException ? error.statusCode : 0;
        final code = error is _CreativeResponseError ? error.code :
            error is TimeoutException ? 'timeout' :
            statusCode != 0 ? 'http_$statusCode' : error.runtimeType.toString();
        final configuration = {400, 401, 402, 403, 404, 422}.contains(statusCode);
        final infrastructure = error is MissingPluginException || error is PlatformException;
        final pause = configuration || infrastructure || failures >= maxFailures;
        final reason = code == 'length'
            ? '输出达到长度上限；未执行截断工具。请缩短单步计划和写入块，使用分块追加，继续已有文件。'
            : code == 'missing_tool_calls' ? '需要调用工作工具才能制作或提交。请执行具体工具步骤，不要只回复说明。'
            : '上一步未完整完成（$code）；保留已有文件，请检查并从现有进度继续。';
        agent['recovery'] = reason;
        feedback({'kind': 'recovery', 'code': code, 'message': reason});
        final delay = error is _CreativeResponseError ? 5 : (15 * (1 << (failures - 1).clamp(0, 4)));
        await checkpoint({'status': pause ? 'paused' : 'queued',
          'note': configuration ? _savedNote(agent, 'DeepSeek 配置或余额需要处理') :
              infrastructure ? _savedNote(agent, '后台试玩暂不可用') :
              pause ? _savedNote(agent, '多次恢复未完成，已暂停') :
              _savedNote(agent, code == 'length' ? '输出未完整返回，正在调整后继续' : '制作遇到临时问题，稍后自动继续'),
          'errors': [code], 'retry_at': pause ? 0 : now().add(Duration(seconds: delay)).millisecondsSinceEpoch,
          'agent_trace': traces({'kind': 'recovery', 'code': code,
            'finish_reason': finishReason, 'content_characters': contentCharacters,
            'reasoning_characters': reasoningCharacters, 'argument_characters': argumentCharacters,
            'elapsed_ms': watch.elapsedMilliseconds,
            if (usage != null) 'input_tokens': usage!.inputTokens,
            if (usage != null) 'output_tokens': usage!.outputTokens,
          })});
      }
    } finally {
      client?.close();
      await db.releaseLocalLease(lease);
    }
  }

  static String _savedNote(Map<String, dynamic> agent, String reason) =>
      '$reason；${CreativeWorkspace.files(agent).isEmpty ? '尚未生成有效草稿' : '已保存制作进度'}';

  static List<Map<String, String>> _checks(Object? raw) {
    if (raw is! List || raw.isEmpty || raw.length > 6) {
      throw const FormatException('试玩需要 1–6 项检查');
    }
    return raw.map((item) {
      if (item is! Map || item['selector'] is! String ||
          (item['selector'] as String).trim().isEmpty || item['text'] is! String ||
          (item['click'] != null && item['click'] is! String)) {
        throw const FormatException('每项检查需要 selector 和 text，可选 click');
      }
      final check = <String, String>{for (final k in ['click', 'selector', 'text']) k: item[k] as String? ?? ''};
      if (check.values.any((v) => v.length > 300)) throw const FormatException('检查内容超过 300 字符');
      return check;
    }).toList();
  }
}

class _CreativeResponseError implements Exception {
  const _CreativeResponseError(this.code);
  final String code;
}
