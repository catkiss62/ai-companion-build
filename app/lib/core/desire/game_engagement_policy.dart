import 'dart:math';

enum GameEngagementPhase { spark, flow, saturated, cooling, available }

class GameEngagementSnapshot {
  const GameEngagementSnapshot({
    required this.phase,
    required this.scoreAdjustment,
    required this.momentum,
    required this.saturation,
    required this.moodAdjustment,
    required this.recentOutcomeCount,
    required this.recentNotableCount,
  });

  final GameEngagementPhase phase;
  final double scoreAdjustment;
  final double momentum;
  final double saturation;
  final double moodAdjustment;
  final int recentOutcomeCount;
  final int recentNotableCount;
}

/// Derives short-lived engagement from real game outcomes and existing affect.
/// It owns no timer, persistence, random roll or permanent personality value.
class GameEngagementPolicy {
  const GameEngagementPolicy._();

  static GameEngagementSnapshot evaluate({
    required DateTime now,
    required Iterable<DateTime> outcomeTimes,
    required Iterable<DateTime> notableTimes,
    double positiveActivation = 0,
    double negativeRestlessness = 0,
  }) {
    final validOutcomes = outcomeTimes
        .where((at) => !at.isAfter(now))
        .toList(growable: false)
      ..sort();
    final validNotable = notableTimes
        .where((at) => !at.isAfter(now))
        .toList(growable: false)
      ..sort();
    final recentOutcomes = validOutcomes
        .where((at) => now.difference(at) <= const Duration(hours: 6))
        .toList(growable: false);
    final recentNotable = validNotable
        .where((at) => now.difference(at) <= const Duration(hours: 6))
        .toList(growable: false);
    final lastOutcome = validOutcomes.isEmpty ? null : validOutcomes.last;

    final moodAdjustment = (positiveActivation.clamp(0.0, 0.85) * 0.04 -
            negativeRestlessness.clamp(0.0, 0.85) * 0.14)
        .clamp(-0.12, 0.04)
        .toDouble();

    if (lastOutcome == null) {
      return GameEngagementSnapshot(
        phase: GameEngagementPhase.available,
        scoreAdjustment: moodAdjustment,
        momentum: 0,
        saturation: 0,
        moodAdjustment: moodAdjustment,
        recentOutcomeCount: recentOutcomes.length,
        recentNotableCount: recentNotable.length,
      );
    }
    final age = now.difference(lastOutcome);
    if (age >= const Duration(hours: 8)) {
      return GameEngagementSnapshot(
        phase: GameEngagementPhase.available,
        scoreAdjustment: moodAdjustment,
        momentum: 0,
        saturation: 0,
        moodAdjustment: moodAdjustment,
        recentOutcomeCount: recentOutcomes.length,
        recentNotableCount: recentNotable.length,
      );
    }

    var saturation = (max(0, recentOutcomes.length - 3) * 0.035)
        .clamp(0.0, 0.24)
        .toDouble();
    if (age >= const Duration(hours: 2)) {
      final coolingFraction =
          ((age.inMinutes - 120) / 360.0).clamp(0.0, 1.0).toDouble();
      saturation *= 1.0 - coolingFraction;
    }
    var momentum = 0.0;
    if (age <= const Duration(minutes: 90)) momentum += 0.06;
    if (recentNotable.isNotEmpty &&
        now.difference(recentNotable.last) <= const Duration(minutes: 90)) {
      momentum += 0.10;
    }

    final phase = age >= const Duration(minutes: 90)
        ? GameEngagementPhase.cooling
        : saturation >= 0.12
            ? GameEngagementPhase.saturated
            : recentOutcomes.length <= 1
                ? GameEngagementPhase.spark
                : GameEngagementPhase.flow;
    final coolingPenalty = phase == GameEngagementPhase.cooling ? 0.07 : 0.0;
    final adjustment =
        (momentum - saturation - coolingPenalty + moodAdjustment)
            .clamp(-0.28, 0.18)
            .toDouble();
    return GameEngagementSnapshot(
      phase: phase,
      scoreAdjustment: adjustment,
      momentum: momentum,
      saturation: saturation,
      moodAdjustment: moodAdjustment,
      recentOutcomeCount: recentOutcomes.length,
      recentNotableCount: recentNotable.length,
    );
  }
}
