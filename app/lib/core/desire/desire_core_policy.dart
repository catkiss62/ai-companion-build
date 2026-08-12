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
  static const fatigueRestGate = 0.78;

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
    final refractory = Map<DriveKey, DateTime>.from(snapshot.refractoryUntil)
      ..removeWhere((_, until) => !until.isAfter(now));

    for (final drive in DriveKey.values) {
      var value = drives[drive] ?? 0.0;
      final baseline = baselines[drive] ?? 0.2;
      final decay = decayPerUnit[drive] ?? 0.015;
      final returnRate = 1 - pow(1 - 0.055, scale).toDouble();
      value += (baseline - value) * returnRate;
      value *= pow(1 - decay, scale).toDouble();
      value += pulses[drive] ?? 0.0;
      drives[drive] = value.clamp(0.0, 1.0).toDouble();
    }

    _applyCoupling(drives, scale);

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

  static List<DesireCoreCandidate> candidates({
    required Map<DriveKey, double> drives,
    required Map<DriveKey, DateTime> refractoryUntil,
    required List<CompanionThought> thoughts,
    required DateTime now,
  }) {
    final fatigue = drives[DriveKey.fatigue] ?? 0.0;
    if (fatigue >= fatigueRestGate) {
      return [
        DesireCoreCandidate(
          drive: DriveKey.fatigue,
          score: fatigue,
          action: 'rest',
          reason: '我现在更需要安静休息一下，不想为了主动而硬找话题。',
          reasonSource: 'drive_state',
        ),
      ];
    }

    final result = <DesireCoreCandidate>[];
    for (final drive in DriveKey.values) {
      if (drive == DriveKey.fatigue) continue;
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
      final score = (nonlinear + base * 0.62).clamp(0.0, 1.0).toDouble();
      final strongest = related.isEmpty ? null : related.first;

      result.add(DesireCoreCandidate(
        drive: drive,
        score: score,
        action: actionForDrive[drive] ?? 'wait',
        reason: strongest?.text ?? '我只是隐约有这种倾向，还没有具体事件把它推成强烈念头。',
        reasonSource: strongest?.source ?? 'drive_state',
        thoughtId: strongest?.id,
      ));
    }

    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  }

  static Map<DriveKey, double> satisfiedDrives({
    required DesireSnapshot snapshot,
    required String action,
    required DriveKey primaryDrive,
    double intensity = 1.0,
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
    return drives;
  }

  static void _applyCoupling(Map<DriveKey, double> d, double scale) {
    void delta(DriveKey target, double amount) {
      // Per-tick coupling is explicitly capped before global clamp so one long
      // resume catch-up cannot turn a small relation into a feedback spike.
      final capped = (amount * scale).clamp(-0.025, 0.025).toDouble();
      d[target] = ((d[target] ?? 0) + capped)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    delta(DriveKey.libido, ((d[DriveKey.attachment] ?? 0) - 0.5) * 0.012);
    delta(DriveKey.reflection, ((d[DriveKey.curiosity] ?? 0) - 0.5) * 0.014);
    delta(DriveKey.attachment, ((d[DriveKey.reflection] ?? 0) - 0.5) * 0.009);
    delta(DriveKey.stress, ((d[DriveKey.duty] ?? 0) - 0.5) * 0.008);
    delta(DriveKey.social, ((d[DriveKey.curiosity] ?? 0) - 0.5) * 0.007);
    delta(DriveKey.fatigue, ((d[DriveKey.stress] ?? 0) - 0.45) * 0.006);
  }
}
