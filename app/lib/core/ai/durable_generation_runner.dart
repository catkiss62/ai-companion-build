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
        );
      }
      final generationSpecialStyle = await db.activeSpecialStyleTrial();
      generationSpecialStyleTrialId = generationSpecialStyle?.id ?? '';
      generationSpecialStyleKey = generationSpecialStyle?.styleKey ?? '';
      final baseRequestMessages = await PromptBuilder(db).buildChatMessages(
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
  