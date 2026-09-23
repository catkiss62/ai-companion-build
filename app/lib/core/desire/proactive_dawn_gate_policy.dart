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

/// One shared contact ceiling for the whole late-night-to-morning window.
/// It counts successful proactive deliveries from every source lane; game and
/// web shares cannot each consume a separate quota.
class ProactiveNightContactCapPolicy {
  const ProactiveNightContactCapPolicy._();

  static const startHour = 21;
  static const endHour = 9;
  static const maxDelivered = 1;

  static DateTime? windowStart(DateTime now) {
    if (now.hour >= endHour && now.hour < startHour) return null;
    final date = now.hour >= startHour
        ? now
        : now.subtract(const Duration(days: 1));
    return now.isUtc
        ? DateTime.utc(date.year, date.month, date.day, startHour)
        : DateTime(date.year, date.month, date.day, startHour);
  }

  static bool blocks({
    required DateTime now,
    required int deliveredSinceWindowStart,
  }) =>
      windowStart(now) != null && deliveredSinceWindowStart >= maxDelivered;
}
