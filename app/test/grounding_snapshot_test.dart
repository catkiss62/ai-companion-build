import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/grounding/grounding_snapshot.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';

ChatMessage message({
  required String id,
  required String role,
  required DateTime at,
  bool proactive = false,
  bool expectsReply = true,
}) =>
    ChatMessage(
      id: id,
      role: role,
      content: id,
      createdAt: at,
      isProactive: proactive,
      expectsReply: expectsReply,
    );

void main() {
  test('answered hello is not treated as a pending user turn', () {
    final base = DateTime(2026, 8, 12, 20, 47);
    final snapshot = ConversationGroundingPolicy.build(
      now: base.add(const Duration(minutes: 10)),
      recent: [
        message(id: 'u1', role: 'user', at: base),
        message(
          id: 'a1',
          role: 'assistant',
          at: base.add(const Duration(minutes: 1)),
        ),
      ],
      answeredUserMessageIds: const {'u1'},
    );

    expect(snapshot.lastUserAnswered, isTrue);
    expect(snapshot.pendingUserTurn, isFalse);
    expect(snapshot.userSpokeAfterLastAssistant, isFalse);
    expect(snapshot.conversationState, 'assistant_replied_user_silent');
  });

  test('consecutive proactive messages never imply the user spoke again', () {
    final base = DateTime(2026, 8, 12, 19, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: base.add(const Duration(hours: 2)),
      recent: [
        message(id: 'u1', role: 'user', at: base),
        message(
          id: 'a1',
          role: 'assistant',
          at: base.add(const Duration(minutes: 1)),
        ),
        message(
          id: 'p1',
          role: 'assistant',
          at: base.add(const Duration(minutes: 50)),
          proactive: true,
        ),
        message(
          id: 'p2',
          role: 'assistant',
          at: base.add(const Duration(minutes: 95)),
          proactive: true,
        ),
      ],
      answeredUserMessageIds: const {'u1'},
    );

    expect(snapshot.pendingUserTurn, isFalse);
    expect(snapshot.userSpokeAfterLastAssistant, isFalse);
    expect(snapshot.proactiveMessagesSinceLastUser, 2);
    expect(
      snapshot.conversationState,
      'assistant_proactive_after_answer_user_silent',
    );
  });

  test('a proactive assistant message never marks an unanswered user turn as answered', () {
    final base = DateTime(2026, 8, 12, 18, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: base.add(const Duration(minutes: 30)),
      recent: [
        message(id: 'u1', role: 'user', at: base),
        message(
          id: 'p1',
          role: 'assistant',
          at: base.add(const Duration(minutes: 20)),
          proactive: true,
        ),
      ],
    );

    expect(snapshot.lastUserAnswered, isFalse);
    expect(snapshot.pendingUserTurn, isTrue);
    expect(snapshot.proactiveMessagesSinceLastUser, 1);
  });

  test('a new real user message becomes the only pending turn', () {
    final base = DateTime(2026, 8, 12, 18, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: base.add(const Duration(minutes: 25)),
      recent: [
        message(id: 'u1', role: 'user', at: base),
        message(
          id: 'a1',
          role: 'assistant',
          at: base.add(const Duration(minutes: 1)),
        ),
        message(
          id: 'u2',
          role: 'user',
          at: base.add(const Duration(minutes: 20)),
        ),
      ],
      answeredUserMessageIds: const {'u1'},
    );

    expect(snapshot.lastUserMessageId, 'u2');
    expect(snapshot.lastUserAnswered, isFalse);
    expect(snapshot.pendingUserTurn, isTrue);
    expect(snapshot.userSpokeAfterLastAssistant, isTrue);
    expect(snapshot.conversationState, 'user_turn_pending');
  });

  test('a local image message does not create a permanently pending AI reply', () {
    final base = DateTime(2026, 8, 12, 18, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: base.add(const Duration(minutes: 25)),
      recent: [
        message(id: 'a1', role: 'assistant', at: base),
        message(
          id: 'image-1',
          role: 'user',
          at: base.add(const Duration(minutes: 20)),
          expectsReply: false,
        ),
      ],
    );

    expect(snapshot.lastUserMessageId, 'image-1');
    expect(snapshot.lastUserAnswered, isTrue);
    expect(snapshot.pendingUserTurn, isFalse);
    expect(snapshot.userSpokeAfterLastAssistant, isTrue);
  });


  test('cross-day user turn records the gap from the previous conversation', () {
    final previous = DateTime(2026, 8, 20, 21, 0);
    final current = DateTime(2026, 8, 21, 12, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: current,
      recent: [
        message(id: 'u1', role: 'user', at: previous.subtract(const Duration(minutes: 2))),
        message(id: 'a1', role: 'assistant', at: previous),
        message(id: 'u2', role: 'user', at: current),
      ],
      answeredUserMessageIds: const {'u1'},
    );

    expect(snapshot.currentTurnGapMinutes, 15 * 60 + 2);
    expect(snapshot.currentTurnInteractionGapMinutes, 15 * 60);
    expect(snapshot.currentTurnCrossedCalendarDays, 1);
    expect(snapshot.currentTurnCrossedDay, isTrue);
    expect(snapshot.currentTurnRequiresTransientRecheck, isTrue);
    expect(snapshot.currentTurnGapBand, 'cross_day');
    expect(snapshot.currentTurnHasLongGap, isTrue);
    expect(snapshot.previousConversationAt, previous);
    expect(snapshot.toRedactedJson()['currentTurnCrossedDay'], isTrue);
  });

  test('15-minute user turn keeps the ordinary short scene available', () {
    final start = DateTime(2026, 9, 1, 13, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: start.add(const Duration(minutes: 15)),
      recent: [
        message(id: 'u1', role: 'user', at: start),
        message(
          id: 'a1',
          role: 'assistant',
          at: start.add(const Duration(minutes: 1)),
        ),
        message(
          id: 'u2',
          role: 'user',
          at: start.add(const Duration(minutes: 15)),
        ),
      ],
      answeredUserMessageIds: const {'u1'},
    );

    expect(snapshot.currentTurnGapMinutes, 15);
    expect(snapshot.currentTurnInteractionGapMinutes, 14);
    expect(snapshot.currentTurnRequiresTransientRecheck, isFalse);
    expect(snapshot.currentTurnHasLongGap, isFalse);
    expect(snapshot.currentTurnGapBand, 'same_scene');
  });

  test('13:00 user scene to 15:00 is long even when interaction gap is 119', () {
    final start = DateTime(2026, 9, 1, 13, 0);
    final current = DateTime(2026, 9, 1, 15, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: current,
      recent: [
        message(id: 'u1', role: 'user', at: start),
        message(
          id: 'a1',
          role: 'assistant',
          at: start.add(const Duration(minutes: 1)),
        ),
        message(id: 'u2', role: 'user', at: current),
      ],
      answeredUserMessageIds: const {'u1'},
    );

    expect(snapshot.previousConversationAt, DateTime(2026, 9, 1, 13, 1));
    expect(snapshot.previousRealUserAt, DateTime(2026, 9, 1, 13, 0));
    expect(snapshot.currentTurnGapMinutes, 120);
    expect(snapshot.currentTurnInteractionGapMinutes, 119);
    expect(snapshot.currentTurnRequiresTransientRecheck, isTrue);
    expect(snapshot.currentTurnHasLongGap, isTrue);
    expect(snapshot.currentTurnGapBand, 'long_gap');
    expect(
      snapshot.toRedactedJson()['currentTurnRequiresTransientRecheck'],
      isTrue,
    );
    final contract = OrdinaryChatSceneBoundaryPolicy.promptContract(snapshot);
    expect(contract, contains('不能机械延续'));
    expect(contract, contains('明确给出的持续时间/结束点'));
  });

  test('current explicit still-active text is allowed to override unknown', () {
    final current = DateTime(2026, 9, 1, 15, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: current,
      recent: [
        message(
          id: 'a1',
          role: 'assistant',
          at: current.subtract(const Duration(minutes: 90)),
        ),
        message(id: 'u1', role: 'user', at: current),
      ],
    );

    final contract = OrdinaryChatSceneBoundaryPolicy.promptContract(snapshot);
    expect(contract, contains('还在/刚做完/一直在'));
    expect(contract, contains('以当前原话为准'));
    expect(contract, contains('话题、关系、长期事实与记忆'));
  });

  test('120-minute boundary is both long and transient recheck', () {
    final previous = DateTime(2026, 9, 1, 13, 0);
    final current = DateTime(2026, 9, 1, 15, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: current,
      recent: [
        message(id: 'a1', role: 'assistant', at: previous),
        message(id: 'u1', role: 'user', at: current),
      ],
    );

    expect(snapshot.currentTurnGapMinutes, 120);
    expect(snapshot.currentTurnRequiresTransientRecheck, isTrue);
    expect(snapshot.currentTurnHasLongGap, isTrue);
    expect(snapshot.currentTurnGapBand, 'long_gap');
  });

  test('30-minute user-scene boundary triggers one detailed injection', () {
    final start = DateTime(2026, 9, 1, 13, 0);
    final current = start.add(const Duration(minutes: 30));
    final snapshot = ConversationGroundingPolicy.build(
      now: current,
      recent: [
        message(id: 'u1', role: 'user', at: start),
        message(
          id: 'a1',
          role: 'assistant',
          at: start.add(const Duration(minutes: 1)),
        ),
        message(id: 'u2', role: 'user', at: current),
      ],
      answeredUserMessageIds: const {'u1'},
    );

    expect(snapshot.userSceneGapMinutes, 30);
    expect(snapshot.userSceneGapBand, 'transient_recheck');
    expect(snapshot.timeBoundaryPromptMode, 'detailed');
  });

  test('a proactive generation uses the last real user as scene clock', () {
    final start = DateTime(2026, 9, 1, 13, 0);
    final current = DateTime(2026, 9, 1, 16, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: current,
      recent: [
        message(id: 'u1', role: 'user', at: start),
        message(
          id: 'a1',
          role: 'assistant',
          at: start.add(const Duration(minutes: 1)),
        ),
      ],
      answeredUserMessageIds: const {'u1'},
    );

    expect(snapshot.currentTurnGapMinutes, isNull);
    expect(snapshot.userSceneAnchorAt, start);
    expect(snapshot.userSceneGapMinutes, 180);
    expect(snapshot.userSceneGapBand, 'long_gap');
    expect(snapshot.timeBoundaryPromptMode, 'detailed');
  });

  test('a proactive message never refreshes the user scene clock', () {
    final start = DateTime(2026, 9, 1, 13, 0);
    final current = DateTime(2026, 9, 1, 16, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: current,
      recent: [
        message(id: 'u1', role: 'user', at: start),
        message(
          id: 'a1',
          role: 'assistant',
          at: start.add(const Duration(minutes: 1)),
        ),
        message(
          id: 'p1',
          role: 'assistant',
          at: DateTime(2026, 9, 1, 15, 50),
          proactive: true,
        ),
        message(id: 'u2', role: 'user', at: current),
      ],
      answeredUserMessageIds: const {'u1'},
    );

    expect(snapshot.currentTurnGapMinutes, 180);
    expect(snapshot.currentTurnInteractionGapMinutes, 10);
    expect(snapshot.userSceneAnchorAt, start);
    expect(snapshot.hasProactiveBoundaryAfterSceneAnchor, isTrue);
    expect(snapshot.timeBoundaryPromptMode, 'carry_forward');
  });

  test('later proactive calls carry a compact boundary without timestamps', () {
    final start = DateTime(2026, 9, 1, 13, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: DateTime(2026, 9, 1, 16, 0),
      recent: [
        message(id: 'u1', role: 'user', at: start),
        message(
          id: 'a1',
          role: 'assistant',
          at: start.add(const Duration(minutes: 1)),
        ),
        message(
          id: 'p1',
          role: 'assistant',
          at: DateTime(2026, 9, 1, 15, 0),
          proactive: true,
        ),
      ],
      answeredUserMessageIds: const {'u1'},
    );

    expect(snapshot.userSceneGapMinutes, 180);
    expect(snapshot.timeBoundaryPromptMode, 'carry_forward');
  });

  test('a prior proactive prompt injection is compact even when it sent WAIT', () {
    final start = DateTime(2026, 9, 1, 13, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: DateTime(2026, 9, 1, 16, 0),
      recent: [
        message(id: 'u1', role: 'user', at: start),
        message(
          id: 'a1',
          role: 'assistant',
          at: start.add(const Duration(minutes: 1)),
        ),
      ],
      answeredUserMessageIds: const {'u1'},
      proactiveBoundaryInjectedUserMessageId: 'u1',
    );

    expect(snapshot.hasProactiveBoundaryAfterSceneAnchor, isTrue);
    expect(snapshot.timeBoundaryPromptMode, 'carry_forward');
  });

  test('a new real user turn still receives detail after proactive WAIT', () {
    final start = DateTime(2026, 9, 1, 13, 0);
    final snapshot = ConversationGroundingPolicy.build(
      now: DateTime(2026, 9, 1, 16, 0),
      recent: [
        message(id: 'u1', role: 'user', at: start),
        message(
          id: 'a1',
          role: 'assistant',
          at: start.add(const Duration(minutes: 1)),
        ),
        message(
          id: 'u2',
          role: 'user',
          at: DateTime(2026, 9, 1, 16, 0),
        ),
      ],
      answeredUserMessageIds: const {'u1'},
      proactiveBoundaryInjectedUserMessageId: 'u1',
    );

    expect(snapshot.userSceneAnchorMessageId, 'u1');
    expect(snapshot.timeBoundaryPromptMode, 'detailed');
  });

  test('20:47 is explicitly evening instead of model-guessed time', () {
    final now = DateTime(2026, 8, 12, 20, 47);
    final snapshot = ConversationGroundingPolicy.build(
      now: now,
      recent: const [],
    );

    expect(snapshot.daypart, GroundingDaypart.evening);
    expect(snapshot.daypart.key, 'evening');
    expect(snapshot.toRedactedJson()['localTime'], '20:47');
  });
}
