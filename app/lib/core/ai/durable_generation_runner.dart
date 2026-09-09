import 'dart:async';

import '../agent/agent_tool.dart';
import '../agent/agent_tool_planner.dart';
import '../agent/agent_tool_registry.dart';
import '../agent/agent_tool_runner.dart';
import '../agent/agent_task_loop.dart';
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
import '../models/chat_language_variant.dart';
import '../models/chat_segment.dart';
import '../models/desire_state.dart';
import '../models/generation_job.dart';
import '../models/message_attachment.dart';
import '../models/thought.dart';
import '../somatic/somatic_engine.dart';
import '../stickers/sticker_expression_service.dart';
import '../storage/secure_config.dart';
import '../platform/android_bridge.dart';
import 'deepseek_client.dart';
import 'dialogue_expression_plan.dart';
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
    final preparedAgentAttachments = <MessageAttachment>[];
    final preparedAgentMediaUsageKeys = <String>[];
    var agentAttachmentsCommitted = false;

    try {
      final multilingualEnabled =
          (await db.getSetting('multilingual_replies_enabled')) != '0';
      final finalGenerationReminder = multilingualEnabled
          ? PromptBuilder.multilingualGenerationReminder()
          : PromptBuilder.visibleChineseGenerationReminder();
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

      final agentToolResults = <AgentToolResult>[];
      final executedToolFingerprints = <String>{};
      var agentPlanningRounds = 0;
      var agentToolCalls = 0;
      var agentLoopBudgetExhausted = false;
      var agentLoopInvalidPlan = false;
      var announcedEmotionKey = '';
      var streamedToolPreamble = '';
      var upstreamReasoningDeltaSeen = false;
      var reasoningDeltaForwardedToSurface = false;
      final localPlan = AgentToolPlanner.routeLocally(user.content);
      if (localPlan != null) {
        agentPlanningRounds = 1;
        final localResults = await agentToolRunner.runPlan(
          localPlan,
          onActivity: emitToolActivity,
          cancellationToken: cancellationToken,
          eventScopeId: job.id,
          userMessageId: user.id,
          assistantMessageId: job.assistantMessageId,
        );
        agentToolResults.addAll(localResults);
        agentToolCalls += localResults.length;
        executedToolFingerprints.addAll(
          localPlan.calls
              .take(localResults.length)
              .map(AgentTaskLoopPolicy.callFingerprint),
        );
        preparedAgentAttachments.addAll(
          localResults.expand((result) => result.attachments),
        );
        preparedAgentMediaUsageKeys.addAll(
          localResults.expand((result) => result.mediaUsageKeys),
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
      final baseRequestMessages = <Map<String, Object?>>[
        ...promptBuild.messages,
        if (multilingualEnabled)
          <String, Object?>{
            'role': 'system',
            'content': finalGenerationReminder,
          },
      ];
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
            final envelopeVisible = EmotionEnvelope.streamingVisible(content);
            final visibleContent = multilingualEnabled
                ? MultilingualReplyCodec.streamingChinese(
                    envelopeVisible,
                    messageId: job.assistantMessageId,
                  )
                : envelopeVisible;
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

      final taskToolDefinitions =
          AgentToolPlanner.nativeToolDefinitionsFor(user.content);
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
          AgentTaskLoopPolicy.allowedCalls(
                planningRounds: agentPlanningRounds,
                toolCalls: agentToolCalls,
              ) >
              0;
      var finalRequestMessages = toolsOpen
          ? <Map<String, Object?>>[
              ...baseRequestMessages,
              <String, Object?>{
                'role': 'system',
                'content': AgentTaskLoopPolicy.planningInstruction(
                  completedPlanningRounds: agentPlanningRounds,
                  completedToolCalls: agentToolCalls,
                ),
              },
            ]
          : localPlan == null
              ? baseRequestMessages
              : finalizationMessages(baseRequestMessages);
      if (toolsOpen) agentPlanningRounds++;
      var generated = await generate(
        finalRequestMessages,
        // Ordinary chat keeps provider reasoning live, but holds the visible
        // body until every guard has approved one durable answer. The chat UI
        // then performs its established local typewriter playback exactly once.
        emitDeltas: false,
        tools: toolsOpen
            ? taskToolDefinitions
            : const <Map<String, Object?>>[],
      );
      cancellationToken?.throwIfCancelled();

      while (toolsOpen && generated.toolCalls.isNotEmpty) {
        final callsAllowed = AgentTaskLoopPolicy.allowedCalls(
          planningRounds: agentPlanningRounds - 1,
          toolCalls: agentToolCalls,
        );
        if (callsAllowed <= 0) {
          agentLoopBudgetExhausted = true;
          toolsOpen = false;
          finalRequestMessages = finalizationMessages(finalRequestMessages);
          generated = await generate(finalRequestMessages, emitDeltas: false);
          cancellationToken?.throwIfCancelled();
          break;
        }

        // A provider may legally emit a short preamble before its first tool
        // call. Preserve the established single preamble, but do not accumulate
        // planning chatter from later rounds into the visible reply.
        if (!multilingualEnabled && streamedToolPreamble.isEmpty) {
          streamedToolPreamble =
              EmotionEnvelope.parse(generated.content).visibleText.trim();
        }
        final nativePlan = AgentToolPlanner.fromNativeToolCalls(
          generated.toolCalls,
          latestUserText: user.content,
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
          generated = await generate(finalRequestMessages, emitDeltas: false);
          cancellationToken?.throwIfCancelled();
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
          cancellationToken: cancellationToken,
          eventScopeId: job.id,
          userMessageId: user.id,
          assistantMessageId: job.assistantMessageId,
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
        cancellationToken?.throwIfCancelled();

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
        ];
        final proposalExecuted = AgentTaskLoopPolicy.containsProposal(
          nativePlan,
        );
        final loopLimitReached =
            agentPlanningRounds >= AgentTaskLoopPolicy.maxPlanningRounds ||
                agentToolCalls >= AgentTaskLoopPolicy.maxToolCalls;
        final shouldFinalize = proposalExecuted ||
            AgentTaskLoopPolicy.hasCommitPendingMedia(roundResults) ||
            loopLimitReached;
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
          generated = await generate(finalRequestMessages, emitDeltas: false);
          cancellationToken?.throwIfCancelled();
          break;
        }

        finalRequestMessages = <Map<String, Object?>>[
          ...history,
          <String, Object?>{
            'role': 'system',
            'content': AgentTaskLoopPolicy.planningInstruction(
              completedPlanningRounds: agentPlanningRounds,
              completedToolCalls: agentToolCalls,
            ),
          },
        ];
        agentPlanningRounds++;
        await _publishToolRuntime(
          phase: 'thinking',
          statusText: '正在根据结果核对下一步…',
          toolId: '',
        );
        generated = await generate(
          finalRequestMessages,
          emitDeltas: false,
          tools: taskToolDefinitions,
        );
        cancellationToken?.throwIfCancelled();
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
      MultilingualReply? multilingualReply;
      String visibleBody(EmotionEnvelopeData parsedEnvelope) {
        if (!multilingualEnabled) return parsedEnvelope.visibleText;
        final parsed = MultilingualReplyCodec.tryParse(
          parsedEnvelope.visibleText,
          messageId: job.assistantMessageId,
        );
        if (parsed == null) {
          throw const FormatException('三语正文协议解析失败');
        }
        multilingualReply = parsed;
        return parsed.chineseContent;
      }

      var envelope = EmotionEnvelope.parse(generated.content);
      String finalContent;
      try {
        finalContent = visibleBody(envelope);
      } on FormatException {
        if (!multilingualEnabled) rethrow;
        generated = await generate(
          <Map<String, Object?>>[
            ...finalRequestMessages,
            <String, Object?>{
              'role': 'assistant',
              'content': generated.content,
            },
            <String, Object?>{
              'role': 'system',
              'content': '''
【三语协议修复 · ONE RETRY】
上一份最终正文没有形成可解析的三语 JSON。保持完全相同的事实、语义、动作—对白顺序、情绪和语气，只修复输出结构；不要增加或删减内容。
$finalGenerationReminder
'''.trim(),
            },
          ],
          emitDeltas: false,
        );
        cancellationToken?.throwIfCancelled();
        envelope = EmotionEnvelope.parse(generated.content);
        finalContent = visibleBody(envelope);
      }
      if (!multilingualEnabled && streamedToolPreamble.isNotEmpty) {
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
$finalGenerationReminder
'''.trim(),
          },
        ];
        generated = await generate(
          correctionMessages,
          emitDeltas: false,
        );
        cancellationToken?.throwIfCancelled();
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
          multilingualReply = null;
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
        languageVariants: multilingualReply?.foreignVariants ??
            const <ChatLanguage, ChatLanguageVariant>{},
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
                  emotionKey: baseAssistant.emotionKey,
                  conversationPlan: conversationPlan,
                  responseMode: DialogueExpressionPlan.select(
                    latestUserText: user.content,
                    turnKey: user.id,
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
