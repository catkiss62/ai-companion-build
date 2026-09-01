import 'dart:math';

import '../models/desire_state.dart';
import '../models/thought.dart';

class DesireCoreAdvanceResult {
  const DesireCoreAdvanceResult({
    required this.drives,
    required this.baselines,
    required this.refractoryUntil,
    required this.scale,
  });

  final Map<DriveKey, double> drives;
  final Map<DriveKey, double> baselines;
  final Map<DriveKey, DateTime> refractoryUntil;
  final double scale;
}

class DesireCoreCandidate {
  const DesireCoreCandidate({
    required this.drive,
    required this.score,
    required this.action,
    required this.reason,
    required this.reasonSource,
    this.thoughtId,
  });

  final DriveKey drive;
  final double score;
  final String action;
  final String reason;
  final String reasonSource;
  final String? thoughtId;
}

/// Deterministic policy layer for the Desire Core.
///
/// No IO, no wall-clock reads and no random source live here. Callers provide
/// `now`, elapsed time (via snapshot.lastTickAt), pulses and user context.
class DesireCorePolicy {
  const DesireCorePolicy._();

  static const unitMinutes = 12.0;
  // Kept as the legacy "very tired" band used by emotion presentation. It is
  // no longer a hard veto over every other Desire candidate.
  static const fatigueRestGate = 0.78;
  static const fatigueCompetitionFloor = 0.48;
  static const fatigueProactiveQuietGate = 0.76;
  static const baselineHalfLifeMinutes = 120.0 * 24.0 * 60.0;
  static const wildcardCooldown = Duration(hours: 6);
  static const postTurnPulseBudget = 0.055;

  /// A model-proposed post-turn pulse is transient interpretation, not a
  /// second relationship event. Keep both each drive and the whole turn
  /// bounded so a verbose extractor cannot push several axes to 1.0 at once.
  static const postTurnPulseCaps = <DriveKey, double>{
    DriveKey.attachment: 0.018,
    DriveKey.curiosity: 0.022,
    DriveKey.reflection: 0.022,
    DriveKey.duty: 0.018,
    DriveKey.social: 0.022,
    DriveKey.libido: 0.018,
    DriveKey.stress: 0.028,
    DriveKey.fatigue: 0.020,
  };

  /// A normal incoming message refreshes attention, but is not by itself new
  /// proof of closeness. Attachment growth remains owned by grounded model
  /// pulses and durable relationship events.
  static const ordinaryConversationPulses = <DriveKey, double>{
    DriveKey.curiosity: 0.004,
    DriveKey.reflection: 0.004,
    DriveKey.social: 0.003,
  };

  static const decayPerUnit = <DriveKey, double>{
    DriveKey.attachment: 0.010,
    DriveKey.curiosity: 0.018,
    DriveKey.reflection: 0.014,
    DriveKey.duty: 0.016,
    DriveKey.social: 0.020,
    DriveKey.libido: 0.015,
    DriveKey.stress: 0.025,
    DriveKey.fatigue: 0.012,
  };

  static const actionForDrive = <DriveKey, String>{
    DriveKey.attachment: 'reach_out',
    DriveKey.curiosity: 'check_in',
    DriveKey.reflection: 'share_thought',
    DriveKey.duty: 'continue_thread',
    DriveKey.social: 'share_thought',
    DriveKey.libido: 'tease_or_intimacy',
    DriveKey.stress: 'comfort_or_ground',
    DriveKey.fatigue: 'rest',
  };

  static DesireCoreAdvanceResult advance({
    required DesireSnapshot snapshot,
    required DateTime now,
    Map<DriveKey, double> pulses = const {},
    bool userBusy = false,
  }) {
    final elapsedMinutes = snapshot.lastTickAt == null
        ? unitMinutes
        : max(0.0, now.difference(snapshot.lastTickAt!).inSeconds / 60.0);
    final scale = (elapsedMinutes / unitMinutes).clamp(0.15, 8.0).toDouble();

    final drives = Map<DriveKey, double>.from(snapshot.drives);
    final baselines = Map<DriveKey, double>.from(snapshot.baselines);
    final anchors = DesireSnapshot.defaultBaselines();
    final refractory = Map<DriveKey, DateTime>.from(snapshot.refractoryUntil)
      ..removeWhere((_, until) => !until.isAfter(now));

    for (final drive in DriveKey.values) {
      final anchor = anchors[drive]!;
      final currentBaseline = baselines[drive] ?? anchor;
      // Learned temperament is durable but not permanent. With no reinforcing
      // relationship evidence it drifts halfway back toward the original
      // anchor over roughly four months. A long process suspension is capped
      // to avoid one resume causing an abrupt personality jump.
      final baselineElapsed = min(elapsedMinutes, 30.0 * 24.0 * 60.0);
      final pullback = 1 - pow(0.5, baselineElapsed / baselineHalfLifeMinutes);
      baselines[drive] = (currentBaseline +
              (anchor - currentBaseline) * pullback)
          .clamp(max(0.02, anchor - 0.10), min(0.92, anchor + 0.10))
          .toDouble();

      var value = drives[drive] ?? 0.0;
      final baseline = baselines[drive] ?? 0.2;
      final decay = decayPerUnit[drive] ?? 0.015;
      final returnRate = 1 - pow(1 - 0.055, scale).toDouble();
      // Baseline is the long-term resting point, not a value which is itself
      // decayed every heartbeat. Both the explicit return and natural decay
      // operate on the deviation from baseline, so an event-free state at the
      // baseline remains stable while excess and deficit still fade.
      final retainedDeviation =
          (value - baseline) * (1 - returnRate) * pow(1 - decay, scale);
      value = baseline + retainedDeviation;
      value += pulses[drive] ?? 0.0;
      drives[drive] = value.clamp(0.0, 1.0).toDouble();
    }

    _applyCoupling(drives, baselines, scale);

    // Fatigue has a real circadian body component. Other drives retain their
    // own values: late-night attachment/curiosity is allowed to remain real,
    // while the body becomes progressively sleepier underneath it.
    final circadianFloor = circadianFatigueFloor(now);
    drives[DriveKey.fatigue] = max(
      drives[DriveKey.fatigue] ?? 0.0,
      circadianFloor,
    ).clamp(0.0, 1.0).toDouble();

    // Busy is friction, not a hard mute. It increases internal strain a little;
    // the delivery gate separately decides how softly to contact the user.
    if (userBusy) {
      drives[DriveKey.fatigue] =
          ((drives[DriveKey.fatigue] ?? 0) + 0.006 * scale)
              .clamp(0.0, 1.0)
              .toDouble();
      drives[DriveKey.stress] =
          ((drives[DriveKey.stress] ?? 0) + 0.003 * scale)
              .clamp(0.0, 1.0)
              .toDouble();
    }

    return DesireCoreAdvanceResult(
      drives: drives,
      baselines: baselines,
      refractoryUntil: refractory,
      scale: scale,
    );
  }

  static Map<DriveKey, double> normalizePostTurnPulses(
    Map<DriveKey, double> pulses,
  ) {
    if (pulses.isEmpty) return const <DriveKey, double>{};
    final bounded = <DriveKey, double>{};
    var magnitude = 0.0;
    for (final entry in pulses.entries) {
      final cap = postTurnPulseCaps[entry.key] ?? 0.018;
      final value = entry.value.clamp(-cap, cap).toDouble();
      if (value.abs() < 0.000001) continue;
      bounded[entry.key] = value;
      magnitude += value.abs();
    }
    if (magnitude <= postTurnPulseBudget || magnitude == 0) return bounded;
    final scale = postTurnPulseBudget / magnitude;
    return {
      for (final entry in bounded.entries) entry.key: entry.value * scale,
    };
  }

  static List<DesireCoreCandidate> candidates({
    required Map<DriveKey, double> drives,
    required Map<DriveKey, DateTime> refractoryUntil,
    required List<CompanionThought> thoughts,
    required DateTime now,
    Map<DriveKey, double>? baselines,
    DateTime? lastWildcardAt,
    bool intimacyAllowed = true,
    bool wildcardAllowed = true,
    bool includeThoughtAlternatives = false,
  }) {
    final fatigue = drives[DriveKey.fatigue] ?? 0.0;
    final result = <DesireCoreCandidate>[];
    if (fatigue >= fatigueCompetitionFloor) {
      result.add(
        DesireCoreCandidate(
          drive: DriveKey.fatigue,
          score: fatigueRestScore(fatigue),
          action: 'rest',
          reason: '困意正在变得具体，身体更想慢下来休息；但特别强的念头仍可能让我暂时撑一下。',
          reasonSource: 'drive_state',
        ),
      );
    }

    for (final drive in DriveKey.values) {
      if (drive == DriveKey.fatigue) continue;
      // Libido is included by default. This flag is only a consumer-surface
      // filter (for example, public-web discovery must not create libido search
      // actions); it is never an Intimacy Session gate.
      if (drive == DriveKey.libido && !intimacyAllowed) continue;
      final until = refractoryUntil[drive];
      if (until != null && until.isAfter(now)) continue;

      final base = (drives[drive] ?? 0.0).clamp(0.0, 1.0).toDouble();
      final related = thoughts
          .where((t) =>
              t.driveKey == drive.name && t.canDriveIntentAt(now))
          .toList()
        ..sort((a, b) => b.strength.compareTo(a.strength));

      // Duty means a concrete remembered obligation/thread. A bare numeric
      // duty baseline is not enough evidence to invent an unfinished promise.
      if (drive == DriveKey.duty && related.isEmpty) continue;

      var thoughtBoost = 0.0;
      for (var i = 0; i < min(5, related.length); i++) {
        final thought = related[i];
        final baseWeight = thought.isFixation ? 0.20 : 0.095;
        final diminishing = 1 / sqrt(i + 1.0);
        thoughtBoost += thought.strength * baseWeight * diminishing;
      }
      thoughtBoost = thoughtBoost.clamp(0.0, 0.28).toDouble();

      final combined = (base + thoughtBoost).clamp(0.0, 1.0).toDouble();
      final nonlinear = 1 - sqrt(max(0.0, 1 - combined));
      final rawScore =
          (nonlinear + base * 0.62).clamp(0.0, 1.0).toDouble();
      final score = (rawScore - fatigueActionPenalty(fatigue))
          .clamp(0.0, 1.0)
          .toDouble();
      final strongest = related.isEmpty ? null : related.first;

      result.add(DesireCoreCandidate(
        drive: drive,
        score: score,
        action: actionForDrive[drive] ?? 'wait',
        reason: strongest?.text ?? '我只是隐约有这种倾向，还没有具体事件把它推成强烈念头。',
        reasonSource: strongest?.source ?? 'drive_state',
        thoughtId: strongest?.id,
      ));

      if (includeThoughtAlternatives && related.length > 1) {
        for (final alternative in related.skip(1)) {
          final alternativeWeight =
              alternative.isFixation ? 0.20 : 0.095;
          final alternativeCombined =
              (base + alternative.strength * alternativeWeight)
                  .clamp(0.0, 1.0)
                  .toDouble();
          final alternativeNonlinear =
              1 - sqrt(max(0.0, 1 - alternativeCombined));
          final alternativeRawScore =
              (alternativeNonlinear + base * 0.62)
                  .clamp(0.0, 1.0)
                  .toDouble();
          final alternativeScore =
              (alternativeRawScore - fatigueActionPenalty(fatigue))
                  .clamp(0.0, 1.0)
                  .toDouble();
          result.add(
            DesireCoreCandidate(
              drive: drive,
              score: alternativeScore,
              action: actionForDrive[drive] ?? 'wait',
              reason: alternative.text,
              reasonSource: alternative.source,
              thoughtId: alternative.id,
            ),
          );
        }
      }
    }

    result.sort((a, b) => b.score.compareTo(a.score));
    final wildcardReady = lastWildcardAt == null ||
        now.difference(lastWildcardAt) >= wildcardCooldown;
    final normalStrong = result.any((candidate) => candidate.score >= 0.60);
    if (wildcardAllowed && wildcardReady && !normalStrong) {
      final anchors = baselines ?? DesireSnapshot.defaultBaselines();
      var tension = 0.0;
      for (final drive in DriveKey.values) {
        if (drive == DriveKey.fatigue || drive == DriveKey.libido) continue;
        tension += max(0.0, (drives[drive] ?? 0.0) - (anchors[drive] ?? 0.2));
      }
      if (tension >= 0.52) {
        const wildcardDrives = <DriveKey>[
          DriveKey.reflection,
          DriveKey.social,
          DriveKey.curiosity,
          DriveKey.attachment,
        ];
        DriveKey? wildcardDrive;
        var greatestExcess = double.negativeInfinity;
        for (final drive in wildcardDrives) {
          final until = refractoryUntil[drive];
          if (until != null && until.isAfter(now)) continue;
          final excess = (drives[drive] ?? 0.0) - (anchors[drive] ?? 0.2);
          if (excess > greatestExcess) {
            greatestExcess = excess;
            wildcardDrive = drive;
          }
        }
        if (wildcardDrive != null) {
          result.add(DesireCoreCandidate(
            drive: wildcardDrive,
            score: (0.56 + tension * 0.16).clamp(0.58, 0.72).toDouble(),
            action: 'wildcard_share',
            reason: '我积着一点难以归类的内在张力，想换个轻松方向随手分享，而不是重复原来的话题。',
            reasonSource: 'wildcard_pressure_release',
          ));
          result.sort((a, b) => b.score.compareTo(a.score));
        }
      }
    }
    return result;
  }

  static Map<DriveKey, double> satisfiedDrives({
    required DesireSnapshot snapshot,
    required String action,
    required DriveKey primaryDrive,
    double intensity = 1.0,
    bool outboundEffort = false,
  }) {
    final drives = Map<DriveKey, double>.from(snapshot.drives);
    final safeIntensity = intensity.clamp(0.0, 1.0).toDouble();

    void settle(DriveKey drive, double factorAtFull) {
      final baseline = snapshot.baselines[drive] ?? 0.2;
      final value = drives[drive] ?? baseline;
      // intensity=0 means no settling; intensity=1 applies the full factor.
      final factor = 1 - (1 - factorAtFull) * safeIntensity;
      drives[drive] = (baseline + (value - baseline) * factor)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    switch (action) {
      case 'reach_out':
        settle(DriveKey.attachment, 0.80);
        settle(DriveKey.social, 0.93);
        break;
      case 'continue_thread':
        settle(DriveKey.duty, 0.78);
        settle(DriveKey.attachment, 0.95);
        break;
      case 'share_thought':
        settle(DriveKey.reflection, 0.80);
        settle(DriveKey.social, 0.94);
        break;
      case 'check_in':
        settle(DriveKey.attachment, 0.84);
        settle(DriveKey.curiosity, 0.91);
        break;
      case 'tease_or_intimacy':
        settle(DriveKey.libido, 0.76);
        settle(DriveKey.attachment, 0.94);
        break;
      case 'comfort_or_ground':
        settle(DriveKey.stress, 0.76);
        settle(DriveKey.attachment, 0.95);
        break;
      case 'discover_interest':
        settle(primaryDrive, 0.84);
        if (primaryDrive != DriveKey.curiosity) {
          settle(DriveKey.curiosity, 0.94);
        }
        break;
      case 'remember_shared_experience':
        settle(DriveKey.reflection, 0.84);
        settle(DriveKey.attachment, 0.94);
        break;
      case 'wildcard_share':
        settle(DriveKey.social, 0.86);
        settle(DriveKey.reflection, 0.92);
        break;
      case 'rest':
      case 'wait':
        // Rest/fatigue recovers with elapsed time; sending a message must never
        // pretend that fatigue itself has been satisfied.
        break;
      default:
        settle(primaryDrive, 0.82);
        break;
    }
    if (outboundEffort && action != 'rest' && action != 'wait') {
      final fatigue = drives[DriveKey.fatigue] ?? 0.0;
      drives[DriveKey.fatigue] =
          (fatigue + outboundFatigueCost(fatigue)).clamp(0.0, 1.0).toDouble();
    }
    return drives;
  }

  /// Local wall-clock fatigue floor. The interpolation avoids a cliff at a
  /// particular bedtime and intentionally remains independent of the user's
  /// willingness to receive a message at that hour.
  static double circadianFatigueFloor(DateTime now) {
    final minute = now.hour * 60 + now.minute;
    const points = <(int, double)>[
      (0, 0.52),
      (60, 0.60),
      (120, 0.68),
      (180, 0.74),
      (240, 0.78),
      (300, 0.72),
      (360, 0.58),
      (420, 0.40),
      (480, 0.24),
      (540, 0.16),
      (1080, 0.16),
      (1200, 0.18),
      (1320, 0.28),
      (1380, 0.42),
      (1440, 0.52),
    ];
    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      if (minute < start.$1 || minute > end.$1) continue;
      final width = end.$1 - start.$1;
      if (width <= 0) return end.$2;
      final progress = (minute - start.$1) / width;
      return (start.$2 + (end.$2 - start.$2) * progress)
          .clamp(0.0, 1.0)
          .toDouble();
    }
    return points.last.$2;
  }

  static double fatigueRestScore(double fatigue) {
    if (fatigue < fatigueCompetitionFloor) return 0.0;
    return (0.54 + (fatigue - 0.45) * 0.66)
        .clamp(0.54, 0.86)
        .toDouble();
  }

  /// Sleepiness makes outward action harder without muting it. A sufficiently
  /// strong Drive + Thought score can still beat the competing rest candidate.
  static double fatigueActionPenalty(double fatigue) {
    if (fatigue <= 0.45) return 0.0;
    return ((fatigue - 0.45) * 0.30).clamp(0.0, 0.18).toDouble();
  }

  /// Only self-initiated outbound action pays this extra body cost. Merely
  /// answering a user or receiving a reply must not pretend that she slept.
  static double outboundFatigueCost(double fatigue) {
    if (fatigue < fatigueCompetitionFloor) return 0.0;
    return (0.055 + (fatigue - fatigueCompetitionFloor) * 0.12)
        .clamp(0.055, 0.11)
        .toDouble();
  }

  static void _applyCoupling(
    Map<DriveKey, double> d,
    Map<DriveKey, double> baselines,
    double scale,
  ) {
    void delta(DriveKey target, double amount) {
      // Per-tick coupling is explicitly capped before global clamp so one long
      // resume catch-up cannot turn a small relation into a feedback spike.
      final capped = (amount * scale).clamp(-0.025, 0.025).toDouble();
      d[target] = ((d[target] ?? 0) + capped)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    double excess(DriveKey source) =>
        (d[source] ?? baselines[source] ?? 0.0) -
        (baselines[source] ?? 0.0);

    delta(DriveKey.libido, excess(DriveKey.attachment) * 0.012);
    delta(DriveKey.reflection, excess(DriveKey.curiosity) * 0.014);
    delta(DriveKey.attachment, excess(DriveKey.reflection) * 0.009);
    delta(DriveKey.stress, excess(DriveKey.duty) * 0.008);
    delta(DriveKey.social, excess(DriveKey.curiosity) * 0.007);
    delta(DriveKey.fatigue, excess(DriveKey.stress) * 0.006);
  }
}
