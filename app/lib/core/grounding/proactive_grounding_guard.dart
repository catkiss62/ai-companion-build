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

class ProactiveReasoningGroundingGuard {
  const ProactiveReasoningGroundingGuard._();

  static const _currentTurnMarkers = <String>[
    '当前用户输入',
    '用户刚发',
    '用户刚刚发',
    '用户刚才发',
    '用户刚才说',
    '用户刚刚说',
    '用户这句',
    '回复用户',
    '回应用户',
    '回答用户',
    '承接用户',
  ];

  static const _negations = <String>[
    '不',
    '不能',
    '不要',
    '不应',
    '避免',
    '并非',
    '不是',
    '无需',
    '没有必要',
  ];

  /// Detects a proactive reasoning trace that has fallen back into ordinary
  /// “answer the user's last message” mode.
  ///
  /// This is intentionally narrow: old history may still be remembered or
  /// referenced. We only reject current-turn framing while SQLite says the
  /// latest user turn is already answered and the user stayed silent.
  static ProactiveGroundingGuardResult evaluate({
    required GroundingSnapshot grounding,
    required String reasoning,
    String lastUserText = '',
  }) {
    if (grounding.pendingUserTurn ||
        !grounding.lastUserAnswered ||
        grounding.userSpokeAfterLastAssistant ||
        reasoning.trim().isEmpty) {
      return const ProactiveGroundingGuardResult(
        allowed: true,
        reason: 'reasoning_current_turn_possible',
      );
    }

    final normalized = _normalize(reasoning);
    final userSnippet = _normalize(lastUserText);

    for (final marker in _currentTurnMarkers) {
      var start = 0;
      while (true) {
        final index = normalized.indexOf(marker, start);
        if (index < 0) break;
        final prefixStart = (index - 12).clamp(0, normalized.length).toInt();
        final prefix = normalized.substring(prefixStart, index);
        final negated = _negations.any(prefix.contains);
        if (!negated) {
          if (marker.startsWith('用户刚') || marker == '当前用户输入' || marker == '用户这句') {
            return const ProactiveGroundingGuardResult(
              allowed: false,
              reason: 'reasoning_invented_current_user_turn',
            );
          }
          if (userSnippet.length >= 2) {
            final windowEnd = (index + marker.length + 48).clamp(0, normalized.length).toInt();
            final window = normalized.substring(index, windowEnd);
            final probe = userSnippet.length > 24
                ? userSnippet.substring(0, 24)
                : userSnippet;
            if (window.contains(probe)) {
              return const ProactiveGroundingGuardResult(
                allowed: false,
                reason: 'reasoning_replied_answered_history',
              );
            }
          }
        }
        start = index + marker.length;
      }
    }

    return const ProactiveGroundingGuardResult(
      allowed: true,
      reason: 'reasoning_grounded',
    );
  }

  static String _normalize(String value) => value
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('“', '')
      .replaceAll('”', '')
      .replaceAll('‘', '')
      .replaceAll('’', '')
      .replaceAll('"', '')
      .replaceAll("'", '');
}

/// Prevents a recalled long-term memory from being compressed into a fresh
/// activity claim. Remembering something now does not update when it happened.
class ProactiveMemoryTemporalGuard {
  const ProactiveMemoryTemporalGuard._();

  static final RegExp _recentOngoingClaim = RegExp(
    r'(刚才|刚刚|方才|刚才还|刚刚还).{0,12}'
    r'(正在|还在|在.{0,10}(调试|制作|开发|修|做|看|玩|工作|聊天))',
  );
  static final RegExp _recallFraming = RegExp(
    r'(刚才|刚刚|方才).{0,8}(想起|想到|记起|回忆起)',
  );

  static ProactiveGroundingGuardResult evaluate({
    required String text,
    required bool sourceIsMemory,
    DateTime? lastEvidenceAt,
    DateTime? now,
  }) {
    if (!sourceIsMemory || text.trim().isEmpty) {
      return const ProactiveGroundingGuardResult(
        allowed: true,
        reason: 'not_memory_temporal_claim',
      );
    }
    final instant = now ?? DateTime.now();
    final sourceIsFresh = lastEvidenceAt != null &&
        !instant.isBefore(lastEvidenceAt) &&
        instant.difference(lastEvidenceAt) <= const Duration(hours: 2);
    if (sourceIsFresh || _recallFraming.hasMatch(text)) {
      return const ProactiveGroundingGuardResult(
        allowed: true,
        reason: 'memory_time_explicit_or_fresh',
      );
    }
    if (_recentOngoingClaim.hasMatch(text)) {
      return const ProactiveGroundingGuardResult(
        allowed: false,
        reason: 'stale_memory_as_recent_activity',
      );
    }
    return const ProactiveGroundingGuardResult(
      allowed: true,
      reason: 'memory_time_grounded',
    );
  }
}
