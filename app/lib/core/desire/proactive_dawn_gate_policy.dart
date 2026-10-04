import '../models/proactive_frequency.dart';

class ProactiveDawnGateAdjustment {
  const ProactiveDawnGateAdjustment({
    required this.active,
    required this.idleBoost,
    required this.thresholdPenalty,
    required this.suppressLongIdleRelief,
  });

  final bool active;
  final double idleBoost;
  final double thresholdPenalty;
  final bool suppressLongIdleRelief;
}

/// Night silence is not a reason to contact the user.
/// Keep the existing additional screen-off dawn caution.
///
/// This is deliberately not a message-count ceiling. A strong intent can still
/// pass, while long screen-off silence no longer makes repeated delivery easier.
class ProactiveDawnGatePolicy {
  const ProactiveDawnGatePolicy._();

  static const double maxIdleBoost = 0.0;
  static const double thresholdPenalty = 0.10;

  static ProactiveDawnGateAdjustment adjust({
    required DateTime now,
    required String activityContext,
    required double rawIdleBoost,
  }) {
    final active =
        now.hour >= 5 && now.hour < 9 && activityContext == 'screen_off';
    final night = ProactiveFrequencyPolicy.isNight(now);
    if (!night) {
      return ProactiveDawnGateAdjustment(
        active: false,
        idleBoost: rawIdleBoost.clamp(0.0, 1.0).toDouble(),
        thresholdPenalty: 0,
        suppressLongIdleRelief: false,
      );
    }
    return ProactiveDawnGateAdjustment(
      active: active,
      idleBoost: rawIdleBoost.clamp(0.0, maxIdleBoost).toDouble(),
      thresholdPenalty: active ? thresholdPenalty : 0,
      suppressLongIdleRelief: true,
    );
  }
}

/// One independent allowance from local midnight until 09:00.
class ProactiveNightContactCapPolicy {
  const ProactiveNightContactCapPolicy._();
  static const startHour = 0;
  static const endHour = 9;
  static const maxDelivered = ProactiveFrequencyPolicy.nightLimit;

  static DateTime? windowStart(DateTime now) =>
      ProactiveFrequencyPolicy.isNight(now)
      ? ProactiveFrequencyPolicy.boundary(now, 0)
      : null;

  static bool blocks({
    required DateTime now,
    required int deliveredSinceWindowStart,
  }) => windowStart(now) != null && deliveredSinceWindowStart >= maxDelivered;
}
