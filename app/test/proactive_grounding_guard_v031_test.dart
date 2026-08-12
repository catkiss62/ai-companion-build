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
}
