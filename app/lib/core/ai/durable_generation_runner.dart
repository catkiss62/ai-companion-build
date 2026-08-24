import 'dart:async';

import '../agent/agent_tool.dart';
import '../agent/agent_tool_planner.dart';
import '../agent/agent_tool_runner.dart';
import '../database/app_database.dart';
import '../desire/desire_engine.dart';
import '../emotion/emotion_classifier_service.dart';
import '../emotion/emotion_episode_engine.dart';
import '../emotion/emotion_contract.dart';
import '../grounding/service_template_guard.dart';
import '../models/chat_message.dart';
import '../models/chat_segment.dart';
import '../models/desire_state.dart';
import '../models/generation_job.dart';
import '../somatic/somatic_engine.dart';
import '../storage/secure_config.dart';
import '../platform/android_bridge.dart';
import 'deepseek_client.dart';
import 'generation_cancellation.dart';
import 'model_profile.dart';
import 'nsfw_context_router.dart';
import 'prompt_builder.dart';

final class _DeepSeekToolCallBuilder {
  _DeepSeekToolCallBuilder(this.index);

  final int index;
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();

  void add(DeepSeekToolCallDelta fragment) {
    if (fragment.id.isNotEmpty) id = fragment.id;
    if (fragment.name.isNotEmpty) name = fragment.name;
    if (fragment.argumentsFragment.isNotEmpty) {
      arguments.write(fragment.argumentsFragment);
    }
  }

  DeepSeekToolCall build() => DeepSeekToolCall(
        id: id.isEmpty ? 'call_$index' : id,
        name: name,
        arguments: arguments.toString(),
      );
}

class GenerationRunResult {
  const GenerationRunResult({
    required this.status,
    this.assistant,
    this.error,
    this.retryAt,
  });

  final String status;
  final ChatMessage? assistant;
  final Object? error;
  final DateTime? retryAt;

  bool get completed => status == 'completed' && assistant != null;
  bool get retryScheduled => status == 'retry_wait';
}

class GenerationSuspendedException implements Exception {
  const GenerationSuspendedException(this.reason);
  final String reason;

  @override
  String toString() => reason;
}

class GenerationStreamIncompleteException implements Exception {
  const GenerationStreamIncompleteException();

  @override
  String toString() => 'DeepSeek 流式连接在收到完成标记前结束';
}

/// Runs one durable assistant-generation job.
///
/// The caller must own `chat_turn_lease`. The job itself is durable in SQLite,
/// while the API stream is intentionally restartable rather than resumable:
/// DeepSeek does not expose a stream-resume cursor. Checkpoints are diagnostics
/// and crash evidence; a recovered attempt starts from the same committed user
/// turn and writes the assistant message only once in a final SQLite transaction.
class DurableGenerationRunner {
  DurableGenerationRunner({
    required this.db,
    required this.client,
    SecureConfig? secureConfig,
    EmotionClassifierService? emotionClassifier,
  })  : secureConfig = secureConfig ?? SecureConfig.instance,
        emotionClassifier =
            emotionClassifier ?? EmotionClassifierService.instance,
        desireEngine = DesireEngine(db),
        somaticEngine = SomaticEngine(db),
        emotionEpisodeEngine = EmotionEpisodeEngine(db),
        nsfwRouter = NsfwContextRouter(db: db, client: client),
        agentToolRunner = AgentToolRunner(
          db: db,
          android: AndroidBridge.instance,
          secureConfig: secureConfig ?? SecureConfig.instance,
        );

  final AppDatabase db;
  final DeepSeekClient client;
  final SecureConfig secureConfig;
  final EmotionClassifierService emotionClassifier;
  final DesireEngine desireEngine;
  final SomaticEngine somaticEngine;
  final EmotionEpisodeEngine emotionEpisodeEngine;
  final NsfwContextRouter nsfwRouter;
  final AgentToolRunner agentToolRunner;

  Future<GenerationRunResult> run(
    GenerationJob requested, {
    void Function(DeepSeekDelta delta)? onDelta,
    void Function(NsfwRouteDecision decision)? onNsfwRoute,
    void Function(AgentToolActivity activity)? onAgentToolActivity,
    void Function(String emotionKey)? onEmotionCue,
    GenerationCancellationToken? cancellationToken,
  }) async {
    if (cancellationToken?.isCancelled ?? false) {
      await db.cancelGenerationJobByUser(requested.id);
      return const GenerationRunResult(status: 'cancelled_by_user');
    }
    if (!await db.brainWorkAllowed()) {
      return const GenerationRunResult(status: 'suspended');
    }

    // API credentials are device-local and intentionally excluded from state
    // transfer. Check them before claiming so a newly transferred pending job
    // does not burn an attempt simply because the new device has not configured
    // its key yet.
    final apiKey = await secureConfig.readApiKey();
    final endpoint = await secureConfig.readEndpoint();
    if (cancellationToken?.isCancelled ?? false) {
      await db.cancelGenerationJobByUser(requested.id);
      return const GenerationRunResult(status: 'cancelled_by_user');
    }
    if (apiKey == null || apiKey.isEmpty) {
      final retryAt = await db.deferGenerationJob(
        requested.id,
        delay: const Duration(minutes: 2),
        reason: 'missing_api_key',
      );
      return GenerationRunResult(
        status: retryAt == null ? 'unavailable' : 'retry_wait',
        error: '请先在当前设备配置 DeepSeek API Key。',
        retryAt: retryAt,
      );
    }

    final job = await db.claimGenerationJob(requested.id);
    if (job == null) {
      final latest = await db.generationJobById(requested.id);
      if (latest?.status == 'completed') {
        final assistant = await db.messageById(latest!.assistantMessageId);
        return GenerationRunResult(status: 'completed', assistant: assistant);
      }
      return GenerationRunResult(status: latest?.status ?? 'unavailable');
    }

    if (cancellationToken?.isCancelled ?? false) {
      await db.cancelGenerationJobByUser(job.id);
      return const GenerationRunResult(status: 'cancelled_by_user');
    }

    final user = await db.messageById(job.userMessageId);
    if (user == null || !user.isUser) {
      final failed = await db.failGenerationJob(
        job.id,
        runToken: job.runToken,
        error: 'missing_user_message',
        recoverable: false,
      );
      return GenerationRunResult(
        status: failed == null ? 'suspended' : 'failed',
        error: '恢复任务找不到对应用户消息。',
      );
    }

    var lastCheckpoint = DateTime.now();
    var charsAtCheckpoint = 0;
    var lastLeaseRefresh = DateTime.now();
    var lastFenceCheck = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      final previous = await db.messagesBefore(user.createdAt, limit: 33);
      final recent = <ChatMessage>[...previous, user];
      // Capture after the durable user turn exists and before prompt build.
      // Stable event IDs make recovered attempts idempotent; cancellation
      // withdraws these events with the user message.
      await somaticEngine.captureUserTurn(
        turnId: user.id,
        text: user.content,
        now: user.createdAt,
      );
      final desire = await db.loadDesire();
      await emotionEpisodeEngine.appraiseUserTurn(
        user: user,
        desire: desire,
        previousConversationAt:
            previous.isEmpty ? null : previous.last.createdAt,
        now: user.createdAt,
      );
      final thoughts = await db.activeThoughts(limit: 18);
      final nsfwRoute = await nsfwRouter.decide(
        apiKey: apiKey,
        endpoint: endpoint,
        turnId: user.id,
        latestUserText: user.content,
        recent: recent,
        cancellationToken: cancellationToken,
      );
      onNsfwRoute?.call(nsfwRoute);
      await _publishToolRuntime(
        phase: 'thinking',
        statusText: '',
        toolId: '',
      );
      void emitToolActivity(AgentToolActivity activity) {
        onAgentToolActivity?.call(activity);
        unawaited(_publishToolRuntime(
          phase: activity.active ? 'thinking' : 'answering',
          statusText: activity.text,
          toolId: activity.toolId,
        ));
      }

      var agentToolResults = const <AgentToolResult>[];
      var announcedEmotionKey = '';
      final localPlan = AgentToolPlanner.routeLocally(user.content);
      if (localPlan != null) {
        agentToolResults = await agentToolRunner.runPlan(
          localPlan,
          onActivity: emitToolActivity,
          cancellationToken: cancellationToken,
        );
      }
      final baseRequestMessages = await PromptBuilder(db).buildChatMessages(
        latestUserText: user.content,
        recent: recent,
        desire: desire,
        thoughts: thoughts,
        nsfwActive: nsfwRoute.active,
        nsfwReferenceActive: nsfwRoute.referenceActive,
        agentToolResults: agentToolResults,
      );
      Future<({
        String reasoning,
        String content,
        List<DeepSeekToolCall> toolCalls,
      })> generate(
        List<Map<String, Object?>> messages, {
        bool emitDeltas = true,
        List<Map<String, Object?>> tools = const <Map<String, Object?>>[],
      }) async {
        var reasoning = '';
        var content = '';
        var emittedVisibleContent = '';
        var sawTerminalSignal = false;
        var publishedAnswering = false;
        final toolCallBuilders = <int, _DeepSeekToolCallBuilder>{};
        charsAtCheckpoint = 0;
        lastCheckpoint = DateTime.now();
        await for (final delta in client.streamChat(
          apiKey: apiKey,
          model: DeepSeekModelProfile.fromApiName(job.model),
          effort: ReasoningEffort.fromApiName(job.reasoningEffort),
          messages: messages,
          endpoint: endpoint,
          thinking: job.thinking,
          tools: tools,
          cancellationToken: cancellationToken,
        )) {
          cancellationToken?.throwIfCancelled();
          if (!await db.brainWorkAllowed()) {
            throw const GenerationSuspendedException('设备正在转移或已经下线');
          }

          final now = DateTime.now();
          if (now.difference(lastFenceCheck) >=
              const Duration(milliseconds: 200)) {
            final current = await db.isGenerationRunCurrent(
              job.id,
              runToken: job.runToken,
            );
            if (!current) {
              final latest = await db.generationJobById(job.id);
              if (latest?.status == 'cancelled_by_user') {
                throw const GenerationCancelledByUserException();
              }
              throw const GenerationSuspendedException(
                '本次生成尝试的写入所有权已经失效',
              );
            }
            lastFenceCheck = now;
          }
          if (now.difference(lastLeaseRefresh) >= const Duration(seconds: 10)) {
            final renewed = await db.renewLocalLease(
              'chat_turn_lease',
              holdFor: const Duration(seconds: 30),
            );
            if (!renewed) {
              throw const GenerationSuspendedException('聊天写入权限已经转移');
            }
            lastLeaseRefresh = now;
          }

          if (delta.done || delta.finishReason != null) {
            sawTerminalSignal = true;
          }
          if (delta.reasoning.isNotEmpty) reasoning += delta.reasoning;
          if (delta.content.isNotEmpty) {
            content += delta.content;
            if (announcedEmotionKey.isEmpty) {
              final partialEnvelope = EmotionEnvelope.parse(content);
              final emotionKey =
                  EmotionCatalog.keyForLabel(partialEnvelope.rawTag);
              if (partialEnvelope.found && emotionKey.isNotEmpty) {
                announcedEmotionKey = emotionKey;
                onEmotionCue?.call(emotionKey);
              }
            }
            if (!publishedAnswering) {
              publishedAnswering = true;
              unawaited(_publishToolRuntime(
                phase: 'answering',
                statusText: '',
                toolId: '',
              ));
            }
          }
          for (final fragment in delta.toolCallDeltas) {
            toolCallBuilders
                .putIfAbsent(
                  fragment.index,
                  () => _DeepSeekToolCallBuilder(fragment.index),
                )
                .add(fragment);
          }
          if (!emitDeltas && delta.reasoning.isNotEmpty) {
            onDelta?.call(DeepSeekDelta(reasoning: delta.reasoning));
          }
          if (emitDeltas) {
            // Hold the leading machine-readable emotion envelope out of the
            // visible bubble and streaming TTS. Providers that ignore the
            // contract still stream ordinary text without waiting for commit.
            final visibleContent = EmotionEnvelope.streamingVisible(content);
            final visibleDelta = visibleContent.startsWith(emittedVisibleContent)
                ? visibleContent.substring(emittedVisibleContent.length)
                : visibleContent;
            emittedVisibleContent = visibleContent;
            // Publish provider reasoning as it arrives so both chat surfaces
            // can expand the reasoning panel immediately. Prompt language
            // guidance still prefers Chinese without rewriting model thought.
            onDelta?.call(DeepSeekDelta(
              reasoning: delta.reasoning,
              content: visibleDelta,
              done: delta.done,
              finishReason: delta.finishReason,
              toolCallDeltas: delta.toolCallDeltas,
            ));
          }

          final chars = reasoning.length + content.length;
          if (now.difference(lastCheckpoint) >= const Duration(seconds: 2) ||
              chars - charsAtCheckpoint >= 768) {
            final checkpointed = await db.checkpointGenerationJob(
              job.id,
              runToken: job.runToken,
              partialReasoning: reasoning,
              partialContent: content,
            );
            if (!checkpointed) {
              throw const GenerationSuspendedException(
                '本次生成尝试的写入所有权已经过期',
              );
            }
            lastCheckpoint = now;
            charsAtCheckpoint = chars;
          }
        }
        if (!sawTerminalSignal) {
          throw const GenerationStreamIncompleteException();
        }
        final indexes = toolCallBuilders.keys.toList()..sort();
        final toolCalls = indexes
            .map((index) => toolCallBuilders[index]!.build())
            .take(2)
            .toList(growable: false);
        return (
          reasoning: reasoning.trim(),
          content: content.trim(),
          toolCalls: toolCalls,
        );
      }

      var finalRequestMessages = baseRequestMessages;
      var generated = await generate(
        baseRequestMessages,
        emitDeltas: localPlan != null,
        tools: localPlan == null
            ? AgentToolPlanner.nativeToolDefinitions
            : const <Map<String, Object?>>[],
      );
      cancellationToken?.throwIfCancelled();

      if (localPlan == null && generated.toolCalls.isEmpty) {
        onDelta?.call(DeepSeekDelta(content: generated.content));
      }

      if (localPlan == null && generated.toolCalls.isNotEmpty) {
        final nativePlan =
            AgentToolPlanner.fromNativeToolCalls(generated.toolCalls);
        if (nativePlan.isEmpty) {
          throw const FormatException('模型返回了无法验证的工具调用');
        }
        agentToolResults = await agentToolRunner.runPlan(
          nativePlan,
          onActivity: emitToolActivity,
          cancellationToken: cancellationToken,
        );
        cancellationToken?.throwIfCancelled();

        final acceptedCalls = <DeepSeekToolCall>[];
        final remaining = generated.toolCalls.toList();
        for (final call in nativePlan.calls) {
          final nativeName =
              AgentToolPlanner.nativeNameForToolId(call.toolId);
          final index = remaining.indexWhere(
            (candidate) => candidate.name == nativeName,
          );
          if (index >= 0) acceptedCalls.add(remaining.removeAt(index));
        }
        if (acceptedCalls.length != agentToolResults.length) {
          throw const FormatException('工具调用与本地执行结果无法对应');
        }

        final assistantToolMessage = <String, Object?>{
          'role': 'assistant',
          'content': generated.content.isEmpty ? null : generated.content,
          if (generated.reasoning.isNotEmpty)
            'reasoning_content': generated.reasoning,
          'tool_calls': acceptedCalls
              .map((call) => call.toAssistantMap())
              .toList(growable: false),
        };
        final toolResultMessages = <Map<String, Object?>>[
          for (var index = 0; index < acceptedCalls.length; index++)
            <String, Object?>{
              'role': 'tool',
              'tool_call_id': acceptedCalls[index].id,
              'content': agentToolResults[index].promptData,
            },
        ];
        finalRequestMessages = <Map<String, Object?>>[
          ...baseRequestMessages,
          assistantToolMessage,
          ...toolResultMessages,
          <String, Object?>{
            'role': 'system',
            'content': '''
【工具结果后的中文表达约束】
工具路由与搜索过程已经结束。现在只用自然中文形成她自己的可见思考与最终正文；专业名词可保留英文。不得复述英文工具规划、参数、调用日志或搜索步骤。
'''.trim(),
          },
        ];
        await _publishToolRuntime(
          phase: 'thinking',
          statusText: '正在整理工具结果…',
          toolId: '',
        );
        generated = await generate(finalRequestMessages);
        cancellationToken?.throwIfCancelled();
      }

      if (generated.content.isEmpty) {
        throw const FormatException('模型没有返回可用正文');
      }

      final recentAssistantTexts = previous
          .where((message) => message.isAssistant)
          .map((message) => message.content);
      var envelope = EmotionEnvelope.parse(generated.content);
      var finalContent = envelope.visibleText;
      var serviceGuard = ServiceTemplateGuard.evaluate(
        text: finalContent,
        recentAssistantTexts: recentAssistantTexts,
        currentUserText: user.content,
      );
      if (!serviceGuard.allowed) {
        await ServiceTemplateGuardTelemetry.note(
          db,
          result: serviceGuard,
          mode: 'user_turn',
          action: 'rewrite',
        );
        final correctionMessages = <Map<String, Object?>>[
          ...finalRequestMessages,
          {
            'role': 'system',
            'content': '''
【NATURAL OUTPUT CORRECTION · ONE RETRY】
上一份正文命中了重复的服务模板语义：${serviceGuard.reason} / ${serviceGuard.family}。
完全丢弃“一直在、不走、不催、你忙你的、等你忙完、无条件顺从”这类承诺—退场—等待收尾。不要换成近义套话，也不要表演随机叛逆。
重新回应当前真实用户消息：保留具体反应、自己的判断/情绪/需求和真正有内容的部分，在自然落点结束。
'''.trim(),
          },
        ];
        generated = await generate(
          correctionMessages,
          emitDeltas: false,
        );
        cancellationToken?.throwIfCancelled();
        envelope = EmotionEnvelope.parse(generated.content);
        finalContent = envelope.visibleText;
        serviceGuard = ServiceTemplateGuard.evaluate(
          text: finalContent,
          recentAssistantTexts: recentAssistantTexts,
          currentUserText: user.content,
        );
        if (!serviceGuard.allowed) {
          final stripped =
              ServiceTemplateGuard.removeTemplateSentences(finalContent);
          final strippedGuard = ServiceTemplateGuard.evaluate(
            text: stripped,
            recentAssistantTexts: recentAssistantTexts,
            currentUserText: user.content,
          );
          if (stripped.isNotEmpty && strippedGuard.allowed) {
            finalContent = stripped;
          } else {
            await ServiceTemplateGuardTelemetry.note(
              db,
              result: serviceGuard,
              mode: 'user_turn',
              action: 'block',
            );
            throw const FormatException(
              '模型连续返回服务模板，已阻止写入',
            );
          }
        }
      }
      if (finalContent.trim().isEmpty) {
        throw const FormatException('模板重写后正文为空');
      }

      final companionEmotion = await emotionClassifier.resolve(
        rawTag: envelope.rawTag,
        visibleText: finalContent,
        envelopeStatus: envelope.status,
      );

      final visibleReasoning = preserveProviderReasoning(generated.reasoning);
      if (visibleReasoning.isNotEmpty) {
        onDelta?.call(DeepSeekDelta(reasoning: visibleReasoning));
      }

      final assistant = ChatMessage(
        id: job.assistantMessageId,
        role: 'assistant',
        content: finalContent,
        reasoningContent: visibleReasoning,
        model: job.model,
        createdAt: DateTime.now(),
        deviceId: await db.ensureDeviceId(),
        segments: ChatSegmentCodec.parseAssistantText(finalContent),
        emotionRawTag: companionEmotion.rawTag,
        emotionKey: companionEmotion.key,
        emotionLabel: companionEmotion.label,
        emotionConfidence: companionEmotion.confidence,
        emotionTop3Json: companionEmotion.top3Json,
        emotionSource: companionEmotion.source,
      );
      // Detection is pure; persistence happens only inside the winning
      // durable commit transaction below.
      final assistantSomaticEvents = somaticEngine.assistantCommitEvents(
        turnId: assistant.id,
        text: assistant.content,
        now: assistant.createdAt,
      );
      final committed = await db.completeGenerationJobIfCurrent(
        jobId: job.id,
        runToken: job.runToken,
        assistant: assistant,
        somaticEvents: assistantSomaticEvents,
      );
      if (!committed) {
        await db.suspendGenerationJob(
          job.id,
          reason: 'ownership_changed_before_commit',
          runToken: job.runToken,
        );
        return const GenerationRunResult(status: 'suspended');
      }

      await desireEngine.satisfy(DriveKey.attachment, factor: 0.58);
      return GenerationRunResult(status: 'completed', assistant: assistant);
    } on GenerationCancelledByUserException catch (e) {
      await db.cancelGenerationJobByUser(job.id);
      return GenerationRunResult(status: 'cancelled_by_user', error: e);
    } on GenerationSuspendedException catch (e) {
      await db.suspendGenerationJob(
        job.id,
        reason: e.reason,
        runToken: job.runToken,
      );
      return GenerationRunResult(status: 'suspended', error: e);
    } catch (e) {
      final interrupted = await db.interruptGenerationJob(
        job.id,
        runToken: job.runToken,
        reason: _compactError(e),
      );
      if (!interrupted) {
        return GenerationRunResult(status: 'suspended', error: e);
      }
      return GenerationRunResult(
        status: 'interrupted',
        error: e,
      );
    } finally {
      await _clearToolRuntime();
    }
  }

  Future<void> _publishToolRuntime({
    required String phase,
    required String statusText,
    required String toolId,
  }) async {
    await db.setSetting('agent_tool_runtime_phase', phase);
    await db.setSetting('agent_tool_runtime_status_text', statusText);
    await db.setSetting('agent_tool_runtime_tool_id', toolId);
    await db.setSetting(
      'agent_tool_runtime_updated_at',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> _clearToolRuntime() async {
    await _publishToolRuntime(
      phase: 'idle',
      statusText: '',
      toolId: '',
    );
  }

  bool _recoverable(Object error) {
    if (error is DeepSeekException) {
      return error.statusCode == 401 ||
          error.statusCode == 402 ||
          error.statusCode == 403 ||
          error.statusCode == 408 ||
          error.statusCode == 409 ||
          error.statusCode == 425 ||
          error.statusCode == 429 ||
          error.statusCode >= 500;
    }
    if (error is FormatException) return false;
    if (error is StateError) return false;
    return true;
  }

  String _compactError(Object error) {
    final raw = error.toString();
    return raw.length <= 360 ? raw : raw.substring(0, 360);
  }
}

/// Provider reasoning is optional, but language alone must never erase it.
String preserveProviderReasoning(String raw) => raw.trim();
