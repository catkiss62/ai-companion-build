import 'grounding_snapshot.dart';

class ProactiveGroundingGuardResult {
  const ProactiveGroundingGuardResult({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final String reason;
}

/// Deterministic final safety check for proactive text.
///
/// The prompt is the primary grounding mechanism, but a model can still invent
/// a recent user utterance. When SQLite says the user has not spoken since the
/// assistant's last message, claims such as “你刚才说……” are objectively
/// impossible in this generation context and are blocked before persistence.
class ProactiveGroundingGuard {
  const ProactiveGroundingGuard._();

  static const _recentUserSpeechClaims = <String>[
    '你刚才说',
    '你刚刚说',
    '你方才说',
    '你刚才讲',
    '你刚刚讲',
    '你刚才提到',
    '你刚刚提到',
    '你刚才提过',
    '你刚刚提过',
    '你刚才发',
    '你刚刚发',
    '你刚回复',
    '你刚回我',
    '你刚才回我',
    '你刚刚回我',
  ];

  static ProactiveGroundingGuardResult evaluate({
    required GroundingSnapshot grounding,
    required String text,
  }) {
    if (grounding.userSpokeAfterLastAssistant ||
        grounding.lastAssistantMessageId == null) {
      return const ProactiveGroundingGuardResult(
        allowed: true,
        reason: 'recent_user_speech_possible',
      );
    }

    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    for (final marker in _recentUserSpeechClaims) {
      if (normalized.contains(marker)) {
        return const ProactiveGroundingGuardResult(
          allowed: false,
          reason: 'invented_recent_user_speech',
        );
      }
    }
    return const ProactiveGroundingGuardResult(
      allowed: true,
      reason: 'grounded',
    );
  }
}
