import 'dart:math';

import '../database/app_database.dart';
import '../models/chat_message.dart';
import '../models/proactive_feedback.dart';
import 'thought_lifecycle_engine.dart';

class ProactiveRhythmContext {
  const ProactiveRhythmContext({
    required this.hourBucket,
    required this.activityContext,
    required this.busyScore,
  });

  final String hourBucket;
  final String activityContext;
  final double busyScore;

  static String hourBucketFor(DateTime instant) {
    final hour = instant.hour;
    if (hour < 6) return 'late_night';
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    return 'evening';
  }
}

class ProactiveRhythmProfile {
  const ProactiveRhythmProfile({
    required this.sampleCount,
    required this.responseRate,
    required this.quickResponseRate,
    required this.medianLatencyMinutes,
    required this.currentHourAffinity,
    required this.thresholdAdjustment,
    required this.preferLowPressure,
    this.topicSampleCount = 0,
    this.topicAdjustment = 0,
    this.intentSampleCount = 0,
    this.intentAdjustment = 0,
    this.currentHourBucket = 'unknown',
    this.currentActivityContext = 'unknown',
    this.timingAdjustment = 0,
    this.hourAdjustment = 0,
    this.activityAdjustment = 0,
    this.timingSampleWeight = 0,
    this.activitySampleWeight = 0,
  });

  final int sampleCount;
  final double responseRate;
  final double quickResponseRate;
  final double medianLatencyMinutes;
  final double currentHourAffinity;
  final double thresholdAdjustment;
  final bool preferLowPressure;
  final int topicSampleCount;
  final double topicAdjustment;
  final int intentSampleCount;
  final double intentAdjustment;
  final String currentHourBucket;
  final String currentActivityContext;
  final double timingAdjustment;
  final double hourAdjustment;
  final double activityAdjustment;
  final double timingSampleWeight;
  final double activitySampleWeight;

  factory ProactiveRhythmProfile.neutral({
    String hourBucket = 'unknown',
    String activityContext = 'unknown',
  }) =>
      ProactiveRhythmProfile(
        sampleCount: 0,
        responseRate: 0.5,
        quickResponseRate: 0.35,
        medianLatencyMinutes: 120,
        currentHourAffinity: 0,
        thresholdAdjustment: 0,
        preferLowPressure: false,
        currentHourBucket: hourBucket,
        currentActivityContext: activityContext,
      );
}

class ProactiveRhythmEngine {
  ProactiveRhythmEngine({required this.db, required this.lifecycle});

  final AppDatabase db;
  final ThoughtLifecycleEngine lifecycle;

  static const _knownActivities = <String>{
    'game',
    'audio',
    'video',
    'image',
    'social',
    'news',
    'maps',
    'productivity',
    'browser',
  };

  /// Captures only coarse, already-interpreted local context. Raw package names,
  /// notification bodies and Accessibility text never enter rhythm learning.
  Future<ProactiveRhythmContext> currentContext({
    DateTime? now,
    double? busyScore,
  }) async {
    final instant = now ?? DateTime.now();
    final observations = await db.activeAwarenessObservations(
      limit: 8,
      now: instant,
    );
    var resolvedBusy = busyScore ?? await db.latestPerceptionBusyScore();
    String? currentActivity;
    var screenOff = false;
    for (final observation in observations) {
      if (observation.kind == 'screen_state') {
        // v0.20 only emits screen_state while the screen is not interactive.
        screenOff = true;
      } else if (observation.kind == 'current_activity') {
        final value = observation.metadata['activity']?.toString().trim().toLowerCase();
        if (value != null && value.isNotEmpty && value != 'unknown') {
          currentActivity = value;
        }
      } else if (observation.kind == 'availability' && resolvedBusy == null) {
        resolvedBusy = (observation.metadata['busy_score'] as num?)?.toDouble();
      }
    }

    final busy = (resolvedBusy ?? 0.30).clamp(0.0, 1.0).toDouble();
    String activity;
    if (screenOff) {
      activity = 'screen_off';
    } else if (currentActivity != null) {
      activity = _knownActivities.contains(currentActivity) ? currentActivity! : 'other';
    } else if (busy >= 0.58) {
      activity = 'busy_unknown';
    } else {
      activity = 'idle';
    }
    return ProactiveRhythmContext(
      hourBucket: ProactiveRhythmContext.hourBucketFor(instant),
      activityContext: activity,
      busyScore: busy,
    );
  }

  Future<void> registerSent({
    required ChatMessage message,
    String? thoughtId,
    String topicKey = '',
    String? threadId,
    ProactiveRhythmContext? context,
  }) async {
    final sentContext = context ?? await currentContext(now: message.createdAt);
    await db.createProactiveFeedback(
      proactiveMessageId: message.id,
      thoughtId: thoughtId,
      topicKey: topicKey,
      threadId: threadId,
      intentKind: message.proactiveIntent,
      deliveryStyle: message.proactiveDelivery,
      sentAt: message.createdAt,
      contextHourBucket: sentContext.hourBucket,
      contextActivity: sentContext.activityContext,
      contextBusy: sentContext.busyScore,
    );
  }

  Future<void> captureUserResponse(ChatMessage user) async {
    // The adaptation switch only disables learned timing changes. The response
    // still has to bind to the proactive message so Thought/thread semantics and
    // post-turn outcome extraction continue to work normally.
    final pending = await db.latestPendingProactiveFeedback();
    if (pending == null || !user.createdAt.isAfter(pending.sentAt)) return;
    final rawLatency = user.createdAt.difference(pending.sentAt);
    final expiryHours = int.tryParse(await db.getSetting('proactive_feedback_expiry_hours') ?? '') ?? 10;
    if (rawLatency > Duration(hours: expiryHours.clamp(4, 36).toInt())) {
      await db.expireProactiveFeedback(before: user.createdAt);
      return;
    }
    final latency = rawLatency.inSeconds.clamp(0, 7 * 86400).toInt();
    final bucket = _bucket(latency);
    final quality = _responseQuality(latency, user.content.length);
    await db.resolveProactiveFeedback(
      id: pending.id,
      userResponseMessageId: user.id,
      latencySeconds: latency,
      responseBucket: bucket,
      userTextLength: user.content.trim().length,
      responseQuality: quality,
    );
    if (pending.thoughtId != null && pending.thoughtId!.isNotEmpty) {
      await lifecycle.markResponseReceived(
        thoughtId: pending.thoughtId!,
        responseQuality: quality,
        responseMessageId: user.id,
      );
    }
  }

  Future<ProactiveRhythmProfile> profile({
    DateTime? now,
    String topicKey = '',
    String intentKind = '',
    ProactiveRhythmContext? context,
  }) async {
    final instant = now ?? DateTime.now();
    final rhythmContext = context ?? await currentContext(now: instant);
    if ((await db.getSetting('proactive_adaptation_enabled')) == '0') {
      return ProactiveRhythmProfile.neutral(
        hourBucket: rhythmContext.hourBucket,
        activityContext: rhythmContext.activityContext,
      );
    }

    final expiryHours = int.tryParse(await db.getSetting('proactive_feedback_expiry_hours') ?? '') ?? 10;
    await db.expireProactiveFeedback(
      before: instant.subtract(Duration(hours: expiryHours.clamp(4, 36).toInt())),
    );
    // A year of feedback is retained on disk, but profile() needs only a bounded
    // recent window. Exponential decay below makes old habits fade naturally.
    final rows = await db.recentProactiveFeedback(limit: 180);
    final topicRows = topicKey.trim().isEmpty
        ? const <ProactiveFeedback>[]
        : await db.recentProactiveFeedbackByTopic(topicKey, limit: 36);
    final intentRows = intentKind.trim().isEmpty
        ? const <ProactiveFeedback>[]
        : await db.recentProactiveFeedbackByIntent(intentKind, limit: 40);

    final responded = rows.where((e) => e.responded).toList();
    final responseRate = rows.isEmpty ? 0.5 : responded.length / rows.length;
    final quick = responded.where((e) => (e.responseLatencySeconds ?? 999999) <= 90 * 60).length;
    final quickRate = responded.isEmpty ? 0.35 : quick / responded.length;
    final latencies = responded
        .map((e) => (e.responseLatencySeconds ?? 0) / 60.0)
        .toList()
      ..sort();
    final median = latencies.isEmpty ? 120.0 : latencies[latencies.length ~/ 2];

    final hourRows = rows
        .where((e) => e.contextHourBucket == rhythmContext.hourBucket)
        .toList(growable: false);
    final activityRows = rows
        .where((e) => e.contextActivity == rhythmContext.activityContext)
        .toList(growable: false);

    final hourSignal = _weightedSignal(
      hourRows,
      _timingFit,
      instant,
      priorWeight: 3.0,
    );
    final activitySignal = _weightedSignal(
      activityRows,
      _timingFit,
      instant,
      priorWeight: 3.0,
    );
    final globalTimingSignal = _weightedSignal(
      rows,
      _timingFit,
      instant,
      priorWeight: 10.0,
    );
    final topicSignal = _weightedSignal(
      topicRows,
      _topicFit,
      instant,
      priorWeight: 2.5,
    );
    final intentSignal = _weightedSignal(
      intentRows,
      _topicFit,
      instant,
      priorWeight: 5.0,
    );

    // Positive fit means the context worked well, so it lowers the outbound
    // threshold. Negative fit raises it. Neutral priors and decay prevent a few
    // accidental interactions from rewriting her personality.
    final hourAdjustment = (-hourSignal.score * 0.09).clamp(-0.040, 0.060).toDouble();
    final activityAdjustment = (-activitySignal.score * 0.08).clamp(-0.035, 0.055).toDouble();
    final globalTimingAdjustment =
        (-globalTimingSignal.score * 0.025).clamp(-0.015, 0.025).toDouble();
    final timingAdjustment =
        (hourAdjustment + activityAdjustment + globalTimingAdjustment)
            .clamp(-0.055, 0.095)
            .toDouble();
    final topicAdjustment =
        (-topicSignal.score * 0.12).clamp(-0.040, 0.090).toDouble();
    final intentAdjustment =
        (-intentSignal.score * 0.055).clamp(-0.020, 0.045).toDouble();
    final totalAdjustment =
        (timingAdjustment + topicAdjustment + intentAdjustment)
            .clamp(-0.070, 0.120)
            .toDouble();

    return ProactiveRhythmProfile(
      sampleCount: rows.length,
      responseRate: responseRate,
      quickResponseRate: quickRate,
      medianLatencyMinutes: median,
      // Kept for old diagnostics. It now represents the learned fit of the
      // current coarse time window rather than raw response-rate arithmetic.
      currentHourAffinity: hourSignal.score.clamp(-0.5, 0.5).toDouble(),
      thresholdAdjustment: totalAdjustment,
      preferLowPressure: rhythmContext.busyScore >= 0.58 ||
          timingAdjustment >= 0.035 ||
          topicAdjustment >= 0.040 ||
          intentAdjustment >= 0.030,
      topicSampleCount: topicRows.length,
      topicAdjustment: topicAdjustment,
      intentSampleCount: intentRows.length,
      intentAdjustment: intentAdjustment,
      currentHourBucket: rhythmContext.hourBucket,
      currentActivityContext: rhythmContext.activityContext,
      timingAdjustment: timingAdjustment,
      hourAdjustment: hourAdjustment,
      activityAdjustment: activityAdjustment,
      timingSampleWeight: hourSignal.weight,
      activitySampleWeight: activitySignal.weight,
    );
  }

  _WeightedSignal _weightedSignal(
    List<ProactiveFeedback> rows,
    double? Function(ProactiveFeedback row) selector,
    DateTime now, {
    required double priorWeight,
  }) {
    var weighted = 0.0;
    var weight = 0.0;
    for (final row in rows) {
      final signal = selector(row);
      if (signal == null) continue;
      final ageHours = max(0.0, now.difference(row.sentAt).inMinutes / 60.0);
      final ageDays = ageHours / 24.0;
      final decay = pow(0.5, ageDays / 45.0).toDouble();
      // No-response is intrinsically ambiguous: maybe the user never saw the
      // notification. It therefore carries less than half the weight of an
      // explicit engaged/deferred/dismissed response.
      final reliability = row.outcome == 'no_response' ? 0.45 : 1.0;
      final w = decay * reliability;
      weighted += signal * w;
      weight += w;
    }
    return _WeightedSignal(
      score: weight <= 0 ? 0 : weighted / (priorWeight + weight),
      weight: weight,
    );
  }

  double? _timingFit(ProactiveFeedback row) {
    if (row.timingFit != null) return row.timingFit!.clamp(-1.0, 1.0).toDouble();
    return switch (row.outcome) {
      'deferred' => -0.75,
      'engaged' || 'resolved' =>
        (row.responseLatencySeconds ?? 999999) <= 2 * 3600 ? 0.55 : 0.35,
      'acknowledged' =>
        (row.responseLatencySeconds ?? 999999) <= 2 * 3600 ? 0.25 : 0.10,
      'no_response' => -0.18,
      'dismissed' || 'redirected' => 0.0,
      _ => null,
    };
  }

  double? _topicFit(ProactiveFeedback row) {
    if (row.topicFit != null) return row.topicFit!.clamp(-1.0, 1.0).toDouble();
    return switch (row.outcome) {
      'engaged' || 'resolved' => 0.55,
      'acknowledged' => 0.20,
      'deferred' => 0.05,
      'dismissed' => -0.85,
      'redirected' => -0.45,
      // Silence says almost nothing about whether the subject itself was bad.
      'no_response' => 0.0,
      _ => null,
    };
  }

  String _bucket(int seconds) {
    if (seconds <= 20 * 60) return 'quick';
    if (seconds <= 2 * 3600) return 'normal';
    if (seconds <= 6 * 3600) return 'late';
    return 'very_late';
  }

  double _responseQuality(int seconds, int textLength) {
    var q = 0.38;
    if (seconds <= 30 * 60) {
      q += 0.28;
    } else if (seconds <= 2 * 3600) {
      q += 0.17;
    } else if (seconds <= 6 * 3600) {
      q += 0.07;
    }
    if (textLength >= 20) {
      q += 0.15;
    } else if (textLength <= 3) {
      q -= 0.08;
    }
    return q.clamp(0.12, 0.88).toDouble();
  }
}

class _WeightedSignal {
  const _WeightedSignal({required this.score, required this.weight});

  final double score;
  final double weight;
}
