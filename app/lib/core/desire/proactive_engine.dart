import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../ai/prompt_builder.dart';
import '../autonomy/public_web_discovery_engine.dart';
import '../continuity/daily_continuity_engine.dart';
import '../database/app_database.dart';
import '../emotion/emotion_classifier_service.dart';
import '../emotion/emotion_contract.dart';
import '../grounding/grounding_engine.dart';
import '../grounding/proactive_grounding_guard.dart';
import '../grounding/service_template_guard.dart';
import '../models/chat_message.dart';
import '../models/chat_segment.dart';
import '../models/desire_state.dart';
import '../models/thought.dart';
import '../models/proactive_intent.dart';
import '../models/proactive_notification_settings.dart';
import '../perception/perception_engine.dart';
import '../relationship/relationship_assimilator.dart';
import '../memory/memory_maintenance_engine.dart';
import '../maintenance/long_running_maintenance_engine.dart';
import '../platform/android_bridge.dart';
import '../presence/presence_intelligence.dart';
import '../storage/secure_config.dart';
import '../tts/tts_policy.dart';
import '../tts/tts_service.dart';
import 'desire_engine.dart';
import 'self_drive_engine.dart';
import 'thought_lifecycle_engine.dart';
import 'thought_consolidation_engine.dart';
import 'proactive_rhythm_engine.dart';
import 'proactive_presentation.dart';
import 'deferred_followup_engine.dart';

class LocalCompanionHeartbeat {
  const LocalCompanionHeartbeat({
    required this.snapshot,
    required this.userBusy,
    required this.busyScore,
  });

  final DesireSnapshot snapshot;
  final bool userBusy;
  final double busyScore;
}

class ProactiveDecision {
  const ProactiveDecision({
    required this.sent,
    required this.reason,
    this.message,
    this.gateScore = 0,
    this.intentKind,
    this.deliveryStyle,
  });

  final bool sent;
  final String reason;
  final ChatMessage? message;
  final double gateScore;
  final ProactiveIntentKind? intentKind;
  final ProactiveDeliveryStyle? deliveryStyle;
}

class _ProactiveGenerationCandidate {
  const _ProactiveGenerationCandidate({
    required this.reasoning,
    required this.content,
  });

  final String reasoning;
  final String content;
}

String _visibleChineseProactiveReasoning(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  final cjk = RegExp(r'[\u3400-\u9fff]').allMatches(text).length;
  final latinWords = RegExp(r'[A-Za-z]{2,}').allMatches(text).length;
  if (latinWords >= 6 && (cjk == 0 || latinWords * 2 > cjk)) return '';
  return text;
}

class ProactiveEngine {
  ProactiveEngine({
    required this.db,
    required this.desireEngine,
    required this.ai,
    required this.android,
    SecureConfig? secureConfig,
    TtsService? ttsService,
    Random? random,
  })  : secureConfig = secureConfig ?? SecureConfig.instance,
        _ttsOverride = ttsService,
        _random = random ?? Random();

  final AppDatabase db;
  final DesireEngine desireEngine;
  final DeepSeekClient ai;
  final AndroidBridge android;
  final SecureConfig secureConfig;
  final TtsService? _ttsOverride;
  final Random _random;
  final Uuid _uuid = Uuid();

  late final TtsService tts = _ttsOverride ?? TtsService(db: db);

  late final SelfDriveEngine selfDrive = SelfDriveEngine(
    db: db,
    desire: desireEngine,
    random: _random,
  );

  late final PresenceIntelligenceEngine presence = PresenceIntelligenceEngine(
    db: db,
    desire: desireEngine,
  );
  late final PerceptionEngine perception = PerceptionEngine(
    db: db,
    android: android,
    desire: desireEngine,
    presence: presence,
  );
  late final RelationshipAssimilator relationshipAssimilator =
      RelationshipAssimilator(db: db);
  late final MemoryMaintenanceEngine memoryMaintenance = MemoryMaintenanceEngine(db);
  late final ThoughtLifecycleEngine thoughtLifecycle = ThoughtLifecycleEngine(db: db, random: _random);
  late final ThoughtConsolidationEngine thoughtConsolidation = ThoughtConsolidationEngine(db);
  late final ProactiveRhythmEngine rhythm = ProactiveRhythmEngine(db: db, lifecycle: thoughtLifecycle);
  late final DeferredFollowupEngine deferredFollowup =
      DeferredFollowupEngine(db: db);
  late final LongRunningMaintenanceEngine longMaintenance =
      LongRunningMaintenanceEngine(db);
  late final DailyContinuityEngine dailyContinuity = DailyContinuityEngine(db);
  late final PublicWebDiscoveryEngine publicWebDiscovery =
      PublicWebDiscoveryEngine(
        db: db,
        desire: desireEngine,
        android: android,
        secureConfig: secureConfig,
      );

  /// Advances local inner-life and maintenance state without sending an
  /// outbound message. Used while a durable user reply is waiting for recovery.
  Future<LocalCompanionHeartbeat?> maintainLocalStateOnly({
    bool forceForDebug = false,
    Duration perceptionMinInterval = const Duration(minutes: 4),
  }) async {
    if ((await db.getSetting('transfer_lock')) == '1') return null;
    final leaseAcquired = await db.tryAcquireProactiveLease(
      holdFor: const Duration(minutes: 5),
    );
    if (!leaseAcquired) return null;
    try {
      if (!await db.brainWorkAllowed()) return null;
      if (await db.isLocalLeaseHeld('chat_turn_lease')) return null;
      return _runLocalHeartbeat(
        forceForDebug: forceForDebug,
        perceptionMinInterval: perceptionMinInterval,
      );
    } finally {
      await db.releaseProactiveLease();
    }
  }

  Future<LocalCompanionHeartbeat> _runLocalHeartbeat({
    bool forceForDebug = false,
    Duration perceptionMinInterval = const Duration(minutes: 4),
  }) async {
    await relationshipAssimilator.assimilatePending();
    await memoryMaintenance.maybeRun();
    await longMaintenance.maybeRun();
    await deferredFollowup.seedDue();
    await selfDrive.maybeGenerate();
    await thoughtConsolidation.maybeRun();
    await thoughtLifecycle.advance(forceForDebug: forceForDebug);

    final perceptionSnapshot = await perception.capture(
      minInterval: perceptionMinInterval,
    );
    if (await db.brainWorkAllowed()) {
      try {
        await dailyContinuity.maybeRefresh();
      } catch (_) {
        // A derived continuity refresh must never suppress an otherwise valid
        // proactive heartbeat. The continuity engine records its own error.
      }
    }
    final recentBusyScore = perceptionSnapshot?.busyScore ??
        await db.latestPerceptionBusyScore();
    final busyScore = (recentBusyScore ?? 0.30).clamp(0.0, 1.0).toDouble();
    final userBusy = busyScore >= 0.58;
    final advancedSnapshot = await desireEngine.tick(userBusy: userBusy);
    try {
      await publicWebDiscovery.maybeDiscover(snapshot: advancedSnapshot);
    } catch (_) {
      // Public discovery is optional enrichment. A provider/network fault must
      // never stop Desire, maintenance, recovery, or proactive evaluation.
    }
    // Discovery may have atomically satisfied the selected drive. Reload so a
    // proactive message in the same heartbeat cannot act on a stale snapshot.
    final snapshot = await db.loadDesire();
    return LocalCompanionHeartbeat(
      snapshot: snapshot,
      userBusy: userBusy,
      busyScore: busyScore,
    );
  }

  Future<ProactiveDecision> evaluate({
    bool forceForDebug = false,
    Duration perceptionMinInterval = const Duration(minutes: 4),
  }) async {
    if ((await db.getSetting('transfer_lock')) == '1') {
      return const ProactiveDecision(sent: false, reason: '设备转移锁定中');
    }
    // Debug/forced evaluation may bypass the probability gate, never the
    // cross-engine writer lease. Otherwise a debug tap could race the real
    // background heartbeat and emit duplicate messages.
    final leaseAcquired = await db.tryAcquireProactiveLease(
      holdFor: const Duration(minutes: 5),
    );
    if (!leaseAcquired) {
      return const ProactiveDecision(sent: false, reason: '主动心跳正在由另一引擎处理');
    }
    final evaluationStartedAt = DateTime.now();

    try {
      if (!await db.brainWorkAllowed()) {
        return const ProactiveDecision(sent: false, reason: '当前设备不是可运行的 Active Brain');
      }
      // A user-initiated chat turn has higher priority than an outbound ping.
      if (await db.isLocalLeaseHeld('chat_turn_lease')) {
        return const ProactiveDecision(sent: false, reason: '用户正在与我聊天');
      }

      final localHeartbeat = await _runLocalHeartbeat(
        forceForDebug: forceForDebug,
        perceptionMinInterval: perceptionMinInterval,
      );
      final userBusy = localHeartbeat.userBusy;
      final snapshot = localHeartbeat.snapshot;
    final thoughts = await db.activeThoughts(limit: 20);
    final activeSession = await db.activeInteractionSession();
    final intimacyAllowed = activeSession != null &&
        (activeSession.kind == 'intimacy' ||
            activeSession.kind == 'roleplay_intimacy');
    final intent = desireEngine.previewIntent(
      snapshot,
      thoughts,
      now: evaluationStartedAt,
      intimacyAllowed: intimacyAllowed,
    );
    if (intent == null) {
      return const ProactiveDecision(sent: false, reason: '没有形成意图');
    }
    if (intent.drive == DriveKey.fatigue || intent.wantAction == 'rest') {
      return const ProactiveDecision(sent: false, reason: '当前更需要休息，不触发主动消息');
    }

    final proactiveGrounding = await GroundingEngine(db).capture(
      now: evaluationStartedAt,
    );
    if (proactiveGrounding.pendingUserTurn) {
      return const ProactiveDecision(
        sent: false,
        reason: '仍有真实用户轮次尚未完成回复，主动联系让位给用户对话',
      );
    }

    final apiKey = await secureConfig.readApiKey();
    final endpoint = await secureConfig.readEndpoint();
    if (apiKey == null || apiKey.isEmpty) {
      return const ProactiveDecision(sent: false, reason: '没有 API Key；本地内在状态已继续运行');
    }

    final lastUser = await db.lastUserMessageAt();
    final idleMinutes = lastUser == null
        ? 180
        : max(0, DateTime.now().difference(lastUser).inMinutes);
    final sentToday = await db.proactiveCountSince(const Duration(hours: 24));
    final sentLastTwoHours = await db.proactiveCountSince(const Duration(hours: 2));
    if (!forceForDebug && sentToday >= 8) {
      await db.addProactiveHistory(
        triggerReason: '${intent.drive.name}:${intent.reason}',
        decision: 'daily_ceiling',
      );
      return const ProactiveDecision(
        sent: false,
        reason: '过去24小时已经主动联系较多，暂时留一点空间',
      );
    }
    if (!forceForDebug && sentLastTwoHours >= 2) {
      await db.addProactiveHistory(
        triggerReason: '${intent.drive.name}:${intent.reason}',
        decision: 'short_window_ceiling',
      );
      return const ProactiveDecision(
        sent: false,
        reason: '短时间内已经主动联系过，避免连续打扰',
      );
    }
    final intentThought = intent.thoughtId == null ? null : await db.thoughtById(intent.thoughtId!);
    final linkedThread = intentThought == null || intentThought.topicKey.isEmpty
        ? null
        : await db.activeUnfinishedThreadByTopic(intentThought.topicKey);
    final intentKind = ProactivePresentationPolicy.classify(
      intent: intent,
      linkedThread: linkedThread,
    );
    final rhythmContext = await rhythm.currentContext(
      now: evaluationStartedAt,
      busyScore: localHeartbeat.busyScore,
    );
    final rhythmProfile = await rhythm.profile(
      now: evaluationStartedAt,
      topicKey: intentThought?.topicKey ?? '',
      intentKind: intentKind.key,
      context: rhythmContext,
    );
    final deliveryStyle = ProactivePresentationPolicy.delivery(
      kind: intentKind,
      userBusy: userBusy,
      rhythm: rhythmProfile,
    );

    // Busy is deliberately a soft multiplier. The lower bound preserves the
    // user's preference that she may still leave a low-pressure message while
    // he is gaming/chatting/working.
    final busyMultiplier = userBusy ? 0.72 : 1.0;
    final idleBoost = (idleMinutes / 240).clamp(0.0, 0.24).toDouble();
    final frequencyPenalty = min(0.30, sentToday * 0.055 + sentLastTwoHours * 0.035);
    final presenceMomentum = await presence.currentMomentum(now: evaluationStartedAt);
    // v0.31: phone activity already enters Desire through Presence ->
    // Drive/Thought pulses. The delivery Gate no longer adds the same signal a
    // second time, avoiding double weighting of device activity.
    const presenceBoost = 0.0;
    final jitter = (_random.nextDouble() - 0.5) * 0.10;
    final gateScore = (intent.score * busyMultiplier +
            idleBoost +
            presenceBoost -
            frequencyPenalty +
            jitter)
        .clamp(0.0, 1.0)
        .toDouble();
    final baseThreshold = userBusy ? 0.66 : 0.60;
    // Learned caution is deliberately capped. After a long quiet interval the
    // threshold gets a small recovery relief so a history of missed messages
    // can never train her into permanent silence. Explicit spam ceilings above
    // still prevent repeated bursts.
    final longIdleRelief = idleMinutes >= 12 * 60
        ? 0.045
        : idleMinutes >= 6 * 60
            ? 0.025
            : 0.0;
    final threshold =
        (baseThreshold + rhythmProfile.thresholdAdjustment - longIdleRelief)
            .clamp(0.52, 0.76)
            .toDouble();

    await db.setSetting(
      'presence_last_gate_breakdown',
      jsonEncode({
        'intent': double.parse(intent.score.toStringAsFixed(3)),
        'busyMultiplier': double.parse(busyMultiplier.toStringAsFixed(3)),
        'idleBoost': double.parse(idleBoost.toStringAsFixed(3)),
        'presenceMomentum': double.parse(presenceMomentum.toStringAsFixed(3)),
        'presenceBoost': double.parse(presenceBoost.toStringAsFixed(3)),
        'presenceAppliedToDesire': true,
        'frequencyPenalty': double.parse(frequencyPenalty.toStringAsFixed(3)),
        'jitter': double.parse(jitter.toStringAsFixed(3)),
        'rhythmThresholdAdjustment':
            double.parse(rhythmProfile.thresholdAdjustment.toStringAsFixed(3)),
        'longIdleRelief': double.parse(longIdleRelief.toStringAsFixed(3)),
        'gate': double.parse(gateScore.toStringAsFixed(3)),
        'threshold': double.parse(threshold.toStringAsFixed(3)),
        'busy': userBusy,
        'idleMinutes': idleMinutes,
      }),
    );

    if (!forceForDebug && gateScore < threshold) {
      await db.addProactiveHistory(
        triggerReason: '${intent.drive.name}:${intent.reason}',
        decision: 'wait',
      );
      return ProactiveDecision(
        sent: false,
        reason: 'Gate ${gateScore.toStringAsFixed(2)} < ${threshold.toStringAsFixed(2)}',
        gateScore: gateScore,
        intentKind: intentKind,
        deliveryStyle: deliveryStyle,
      );
    }

    final recent = await db.recentMessages(limit: 28);
    final prompt = PromptBuilder(db);
    final context = await prompt.buildChatMessages(
      latestUserText: '',
      retrievalQuery: intent.reason,
      recent: recent,
      desire: snapshot,
      thoughts: thoughts,
      mode: PromptGenerationMode.proactive,
      now: evaluationStartedAt,
      groundingOverride: proactiveGrounding,
    );
    // The editable 08_proactive_turn template now owns these former inline
    // contracts: 当前“内在反应 + 表达过滤”仍完整生效；正文停在最有性格的自然落点。
    context.add({
      'role': 'system',
      'content': '''
这是一次“AI 自己主动联系用户”的出站判断。不是用户刚发来的消息。
当前最高意图：${intent.wantAction}
驱动：${intent.drive.name}
内部线索来源：${ThoughtProvenancePolicy.fromSource(intent.reasonSource).key}
存在关联主题：${intentThought?.topicKey.isNotEmpty == true ? 'true' : 'false'}
这里只提供结构化线索，不注入 Thought 原文。它不是用户原话；只有 ANSWERED CHAT HISTORY 中明确标记 REAL_USER_HISTORY 的数据库历史才是用户真实说过的话，而且这些历史不等于当前 user turn。
主动联系类型：${intentKind.zhLabel} (${intentKind.key})
投递风格：${deliveryStyle.zhLabel} (${deliveryStyle.key})
Gate：${gateScore.toStringAsFixed(2)}
用户当前可能${userBusy ? '在使用其他 App，偏忙' : '可被打扰'}；即使偏忙，也不是禁止联系，只应降低打扰强度。
过去主动消息样本：${rhythmProfile.sampleCount}；当前主题历史样本：${rhythmProfile.topicSampleCount}；同类主动意图样本：${rhythmProfile.intentSampleCount}。当前粗粒度时间段=${rhythmProfile.currentHourBucket}，活动情境=${rhythmProfile.currentActivityContext}。这些只作为轻量节奏参考，不要向用户提及统计。
${ProactivePresentationPolicy.promptHint(intentKind, deliveryStyle)}
严格服从前文可编辑的【CURRENT TURN CONTRACT】与 REALITY GROUNDING；结构化运行数据不是用户发言。
'''.trim(),
    });

    final model = DeepSeekModelProfile.flash;
    final lastGroundedUser = proactiveGrounding.lastUserMessageId == null
        ? null
        : await db.messageById(proactiveGrounding.lastUserMessageId!);
    final lastGroundedUserText = lastGroundedUser?.content ?? '';
    var lastProactiveLeaseRefresh = DateTime.now();

    Future<_ProactiveGenerationCandidate?> generateCandidate(
      List<Map<String, Object?>> promptMessages,
    ) async {
      final reasoning = StringBuffer();
      final content = StringBuffer();
      await for (final delta in ai.streamChat(
        apiKey: apiKey,
        model: model,
        effort: ReasoningEffort.high,
        messages: promptMessages,
        endpoint: endpoint,
        thinking: true,
        maxTokens: 700,
      )) {
        if (DateTime.now().difference(lastProactiveLeaseRefresh) >=
            const Duration(minutes: 1)) {
          final renewed = await db.renewLocalLease(
            'proactive_lease_until',
            holdFor: const Duration(minutes: 5),
          );
          if (!renewed) return null;
          lastProactiveLeaseRefresh = DateTime.now();
        }
        reasoning.write(delta.reasoning);
        content.write(delta.content);
      }
      return _ProactiveGenerationCandidate(
        reasoning: reasoning.toString().trim(),
        content: content.toString().trim(),
      );
    }

    Future<void> noteGroundingRetry(String reason) async {
      final count = int.tryParse(
            await db.getSetting('grounding_retry_count') ?? '',
          ) ??
          0;
      await db.setSetting('grounding_retry_count', (count + 1).toString());
      await db.setSetting(
        'grounding_retry_last_at',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await db.setSetting('grounding_retry_last_reason', reason);
    }

    Future<ProactiveDecision> blockGrounding(String reason) async {
      final previousBlocks = int.tryParse(
            await db.getSetting('grounding_guard_block_count') ?? '',
          ) ??
          0;
      await db.setSetting(
        'grounding_guard_block_count',
        (previousBlocks + 1).toString(),
      );
      await db.setSetting(
        'grounding_guard_last_at',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await db.setSetting('grounding_guard_last_reason', reason);
      await db.addProactiveHistory(
        triggerReason: '${intent.drive.name}:grounding_guard',
        decision: 'grounding_guard_block',
      );
      return ProactiveDecision(
        sent: false,
        reason: 'Reality Grounding 拦截了一次把已完成历史当成当前用户轮次的生成',
        gateScore: gateScore,
        intentKind: intentKind,
        deliveryStyle: deliveryStyle,
      );
    }

    var candidate = await generateCandidate(context);
    if (candidate == null) {
      return ProactiveDecision(
        sent: false,
        reason: '主动心跳写入权限已经转移，本次生成取消',
        gateScore: gateScore,
        intentKind: intentKind,
        deliveryStyle: deliveryStyle,
      );
    }

    bool isWait(_ProactiveGenerationCandidate value) =>
        value.content.isEmpty || value.content == 'WAIT';

    // Proactive generation does not use DurableGenerationRunner, so it must
    // explicitly share the same machine-only envelope normalization before
    // guards, SQLite, notification, overlay and TTS can see the content.
    var emotionEnvelope = EmotionEnvelope.parse(candidate.content);
    candidate = _ProactiveGenerationCandidate(
      reasoning: candidate.reasoning,
      content: emotionEnvelope.visibleText,
    );

    if (isWait(candidate)) {
      await db.addProactiveHistory(
        triggerReason: '${intent.drive.name}:${intent.reason}',
        decision: 'model_wait',
      );
      return ProactiveDecision(
        sent: false,
        reason: '模型选择 WAIT',
        gateScore: gateScore,
        intentKind: intentKind,
        deliveryStyle: deliveryStyle,
      );
    }

    var textGuard = ProactiveGroundingGuard.evaluate(
      grounding: proactiveGrounding,
      text: candidate.content,
    );
    var reasoningGuard = ProactiveReasoningGroundingGuard.evaluate(
      grounding: proactiveGrounding,
      reasoning: candidate.reasoning,
      lastUserText: lastGroundedUserText,
    );
    final recentAssistantTexts = recent
        .where((message) => message.isAssistant)
        .map((message) => message.content);
    var serviceGuard = ServiceTemplateGuard.evaluate(
      text: candidate.content,
      recentAssistantTexts: recentAssistantTexts,
      proactive: true,
    );

    if (!textGuard.allowed ||
        !reasoningGuard.allowed ||
        !serviceGuard.allowed) {
      final retryReason = !reasoningGuard.allowed
          ? reasoningGuard.reason
          : !textGuard.allowed
              ? textGuard.reason
              : serviceGuard.reason;
      if (!serviceGuard.allowed) {
        await ServiceTemplateGuardTelemetry.note(
          db,
          result: serviceGuard,
          mode: 'proactive',
          action: 'rewrite',
        );
      }
      await noteGroundingRetry(retryReason);
      final retryContext = <Map<String, Object?>>[
        ...context,
        {
          'role': 'system',
          'content': '''
【PROACTIVE OUTPUT CORRECTION · ONE RETRY】
上一份候选违反了当前出站约束：$retryReason。
CURRENT_USER_TURN = NONE。最后一条真实用户消息已经回答完毕，用户之后没有新的发言。
请完全丢弃上一份候选的推理方向，从当前 Desire / Thought / Awareness / 已完成历史重新选择“我现在主动想说什么”。
推理和正文都不能虚构用户刚刚说了、回复了或发来了任何内容；也不能用“一直在、不走、不催、你忙你的、等你回来”一类待命客服模板主动找话。
重选时仍保持当前性格的内在反应与表达过滤；说具体内容、真实发现或自己的念头，没有值得说的就输出 WAIT。
'''.trim(),
        },
      ];
      final retried = await generateCandidate(retryContext);
      if (retried == null) {
        return ProactiveDecision(
          sent: false,
          reason: '主动心跳写入权限已经转移，本次纠正生成取消',
          gateScore: gateScore,
          intentKind: intentKind,
          deliveryStyle: deliveryStyle,
        );
      }
      emotionEnvelope = EmotionEnvelope.parse(retried.content);
      candidate = _ProactiveGenerationCandidate(
        reasoning: retried.reasoning,
        content: emotionEnvelope.visibleText,
      );
      if (isWait(candidate)) {
        await db.addProactiveHistory(
          triggerReason: '${intent.drive.name}:${intent.reason}',
          decision: 'grounding_retry_wait',
        );
        return ProactiveDecision(
          sent: false,
          reason: 'Reality Grounding 纠正后模型选择 WAIT',
          gateScore: gateScore,
          intentKind: intentKind,
          deliveryStyle: deliveryStyle,
        );
      }
      textGuard = ProactiveGroundingGuard.evaluate(
        grounding: proactiveGrounding,
        text: candidate.content,
      );
      reasoningGuard = ProactiveReasoningGroundingGuard.evaluate(
        grounding: proactiveGrounding,
        reasoning: candidate.reasoning,
        lastUserText: lastGroundedUserText,
      );
      serviceGuard = ServiceTemplateGuard.evaluate(
        text: candidate.content,
        recentAssistantTexts: recentAssistantTexts,
        proactive: true,
      );
    }

    if (!textGuard.allowed) {
      return blockGrounding(textGuard.reason);
    }
    if (!reasoningGuard.allowed) {
      return blockGrounding(reasoningGuard.reason);
    }
    if (!serviceGuard.allowed) {
      await ServiceTemplateGuardTelemetry.note(
        db,
        result: serviceGuard,
        mode: 'proactive',
        action: 'block',
      );
      await db.addProactiveHistory(
        triggerReason: '${intent.drive.name}:${intent.reason}',
        decision: 'service_template_block',
      );
      return ProactiveDecision(
        sent: false,
        reason: '主动候选命中重复服务模板，已取消',
        gateScore: gateScore,
        intentKind: intentKind,
        deliveryStyle: deliveryStyle,
      );
    }

    final text = candidate.content;
    final companionEmotion = await EmotionClassifierService.instance.resolve(
      rawTag: emotionEnvelope.rawTag,
      visibleText: text,
    );

    // The model call can take long enough for the real world to change. The
    // final eligibility check is repeated atomically with the message INSERT
    // below, so a user chat lease cannot slip into the check/commit gap.
    final message = ChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: text,
      reasoningContent: _visibleChineseProactiveReasoning(candidate.reasoning),
      model: model.apiName,
      createdAt: DateTime.now(),
      isProactive: true,
      proactiveIntent: intentKind.key,
      proactiveDelivery: deliveryStyle.key,
      deviceId: await db.ensureDeviceId(),
      segments: ChatSegmentCodec.parseAssistantText(text),
      emotionRawTag: companionEmotion.rawTag,
      emotionKey: companionEmotion.key,
      emotionLabel: companionEmotion.label,
      emotionConfidence: companionEmotion.confidence,
      emotionTop3Json: companionEmotion.top3Json,
      emotionSource: companionEmotion.source,
    );
    final commitBlock = await db.commitProactiveMessageIfCurrent(
      message: message,
      evaluationStartedAt: evaluationStartedAt,
    );
    if (commitBlock != null) {
      final userPreempted = commitBlock == 'chat_turn' || commitBlock == 'new_user';
      await db.addProactiveHistory(
        triggerReason: '${intent.drive.name}:${intent.reason}',
        decision: userPreempted ? 'preempted_by_user' : 'preempted_by_device_state',
      );
      return ProactiveDecision(
        sent: false,
        reason: userPreempted
            ? '用户已经开始新的聊天，本次主动消息取消'
            : '设备状态已变化，本次主动消息取消',
        gateScore: gateScore,
        intentKind: intentKind,
        deliveryStyle: deliveryStyle,
      );
    }
    await db.addProactiveHistory(
      triggerReason: '${intent.drive.name}:${intent.reason}',
      decision: 'sent',
      messageId: message.id,
    );
    await db.markRecentlyInjectedMemoriesExpressed(
      message.content,
      now: message.createdAt,
    );
    if (intentThought != null) {
      await thoughtLifecycle.markActed(thought: intentThought, messageId: message.id);
    }
    final now = DateTime.now();
    if (linkedThread != null &&
        linkedThread.followupDueAt != null &&
        !linkedThread.followupDueAt!.isAfter(now) &&
        linkedThread.followupSeededAt != null) {
      await db.markUnfinishedThreadFollowupSent(linkedThread.id);
    }
    await rhythm.registerSent(
      message: message,
      thoughtId: intent.thoughtId,
      topicKey: intentThought?.topicKey ?? '',
      threadId: linkedThread?.id,
      context: rhythmContext,
    );
    // Sending the message itself releases some tension, but user response is
    // what can truly settle the originating thought later.
    await desireEngine.satisfyIntent(
      intent,
      intensity: 0.55,
      now: DateTime.now(),
    );
    await android.incrementOverlayUnread();
    final notificationPrivacy = ProactiveNotificationPrivacy.fromKey(
      await db.getSetting('proactive_notification_privacy'),
    );
    final sensitiveSession = activeSession?.kind.toLowerCase().contains('intimacy') ?? false;
    final notificationBody = ProactivePresentationPolicy.notificationBody(
      kind: intentKind,
      fullText: text,
      privacy: notificationPrivacy,
      sensitiveContext: sensitiveSession,
    );
    final popupMode = ProactivePopupMode.fromSetting(
      await db.getSetting('proactive_popup_mode'),
    );
    final notificationSound = ProactiveNotificationSound.fromSetting(
      await db.getSetting('proactive_notification_sound'),
    );
    final effectiveNotificationDelivery = popupMode.effectiveDeliveryStyle(
      deliveryStyle.key,
    );
    await db.setSetting(
      'last_proactive_notification_presentation',
      jsonEncode({
        'popupMode': popupMode.key,
        'suggestedDelivery': deliveryStyle.key,
        'effectiveDelivery': effectiveNotificationDelivery,
        'sound': notificationSound.key,
        'at': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    await android.postCompanionNotification(
      title: intentKind.notificationTitle,
      body: notificationBody,
      messageId: message.id,
      intentKind: intentKind.key,
      deliveryStyle: effectiveNotificationDelivery,
      soundKey: notificationSound.key,
    );

    final voicePolicy = ProactiveTtsPolicy.fromSetting(
      await db.getSetting('proactive_tts_policy'),
    );
    final ttsEnabled = (await db.getSetting('tts_enabled')) != '0';
    if (ttsEnabled && voicePolicy == ProactiveTtsPolicy.immediate) {
      // Do not block the proactive heartbeat on local model generation/playback.
      // Background FlutterEngine owns a NativeTtsBridge only for this explicit
      // user-selected policy.
      unawaited(tts.speak(text, manual: true).then((ok) async {
        if (ok) {
          await db.setSetting('last_proactive_spoken_message_id', message.id);
        }
      }));
    }
    return ProactiveDecision(
      sent: true,
      reason: intent.reason,
      message: message,
      gateScore: gateScore,
      intentKind: intentKind,
      deliveryStyle: deliveryStyle,
    );
    } finally {
      await db.releaseProactiveLease();
    }
  }
}
