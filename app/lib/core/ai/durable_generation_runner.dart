import 'dart:async';

import '../agent/agent_tool.dart';
import '../agent/agent_tool_planner.dart';
import '../agent/agent_tool_runner.dart';
import '../database/app_database.dart';
import '../desire/conversation_initiative_policy.dart';
import '../desire/conversation_outcome_verifier.dart';
import '../desire/thought_lifecycle_engine.dart';
import '../diagnostics/conversation_initiative_telemetry.dart';
import '../diagnostics/conversation_initiative_ablation_telemetry.dart';
import '../diagnostics/visible_reasoning_language_telemetry.dart';
import '../emotion/emotion_classifier_service.dart';
import '../emotion/emotion_episode_engine.dart';
import '../emotion/emotion_contract.dart';
import '../grounding/service_template_guard.dart';
import '../grounding/information_seeking_question_guard.dart';
import '../grounding/operational_claim_grounding_guard.dart';
import '../grounding/user_perspective_guard.dart';
import '../integration/moe_shadow_coordinator.dart';
import '../models/chat_message.dart';
import '../models/chat_segment.dart';
import '../models/desire_state.dart';
import '../models/generation_job.dart';
import '../models/thought.dart';
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
    this.specialStyleTrialId = '',
    this.specialStyleKey = '',
  });

  final String status;
  final ChatMessage? assistant;
  final Object? error;
  final DateTime? retryAt;
  final String specialStyleTrialId;
  final String specialStyleKey;

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
    var generationSpecialStyleTrialId = '';
    var generationSpecialStyleKey = '';

    try {
      final previous = await db.messagesBefore(
        user.createdAt,
        limit: 33,
        notBefore: await db.conversationContextResetAt(),
      );
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
      final conversationPlan = ConversationInitiativePolicy.select(
        snapshot: desire,
        thoughts: thoughts,
        recent: recent,
        latestUserText: user.content,
        now: user.createdAt,
      );
      CompanionThought? sourceConversationThought;
      final sourceThoughtId = conversationPlan.sourceThoughtId;
      if (sourceThoughtId != null) {
        for (final thought in thoughts) {
          if (thought.id == sourceThoughtId) {
            sourceConversationThought = thought;
            break;
          }
        }
      }
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
      var streamedToolPreamble = '';
      var upstreamReasoningDeltaSeen = false;
      var reasoningDeltaForwardedToSurface = false;
      final localPlan = AgentToolPlanner.routeLocally(user.content);
      if (localPlan != null) {
        agentToolResults = await agentToolRunner.runPlan(
          localPlan,
          onActivity: emitToolActivity,
          cancellationToken: cancellationToken,
          eventScopeId: job.id,
          userMessageId: user.id,
        );
      }
      // Legacy special-style snapshots stay in the schema only for backup
      // compatibility. New ordinary-chat roleplay provenance comes from the
      // prompt's world-book context.
      generationSpecialStyleTrialId = '';
      generationSpecialStyleKey = '';
      final promptBuild = await PromptBuilder(db).buildChatPrompt(
        latestUserText: user.content,
        recent: recent,
        desire: desire,
        thoughts: thoughts,
        nsfwActive: nsfwRoute.active,
        nsfwReferenceActive: nsfwRoute.referenceActive,
        agentToolResults: agentToolResults,
        specialStyleKeyOverride: generationSpecialStyleKey,
        conversationInitiativeOverride: conversationPlan,
      );
      final baseRequestMessages = promptBuild.messages;
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
          if (delta.reasoning.isNotEmpty) {
            reasoning += delta.reasoning;
            upstreamReasoningDeltaSeen = true;
          }
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
            if (onDelta != null) reasoningDeltaForwardedToSurface = true;
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
            if (onDelta != null && delta.reasoning.isNotEmpty) {
              reasoningDeltaForwardedToSurface = true;
            }
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
        // Ordinary chat keeps provider reasoning live, but holds the visible
        // body until every guard has approved one durable answer. The chat UI
        // then performs its established local typewriter playback exactly once.
        emitDeltas: false,
        tools: localPlan == null
            ? AgentToolPlanner.nativeToolDefinitionsFor(user.content)
            : const <Map<String, Object?>>[],
      );
      cancellationToken?.throwIfCancelled();

      if (localPlan == null && generated.toolCalls.isNotEmpty) {
        // A provider may legally emit a short preamble before its tool call.
        // Keep it buffered and retain it in the single committed answer.
        streamedToolPreamble =
            EmotionEnvelope.parse(generated.content).visibleText.trim();
        final nativePlan =
            AgentToolPlanner.fromNativeToolCalls(generated.toolCalls);
        if (nativePlan.isEmpty) {
          throw const FormatException('模型返回了无法验证的工具调用');
        }
        agentToolResults = await agentToolRunner.runPlan(
          nativePlan,
          onActivity: emitToolActivity,
          cancellationToken: cancellationToken,
          eventScopeId: job.id,
          userMessageId: user.id,
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
${PromptBuilder.visibleChineseGenerationReminder()}
'''.trim(),
          },
        ];
        await _publishToolRuntime(
          phase: 'thinking',
          statusText: '正在整理工具结果…',
          toolId: '',
        );
        generated = await generate(finalRequestMessages, emitDeltas: false);
        cancellationToken?.throwIfCancelled();
      }

      if (generated.content.isEmpty) {
        throw const FormatException('模型没有返回可用正文');
      }

      final recentAssistantTexts = previous
          .where((message) => message.isAssistant)
          .map((message) => message.content);
      final userPerspectiveContext = <String>[
        user.promptContent,
        ...previous.reversed
            .where((message) => message.isUser)
            .take(3)
            .map((message) => message.promptContent),
      ].join('\n');
      var envelope = EmotionEnvelope.parse(generated.content);
      var finalContent = envelope.visibleText;
      if (streamedToolPreamble.isNotEmpty) {
        finalContent = '$streamedToolPreamble\n\n$finalContent'.trim();
      }
      final promptResponsibilityShape =
          PromptResponsibilityShape.fromMessages(finalRequestMessages);
      final rawExpressionVerification = ConversationOutcomeVerifier.verify(
        finalText: finalContent,
        plan: conversationPlan,
        sourceThought: sourceConversationThought,
      );
      var ablationTransformation = 'none';
      final serviceGuard = ServiceTemplateGuard.evaluate(
        text: finalContent,
        recentAssistantTexts: recentAssistantTexts,
        currentUserText: user.content,
      );
      final perspectiveGuard = UserPerspectiveGuard.evaluate(
        finalContent,
        currentUserText: userPerspectiveContext,
      );
      var operationGuard = OperationalClaimGroundingGuard.evaluate(
        // Visible reasoning is inner deliberation, not an outward factual
        // claim. Only the message the user will actually receive is guarded.
        text: finalContent,
        currentToolResults: agentToolResults,
      );
      final questionGuard = InformationSeekingQuestionGuard.evaluate(
        text: finalContent,
        askAuthorized: conversationPlan.askAuthorized,
      );
      var expressionVerification = rawExpressionVerification;
      // v0.41.26 ablation: style-quality detectors remain observable but no
      // longer rewrite or block ordinary speech. DeepSeek may make a pronoun
      // slip, ask an unplanned question or use a disliked template; those are
      // quality signals, not grounds for deleting the user's entire turn.
      if (!serviceGuard.allowed) {
        await ServiceTemplateGuardTelemetry.note(
          db,
          result: serviceGuard,
          mode: 'user_turn',
          action: 'observe',
        );
      }
      if (!questionGuard.allowed) {
        await InformationSeekingQuestionGuardTelemetry.note(
          db,
          result: questionGuard,
          action: 'observe',
        );
      }
      if (!perspectiveGuard.allowed) {
        await db.setSetting(
          'output_ablation_last_pronoun_slip_at',
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      // Falsely claiming a completed real operation is the one remaining
      // correction class. Correct it once, then salvage by removing only the
      // unsupported sentence instead of interrupting the whole conversation.
      if (!operationGuard.allowed) {
        ablationTransformation = 'operation_retry';
        final correctionMessages = <Map<String, Object?>>[
          ...finalRequestMessages,
          {
            'role': 'system',
            'content': '''
【事实声明修正 · ONE RETRY】
上一份正文包含没有真实工具结果支持的可核验操作声明：${operationGuard.reason}。
所有“看过/查过/读取过系统、看见屏幕、调用/保存/修改/设置完成”的可核验操作报告，只能来自本轮匹配的真实成功工具结果。失败、无结果或阻止必须照实说；一次读取绝不能扩写成“一下午/半天/几小时”。没有结果时说尚未执行，或改为“我在想这件事”等真实主观体验。
真实上下文、Memory、Thought 或 Self Experience 可以说成“想起/又琢磨过某件具体的事”，但不能包装成并未发生的“翻了聊天记录/从头到尾看了一遍”。
只修正事实，不修改语气、称呼、问题、动作、性格或自然停顿。
${PromptBuilder.visibleChineseGenerationReminder()}
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
        operationGuard = OperationalClaimGroundingGuard.evaluate(
          text: finalContent,
          currentToolResults: agentToolResults,
        );
        if (!operationGuard.allowed) {
          ablationTransformation = 'operation_retry_salvage';
          final salvaged =
              OperationalClaimGroundingGuard.removeUnsupportedSentences(
            text: finalContent,
            currentToolResults: agentToolResults,
          );
          finalContent = salvaged.isNotEmpty
              ? salvaged
              : '「那件事我还没有真的执行，刚才说岔了。」';
        }
        expressionVerification = ConversationOutcomeVerifier.verify(
          finalText: finalContent,
          plan: conversationPlan,
          sourceThought: sourceConversationThought,
        );
      }
      if (finalContent.trim().isEmpty) {
        throw const FormatException('模型修正后正文为空');
      }

      final companionEmotion = await emotionClassifier.resolve(
        rawTag: envelope.rawTag,
        visibleText: finalContent,
        envelopeStatus: envelope.status,
      );

      final visibleReasoning = preserveProviderReasoning(generated.reasoning);
      unawaited(
        VisibleReasoningLanguageTelemetry.note(
          db,
          visibleReasoning,
          providerDeltaSeen: upstreamReasoningDeltaSeen,
          forwardedToSurface: reasoningDeltaForwardedToSurface,
        ),
      );
      // generate() already forwarded every provider reasoning delta in both
      // buffered and visible-content modes. Do not re-emit the full reasoning
      // here: that doubled the live panel height just before it collapsed.

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
        worldBookContextJson: promptBuild.worldBookContext.encode(),
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

      await ConversationInitiativeTelemetry.recordCommittedPlan(
        db,
        assistantMessageId: assistant.id,
        plan: conversationPlan,
        verification: expressionVerification,
      );
      await ConversationInitiativeAblationTelemetry.record(
        db,
        plan: conversationPlan,
        rawVerification: rawExpressionVerification,
        finalVerification: expressionVerification,
        promptShape: promptResponsibilityShape,
        transformation: ablationTransformation,
      );
      if (expressionVerification.shouldMarkThoughtActed &&
          conversationPlan.sourceThoughtId != null) {
        try {
          final sourceThought = await db.thoughtById(
            conversationPlan.sourceThoughtId!,
          );
          if (sourceThought != null) {
            await ThoughtLifecycleEngine(db: db).markActed(
              thought: sourceThought,
              messageId: assistant.id,
            );
          }
        } catch (_) {
          // The assistant turn is already durable. Thought lifecycle recovery
          // may be retried later and must not invalidate the visible reply.
        }
      }

      unawaited(MoeShadowCoordinator(db).observeCompletedTurn(assistant));
      return GenerationRunResult(
        status: 'completed',
        assistant: assistant,
        specialStyleTrialId: generationSpecialStyleTrialId,
        specialStyleKey: generationSpecialStyleKey,
      );
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
      final failed = await db.failGenerationJob(
        job.id,
        runToken: job.runToken,
        error: _compactError(e),
        recoverable: _recoverable(e),
      );
      if (failed == null) {
        return GenerationRunResult(status: 'suspended', error: e);
      }
      return GenerationRunResult(
        status: failed.status,
        error: e,
        retryAt: failed.nextRetryAt,
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
    // Empty bodies and malformed/bogus tool calls are provider-output faults,
    // not a user Stop. Retry the same durable turn instead of leaving a hole.
    if (error is FormatException) return true;
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
