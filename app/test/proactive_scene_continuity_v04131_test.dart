import 'package:ai_companion_localfirst/core/desire/proactive_scene_continuity_policy.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage message({
  required String id,
  required String role,
  required String content,
  required DateTime at,
  bool proactive = false,
}) =>
    ChatMessage(
      id: id,
      role: role,
      content: content,
      createdAt: at,
      isProactive: proactive,
    );

void main() {
  final now = DateTime(2026, 9, 4, 0, 40);

  test('mutual goodnight holds unrelated proactive curiosity for 90 minutes', () {
    final result = ProactiveSceneContinuityPolicy.evaluate(
      now: now,
      recent: [
        message(
          id: 'u1',
          role: 'user',
          content: '你也困了，那去睡吧，我现在也去睡，晚安。',
          at: now.subtract(const Duration(minutes: 12)),
        ),
        message(
          id: 'a1',
          role: 'assistant',
          content: '「嗯，晚安。我要睡了。」',
          at: now.subtract(const Duration(minutes: 11)),
        ),
      ],
    );

    expect(result.hold, isTrue);
    expect(result.reason, 'recent_mutual_rest_closure');
  });

  test('rest closure expires so fresh topics are not permanently suppressed', () {
    final result = ProactiveSceneContinuityPolicy.evaluate(
      now: now,
      recent: [
        message(
          id: 'u1',
          role: 'user',
          content: '先睡了，晚安。',
          at: now.subtract(const Duration(hours: 3)),
        ),
        message(
          id: 'a1',
          role: 'assistant',
          content: '「晚安。」',
          at: now.subtract(const Duration(hours: 3)),
        ),
      ],
    );

    expect(result.hold, isFalse);
    expect(result.reason, 'rest_closure_expired');
  });

  test('a later real user turn clears the closed rest scene', () {
    final result = ProactiveSceneContinuityPolicy.evaluate(
      now: now,
      recent: [
        message(
          id: 'u1',
          role: 'user',
          content: '晚安。',
          at: now.subtract(const Duration(minutes: 20)),
        ),
        message(
          id: 'a1',
          role: 'assistant',
          content: '「晚安，我也睡了。」',
          at: now.subtract(const Duration(minutes: 19)),
        ),
        message(
          id: 'u2',
          role: 'user',
          content: '等等，我忽然想起一件事。',
          at: now.subtract(const Duration(minutes: 2)),
        ),
      ],
    );

    expect(result.hold, isFalse);
    expect(result.reason, 'latest_scene_not_user_assistant_pair');
  });
}
