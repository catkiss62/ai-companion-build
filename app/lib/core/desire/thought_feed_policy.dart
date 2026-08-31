import '../models/thought.dart';

class ThoughtFeedDecision {
  const ThoughtFeedDecision({
    required this.strength,
    required this.fedCount,
    required this.kind,
    required this.lifecycleState,
  });

  final double strength;
  final int fedCount;
  final String kind;
  final String lifecycleState;
}

/// Source-aware rules for merging a repeated inner signal into one Thought.
///
/// Durable evidence may become a fixation after repeated reinforcement. Coarse
/// device/environment awareness is different: the same heartbeat is a refresh
/// of one observation, not new relational evidence. It stays a bounded flit.
class ThoughtFeedPolicy {
  const ThoughtFeedPolicy._();

  static bool isEphemeralAwareness(String source) =>
      ThoughtProvenancePolicy.fromSource(source) ==
      ThoughtProvenance.awareness;

  static double initialStrength({
    required String source,
    required double incomingStrength,
  }) {
    if (isEphemeralAwareness(source)) {
      return incomingStrength.clamp(0.08, 0.34).toDouble();
    }
    return incomingStrength.clamp(0.08, 0.70).toDouble();
  }

  static ThoughtFeedDecision merge({
    required CompanionThought existing,
    required String source,
    required double incomingStrength,
  }) {
    if (isEphemeralAwareness(source)) {
      final incoming = incomingStrength.clamp(0.08, 0.34).toDouble();
      final refreshed = (existing.strength * 0.72).clamp(0.0, 0.42);
      return ThoughtFeedDecision(
        strength: (refreshed > incoming ? refreshed : incoming)
            .clamp(0.08, 0.42)
            .toDouble(),
        // One repeated observation is retained for diagnostics, but heartbeat
        // count can never satisfy the normal fed>=3 fixation condition.
        fedCount: 1,
        kind: 'flit',
        lifecycleState: 'active',
      );
    }

    final fed = existing.fedCount + 1;
    final nextStrength =
        (existing.strength * 0.88 + incomingStrength * 0.55 + 0.06)
            .clamp(0.0, 1.0)
            .toDouble();
    final fixation = fed >= 3 || nextStrength >= 0.68;
    return ThoughtFeedDecision(
      strength: nextStrength,
      fedCount: fed,
      kind: fixation ? 'fixation' : existing.kind,
      lifecycleState: fixation ? 'fixation' : 'active',
    );
  }
}
