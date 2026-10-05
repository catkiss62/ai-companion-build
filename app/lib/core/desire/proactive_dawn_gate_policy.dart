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
    DateTime? wakeAt,
    required String activityContext,
    required double rawIdleBoost,
  }) {
    final night = ProactiveFrequencyPolicy.isNight(now, wakeAt: wakeAt);
    final active = now.hour >= 5 && night && activityContext == 'screen_off';
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

/// One independent allowance from local midnight until the daily wake time.
class ProactiveNightContactCapPolicy {
  const ProactiveNightContactCapPolicy._();
  static const startHour = 0;
  static const maxDelivered = ProactiveFrequencyPolicy.nightLimit;

  static DateTime? windowStart(DateTime now, {DateTime? wakeAt}) =>
      ProactiveFrequencyPolicy.isNight(now, wakeAt: wakeAt)
      ? ProactiveFrequencyPolicy.boundary(now, 0)
      : null;

  static bool blocks({
    required DateTime now,
    required int deliveredSinceWindowStart,
    DateTime? wakeAt,
  }) => windowStart(now, wakeAt: wakeAt) != null && deliveredSinceWindowStart >= maxDelivered;
}
