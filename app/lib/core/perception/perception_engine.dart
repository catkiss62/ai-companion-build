import 'dart:math';

import '../database/app_database.dart';
import '../desire/desire_engine.dart';
import '../models/desire_state.dart';
import '../models/perception_snapshot.dart';
import '../platform/android_bridge.dart';
import '../presence/presence_intelligence.dart';
import 'current_device_context_refresher.dart';
import 'perception_interpreter.dart';
import 'screen_off_contact_policy.dart';

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

  late final CurrentDeviceContextRefresher contextRefresher =
      CurrentDeviceContextRefresher(
        db: db,
        android: android,
        interpreter: interpreter,
      );

  /// Updates the expiring Awareness used by the next prompt without applying
  /// any Desire/Thought/Presence side effects.
  Future<CurrentDeviceContextCapture?> refreshCurrentContext({
    required String reason,
    DateTime? now,
  }) =>
      contextRefresher.refresh(reason: reason, now: now);

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

    final context = await contextRefresher.refresh(
      reason: force ? 'manual_perception_capture' : 'inner_state_heartbeat',
      now: now,
    );
    if (context == null) return null;
    final deviceLabel = await android.deviceLabel();
    final deviceState = context.deviceState;
    final usage = context.usage;
    final recentSignals = context.recentSignals;
    final newEvents = lastMillis == null
        ? recentSignals
        : await db.deviceEventsAfter(
            DateTime.fromMillisecondsSinceEpoch(lastMillis),
            limit: 240,
          );

    final interpretation = context.interpretation;

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
      screenOffAt: _lastScreenOffAt(context.deviceStateEvents),
      now: now,
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
    required DateTime? screenOffAt,
    required DateTime now,
  }) async {
    // A transfer may begin after capture persistence but before inner-state
    // integration. Re-check here so the old device cannot grow Thought/Desire
    // after it has lost Active Brain ownership.
    if (!await db.brainWorkAllowed()) return;

    final activityKey = interpretation.dominantActivityKey;
    final activityLabel = interpretation.dominantActivityLabel;
    if (interpretation.dominantActivityMinutes >= 35) {
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
          DriveKey.social: 0.003,
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

    // Screen-on inactivity cannot reliably prove that the user is free: a
    // movie, reading session or paused foreground app may all look quiet. A
    // sustained screen-off session is instead treated as one bounded contact
    // opportunity, never as an availability fact and never once per heartbeat.
    if (!screenInteractive) {
      final current = await db.loadDesire();
      final decision = ScreenOffContactPolicy.evaluate(
        now: now,
        screenOffAt: screenOffAt,
        lastPulsedSessionKey:
            await db.getSetting('screen_off_contact_pulsed_session') ?? '',
        currentFatigue: current.drives[DriveKey.fatigue] ?? 0,
      );
      await db.setSetting('screen_off_contact_last_reason', decision.reason);
      await db.setSetting(
        'screen_off_contact_last_scale',
        decision.nightScale.toStringAsFixed(4),
      );
      if (decision.eligible) {
        await desire.applyExperience(
          {DriveKey.social: decision.socialPulse},
          baselineLearning: 0,
          source: 'screen_off_contact_window',
        );
        if (decision.thoughtStrength >= 0.08) {
          await desire.feedThought(
            text: '已经隔了一阵子没有互动，我有一点想找你聊聊；但这不代表你现在一定有空。',
            drive: DriveKey.social,
            incomingStrength: decision.thoughtStrength,
            source: 'perception/screen_off_contact_window',
            topicKey: 'contact:screen_off',
            now: now,
          );
        }
        await db.setSetting(
          'screen_off_contact_pulsed_session',
          decision.sessionKey,
        );
        await db.setSetting(
          'screen_off_contact_last_pulse_at',
          now.millisecondsSinceEpoch.toString(),
        );
      }
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

  DateTime? _lastScreenOffAt(List<Map<String, Object?>> events) {
    DateTime? latest;
    for (final row in events) {
      if ((row['event_type'] as String? ?? '') != 'screen_off') continue;
      final millis = (row['occurred_at'] as num?)?.toInt();
      if (millis == null) continue;
      final at = DateTime.fromMillisecondsSinceEpoch(millis);
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    return latest;
  }
}
