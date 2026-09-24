import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';

void main() {
  test('manual virtual interaction persists, then ordinary turns cool down', () {
    final now = DateTime(2026, 9, 23, 12);
    final excited = const PlayfulFormState().interact(kindle: true, now: now);
    expect(excited.heat, 92);
    expect(excited.qForm, isTrue);
    final first = excited.advance(PlayfulInteraction.ordinary, 'turn-1', now);
    expect(first.qForm, isTrue);
    expect(first.promptForTurn('turn-1', serious: false), contains('虚拟互动'));
    expect(first.advance(PlayfulInteraction.strong, 'turn-1', now).heat, first.heat);
    final next = first.advance(PlayfulInteraction.ordinary, 'turn-2', now);
    expect(next.heat, lessThan(first.heat));
    expect(next.promptForTurn('turn-2', serious: false), isNot(contains('轻弹额头')));
  });

  test('serious turn softens reply while form waits for zero heat', () {
    final now = DateTime(2026, 9, 23, 12);
    final excited = const PlayfulFormState().interact(kindle: true, now: now);
    final serious = excited.advance(PlayfulInteraction.serious, 'sad', now);
    expect(serious.heat, 64);
    expect(serious.qForm, isTrue);
    expect(serious.promptForTurn('sad', serious: true), contains('松弛自然'));
    final locked = excited.withLock(true).advance(PlayfulInteraction.serious, 'sad', now);
    expect(locked.qForm, isTrue);
    expect(locked.promptForTurn('sad', serious: true), contains('严肃话题'));
    final comforted = locked.interact(kindle: false, now: now);
    expect(comforted.heat, 0);
    expect(comforted.qForm, isFalse);
  });

  test('five mutually playful turns switch form without keyword matching', () {
    final now = DateTime(2026, 9, 24, 12);
    var state = const PlayfulFormState();
    for (var turn = 1; turn <= 4; turn++) {
      state = state.advance(PlayfulInteraction.mutual, '$turn', now);
      expect(state.qForm, isFalse);
    }
    state = state.advance(PlayfulInteraction.mutual, '5', now);
    expect(state.heat, 80);
    expect(state.qForm, isTrue);
    expect(state.advance(PlayfulInteraction.strong, '5', now).heat, 80);
    expect(state.advance(PlayfulInteraction.serious, '6', now).qForm, isTrue);
  });

  test('an expired button event does not appear in the next reply', () {
    final now = DateTime(2026, 9, 24, 12);
    final state = const PlayfulFormState().interact(kindle: true, now: now)
        .advance(PlayfulInteraction.ordinary, 'later',
            now.add(const Duration(minutes: 11)));
    expect(state.promptForTurn('later', serious: false), isNot(contains('轻弹额头')));
  });
}
