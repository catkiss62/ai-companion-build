class RestNeedDecision {
  const RestNeedDecision({
    required this.active,
    required this.resolve,
    required this.intensity,
    required this.causeCode,
  });

  final bool active;
  final bool resolve;
  final double intensity;
  final String causeCode;
}

/// Hysteresis for one continuous rest-need episode. Clock-driven fatigue and
/// activity/stress remain separate causes; chat message count is not a cause.
class RestNeedPolicy {
  const RestNeedPolicy._();

  static const fatigueEntry = 0.66;
  static const fatigueExit = 0.52;
  static const stressEntry = 0.82;
  static const stressExit = 0.64;

  static RestNeedDecision evaluate({
    required double fatigue,
    required double stress,
    required bool currentlyActive,
  }) {
    final f = fatigue.clamp(0.0, 1.0).toDouble();
    final s = stress.clamp(0.0, 1.0).toDouble();
    final enters = f >= fatigueEntry || s >= stressEntry;
    final recovers = f < fatigueExit && s < stressExit;
    final active = enters || (currentlyActive && !recovers);
    return RestNeedDecision(
      active: active,
      resolve: currentlyActive && recovers,
      intensity: (f > s ? f : s).clamp(0.0, 1.0).toDouble(),
      causeCode: f >= s ? 'drive_fatigue_high' : 'drive_stress_high',
    );
  }
}
