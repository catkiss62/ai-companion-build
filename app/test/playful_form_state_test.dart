import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';

void main() {
  test('zero settlement anchors normal form after historical Q dialogue', () {
    final now = DateTime(2026, 10, 7, 14, 42);
    final pending = const PlayfulFormState(heat: 15, qForm: true)
        .advance(PlayfulInteraction.ordinary, 'gold', now);
    expect(pending.currentFormFact, contains('当前为小豆丁形态'));
    final normal = pending.onAssistantTurn(PlayfulSelfActivity.none, 'gold-reply', now);
    expect(normal.qForm, false);
    final next = normal.advance(PlayfulInteraction.light, 'food', now);
    final messages = <Map<String, Object?>>[
      {'role': 'assistant', 'content': '本豆丁晃着小短腿'},
      {'role': 'user', 'content': '噫，还好没在吃饭'},
    ];
    next.anchorCurrentForm(messages);
    expect(messages.first['content'], '本豆丁晃着小短腿');
    expect(messages[messages.length - 2]['role'], 'system');
    expect(messages[messages.length - 2]['content'], contains('当前为正常本体'));
    expect(messages.last['role'], 'user');
    final proactive = <Map<String, Object?>>[{'role': 'system', 'content': 'ANSWERED_HISTORY_ONLY'}];
    next.anchorCurrentForm(proactive);
    expect(proactive.last['content'], contains('当前为正常本体'));
    expect(proactive.where((m) => m['role'] == 'user'), isEmpty);
    final tiny = const PlayfulFormState(qForm: true, locked: true);
    expect(tiny.currentFormFact, contains('当前为小豆丁形态'));
  });
  test('manual virtual interaction persists, then ordinary turns cool down', () {
    final now = DateTime(2026, 9, 23, 12);
    final excited = const PlayfulFormState().interact(kindle: true, now: now);
    expect(excited.heat, 100);
    expect(excited.qForm, isTrue);
    final first = excited.advance(PlayfulInteraction.ordinary, 'turn-1', now);
    expect(first.qForm, isTrue);
    expect(first.promptForTurn('turn-1'), contains('虚拟互动'));
    expect(first.advance(PlayfulInteraction.strong, 'turn-1', now).heat, first.heat);
    final settled = first.onAssistantTurn(PlayfulSelfActivity.none, 'reply-1', now);
    final next = settled.advance(PlayfulInteraction.ordinary, 'turn-2', now);
    expect(next.heat, lessThan(first.heat));
    expect(next.promptForTurn('turn-2'), isNot(contains('轻弹额头')));
  });

  test('serious turn preserves Q form and its prompt until zero heat', () {
    final now = DateTime(2026, 9, 23, 12);
    final excited = const PlayfulFormState().interact(kindle: true, now: now);
    final serious = excited.advance(PlayfulInteraction.serious, 'sad', now);
    expect(serious.heat, 100); // The user turn is provisional until its reply.
    expect(serious.qForm, isTrue);
    expect(serious.promptForTurn('sad'), contains('现在脾气更冲'));
    expect(serious.onAssistantTurn(PlayfulSelfActivity.none, 'comfort', now).heat, 70);
    final locked = excited.withLock(true).advance(PlayfulInteraction.serious, 'sad', now);
    expect(locked.qForm, isTrue);
    expect(locked.promptForTurn('sad'), contains('用户锁定了当前形态'));
    final comforted = locked.interact(kindle: false, now: now);
    expect(comforted.heat, 0);
    expect(comforted.qForm, isFalse);
  });

  test('first full turn is protected, then two deliberate stimuli transform', () {
    final now = DateTime(2026, 9, 24, 12);
    var state = const PlayfulFormState();
    for (var turn = 1; turn <= 4; turn++) {
      state = state.advance(PlayfulInteraction.mutual, '$turn', now)
          .onAssistantTurn(PlayfulSelfActivity.none, 'reply-$turn', now);
      expect(state.qForm, isFalse);
    }
    expect(state.heat, 100);
    state = state.advance(PlayfulInteraction.light, '5', now)
        .onAssistantTurn(PlayfulSelfActivity.none, 'reply-5', now);
    expect(state.qForm, isFalse);
    state = state.advance(PlayfulInteraction.mutual, '6', now);
    expect(state.promptQForm, isTrue);
    expect(state.qForm, isFalse); // Durable form changes only on commit.
    state = state.onAssistantTurn(PlayfulSelfActivity.none, 'reply-6', now);
    expect(state.qForm, isTrue);
  });

  test('Stop restores only the pending user turn and keeps later actions', () {
    final now = DateTime.utc(2026, 9, 25);
    final prior = const PlayfulFormState(heat: 54);
    final pending = prior.advance(PlayfulInteraction.mutual, 'user-a', now);
    expect(pending.heat, 54);
    expect(pending.rollbackTurn('user-a').heat, 54);
    expect(pending.rollbackTurn('user-a').lastTurn, '');
    expect(pending.rollbackTurn('another-turn').heat, 54);
    final second = pending.advance(PlayfulInteraction.ordinary, 'user-b', now);
    expect(second.rollbackTurn('user-a').heat, second.heat);
    expect(second.rollbackTurn('user-b').heat, 54);
    final manual = pending.interact(kindle: false, now: now);
    expect(manual.rollbackTurn('user-a').heat, 0);
    final completed = pending.onAssistantTurn(
      PlayfulSelfActivity.none, 'assistant-a', now,
    );
    expect(completed.rollbackTurn('user-a').heat, 84);
    expect(PlayfulFormState.decode(pending.encode()).rollbackTurn('user-a').heat, 54);
  });

  test('an expired button event does not appear in the next reply', () {
    final now = DateTime(2026, 9, 24, 12);
    final state = const PlayfulFormState().interact(kindle: true, now: now)
        .advance(PlayfulInteraction.ordinary, 'later',
            now.add(const Duration(minutes: 11)));
    expect(state.promptForTurn('later'), isNot(contains('轻弹额头')));
  });
}
