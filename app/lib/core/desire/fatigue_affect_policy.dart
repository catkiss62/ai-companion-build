import 'dart:math' as math;

import '../models/emotion_episode.dart';

/// A bounded, transient modifier over the existing body-fatigue curve.
///
/// Body fatigue remains authoritative. Positive activation may briefly make
/// rest less compelling, while negative activation models "tired but unable
/// to settle" without turning distress into energy. Persisted sleep debt
/// eventually outweighs both and cannot be cleared by an ordinary reply.
class FatigueAffectSnapshot {
  const FatigueAffectSnapshot({
    this.positiveActivation = 0,
    this.negativeRestlessness = 0,
    this.sleepDebt = 0,
    this.updatedAt,
    this.lastExertionAt,
    this.lastExertionSource = '',
  });

  static const neutral = FatigueAffectSnapshot();

  final double positiveActivation;
  final double negativeRestlessness;
  final double sleepDebt;
  final DateTime? updatedAt;
  final DateTime? lastExertionAt;
  final String lastExertionSource;

  double get restScoreAdjustment =>
      (-positiveActivation * 0.07 -
              negativeRestlessness * 0.04 +
              sleepDebt * 0.45)
          .clamp(-0.09, 0.10)
          .toDouble();

  double get actionPenaltyAdjustment =>
      (-positiveActivation * 0.05 +
              negativeRestlessness * 0.03 +
              sleepDebt * 0.60)
          .clamp(-0.05, 0.12)
          .toDouble();

  String get mode {
    if (sleepDebt >= 0.12) return 'sleep_debt';
    if (negativeRestlessness > positiveActivation + 0.08) {
      return 'tired_but_restless';
    }
    if (positiveActivation >= 0.22) return 'temporarily_activated';
    if (sleepDebt >= 0.025) return 'debt_recovery';
    return 'neutral';
  }

  FatigueAffectSnapshot withActivityActivation(double value) =>
      FatigueAffectSnapshot(
        positiveActivation: math.max(
          positiveActivation,
          value.clamp(0.0, 0.85).toDouble(),
        ),
        negativeRestlessness: negativeRestlessness,
        sleepDebt: sleepDebt,
        updatedAt: updatedAt,
        lastExertionAt: lastExertionAt,
        lastExertionSource: lastExertionSource,
      );
}

class FatigueAffectPolicy {
  const FatigueAffectPolicy._();

  static const maxSleepDebt = 0.18;
  static const quietBeforeRepayment = Duration(minutes: 90);
  static const repaymentPerHour = 0.025;

  static FatigueAffectSnapshot evaluate({
    required Iterable<EmotionEpisode> episodes,
    required DateTime now,
    double sleepDebt = 0,
    DateTime? updatedAt,
    DateTime? lastExertionAt,
    String lastExertionSource = '',
    double activityActivation = 0,
  }) {
    var positive = activityActivation.clamp(0.0, 0.85).toDouble();
    var restless = 0.0;
    for (final episode in episodes) {
      final intensity = episode.effectiveIntensity(now);
      if (intensity <= 0) continue;
      switch (episode.category) {
        case EmotionEpisodeCategory.connection:
        case EmotionEpisodeCategory.reunion:
          positive = math.max(positive, intensity * 0.82);
          break;
        case EmotionEpisodeCategory.repair:
          positive = math.max(positive, intensity * 0.48);
          break;
        case EmotionEpisodeCategory.hurt:
        case EmotionEpisodeCategory.unmetBid:
          restless = math.max(restless, intensity * 0.86);
          break;
        case EmotionEpisodeCategory.disagreement:
          restless = math.max(restless, intensity * 0.68);
          break;
        case EmotionEpisodeCategory.restNeed:
          break;
      }
    }
    return FatigueAffectSnapshot(
      positiveActivation: positive.clamp(0.0, 0.85).toDouble(),
      negativeRestlessness: restless.clamp(0.0, 0.85).toDouble(),
      sleepDebt: sleepDebt.clamp(0.0, maxSleepDebt).toDouble(),
      updatedAt: updatedAt,
      lastExertionAt: lastExertionAt,
      lastExertionSource: lastExertionSource,
    );
  }

  static double exertionDebt({
    required double bodyFatigue,
    double weight = 1,
  }) {
    final fatigue = bodyFatigue.clamp(0.0, 1.0).toDouble();
    if (fatigue < 0.48 || weight <= 0) return 0;
    final raw = (0.028 + (fatigue - 0.48) * 0.10)
        .clamp(0.028, 0.065)
        .toDouble();
    return (raw * weight.clamp(0.0, 1.0)).clamp(0.0, 0.065).toDouble();
  }

  /// Repayment requires a real quiet window. Callers use the latest chat or
  /// autonomous exertion as [lastWakefulAt], so ordinary conversation never
  /// masquerades as sleep. Long inactive gaps converge to zero.
  static double repaySleepDebt({
    required double sleepDebt,
    required DateTime updatedAt,
    required DateTime now,
    DateTime? lastWakefulAt,
  }) {
    var debt = sleepDebt.clamp(0.0, maxSleepDebt).toDouble();
    if (debt == 0 || !now.isAfter(updatedAt)) return debt;
    final wakefulAt = lastWakefulAt ?? updatedAt;
    final eligibleAt = wakefulAt.add(quietBeforeRepayment);
    final start = updatedAt.isAfter(eligibleAt) ? updatedAt : eligibleAt;
    if (!now.isAfter(start)) return debt;
    final quietHours = now.difference(start).inSeconds / 3600.0;
    debt -= quietHours * repaymentPerHour;
    return debt.clamp(0.0, maxSleepDebt).toDouble();
  }
}
