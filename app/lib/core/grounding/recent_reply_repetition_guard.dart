class RecentReplyRepetitionResult {
  const RecentReplyRepetitionResult({
    required this.allowed,
    this.reason = '',
  });

  final bool allowed;
  final String reason;
}

/// Prevents an already committed assistant reply from being committed again.
///
/// This is intentionally exact after light presentation normalization. It is
/// a loop breaker, not a style or semantic-similarity filter: recurring topics
/// and naturally similar wording remain allowed.
class RecentReplyRepetitionGuard {
  const RecentReplyRepetitionGuard._();

  static RecentReplyRepetitionResult evaluate({
    required String text,
    Iterable<String> recentAssistantTexts = const <String>[],
  }) {
    final candidate = _normalize(text);
    if (candidate.isEmpty) {
      return const RecentReplyRepetitionResult(allowed: true);
    }
    for (final previous in recentAssistantTexts.toList().reversed.take(4)) {
      if (_normalize(previous) == candidate) {
        return const RecentReplyRepetitionResult(
          allowed: false,
          reason: 'exact_recent_reply',
        );
      }
    }
    return const RecentReplyRepetitionResult(allowed: true);
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'<emotion>.*?</emotion>', caseSensitive: false), '')
      .replaceAll(RegExp(r'''[\s「」『』“”‘’"']+'''), '');
}

enum UserReplyCandidateSource { corrected, initial }

/// Keeps an ordinary user turn live without inventing a local persona line.
///
/// The model's corrected answer wins when it is usable and not an exact
/// repeat. Otherwise the original model answer is preferred when that avoids
/// repetition. Empty output is never selected while either model answer has
/// visible text.
class UserReplyLivenessPolicy {
  const UserReplyLivenessPolicy._();

  static UserReplyCandidateSource choose({
    required String initialText,
    required String correctedText,
    required bool initialRepeated,
    required bool correctedRepeated,
  }) {
    if (correctedText.trim().isNotEmpty && !correctedRepeated) {
      return UserReplyCandidateSource.corrected;
    }
    if (initialText.trim().isNotEmpty && !initialRepeated) {
      return UserReplyCandidateSource.initial;
    }
    if (correctedText.trim().isNotEmpty) {
      return UserReplyCandidateSource.corrected;
    }
    return UserReplyCandidateSource.initial;
  }
}
