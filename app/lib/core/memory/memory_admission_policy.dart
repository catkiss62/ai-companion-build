import '../models/memory_item.dart';
import '../models/personality_learning.dart';

abstract final class MemoryAdmissionPolicy {
  static bool forPrompt(MemoryItem item) => item.sourceValid &&
      !PersonalityLearningBoundaryPolicy.isBehavioralMemorySubject(item.subjectKey) &&
      !PersonalityLearningBoundaryPolicy.looksLikeBehavioralPreference(item.content) &&
      !PersonalityLearningBoundaryPolicy.isCapabilityImplementationClaim(item.content);

  /// Compare source confirmations, never retry processing time. A legacy
  /// target remains compatible; unknown incoming evidence cannot replace a
  /// target with a known confirmation. Equal-time ambiguity is conservative.
  static bool mayChangeCurrent(MemoryItem target, DateTime? sourceAt) =>
      !target.evidenceTimeKnown || sourceAt != null && sourceAt.isAfter(target.lastEvidenceAt);
}
