import '../models/thought.dart';

/// A Thought may remain useful for ordinary conversational recall while being
/// too weak to initiate an unsolicited action. This policy is deliberately
/// scoped to autonomous behavior selection and never changes prompt recall.
class ProactiveThoughtReadinessPolicy {
  const ProactiveThoughtReadinessPolicy._();

  static bool isReady(CompanionThought thought, DateTime now) {
    if (!thought.canDriveIntentAt(now)) return false;
    if (thought.isFixation) return thought.strength >= 0.18;
    final minimum = switch (thought.provenance) {
      ThoughtProvenance.publicWebCandidate => 0.50,
      ThoughtProvenance.realUserMessage => 0.22,
      ThoughtProvenance.awareness => 0.24,
      ThoughtProvenance.memory => 0.24,
      ThoughtProvenance.selfExperience => 0.20,
      ThoughtProvenance.inference => 0.30,
      ThoughtProvenance.internal => 0.24,
    };
    return thought.strength >= minimum;
  }
}
