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

/// A continuous delivery adjustment for the quiet dawn window.
///
/// This is deliberately not a message-count ceiling. A strong intent can still
/// pass, while long screen-off silence no longer makes repeated delivery easier.
class ProactiveDawnGatePolicy {
  const ProactiveDawnGatePolicy._();

  static const double maxIdleBoost = 0.04;
  static const double thresholdPenalty = 0.10;

  static ProactiveDawnGateAdjustment adjust({
    required DateTime now,
    required String activityContext,
    required double rawIdleBoost,
  }) {
    final active = now.hour >= 5 &&
        now.hour < 9 &&
        activityContext == 'screen_off';
    if (!active) {
      return ProactiveDawnGateAdjustment(
        active: false,
        idleBoost: rawIdleBoost.clamp(0.0, 1.0).toDouble(),
        thresholdPenalty: 0,
        suppressLongIdleRelief: false,
      );
    }
    return ProactiveDawnGateAdjustment(
      active: true,
      idleBoost: rawIdleBoost.clamp(0.0, maxIdleBoost).toDouble(),
      thresholdPenalty: thresholdPenalty,
      suppressLongIdleRelief: true,
    );
  }
}
