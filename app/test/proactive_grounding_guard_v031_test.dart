import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/grounding/grounding_snapshot.dart';
import 'package:ai_companion_localfirst/core/grounding/proactive_grounding_guard.dart';

GroundingSnapshot snapshot({required bool userSpokeAfterAssistant}) {
  final now = DateTime(2026, 8, 12, 20, 0);
  return GroundingSnapshot(
    nowLocal: now,
    utcOffset: const Duration(hours: 8),
    weekday: DateTime.wednesday,
    daypart: GroundingDaypart.evening,
    lastUserMessageId: 'u1',
    lastAssistantMessageId: 'a1',
    lastUserAt: now.subtract(const Duration(minutes: 30)),
    lastAssistantAt: now.subtract(const Duration(minutes: 25)),
    lastUserAnswered: true,
    pendingUserTurn: false,
    userSpokeAfterLastAssistant: userSpokeAfterAssistant,
    assistantMessagesSinceLastUser: 1,
    proactiveMessagesSinceLastUser: 0,
    lastAssistantWasProactive: false,
    minutesSinceLastUser: 30,
    minutesSinceLastAssistant: 25,
  );
}

void main() {
  test('blocks invented recent user speech while user is actually silent', () {
    final result = ProactiveGroundingGuard.evaluate(
      grounding: snapshot(userSpokeAfterAssistant: false),
      text: '你刚才说了句“是我”，我还在想那句话。',
    );
    expect(result.allowed, isFalse);
    expect(result.reason, 'invented_recent_user_speech');
  });

  test('does not block a grounded fresh-user-turn context', () {
    final result = ProactiveGroundingGuard.evaluate(
      grounding: snapshot(userSpokeAfterAssistant: true),
      text: '你刚才说的那句我看到了。',
    );
    expect(result.allowed, isTrue);
  });

  test('ordinary new proactive opening remains allowed during silence', () {
    final result = ProactiveGroundingGuard.evaluate(
      grounding: snapshot(userSpokeAfterAssistant: false),
      text: '突然有点想你，就过来轻轻碰你一下。',
    );
    expect(result.allowed, isTrue);
  });


  reasoningGuardTests();
}

void reasoningGuardTests() {
  test('reasoning guard blocks replying to answered hello as current turn', () {
    final result = ProactiveReasoningGroundingGuard.evaluate(
      grounding: snapshot(userSpokeAfterAssistant: false),
      reasoning: '需要回复用户的“你好”，语气自然一点。',
      lastUserText: '你好',
    );
    expect(result.allowed, isFalse);
    expect(result.reason, 'reasoning_replied_answered_history');
  });

  test('reasoning guard allows remembering old hello without treating it as current', () {
    final result = ProactiveReasoningGroundingGuard.evaluate(
      grounding: snapshot(userSpokeAfterAssistant: false),
      reasoning: '不能继续回复用户的“你好”。这是主动联系，应该从当前想念出发。',
      lastUserText: '你好',
    );
    expect(result.allowed, isTrue);
  });

  test('reasoning guard allows proactive desire reasoning', () {
    final result = ProactiveReasoningGroundingGuard.evaluate(
      grounding: snapshot(userSpokeAfterAssistant: false),
      reasoning: '当前 attachment 有些高，可以主动轻轻说一句想他。',
      lastUserText: '你好',
    );
    expect(result.allowed, isTrue);
  });
}
