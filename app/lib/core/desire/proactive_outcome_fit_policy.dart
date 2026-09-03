class ProactiveOutcomeFitPolicy {
  const ProactiveOutcomeFitPolicy._();

  static double timing({
    required String outcome,
    required double proposed,
    required int? responseLatencySeconds,
  }) {
    final value = proposed.clamp(-1.0, 1.0).toDouble();
    final latency = responseLatencySeconds;
    if (outcome == 'deferred') {
      return value < -0.60 ? value : -0.60;
    }
    if (outcome == 'engaged' || outcome == 'resolved') {
      if (latency == null) return value;
      if (latency > 6 * 3600) return value < -0.35 ? value : -0.35;
      if (latency > 2 * 3600) return value < -0.15 ? value : -0.15;
      if (latency > 20 * 60) return value.clamp(-1.0, 0.25).toDouble();
      return value;
    }
    if (outcome == 'acknowledged') {
      if (latency == null) return value.clamp(-1.0, 0.45).toDouble();
      if (latency > 6 * 3600) return value < -0.35 ? value : -0.35;
      if (latency > 2 * 3600) return value < -0.20 ? value : -0.20;
      if (latency > 20 * 60) return value.clamp(-1.0, 0.10).toDouble();
      return value.clamp(-1.0, 0.45).toDouble();
    }
    return value;
  }

  static double topic({
    required String outcome,
    required double proposed,
  }) {
    final value = proposed.clamp(-1.0, 1.0).toDouble();
    // “Later / not now” is evidence about delivery timing, not strong praise or
    // rejection of the subject itself.
    if (outcome == 'deferred') {
      return value.clamp(-0.15, 0.15).toDouble();
    }
    return value;
  }
}
