import 'dart:math';

import '../database/app_database.dart';
import '../desire/desire_engine.dart';
import '../models/desire_state.dart';
import '../models/perception_snapshot.dart';
import '../platform/android_bridge.dart';
import '../presence/presence_intelligence.dart';
import 'perception_interpreter.dart';

/// Captures Android signals and routes them through a bounded local
/// interpretation layer before anything reaches ordinary relationship context.
///
/// Raw notification/accessibility text and package names remain short-lived
/// device-event data. The model sees only expiring human-level awareness.
class PerceptionEngine {
  PerceptionEngine({
    required this.db,
    required this.android,
    required this.desire,
    PerceptionInterpreter interpreter = const PerceptionInterpreter(),
    PresenceIntelligenceEngine? presence,
  })  : interpreter = interpreter,
        presence = presence ?? PresenceIntelligenceEngine(db: db, desire: desire);

  final AppDatabase db;
  final AndroidBridge android;
  final DesireEngine desire;
  final PerceptionInterpreter interpreter;
  final PresenceIntelligenceEngine presence;

  Future<PerceptionSnapshot?> capture({
    bool force = false,
    Duration minInterval = const Duration(minutes: 4),
  }) async {
    // capture() may persist awareness and feed Thought/Desire. Even a manual
    // debug capture must respect single-Active-Brain and transfer freeze.
    if (!await db.brainWorkAllowed()) return null;
    if ((await db.getSetting('perception_enabled')) == '0') return null;

    final now = DateTime.now();
    final rawLast = await db.getSetting('last_perception_capture_at');
    final lastMillis = int.tryParse(rawLast ?? '');
    if (!force && lastMillis != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
      if (now.difference(last) < minInterval) return null;
    }

    final deviceLabel = await android.deviceLabel();
    final deviceState = await android.getPerceptionState();
    final usage = deviceState.usageAccess
        ? await android.getRecentUsage(minutes: 90)
        : const <UsageEventInfo>[];
    final recentSignals = await db.recentDeviceEvents(minutes: 30, limit: 240);
    final deviceStateEvents = await db.recentDeviceStateEvents();
    final newEvents = lastMillis == null
        ? recentSignals
        : await db.deviceEventsAfter(
            DateTime.fromMillisecondsSinceEpoch(lastMillis),
            limit: 240,
          );

    final interpretation = interpreter.interpret(
      usage: usage,
      recentSignals: recentSignals,
      deviceStateEvents: deviceStateEvents,
      deviceState: deviceState,
      now: now,
    );

    // The DB transaction performs a second Active Brain/transfer-lock check,
    // closing the race between native capture and local persistence.
    await db.syncAwarenessObservations(
      drafts: interpretation.observations,
      managedKeys: interpretation.managedKeys,
      now: now,
    );
    if (!await db.brainWorkAllowed()) return null;

    final newNotificationCount = newEvents
        .where((row) => (row['source'] as String? ?? '') == 'notification')
        .length;
    final newAccessibilityCount = newEvents
        .where((row) => (row['source'] as String? ?? '') == 'accessibility')
        .length;
    await _integrateIntoInnerState(
      interpretation: interpretation,
      newNotificationCount: newNotificationCount,
      newAccessibilityCount: newAccessibilityCount,
      screenInteractive: deviceState.screenInteractive,
    );

    final summary = interpretation.observations
        .map((e) => e.summary.trim())
        .where((e) => e.isNotEmpty)
        .join('\n');
    final hasInput = usage.isNotEmpty || recentSignals.isNotEmpty || summary.isNotEmpty;
    if (!hasInput && !force) {
      await db.setSetting(
        'last_perception_capture_at',
        now.millisecondsSinceEpoch.toString(),
      );
      return null;
    }

    final previousSummary = await db.getSetting('last_perception_summary');
    if (!force && previousSummary == summary && lastMillis != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
      if (now.difference(last) < const Duration(minutes: 15)) {
        await db.setSetting(
          'last_perception_capture_at',
          now.millisecondsSinceEpoch.toString(),
        );
        return null;
      }
    }

    final snapshot = await db.insertPerceptionSnapshot(
      summary: summary.isEmpty ? '近期没有形成稳定的日常观察。' : summary,
      // v0.20 deliberately stops copying foreground package names into the
      // long-lived snapshot layer. Raw usage stays available only locally.
      currentPackage: null,
      deviceLabel: deviceLabel,
      busyScore: interpretation.busyScore,
      notificationCount: interpretation.notificationCount,
      metadata: {
        'awareness_keys': interpretation.observations.map((e) => e.dedupeKey).toList(),
        'dominant_activity': interpretation.dominantActivityKey,
        'dominant_minutes': interpretation.dominantActivityMinutes,
        'accessibility_event_count_30m': interpretation.accessibilityEventCount,
        'sources': ['usage_category', 'device_state', 'signal_counts'],
      },
      occurredAt: now,
    );

    await db.setSetting('last_perception_summary', summary);
    await db.setSetting(
      'last_perception_capture_at',
      now.millisecondsSinceEpoch.toString(),
    );
    return snapshot;
  }

  Future<void> _integrateIntoInnerState({
    required PerceptionInterpretation interpretation,
    required int newNotificationCount,
    required int newAccessibilityCount,
    required bool screenInteractive,
  }) async {
    // A transfer may begin after capture persistence but before inner-state
    // integration. Re-check here so the old device cannot grow Thought/Desire
    // after it has lost Active Brain ownership.
    if (!await db.brainWorkAllowed()) return;

    final activityKey = interpretation.dominantActivityKey;
    final activityLabel = interpretation.dominantActivityLabel;
    if (interpretation.dominantActivityMinutes >= 35) {
      final now = DateTime.now();
      final lastLongMillis = int.tryParse(
        await db.getSetting('last_long_usage_thought_at') ?? '',
      );
      final lastLongCategory = await db.getSetting('last_long_usage_category');
      final normalizedKey = activityKey ?? 'general';
      final throttled = lastLongMillis != null &&
          lastLongCategory == normalizedKey &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(lastLongMillis)) <
              const Duration(minutes: 40);
      if (!throttled) {
        final text = activityLabel == null || activityKey == 'unknown'
            ? '你好像持续用手机有一阵了，我有点在意，也有点好奇你在忙什么。'
            : '你好像有一段时间主要在进行$activityLabel相关的活动，我有点好奇你现在在忙什么。';
        await desire.feedThought(
          text: text,
          drive: DriveKey.curiosity,
          incomingStrength: (0.16 + min(45, interpretation.dominantActivityMinutes) / 260)
              .clamp(0.16, 0.34)
              .toDouble(),
          source: 'perception/awareness',
          topicKey: 'usage:$normalizedKey',
        );
        await desire.applyExperience({
          DriveKey.curiosity: 0.012,
          DriveKey.attachment: 0.006,
        });
        await db.setSetting(
          'last_long_usage_thought_at',
          now.millisecondsSinceEpoch.toString(),
        );
        await db.setSetting('last_long_usage_category', normalizedKey);
      }
    }

    // External text is never promoted into a durable Thought. Dense interface
    // activity may nudge curiosity slightly, but only as a count.
    if (newAccessibilityCount >= 8) {
      await desire.applyExperience({DriveKey.curiosity: 0.004});
    }
    if (newNotificationCount >= 4) {
      await desire.applyExperience({
        DriveKey.social: 0.008,
        DriveKey.stress: 0.006,
      });
    }

    // Busy is deliberately not a negative attachment pulse. It only informs
    // the outbound gate later; she may still think of/contact the user.
    if (interpretation.busyScore < 0.35) {
      await desire.applyExperience({DriveKey.social: 0.006});
    }

    // Repeated phone activity is allowed to accumulate into a small, decaying
    // sense of presence. A single app switch is intentionally too weak; several
    // coarse captures over time can feed one mergeable Thought instead. Raw app
    // names/text never enter this layer.
    await presence.integrate(
      screenInteractive: screenInteractive,
      busyScore: interpretation.busyScore,
      dominantActivityMinutes: interpretation.dominantActivityMinutes,
      appSwitchesLast30Minutes: interpretation.appSwitchesLast30Minutes,
      newNotificationCount: newNotificationCount,
      newAccessibilityCount: newAccessibilityCount,
      hasCurrentActivity:
          interpretation.observations.any((observation) => observation.kind == 'current_activity'),
    );
  }
}
