import '../models/thought.dart';

/// Keeps one Cedar Outcome as one immutable piece of evidence.
///
/// The ordinary Thought pool is allowed to merge recurring themes. Cedar play
/// results are different: two fishing Outcomes may share a topic while still
/// describing different externally-verifiable events. Their event identity
/// and occurrence time must survive lifecycle maintenance unchanged.
class CedarGameThoughtPolicy {
  const CedarGameThoughtPolicy._();

  static const String sourcePrefix = 'mcp/cedar_game:';
  static const Duration recentClaimWindow = Duration(hours: 1);
  static const Duration proactiveShareMaxAge = Duration(hours: 48);

  static bool isOutcomeThought(CompanionThought thought) =>
      thought.source.startsWith(sourcePrefix);

  /// Event ids created by Cedar use `DateTime.microsecondsSinceEpoch`.
  /// Older/imported rows without that suffix fall back to immutable bornAt;
  /// updatedAt is deliberately never evidence because maintenance refreshes it.
  static DateTime evidenceAt(CompanionThought thought) {
    final match = RegExp(r'(?:play|invite)-(\d{13,17})')
        .firstMatch(thought.source);
    final raw = int.tryParse(match?.group(1) ?? '');
    if (raw != null) {
      final millis = raw >= 1000000000000000 ? raw ~/ 1000 : raw;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return thought.bornAt;
  }

  static bool isRecent(CompanionThought thought, DateTime now) {
    final age = now.difference(evidenceAt(thought));
    return age >= Duration.zero && age <= recentClaimWindow;
  }

  /// A concrete Outcome is an unsolicited share seed, not a recurring topic.
  /// It remains available to normal recall after this returns false.
  static bool canInitiateShare(CompanionThought thought, DateTime now) {
    if (!isOutcomeThought(thought)) return true;
    if (thought.actionCount > 0 || thought.lastActedAt != null) return false;
    final age = now.difference(evidenceAt(thought));
    return age >= Duration.zero && age <= proactiveShareMaxAge;
  }

  /// Exact duplicate rows for the same event may still consolidate. Different
  /// event ids must never merge merely because `cedar_game:<game>` matches.
  static bool canConsolidateByTopic(
    CompanionThought first,
    CompanionThought second,
  ) {
    final firstIsCedar = isOutcomeThought(first);
    final secondIsCedar = isOutcomeThought(second);
    if (!firstIsCedar && !secondIsCedar) return true;
    return firstIsCedar &&
        secondIsCedar &&
        first.source == second.source;
  }
}
