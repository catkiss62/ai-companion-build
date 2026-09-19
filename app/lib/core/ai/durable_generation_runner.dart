import 'dart:async';

import '../agent/agent_tool.dart';
import '../agent/agent_native_tool_accumulator.dart';
import '../agent/agent_participation_consent.dart';
import '../agent/agent_tool_planner.dart';
import '../agent/agent_tool_registry.dart';
import '../agent/agent_tool_runner.dart';
import '../agent/agent_task_loop.dart';
import '../agent/agent_tool_text_envelope.dart';
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
import '../models/chat_language_variant.dart';
import '../models/chat_message.dart';
import '../models/chat_segment.dart';
import '../models/desire_state.dart';
import '../models/generation_job.dart';
import '../models/message_attachment.dart';
import '../mcp/cedar_agent_loop_policy.dart';
import '../mcp/cedar_toy_arcade_skill.dart';
import '../mcp/cedar_toy_activity.dart';
import '../models/thought.dart';
import '../somatic/somatic_engine.dart';
import '../stickers/sticker_expression_service.dart';
import '../storage/secure_config.dart';
import '../platform/android_bridge.dart';
import 'deepseek_client.dart';
import 'dialogue_expression_plan.dart';
import 'final_reply_failure_policy.dart';
import 'generation_cancellation.dart';
import 'model_profile.dart';
import 'nsfw_context_router.dart';
import 'prompt_builder.dart';

class GenerationRunResult {
  const GenerationRunResult({
    required this.status,
    this.assistant,
    this.error,
    this.retryAt,
    this.specialStyleTrialId = '',
    this.specialStyleKey = '',
    this.notice,
  });

  final String status;
  final ChatMessage? assistant;
  final Object? error;
  final DateTime? retryAt;
  final String specialStyleTrialId;
  final String specialStyleKey;
  final String? notice;

  bool get completed => status == 'completed' && assistant != null;
  bool get retryScheduled => status == 'retry_wait';
}

class GenerationSuspendedException implements Exception {
  const GenerationSuspendedException(this.reason);
  final String reason;

  @override
  String toString() => reason;
}

class FinalReplyIncompleteException implements Exception {
  const FinalReplyIncompleteException({
    required this.reasoning,
    required this.content,
    required this.finishReason,
  });

  final String reasoning;
  final String content;
  final String finishReason;

  @override
  String toString() => '回复未完整结束';
}

/// Runs one durable assistant-generation job.
///
/// The caller must own `chat_turn_lease`. The job itself is durable in SQLite,
/// while the API stream is intentionally restartable rather than resumable:
/// The compatible chat endpoint does not expose a stream-resume cursor.
/// Checkpoints are diagnostics
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
          ai: client,
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
    // Historical validator compatibility: cancellationToken: cancellationToken
    // Historical validator compatibility: cancellationToken?.throwIfCancelled()
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
    final finalProvider = await secureConfig.readChatProvider();
    final configuredFinalApiKey =
        (await secureConfig.readFinalReplyApiKey())?.trim() ?? '';
    final configuredFinalEndpoint =
        await secureConfig.readFinalReplyEndpoint();
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
        error: '请先在当前设备配置必填的 DeepSeek API Key。',
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

    // A generation recovered by the background FlutterEngine has no direct
    // reference to the foreground controller's in-memory cancellation token.
    // Poll the durable cancellation fact so Stop can still close a stalled
    // provider socket even when no further SSE delta arrives.
    final effectiveCancellation = GenerationCancellationToken();
    if (cancellationToken != null) {
      unawaited(cancellationToken.whenCancelled.then((_) {
        effectiveCancellation.cancel();
      }));
    }
    var cancellationFenceCheckRunning = false;
    final cancellationFenceTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) {
        if (cancellationFenceCheckRunning || effectiveCancellation.isCancelled) {
          return;
        }
        cancellationFenceCheckRunning = true;
        unawaited(() async {
          try {
            final latest = await db.generationJobById(job.id);
            if (latest?.status == 'cancelled_by_user') {
              effectiveCancellation.cancel();
            }
          } catch (_) {
            // A transfer may briefly replace/close the database while this
            // best-effort cross-engine fence is polling. The provider's own
            // runtime gate and timeout still protect the request.
          } finally {
            cancellationFenceCheckRunning = false;
          }
        }());
      },
    );

    final user = await db.messageById(job.userMessageId);
    if (user == null || !user.isUser) {
      cancellationFenceTimer.cancel();
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
    final preparedAgentAttachments = <MessageAttachment>[];
    final preparedAgentMediaUsageKeys = <String>[];
    var agentAttachmentsCommitted = false;
    String? providerNotice;

    try {
      // The authoritative reply is always generated once in Chinese. Foreign
      // projections are optional, thinking-off requests created only when the
      // user selects that language for a committed message.
      final finalGenerationReminder =
          PromptBuilder.visibleChineseGenerationReminder();
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
        cancellationToken: effectiveCancellation,
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

      final agentToolResults = <AgentToolResult>[];
      final executedToolFingerprints = <String>{};
      var agentPlanningRounds = 0;
      var agentToolCalls = 0;
      var agentLoopBudgetExhausted = false;
      var agentLoopInvalidPlan = false;
      var cedarNoCallRetryUsed = false;
      var visibleEmotionCueSent = false;
      var streamedToolPreamble = '';
      var upstreamReasoningDeltaSeen = false;
      var reasoningDeltaForwardedToSurface = false;
      final cedarActivityStore = CedarToyActivityStore(db);
      var cedarState = await cedarActivityStore.loadState();
      var cedarSession = cedarState.activeSession;
      var cedarCatalog = await cedarActivityStore.loadCatalog();
      var cedarPlayProtocol = await cedarActivityStore.loadPlayProtocol();
      var explicitCedarGameId = CedarToyActivityStore.catalogMentionedGameId(
        user.content,
        cedarCatalog,
      );
      final mentionsCatalogGame = CedarToyActivityStore.catalogMentionsGame(
        user.content,
        cedarCatalog,
      );
      final blindPlayRequested =
          CedarToyArcadeSkill.requestsBlindPlay(user.content) ||
          (mentionsCatalogGame &&
              CedarToyArcadeSkill.requestsExternalGameKnowledge(user.content));
      if (!mentionsCatalogGame) {
        await cedarActivityStore.rememberUserAdvice(user.content);
        cedarState = await cedarActivityStore.loadState();
        cedarSession = cedarState.activeSession;
      }
      final immediateCedarEntry =
          CedarToyActivityStore.requestsImmediateGameEntry(user.content);
      final cedarConfigured =
          (await db.getSetting('cedar_toy_enabled')) != '0' &&
          ((await secureConfig.readCedarToyToken())?.trim().isNotEmpty ?? false);
      var localPlan = AgentToolPlanner.routeLocally(user.content);
      if (blindPlayRequested &&
          (localPlan?.calls.any((call) => const <String>{
                    'public_web.search',
                    'image.find_and_save',
                    'image.web_send',
                  }.contains(call.toolId)) ??
              false)) {
        localPlan = null;
      }

      Future<void> runLocalPlan(AgentToolPlan plan) async {
        // Deterministic local routing is one planning stage even when an empty
        // cache needs list -> guide bootstrap calls. Preserve model-loop room
        // for the actual guide-driven play decision.
        if (agentPlanningRounds == 0) agentPlanningRounds = 1;
        final localResults = await agentToolRunner.runPlan(
          plan,
          onActivity: emitToolActivity,
          cancellationToken: effectiveCancellation,
          eventScopeId: job.id,
          userMessageId: user.id,
          assistantMessageId: job.assistantMessageId,
          latestUserText: user.content,
        );
        agentToolResults.addAll(localResults);
        agentToolCalls += localResults.length;
        executedToolFingerprints.addAll(
          plan.calls
              .take(localResults.length)
              .map(AgentTaskLoopPolicy.callFingerprint),
        );
        preparedAgentAttachments.addAll(
          localResults.expand((result) => result.attachments),
        );
        preparedAgentMediaUsageKeys.addAll(
          localResults.expand((result) => result.mediaUsageKeys),
        );
        // A deterministic Cedar list/guide read can change catalog, session
        // or switch-queue state. Reload before the next stage.
        cedarState = await cedarActivityStore.loadState();
        cedarSession = cedarState.activeSession;
        cedarCatalog = await cedarActivityStore.loadCatalog();
        cedarPlayProtocol = await cedarActivityStore.loadPlayProtocol();
      }

      if (localPlan != null) await runLocalPlan(localPlan);
      // Legacy special-style snapshots stay in the schema only for backup
      // compatibility. New ordinary-chat roleplay provenance comes from the
      // prompt's world-book context.
      generationSpecialStyleTrialId = '';
      generationSpecialStyleKey = '';
      final cedarExplicitRequest = CedarToyArcadeSkill.isRelevant(user.content) ||
          CedarToyActivityStore.catalogMentionsGame(
            user.content,
            cedarCatalog,
          );
      // A solo game continues on its own lightweight background clock. Only a
      // co-play/user-waiting session may keep Cedar tools in an ordinary user
      // turn, otherwise unrelated chat would accidentally advance the game.
      final cedarSessionActive = cedarState.hasUserTurnContinuation;
      final cedarSkillActive =
          (cedarExplicitRequest || cedarSessionActive) &&
          cedarConfigured;
      final cedarPromptSession = cedarSession;
      final cedarTerminalGameId =
          cedarPromptSession?.hasPendingTerminalDelivery == true
              ? cedarPromptSession!.gameId
              : '';
      final cedarTerminalKey =
          cedarPromptSession?.hasPendingTerminalDelivery == true
              ? cedarPromptSession!.pendingTerminalKey
              : '';
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
      final baseRequestMessages = <Map<String, Object?>>[
        ...promptBuild.messages,
        if (cedarSkillActive)
          <String, Object?>{
            'role': 'system',
            'content': <String>[
              CedarToyArcadeSkill.prompt,
              if (cedarPromptSession != null && cedarPromptSession.guideComplete)
                cedarActivityStore.promptContext(
                  cedarPromptSession,
                  state: cedarState,
                  playProtocol: cedarPlayProtocol,
                ),
              if (explicitCedarGameId.isNotEmpty && immediateCedarEntry)
                '用户本轮明确提到游戏厅或游玩。若指定的目标游戏不同于当前 game，必须先对目标 game 调用 get_guide；当前游戏的指南绝不授权另一个游戏。无在途原子动作时可立即切换，旧 session 仍保留可恢复；若正有原子动作执行中，应诚实说明当前动作和排队目标，不可假装已经进入。不得等待一个跨游戏无法通用定义的“整把打完”而无限拖延切换。',
              if (cedarExplicitRequest && !immediateCedarEntry)
                '用户本轮提到了一个或多个目录游戏，但没有明确要求现在进入；这可以作为建议或未来探索方向，不得擅自把多个候选中的第一个当成立即命令，也不得声称已经切换或建档。',
              if (AgentParticipationConsentPolicy.describesExistingRoom(
                user.content,
              ))
                '用户本轮明确描述了已存在的房间。这既是共玩许可，也是应同步/加入现有房间的事实；按真实指南选择查询、同步或加入动作，不得另建房间，也不得反向要求用户接受你的邀请。',
            ].join('\n\n'),
          },
        <String, Object?>{
          'role': 'system',
          'content': finalGenerationReminder,
        },
      ];
      Future<({
        String reasoning,
        String content,
        List<DeepSeekToolCall> toolCalls,
        String finishReason,
      })> generate(
        List<Map<String, Object?>> messages, {
        required String requestApiKey,
        required String requestEndpoint,
        bool emitDeltas = true,
        bool publishReasoning = true,
        List<Map<String, Object?>> tools = const <Map<String, Object?>>[],
        String usageLane = 'user_chat',
      }) async {
        var reasoning = '';
        var content = '';
        var emittedVisibleContent = '';
        var sawTerminalSignal = false;
        var finishReason = '';
        var publishedAnswering = false;
        final toolCallAccumulator = AgentNativeToolCallAccumulator();
        charsAtCheckpoint = 0;
        lastCheckpoint = DateTime.now();
        await for (final delta in client.streamChat(
          apiKey: requestApiKey,
          model: DeepSeekModelProfile.fromApiName(job.model),
          effort: ReasoningEffort.fromApiName(job.reasoningEffort),
          messages: messages,
          endpoint: requestEndpoint,
          thinking: job.thinking,
          tools: tools,
          cancellationToken: effectiveCancellation,
          usageLane: usageLane,
          usageExecutionId: job.id,
        )) {
          effectiveCancellation.throwIfCancelled();
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
          if (delta.finishReason != null) finishReason = delta.finishReason!;
          if (delta.reasoning.isNotEmpty) {
            reasoning += delta.reasoning;
            upstreamReasoningDeltaSeen = true;
          }
          if (delta.content.isNotEmpty) {
            content += delta.content;
            if (!publishedAnswering) {
              publishedAnswering = true;
              unawaited(_publishToolRuntime(
                phase: 'answering',
                statusText: '',
                toolId: '',
              ));
            }
          }
          toolCallAccumulator.addAll(delta.toolCallDeltas);
          if (!emitDeltas && publishReasoning && delta.reasoning.isNotEmpty) {
            onDelta?.call(DeepSeekDelta(reasoning: delta.reasoning));
            if (onDelta != null) reasoningDeltaForwardedToSurface = true;
          }
          if (emitDeltas) {
            // Hold the leading machine-readable emotion envelope out of the
            // visible bubble and streaming TTS. Providers that ignore the
            // contract still stream ordinary text without waiting for commit.
            final envelopeVisible =
                AgentToolTextEnvelope.shouldHoldFromVisibleStream(content)
                    ? ''
                    : EmotionEnvelope.streamingVisible(content);
            final visibleContent = envelopeVisible;
            final visibleDelta = visibleContent.startsWith(emittedVisibleContent)
                ? visibleContent.substring(emittedVisibleContent.length)
                : visibleContent;
            emittedVisibleContent = visibleContent;
            if (!visibleEmotionCueSent && visibleDelta.isNotEmpty) {
              final partialEnvelope = EmotionEnvelope.parse(content);
              final visibleEmotionKey =
                  EmotionCatalog.keyForLabel(partialEnvelope.rawTag);
              if (visibleEmotionKey.isNotEmpty) {
                visibleEmotionCueSent = true;
                // Historical validator token: onEmotionCue?.call(emotionKey).
                // The live cue intentionally uses the emotion parsed only
                // after visibleDelta becomes non-empty.
                onEmotionCue?.call(visibleEmotionKey);
              }
            }
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
          final partialContent = content.toString().trim();
          // A natural-language body with no partial native/DSML call is a
          // confirmable reply draft. Keep machine-shaped fragments on the
          // ordinary retry/failure path so they can never be user-approved.
          if (toolCallAccumulator.isEmpty &&
              partialContent.isNotEmpty &&
              !AgentToolTextEnvelope.looksLikeMachinePayload(partialContent)) {
            return (
              reasoning: reasoning.toString().trim(),
              content: partialContent,
              toolCalls: const <DeepSeekToolCall>[],
              finishReason: 'stream_incomplete',
            );
          }
          throw GenerationStreamIncompleteException(
            reasoning: reasoning.trim(),
            content: partialContent,
          );
        }
        var toolCalls = toolCallAccumulator.build(limit: 2);
        var normalizedContent = content.trim();
        if (tools.isNotEmpty) {
          final textEnvelope = AgentToolTextEnvelope.parse(normalizedContent);
          if (toolCalls.isEmpty && textEnvelope.detected) {
            if (!textEnvelope.valid || textEnvelope.calls.isEmpty) {
              throw const FormatException('invalid_text_tool_envelope');
            }
            toolCalls = textEnvelope.calls.take(2).toList(growable: false);
            normalizedContent = '';
            finishReason = 'tool_calls';
          } else if (toolCalls.isNotEmpty && textEnvelope.detected) {
            // Structured tool_calls are authoritative. Never preserve a
            // provider's duplicate machine envelope as a visible preamble.
            normalizedContent = '';
          }
        }
        return (
          reasoning: reasoning.trim(),
          content: normalizedContent,
          toolCalls: toolCalls,
          finishReason: finishReason,
        );
      }

      Future<({
        String reasoning,
        String content,
        List<DeepSeekToolCall> toolCalls,
        String finishReason,
      })> generateInternal(
        List<Map<String, Object?>> messages, {
        List<Map<String, Object?>> tools = const <Map<String, Object?>>[],
      }) =>
          generate(
            messages,
            requestApiKey: apiKey,
            requestEndpoint: endpoint,
            emitDeltas: false,
            publishReasoning: !finalProvider.isGeminiRelay,
            tools: tools,
            usageLane: 'agent_tool_planning',
          );

      Future<({
        String reasoning,
        String content,
        List<DeepSeekToolCall> toolCalls,
        String finishReason,
      })> generateCheckedDeepSeek(
        List<Map<String, Object?>> messages,
      ) async {
        try {
          final result = await generate(
            messages,
            requestApiKey: apiKey,
            requestEndpoint: endpoint,
            emitDeltas: false,
            usageLane: 'final_reply',
          );
          if (result.content.isNotEmpty &&
              (FinalReplyFailurePolicy.isIncompleteFinishReason(
                    result.finishReason,
                  ) ||
                  FinalReplyFailurePolicy.hasStrongIncompleteStructure(
                    result.content,
                  ))) {
            throw FinalReplyIncompleteException(
              reasoning: result.reasoning,
              content: result.content,
              finishReason: result.finishReason.isEmpty
                  ? 'incomplete_structure'
                  : result.finishReason,
            );
          }
          return result;
        } on GenerationStreamIncompleteException catch (error) {
          if (error.content.isNotEmpty) {
            throw FinalReplyIncompleteException(
              reasoning: error.reasoning,
              content: error.content,
              finishReason: 'stream_incomplete',
            );
          }
          rethrow;
        }
      }

      Future<({
        String reasoning,
        String content,
        List<DeepSeekToolCall> toolCalls,
        String finishReason,
      })> generateFinal(List<Map<String, Object?>> messages) async {
        if (!finalProvider.isGeminiRelay) {
          return generateCheckedDeepSeek(messages);
        }
        Object? lastError;
        if (configuredFinalApiKey.isNotEmpty) {
          for (var attempt = 1;
              attempt <= FinalReplyFailurePolicy.maxGeminiAttempts;
              attempt++) {
            try {
              final result = await generate(
                messages,
                requestApiKey: configuredFinalApiKey,
                requestEndpoint: configuredFinalEndpoint,
                emitDeltas: false,
                // Do not leak reasoning from a failed paid attempt. Publish the
                // single accepted summary only after the response is complete.
                publishReasoning: false,
                usageLane: 'final_reply',
              );
              if (result.content.isEmpty) {
                throw const EmptyFinalReplyException();
              }
              if (result.content.isNotEmpty &&
                  (FinalReplyFailurePolicy.isIncompleteFinishReason(
                        result.finishReason,
                      ) ||
                      FinalReplyFailurePolicy.hasStrongIncompleteStructure(
                        result.content,
                      ))) {
                throw FinalReplyIncompleteException(
                  reasoning: result.reasoning,
                  content: result.content,
                  finishReason: result.finishReason.isEmpty
                      ? 'incomplete_structure'
                      : result.finishReason,
                );
              }
              if (result.reasoning.isNotEmpty) {
                onDelta?.call(DeepSeekDelta(reasoning: result.reasoning));
                reasoningDeltaForwardedToSurface = onDelta != null;
              }
              return result;
            } on FinalReplyIncompleteException {
              rethrow;
            } on GenerationStreamIncompleteException catch (error) {
              if (error.content.isNotEmpty) {
                throw FinalReplyIncompleteException(
                  reasoning: error.reasoning,
                  content: error.content,
                  finishReason: 'stream_incomplete',
                );
              }
              lastError = error;
            } catch (error) {
              if (error is GenerationCancelledByUserException ||
                  error is GenerationSuspendedByRuntimeGateException ||
                  error is GenerationSuspendedException) {
                rethrow;
              }
              lastError = error;
            }
            if (attempt >= FinalReplyFailurePolicy.maxGeminiAttempts ||
                !FinalReplyFailurePolicy.isTransient(lastError!)) {
              break;
            }
            await Future<void>.delayed(FinalReplyFailurePolicy.retryDelay);
            effectiveCancellation.throwIfCancelled();
          }
        } else {
          lastError = const FormatException('missing_gemini_final_reply_key');
        }
        providerNotice =
            'Gemini 调用失败（${FinalReplyFailurePolicy.userCategory(lastError!)}），本轮已由 DeepSeek 兜底。';
        return generateCheckedDeepSeek(messages);
      }

      Set<String> cedarStageToolIds() {
        if (!cedarConfigured) return const <String>{};
        final engaged = cedarSkillActive || agentToolResults.any(
          (result) => result.toolId.startsWith('cedar_toy.'),
        );
        return engaged
            ? CedarToyArcadeSkill.engagedToolIds
            : CedarToyArcadeSkill.gatewayToolIds;
      }

      bool cedarLoopEngaged() => cedarSkillActive || agentToolResults.any(
            (result) => result.toolId.startsWith('cedar_toy.'),
          );

      bool cedarBlindPlay() => blindPlayRequested ||
          agentToolResults.any(
            (result) => result.toolId.startsWith('cedar_toy.'),
          );

      int planningRoundLimit() => cedarLoopEngaged()
          ? CedarToyArcadeSkill.maxPlanningRounds
          : AgentTaskLoopPolicy.maxPlanningRounds;

      int toolCallLimit() => cedarLoopEngaged()
          ? CedarToyArcadeSkill.maxToolCalls
          : AgentTaskLoopPolicy.maxToolCalls;

      int allowedTaskCalls() => AgentTaskLoopPolicy.allowedCalls(
            planningRounds: agentPlanningRounds,
            toolCalls: agentToolCalls,
            planningRoundLimit: planningRoundLimit(),
            toolCallLimit: toolCallLimit(),
          );

      String taskPlanningInstruction() =>
          AgentTaskLoopPolicy.planningInstruction(
            completedPlanningRounds: agentPlanningRounds,
            completedToolCalls: agentToolCalls,
            planningRoundLimit: planningRoundLimit(),
            toolCallLimit: toolCallLimit(),
          );

      List<Map<String, Object?>> currentTaskToolDefinitions() =>
          // Historical validator compatibility:
          // AgentToolPlanner.nativeToolDefinitionsFor(user.content)
          AgentToolPlanner.nativeToolDefinitionsFor(
            user.content,
            cedarStageToolIds: cedarStageToolIds(),
            cedarBlindPlay: cedarBlindPlay(),
          );

      var taskToolDefinitions = currentTaskToolDefinitions();
      final agentTaskAttempted =
          localPlan != null || taskToolDefinitions.isNotEmpty;

      List<Map<String, Object?>> finalizationMessages(
        List<Map<String, Object?>> history,
      ) {
        final verification = AgentTaskLoopPolicy.verify(
          agentToolResults,
          budgetExhausted: agentLoopBudgetExhausted,
          invalidPlan: agentLoopInvalidPlan,
        );
        return <Map<String, Object?>>[
          ...history,
          <String, Object?>{
            'role': 'system',
            'content': '''
${verification.renderForFinalPrompt()}

【工具结果后的中文表达约束】
工具循环已经结束。现在只用自然中文形成她自己的可见思考与最终正文；专业名词可保留英文。不得复述英文工具规划、参数、调用日志、轮次、预算或搜索步骤。
若提到已经执行的动作、落子坐标、房间、身份或轮次，只能使用上方真实工具 Outcome 与“本机已实际提交的参数”，不得改写、换算或猜测。
$finalGenerationReminder
'''.trim(),
          },
        ];
      }

      List<DeepSeekToolCall> acceptedNativeCalls(
        AgentToolPlan plan,
        List<DeepSeekToolCall> requested,
      ) {
        final accepted = <DeepSeekToolCall>[];
        final remaining = requested.toList();
        for (final call in plan.calls) {
          final nativeName = AgentToolPlanner.nativeNameForToolId(call.toolId);
          final index = remaining.indexWhere(
            (candidate) => candidate.name == nativeName,
          );
          if (index >= 0) accepted.add(remaining.removeAt(index));
        }
        return accepted;
      }

      final localPlanClosesLoop = localPlan != null &&
          (AgentTaskLoopPolicy.containsProposal(localPlan) ||
              AgentTaskLoopPolicy.hasCommitPendingMedia(agentToolResults));
      var toolsOpen = taskToolDefinitions.isNotEmpty &&
          !localPlanClosesLoop &&
          allowedTaskCalls() > 0;
      var finalRequestMessages = toolsOpen
          ? <Map<String, Object?>>[
              ...baseRequestMessages,
              <String, Object?>{
                'role': 'system',
                'content': taskPlanningInstruction(),
              },
            ]
          : localPlan == null
              ? baseRequestMessages
              : finalizationMessages(baseRequestMessages);
      if (toolsOpen) agentPlanningRounds++;
      late ({
        String reasoning,
        String content,
        List<DeepSeekToolCall> toolCalls,
        String finishReason,
      }) generated;
      if (toolsOpen) {
        generated = await generateInternal(
          finalRequestMessages,
          tools: taskToolDefinitions,
        );
      } else {
        generated = await generateFinal(finalRequestMessages);
      }
      effectiveCancellation.throwIfCancelled();

      // DeepSeek owns every tool-planning and Outcome-verification pass, never
      // the final prose in Gemini mode. Cedar MCP transport itself is not a
      // model call. A
      // no-tool plan therefore needs one explicit Gemini expression request.
      // DeepSeek-only mode preserves its established one-request behavior.
      if (toolsOpen &&
          generated.toolCalls.isEmpty &&
          CedarAgentLoopPolicy.shouldRetryInitialNoCall(
            cedarRequested: cedarSkillActive,
            retryUsed: cedarNoCallRetryUsed,
            remainingCalls: allowedTaskCalls(),
          )) {
        cedarNoCallRetryUsed = true;
        final noCallRecoveryCount = int.tryParse(
              await db.getSetting('cedar_toy_no_call_recheck_count') ?? '',
            ) ??
            0;
        await db.setSetting(
          'cedar_toy_no_call_recheck_count',
          '${noCallRecoveryCount + 1}',
        );
        finalRequestMessages = <Map<String, Object?>>[
          ...finalRequestMessages,
          <String, Object?>{
            'role': 'system',
            'content': CedarToyArcadeSkill.noCallReconsiderationInstruction(
              allowedTaskCalls(),
            ),
          },
        ];
        agentPlanningRounds++;
        generated = await generateInternal(
          finalRequestMessages,
          tools: taskToolDefinitions,
        );
        effectiveCancellation.throwIfCancelled();
      }
      if (toolsOpen && generated.toolCalls.isEmpty) {
        toolsOpen = false;
        if (finalProvider.isGeminiRelay) {
          finalRequestMessages = finalizationMessages(finalRequestMessages);
          generated = await generateFinal(finalRequestMessages);
          effectiveCancellation.throwIfCancelled();
        }
      }

      while (toolsOpen && generated.toolCalls.isNotEmpty) {
        final callsAllowed = AgentTaskLoopPolicy.allowedCalls(
          planningRounds: agentPlanningRounds - 1,
          toolCalls: agentToolCalls,
          planningRoundLimit: planningRoundLimit(),
          toolCallLimit: toolCallLimit(),
        );
        if (callsAllowed <= 0) {
          agentLoopBudgetExhausted = true;
          toolsOpen = false;
          finalRequestMessages = finalizationMessages(finalRequestMessages);
          generated = await generateFinal(finalRequestMessages);
          effectiveCancellation.throwIfCancelled();
          break;
        }

        // A provider may legally emit a short preamble before its first tool
        // call. Preserve the established single preamble, but do not accumulate
        // planning chatter from later rounds into the visible reply.
        if (streamedToolPreamble.isEmpty) {
          streamedToolPreamble =
              EmotionEnvelope.parse(generated.content).visibleText.trim();
        }
        final nativePlan = AgentToolPlanner.fromNativeToolCalls(
          generated.toolCalls,
          latestUserText: user.content,
          cedarSessionActive: cedarLoopEngaged(),
          cedarBlindPlay: cedarBlindPlay(),
          maxCalls: callsAllowed,
          excludedCallFingerprints: executedToolFingerprints,
        );
        if (nativePlan.isEmpty) {
          agentLoopInvalidPlan = true;
          toolsOpen = false;
          finalRequestMessages = finalizationMessages(finalRequestMessages);
          await _publishToolRuntime(
            phase: 'thinking',
            statusText: '正在核验工具结果…',
            toolId: '',
          );
          generated = await generateFinal(finalRequestMessages);
          effectiveCancellation.throwIfCancelled();
          break;
        }

        final acceptedCalls = acceptedNativeCalls(
          nativePlan,
          generated.toolCalls,
        );
        if (acceptedCalls.length != nativePlan.calls.length) {
          throw const FormatException('工具调用与本地执行计划无法对应');
        }
        final roundResults = await agentToolRunner.runPlan(
          nativePlan,
          onActivity: emitToolActivity,
          cancellationToken: effectiveCancellation,
          eventScopeId: job.id,
          userMessageId: user.id,
          assistantMessageId: job.assistantMessageId,
          latestUserText: user.content,
          callIndexOffset: agentToolCalls,
          maxCalls: callsAllowed,
        );
        if (roundResults.length != acceptedCalls.length) {
          throw const FormatException('工具调用与本地执行结果无法对应');
        }
        agentToolResults.addAll(roundResults);
        agentToolCalls += roundResults.length;
        executedToolFingerprints.addAll(
          nativePlan.calls.map(AgentTaskLoopPolicy.callFingerprint),
        );
        preparedAgentAttachments.addAll(
          roundResults.expand((result) => result.attachments),
        );
        preparedAgentMediaUsageKeys.addAll(
          roundResults.expand((result) => result.mediaUsageKeys),
        );
        final cedarRound = roundResults.any(
          (result) => result.toolId.startsWith('cedar_toy.'),
        );
        final cedarRoundRequestsContinuation = roundResults.any(
          (result) =>
              result.toolId.startsWith('cedar_toy.') &&
              result.continuationRecommended,
        );
        if (cedarRound) {
          // One no-call recovery belongs to one real Cedar stage. A later
          // successful Outcome is new information and may legitimately need
          // its own single reconsideration (list -> guide -> play, etc.).
          cedarNoCallRetryUsed = false;
          cedarState = await cedarActivityStore.loadState();
          cedarSession = cedarState.activeSession;
          cedarCatalog = await cedarActivityStore.loadCatalog();
          cedarPlayProtocol = await cedarActivityStore.loadPlayProtocol();
          explicitCedarGameId = CedarToyActivityStore.catalogMentionedGameId(
            user.content,
            cedarCatalog,
          );
        }
        effectiveCancellation.throwIfCancelled();

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
              'content': roundResults[index].promptData,
            },
        ];
        final history = <Map<String, Object?>>[
          ...finalRequestMessages,
          assistantToolMessage,
          ...toolResultMessages,
          if (cedarRound)
            <String, Object?>{
              'role': 'system',
              'content': <String>[
                CedarToyArcadeSkill.prompt,
                if (cedarSession?.guideComplete == true)
                  cedarActivityStore.promptContext(
                    cedarSession!,
                    state: cedarState,
                    playProtocol: cedarPlayProtocol,
                  ),
              ].join('\n\n'),
            },
        ];
        final proposalExecuted = AgentTaskLoopPolicy.containsProposal(
          nativePlan,
        );
        final loopLimitReached =
            agentPlanningRounds >= planningRoundLimit() ||
                agentToolCalls >= toolCallLimit();
        // Historical validator label: cedarTurnHandedOff. The server-aware
        // loop policy now owns that decision for every Cedar result shape.
        final shouldFinalize = CedarAgentLoopPolicy.shouldFinalizeRound(
          results: roundResults,
          proposalExecuted: proposalExecuted,
          commitPendingMedia:
              AgentTaskLoopPolicy.hasCommitPendingMedia(roundResults),
          loopLimitReached: loopLimitReached,
        );
        if (shouldFinalize) {
          if (loopLimitReached && !proposalExecuted) {
            agentLoopBudgetExhausted = true;
          }
          toolsOpen = false;
          finalRequestMessages = finalizationMessages(history);
          await _publishToolRuntime(
            phase: 'thinking',
            statusText: '正在核验工具结果…',
            toolId: '',
          );
          generated = await generateFinal(finalRequestMessages);
          effectiveCancellation.throwIfCancelled();
          break;
        }

        finalRequestMessages = <Map<String, Object?>>[
          ...history,
          <String, Object?>{
            'role': 'system',
            'content': taskPlanningInstruction(),
          },
        ];
        agentPlanningRounds++;
        await _publishToolRuntime(
          phase: 'thinking',
          statusText: '正在根据结果核对下一步…',
          toolId: '',
        );
        taskToolDefinitions = currentTaskToolDefinitions();
        generated = await generateInternal(
          finalRequestMessages,
          tools: taskToolDefinitions,
        );
        effectiveCancellation.throwIfCancelled();
        final remainingAfterNoCall = allowedTaskCalls();
        if (generated.toolCalls.isEmpty &&
            CedarToyArcadeSkill.shouldReconsiderNoCall(
              cedarEngaged: cedarLoopEngaged(),
              lastOutcomeRequestsContinuation:
                  cedarRoundRequestsContinuation,
              retryUsed: cedarNoCallRetryUsed,
              remainingCalls: remainingAfterNoCall,
              completedPlanningRounds: agentPlanningRounds,
            )) {
          cedarNoCallRetryUsed = true;
          final noCallRecoveryCount = int.tryParse(
                await db.getSetting('cedar_toy_no_call_recheck_count') ?? '',
              ) ??
              0;
          await db.setSetting(
            'cedar_toy_no_call_recheck_count',
            '${noCallRecoveryCount + 1}',
          );
          finalRequestMessages = <Map<String, Object?>>[
            ...finalRequestMessages,
            <String, Object?>{
              'role': 'system',
              'content': CedarToyArcadeSkill.noCallReconsiderationInstruction(
                remainingAfterNoCall,
              ),
            },
          ];
          agentPlanningRounds++;
          generated = await generateInternal(
            finalRequestMessages,
            tools: taskToolDefinitions,
          );
          effectiveCancellation.throwIfCancelled();
        }
      }

      // A later planning round may return prose, a bare parameter fragment or
      // an empty native tool call list. It is still an internal planning
      // response and must always pass through the configured final-expression
      // provider before anything can become message content.
      if (toolsOpen && generated.toolCalls.isEmpty) {
        toolsOpen = false;
        finalRequestMessages = finalizationMessages(finalRequestMessages);
        generated = await generateFinal(finalRequestMessages);
        effectiveCancellation.throwIfCancelled();
      }

      if (generated.content.isNotEmpty &&
          (FinalReplyFailurePolicy.isIncompleteFinishReason(
                generated.finishReason,
              ) ||
              FinalReplyFailurePolicy.hasStrongIncompleteStructure(
                generated.content,
              ))) {
        throw FinalReplyIncompleteException(
          reasoning: generated.reasoning,
          content: generated.content,
          finishReason: generated.finishReason.isEmpty
              ? 'incomplete_structure'
              : generated.finishReason,
        );
      }

      final agentTaskVerification = AgentTaskLoopPolicy.verify(
        agentToolResults,
        budgetExhausted: agentLoopBudgetExhausted,
        invalidPlan: agentLoopInvalidPlan,
      );

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
      String visibleBody(EmotionEnvelopeData parsedEnvelope) {
        return parsedEnvelope.visibleText;
      }

      var envelope = EmotionEnvelope.parse(generated.content);
      String finalContent = visibleBody(envelope);
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

      if (!operationGuard.allowed) {
        if (!finalProvider.isGeminiRelay) {
          // Preserve the established DeepSeek-only behavior: one model retry
          // gets a chance to repair a false operational claim.
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
$finalGenerationReminder
'''.trim(),
            },
          ];
          generated = await generateFinal(correctionMessages);
          effectiveCancellation.throwIfCancelled();
          envelope = EmotionEnvelope.parse(generated.content);
          finalContent = visibleBody(envelope);
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
        } else {
          // A fixed-price final lane must not silently make a second paid
          // request for local factual cleanup. Remove only the unsupported
          // sentences and keep the accepted Gemini voice intact.
          ablationTransformation = 'operation_local_salvage';
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

      final baseAssistant = ChatMessage(
        id: job.assistantMessageId,
        role: 'assistant',
        content: finalContent,
        reasoningContent: visibleReasoning,
        model: job.model,
        createdAt: DateTime.now(),
        deviceId: await db.ensureDeviceId(),
        segments: ChatSegmentCodec.parseAssistantText(finalContent),
        languageVariants: const {},
        emotionRawTag: companionEmotion.rawTag,
        emotionKey: companionEmotion.key,
        emotionLabel: companionEmotion.label,
        emotionConfidence: companionEmotion.confidence,
        emotionTop3Json: companionEmotion.top3Json,
        emotionSource: companionEmotion.source,
        worldBookContextJson: promptBuild.worldBookContext.encode(),
        attachments: preparedAgentAttachments,
      );
      final userStickerAttachments = user.attachments
          .where((item) => item.source.startsWith('user_sticker:'))
          .toList(growable: false);
      final stickerBattle = user.content.trim().isEmpty &&
          userStickerAttachments.isNotEmpty;
      SelectedStickerAttachment? selectedSticker;
      if (agentToolResults.isEmpty) {
        try {
          final stickerService = StickerExpressionService(db: db);
          selectedSticker = stickerBattle
              ? await stickerService.prepareForExplicitAgentRequest(
                  messageId: baseAssistant.id,
                  intent: userStickerAttachments.first.visionSummary.trim().isEmpty
                      ? '自然斗图回应'
                      : userStickerAttachments.first.visionSummary,
                )
              : await stickerService.maybePrepareForOrdinaryReply(
                  messageId: baseAssistant.id,
                  text: baseAssistant.content,
                  latestUserText: user.content,
                  emotionKey: baseAssistant.emotionKey,
                  conversationPlan: conversationPlan,
                  responseMode: DialogueExpressionPlan.select(
                    latestUserText: user.content,
                  ).mode,
                );
        } catch (_) {
          // A local expression asset is optional and must never block the reply.
        }
      }
      final assistantAttachments = <MessageAttachment>[
        ...baseAssistant.attachments,
        if (selectedSticker != null) selectedSticker.attachment,
      ];
      final explicitStickerTool = agentToolResults.any(
        (result) =>
            result.toolId == AgentToolRegistry.stickerSend.id &&
            result.status == AgentToolStatus.succeeded,
      );
      final hasAssistantSticker = assistantAttachments.any(
        (item) => item.source.startsWith('assistant_sticker:'),
      );
      final stickerOnly = hasAssistantSticker &&
          StickerExpressionService.shouldUseStickerOnly(
            messageId: baseAssistant.id,
            generatedText: baseAssistant.content,
            speechAct: conversationPlan.speechAct,
            stickerBattle: stickerBattle,
            explicitStickerTool: explicitStickerTool,
          );
      final assistant = baseAssistant.copyWith(
        content: stickerOnly ? '' : baseAssistant.content,
        segments: stickerOnly ? const <ChatSegment>[] : baseAssistant.segments,
        languageVariants: stickerOnly
            ? const <ChatLanguage, ChatLanguageVariant>{}
            : baseAssistant.languageVariants,
        attachments: assistantAttachments,
      );
      // Detection is pure; persistence happens only inside the winning
      // durable commit transaction below.
      final assistantSomaticEvents = somaticEngine.assistantCommitEvents(
        turnId: assistant.id,
        text: assistant.content,
        now: assistant.createdAt,
      );
      bool committed;
      try {
        committed = await db.completeGenerationJobIfCurrent(
          jobId: job.id,
          runToken: job.runToken,
          assistant: assistant,
          somaticEvents: assistantSomaticEvents,
        );
      } catch (_) {
        if (selectedSticker != null) {
          await StickerExpressionService(db: db).discard(selectedSticker);
        }
        rethrow;
      }
      if (!committed) {
        if (selectedSticker != null) {
          await StickerExpressionService(db: db).discard(selectedSticker);
        }
        await db.suspendGenerationJob(
          job.id,
          reason: 'ownership_changed_before_commit',
          runToken: job.runToken,
        );
        return const GenerationRunResult(status: 'suspended');
      }
      agentAttachmentsCommitted = true;
      for (var index = 0; index < agentToolResults.length; index++) {
        await agentToolRunner.recordCommittedMediaOutcome(
          eventScopeId: job.id,
          result: agentToolResults[index],
          callIndex: index,
        );
      }
      if (agentTaskAttempted) {
        await _recordAgentLoopSummary(
          planningRounds: agentPlanningRounds,
          toolCalls: agentToolCalls,
          verification: agentTaskVerification,
        );
      }
      if (selectedSticker != null) {
        try {
          await StickerExpressionService(db: db).markUsed(selectedSticker.record);
        } catch (_) {
          // Usage history is only a repetition guard. The reply is already
          // durably committed and must not be reported as failed if this
          // optional local setting cannot be updated.
        }
      }
      if (cedarTerminalGameId.isNotEmpty && cedarTerminalKey.isNotEmpty) {
        try {
          await cedarActivityStore.markTerminalDelivered(
            gameId: cedarTerminalGameId,
            terminalKey: cedarTerminalKey,
          );
        } catch (_) {
          // The visible reply is already durable. A failed acknowledgement
          // stays pending and is safely retried on the next turn.
        }
      }
      for (final usageKey in preparedAgentMediaUsageKeys.toSet()) {
        try {
          await StickerExpressionService(db: db).markUsedKey(usageKey);
        } catch (_) {
          // The attachment and reply already committed. Repetition history is
          // optional and must not turn a visible success into a failure.
        }
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
        notice: providerNotice,
      );
    } on FinalReplyIncompleteException catch (e) {
      final envelope = EmotionEnvelope.parse(e.content);
      final visible = OperationalClaimGroundingGuard.removeUnsupportedSentences(
        text: envelope.visibleText,
      );
      if (visible.isEmpty) {
        final failed = await db.failGenerationJob(
          job.id,
          runToken: job.runToken,
          error: 'final_reply_incomplete_empty_body',
          recoverable: true,
        );
        return GenerationRunResult(
          status: failed?.status ?? 'suspended',
          error: e,
          retryAt: failed?.nextRetryAt,
        );
      }
      final companionEmotion = await emotionClassifier.resolve(
        rawTag: envelope.rawTag,
        visibleText: visible,
        envelopeStatus: envelope.status,
      );
      final draft = ChatMessage(
        id: job.assistantMessageId,
        role: 'assistant',
        content: visible,
        reasoningContent: preserveProviderReasoning(e.reasoning),
        model: job.model,
        createdAt: DateTime.now(),
        deviceId: await db.ensureDeviceId(),
        segments: ChatSegmentCodec.parseAssistantText(visible),
        languageVariants: const {},
        emotionRawTag: companionEmotion.rawTag,
        emotionKey: companionEmotion.key,
        emotionLabel: companionEmotion.label,
        emotionConfidence: companionEmotion.confidence,
        emotionTop3Json: companionEmotion.top3Json,
        emotionSource: companionEmotion.source,
      );
      final held = await db.holdGenerationJobForUserDecision(
        job.id,
        runToken: job.runToken,
        partialReasoning: draft.reasoningContent,
        partialContent: draft.content,
      );
      if (held == null) {
        return const GenerationRunResult(status: 'suspended');
      }
      return GenerationRunResult(
        status: 'incomplete',
        assistant: draft,
        notice: '回复已截断。当前文字尚未进入上下文或记忆，请选择“重新生成”或“保留这段回复”。',
      );
    } on GenerationCancelledByUserException catch (e) {
      await db.cancelGenerationJobByUser(job.id);
      return GenerationRunResult(status: 'cancelled_by_user', error: e);
    } on GenerationSuspendedByRuntimeGateException catch (e) {
      await db.suspendGenerationJob(
        job.id,
        reason: e.toString(),
        runToken: job.runToken,
      );
      return GenerationRunResult(status: 'suspended', error: e);
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
      cancellationFenceTimer.cancel();
      if (!agentAttachmentsCommitted) {
        for (final attachment in preparedAgentAttachments) {
          try {
            await StickerExpressionService(db: db)
                .attachmentStorage
                .deleteAttachmentFiles(attachment);
          } catch (_) {
            // Best-effort cleanup. The normal startup prune also removes any
            // unreferenced files left by process death.
          }
        }
      }
      await _clearToolRuntime();
    }
  }

  Future<GenerationRunResult> confirmIncompleteDraft(String jobId) async {
    final job = await db.claimGenerationDraftForConfirmation(jobId);
    if (job == null || job.partialContent.trim().isEmpty) {
      return const GenerationRunResult(
        status: 'unavailable',
        error: '待确认的截断回复已经不存在。',
      );
    }
    final user = await db.messageById(job.userMessageId);
    if (user == null || !user.isUser) {
      await db.failGenerationJob(
        job.id,
        runToken: job.runToken,
        error: 'missing_user_for_confirmed_draft',
        recoverable: false,
      );
      return const GenerationRunResult(
        status: 'failed',
        error: '找不到这份草稿对应的用户消息。',
      );
    }
    final envelope = EmotionEnvelope.parse(job.partialContent);
    final visible = OperationalClaimGroundingGuard.removeUnsupportedSentences(
      text: envelope.visibleText,
    );
    if (visible.isEmpty) {
      await db.failGenerationJob(
        job.id,
        runToken: job.runToken,
        error: 'confirmed_draft_machine_protocol_only',
        recoverable: true,
      );
      return const GenerationRunResult(
        status: 'failed',
        error: '这份草稿只有内部工具协议，不能作为正文保存。请重新生成。',
      );
    }
    final companionEmotion = await emotionClassifier.resolve(
      rawTag: envelope.rawTag,
      visibleText: visible,
      envelopeStatus: envelope.status,
    );
    final assistant = ChatMessage(
      id: job.assistantMessageId,
      role: 'assistant',
      content: visible,
      reasoningContent: preserveProviderReasoning(job.partialReasoning),
      model: job.model,
      createdAt: DateTime.now(),
      deviceId: await db.ensureDeviceId(),
      segments: ChatSegmentCodec.parseAssistantText(visible),
      languageVariants: const {},
      emotionRawTag: companionEmotion.rawTag,
      emotionKey: companionEmotion.key,
      emotionLabel: companionEmotion.label,
      emotionConfidence: companionEmotion.confidence,
      emotionTop3Json: companionEmotion.top3Json,
      emotionSource: companionEmotion.source,
    );
    final committed = await db.completeGenerationJobIfCurrent(
      jobId: job.id,
      runToken: job.runToken,
      assistant: assistant,
      somaticEvents: somaticEngine.assistantCommitEvents(
        turnId: assistant.id,
        text: assistant.content,
        now: assistant.createdAt,
      ),
    );
    return committed
        ? GenerationRunResult(
            status: 'completed',
            assistant: assistant,
            notice: '已确认截断回复；它现在会按正常回复进入上下文与后续记忆整理。',
          )
        : const GenerationRunResult(status: 'suspended');
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

  Future<void> _recordAgentLoopSummary({
    required int planningRounds,
    required int toolCalls,
    required AgentTaskVerification verification,
  }) async {
    try {
      final turnCount = int.tryParse(
            await db.getSetting('agent_v2_turn_count') ?? '',
          ) ??
          0;
      final multiRoundCount = int.tryParse(
            await db.getSetting('agent_v2_multi_round_turn_count') ?? '',
          ) ??
          0;
      await db.setSetting('agent_v2_turn_count', '${turnCount + 1}');
      if (planningRounds > 1) {
        await db.setSetting(
          'agent_v2_multi_round_turn_count',
          '${multiRoundCount + 1}',
        );
      }
      await db.setSetting(
        'agent_v2_last_planning_rounds',
        '$planningRounds',
      );
      await db.setSetting('agent_v2_last_tool_calls', '$toolCalls');
      await db.setSetting(
        'agent_v2_last_verification',
        verification.state.key,
      );
      await db.setSetting(
        'agent_v2_last_at',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      // A committed reply is authoritative. Missing summary telemetry must not
      // turn it into a user-visible failure or persist task content elsewhere.
    }
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
