import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';

void main() {
  test('manual virtual interaction persists, then ordinary turns cool down', () {
    final now = DateTime(2026, 9, 23, 12);
    final excited = const PlayfulFormState().interact(kindle: true, now: now);
    expect(excited.heat, 100);
    expect(excited.qForm, isTrue);
    final first = excited.advance(PlayfulInteraction.ordinary, 'turn-1', now);
    expect(first.qForm, isTrue);
    expect(first.promptForTurn('turn-1'), contains('虚拟互动'));
    expect(first.advance(PlayfulInteraction.strong, 'turn-1', now).heat, first.heat);
    final next = first.advance(PlayfulInteraction.ordinary, 'turn-2', now);
    expect(next.heat, lessThan(first.heat));
    expect(next.promptForTurn('turn-2'), isNot(contains('轻弹额头')));
  });

  test('serious turn preserves Q form and its prompt until zero heat', () {
    final now = DateTime(2026, 9, 23, 12);
    final excited = const PlayfulFormState().interact(kindle: true, now: now);
    final serious = excited.advance(PlayfulInteraction.serious, 'sad', now);
    expect(serious.heat, 85);
    expect(serious.qForm, isTrue);
    expect(serious.promptForTurn('sad'), contains('现在脾气更冲'));
    final locked = excited.withLock(true).advance(PlayfulInteraction.serious, 'sad', now);
    expect(locked.qForm, isTrue);
    expect(locked.promptForTurn('sad'), contains('用户锁定了当前形态'));
    final comforted = locked.interact(kindle: false, now: now);
    expect(comforted.heat, 0);
    expect(comforted.qForm, isFalse);
  });

  test('four mutually playful turns arm a later trigger without keywords', () {
    final now = DateTime(2026, 9, 24, 12);
    var state = const PlayfulFormState();
    for (var turn = 1; turn <= 3; turn++) {
      state = state.advance(PlayfulInteraction.mutual, '$turn', now);
      expect(state.qForm, isFalse);
    }
    state = state.advance(PlayfulInteraction.mutual, '4', now);
    expect(state.heat, 100);
    expect(state.qForm, isFalse);
    expect(state.breakthroughDue, isTrue);
    expect(state.advance(PlayfulInteraction.strong, '4', now).heat, 100);
    expect(state.advance(PlayfulInteraction.serious, '6', now).qForm, isFalse);
  });

  test('Stop restores only the pending user turn and keeps later actions', () {
    final now = DateTime.utc(2026, 9, 25);
    final prior = const PlayfulFormState(heat: 54);
    final pending = prior.advance(PlayfulInteraction.mutual, 'user-a', now);
    expect(pending.heat, 82);
    expect(pending.rollbackTurn('user-a').heat, 54);
    expect(pending.rollbackTurn('user-a').lastTurn, '');
    expect(pending.rollbackTurn('another-turn').heat, 82);
    final second = pending.advance(PlayfulInteraction.ordinary, 'user-b', now);
    expect(second.rollbackTurn('user-a').heat, second.heat);
    expect(second.rollbackTurn('user-b').heat, 82);
    final manual = pending.interact(kindle: false, now: now);
    expect(manual.rollbackTurn('user-a').heat, 0);
    final completed = pending.onAssistantTurn(
      PlayfulSelfActivity.none, 'assistant-a', now,
    );
    expect(completed.rollbackTurn('user-a').heat, 82);
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
