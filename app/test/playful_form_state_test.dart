import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';

void main() {
  test('manual virtual interaction persists, then ordinary turns cool down', () {
    final now = DateTime(2026, 9, 23, 12);
    final excited = const PlayfulFormState().interact(kindle: true, now: now);
    expect(excited.heat, 92);
    expect(excited.qForm, isTrue);
    final first = excited.advance('今天聊聊吧', 'turn-1', now);
    expect(first.qForm, isTrue);
    expect(first.promptForTurn('turn-1', serious: false), contains('虚拟互动'));
    expect(first.advance('今天聊聊吧', 'turn-1', now).heat, first.heat);
    final next = first.advance('继续', 'turn-2', now);
    expect(next.heat, lessThan(first.heat));
    expect(next.promptForTurn('turn-2', serious: false), isNot(contains('轻弹额头')));
  });

  test('serious turn softens form and lock is explicit', () {
    final now = DateTime(2026, 9, 23, 12);
    final excited = const PlayfulFormState().interact(kindle: true, now: now);
    final serious = excited.advance('我很难过，别开玩笑', 'sad', now);
    expect(serious.qForm, isFalse);
    final locked = excited.withLock(true).advance('我很难过', 'sad', now);
    expect(locked.qForm, isTrue);
    expect(locked.promptForTurn('sad', serious: true), contains('严肃话题'));
    final comforted = locked.interact(kindle: false, now: now);
    expect(comforted.heat, 0);
    expect(comforted.qForm, isFalse);
  });
}
