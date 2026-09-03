import '../models/chat_message.dart';

class ProactiveSceneContinuityDecision {
  const ProactiveSceneContinuityDecision({
    required this.hold,
    required this.reason,
    this.closedAt,
  });

  final bool hold;
  final String reason;
  final DateTime? closedAt;
}

/// A small, time-bounded scene guard for proactive contact.
///
/// Fresh-topic proactive lanes intentionally do not reuse old dialogue as
/// writing material. They must still respect a just-completed real-world
/// scene, though: after both sides say goodnight, an unrelated curiosity
/// Thought must not immediately behave as if nobody went to sleep.
class ProactiveSceneContinuityPolicy {
  const ProactiveSceneContinuityPolicy._();

  static const restClosureHold = Duration(minutes: 90);

  static final RegExp _restClosure = RegExp(
    r'(晚安|明天见|我(?:先|要|去)?睡(?:了|觉)?|去睡吧|先睡(?:了|吧)?|早点睡|休息吧|先休息)',
  );

  static ProactiveSceneContinuityDecision evaluate({
    required List<ChatMessage> recent,
    required DateTime now,
  }) {
    final ordinary = recent
        .where((message) => !message.isProactive)
        .toList(growable: false);
    if (ordinary.length < 2) {
      return const ProactiveSceneContinuityDecision(
        hold: false,
        reason: 'no_recent_mutual_rest_closure',
      );
    }

    final assistant = ordinary.last;
    final user = ordinary[ordinary.length - 2];
    if (!user.isUser || !assistant.isAssistant) {
      return const ProactiveSceneContinuityDecision(
        hold: false,
        reason: 'latest_scene_not_user_assistant_pair',
      );
    }
    if (!_restClosure.hasMatch(user.content) ||
        !_restClosure.hasMatch(assistant.content)) {
      return const ProactiveSceneContinuityDecision(
        hold: false,
        reason: 'latest_pair_not_mutual_rest_closure',
      );
    }

    final age = now.difference(assistant.createdAt);
    if (age.isNegative || age > restClosureHold) {
      return ProactiveSceneContinuityDecision(
        hold: false,
        reason: 'rest_closure_expired',
        closedAt: assistant.createdAt,
      );
    }
    return ProactiveSceneContinuityDecision(
      hold: true,
      reason: 'recent_mutual_rest_closure',
      closedAt: assistant.createdAt,
    );
  }
}
