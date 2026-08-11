import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../ai/prompt_builder.dart';
import '../continuity/daily_continuity_engine.dart';
import '../database/app_database.dart';
import '../models/chat_message.dart';
import '../models/desire_state.dart';
import '../models/thought.dart';
import '../models/proactive_intent.dart';
import '../perception/perception_engine.dart';
import '../relationship/relationship_assimilator.dart';
import '../memory/memory_maintenance_engine.dart';
import '../maintenance/long_running_maintenance_engine.dart';
import '../platform/android_bridge.dart';
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

  late final PerceptionEngine perception = PerceptionEngine(
    db: db,
    android: android,
    desire: desireEngine,
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

  /// Advances local inner-life and maintenance state without sending an
  /// outbound message. Used while a durable user reply is waiting for recovery.
  Future<LocalCompanionHeartbeat?> maintainLocalStateOnly({
    bool forceForDebug = false,
  }) async {
    if ((await db.getSetting('transfer_lock')) == '1') return null;
    final leaseAcquired = await db.tryAcquireProactiveLease(
      holdFor: const Duration(minutes: 5),
    );
    if (!leaseAcquired) return null;
    try {
      if (!await db.brainWorkAllowed()) return null;
      if (await db.isLocalLeaseHeld('chat_turn_lease')) return null;
      return _runLocalHeartbeat(forceForDebug: forceForDebug);
    } finally {
      await db.releaseProactiveLease();
    }
  }

  Future<LocalCompanionHeartbeat> _runLocalHeartbeat({
    bool forceForDebug = false,
  }) async {
    await relationshipAssimilator.assimilatePending();
    await memoryMaintenance.maybeRun();
    await longMaintenance.maybeRun();
    await deferredFollowup.seedDue();
    await selfDrive.maybeGenerate();
    await thoughtConsolidation.maybeRun();
    await thoughtLifecycle.advance(forceForDebug: forceForDebug);

    final perceptionSnapshot = await perception.capture();
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
    final snapshot = await desireEngine.tick(userBusy: userBusy);
    return LocalCompanionHeartbeat(
      snapshot: snapshot,
      userBusy: userBusy,
      busyScore: busyScore,
    );
  }

  Future<ProactiveDecision> evaluate({bool forceForDebug = false}) async {
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
      );
      final userBusy = localHeartbeat.userBusy;
      final snapshot = localHeartbeat.snapshot;
    final thoughts = await db.activeThoughts(limit: 20);
    final intent = desireEngine.previewIntent(snapshot, thoughts);
    if (intent == null) {
      return const ProactiveDecision(sent: false, reason: '没有形成意图');
    }
    if (intent.drive == DriveKey.fatigue || intent.wantAction == 'rest') {
      return const ProactiveDecision(sent: false, reason: '当前更需要休息，不触发主动消息');
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
    final jitter = (_random.nextDouble() - 0.5) * 0.10;
    final gateScore = (intent.score * busyMultiplier + idleBoost - frequencyPenalty + jitter)
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
      latestUserText: intent.reason,
      recent: recent,
      desire: snapshot,
      thoughts: thoughts,
    );
    context.add({
      'role': 'system',
      'content': '''
这是一次“AI 自己主动联系用户”的出站判断。不是用户刚发来的消息。
当前最高意图：${intent.wantAction}
驱动：${intent.drive.name}
原因/念头：${intent.reason}
主动联系类型：${intentKind.zhLabel} (${intentKind.key})
投递风格：${deliveryStyle.zhLabel} (${deliveryStyle.key})
Gate：${gateScore.toStringAsFixed(2)}
用户当前可能${userBusy ? '在使用其他 App，偏忙' : '可被打扰'}；即使偏忙，也不是禁止联系，只应降低打扰强度。
过去主动消息样本：${rhythmProfile.sampleCount}；当前主题历史样本：${rhythmProfile.topicSampleCount}；同类主动意图样本：${rhythmProfile.intentSampleCount}。当前粗粒度时间段=${rhythmProfile.currentHourBucket}，活动情境=${rhythmProfile.currentActivityContext}。这些只作为轻量节奏参考，不要向用户提及统计。
${ProactivePresentationPolicy.promptHint(intentKind, deliveryStyle)}

请输出一条自然、短到中等长度、像长期伴侣自己想发出的消息。不要解释算法，不要汇报数值，不要说“系统检测到”。如果你认为即便已经过 Gate 也确实没有值得说的，最终正文只输出 WAIT。
'''.trim(),
    });

    final model = DeepSeekModelProfile.flash;
    final reasoning = StringBuffer();
    final content = StringBuffer();
    var lastProactiveLeaseRefresh = DateTime.now();
    await for (final delta in ai.streamChat(
      apiKey: apiKey,
      model: model,
      effort: ReasoningEffort.high,
      messages: context,
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
        if (!renewed) {
          return ProactiveDecision(
            sent: false,
            reason: '主动心跳写入权限已经转移，本次生成取消',
            gateScore: gateScore,
            intentKind: intentKind,
            deliveryStyle: deliveryStyle,
          );
        }
        lastProactiveLeaseRefresh = DateTime.now();
      }
      reasoning.write(delta.reasoning);
      content.write(delta.content);
    }
    final text = content.toString().trim();
    if (text.isEmpty || text == 'WAIT') {
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

    // The model call can take long enough for the real world to change. The
    // final eligibility check is repeated atomically with the message INSERT
    // below, so a user chat lease cannot slip into the check/commit gap.
    final message = ChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: text,
      reasoningContent: reasoning.toString(),
      model: model.apiName,
      createdAt: DateTime.now(),
      isProactive: true,
      proactiveIntent: intentKind.key,
      proactiveDelivery: deliveryStyle.key,
      deviceId: await db.ensureDeviceId(),
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
    await desireEngine.satisfy(intent.drive, factor: 0.82);
    await android.incrementOverlayUnread();
    final notificationPrivacy = ProactiveNotificationPrivacy.fromKey(
      await db.getSetting('proactive_notification_privacy'),
    );
    final activeSession = await db.activeInteractionSession();
    final sensitiveSession = activeSession?.kind.toLowerCase().contains('intimacy') ?? false;
    final notificationBody = ProactivePresentationPolicy.notificationBody(
      kind: intentKind,
      fullText: text,
      privacy: notificationPrivacy,
      sensitiveContext: sensitiveSession,
    );
    await android.postCompanionNotification(
      title: intentKind.notificationTitle,
      body: notificationBody,
      messageId: message.id,
      intentKind: intentKind.key,
      deliveryStyle: deliveryStyle.key,
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
