import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';

void main() {
  final now = DateTime.utc(2026, 9, 24);

  test('ordinary talk is near level in adult form and cools Q in seven turns',
      () {
    final adult = const PlayfulFormState(heat: 60)
        .advance(PlayfulInteraction.ordinary, 'normal', now);
    expect(adult.heat, 58);
    expect(adult.qForm, isFalse);
    expect(const PlayfulFormState()
        .advance(PlayfulInteraction.ordinary, 'neutral', now).heat, 0);

    var q = const PlayfulFormState(heat: 100, qForm: true);
    for (var turn = 1; turn <= 6; turn++) {
      q = q.advance(PlayfulInteraction.ordinary, 'quiet_$turn', now);
      expect(q.heat, 100 - 15 * turn);
      expect(q.qForm, isTrue);
    }
    q = q.advance(PlayfulInteraction.ordinary, 'quiet_7', now);
    expect(q.heat, 0);
    expect(q.qForm, isFalse);
  });

  test('full meter holds once, then judges while renewed play keeps it full',
      () {
    var state = const PlayfulFormState();
    for (var turn = 1; turn <= 3; turn++) {
      state = state.advance(PlayfulInteraction.mutual, 'mutual_$turn', now);
      expect(state.heat, turn * 28);
      expect(state.qForm, isFalse);
    }
    state = state.advance(PlayfulInteraction.mutual, 'mutual_4', now);
    expect(state.heat, 100);
    expect(state.qForm, isFalse);
    expect(state.breakthroughDue, isTrue);
    final waited = state.advance(PlayfulInteraction.ordinary, 'wait', now,
        breakthrough: false);
    expect(waited.heat, 100);
    expect(waited.breakthroughDue, isTrue);
    expect(waited.advance(PlayfulInteraction.ordinary, 'later', now).heat, 98);
    final stillPlaying = waited.advance(PlayfulInteraction.mutual, 'tease', now,
        breakthrough: false);
    expect(stillPlaying.heat, 100);
    expect(stillPlaying.breakthroughDue, isTrue);
    expect(stillPlaying.advance(PlayfulInteraction.strong, 'tip', now,
        breakthrough: true).qForm, isTrue);
    final tipped = state.advance(PlayfulInteraction.ordinary, 'tipped', now,
        breakthrough: true);
    expect(tipped.qForm, isTrue);
    expect(tipped.heat, 100);
    expect(state.advance(PlayfulInteraction.serious, 'help', now,
        breakthrough: true).qForm, isFalse);

    final mild = const PlayfulFormState(heat: 84)
        .advance(PlayfulInteraction.light, 'light', now);
    expect(mild.heat, 88);
    expect(mild.qForm, isFalse);
    final embarrassed = mild.advance(PlayfulInteraction.ordinary, 'shy', now);
    expect(embarrassed.heat, 86);
    expect(embarrassed.qForm, isFalse);
  });

  test('serious help does not force a form or persona switch', () {
    final q = const PlayfulFormState(heat: 90, qForm: true)
        .advance(PlayfulInteraction.serious, 'help', now);
    expect(q.heat, 75);
    expect(q.qForm, isTrue);
    expect(q.promptForTurn('help'), contains('现在脾气更冲'));
    expect(q.promptForTurn('help'), isNot(contains('严肃话题')));
  });

  test('a visible assistant challenge counts once and can reach an endpoint',
      () {
    var state = const PlayfulFormState(heat: 84)
        .advance(PlayfulInteraction.ordinary, 'user-turn', now);
    expect(state.heat, 82);
    state = state.onAssistantTurn(
        PlayfulSelfActivity.strong, 'assistant-1', now);
    expect(state.heat, 100);
    expect(state.qForm, isFalse);
    expect(state.breakthroughDue, isTrue);
    final restored = PlayfulFormState.decode(state.encode());
    expect(restored.lastAssistantTurn, 'assistant-1');
    expect(restored.breakthroughDue, isTrue);
    expect(
      restored.onAssistantTurn(
          PlayfulSelfActivity.strong, 'assistant-1', now).heat,
      100,
    );
    expect(
      restored.onAssistantTurn(
          PlayfulSelfActivity.settle, 'assistant-2', now).heat,
      92,
    );
  });

  test('Stop restores the one-turn chance and a failed judgment does not spend it', () {
    final full = const PlayfulFormState(heat: 82)
        .onAssistantTurn(PlayfulSelfActivity.strong, 'assistant-full', now);
    expect(full.breakthroughDue, isTrue);
    final unavailable = full.advance(PlayfulInteraction.ordinary, 'missing', now);
    expect(unavailable.breakthroughDue, isTrue);
    final stopped = unavailable.rollbackTurn('missing');
    expect(stopped.breakthroughDue, isTrue);
    final tipped = stopped.advance(PlayfulInteraction.mutual, 'retry', now,
        breakthrough: true);
    expect(tipped.qForm, isTrue);
    expect(PlayfulFormState.decode(tipped.encode()).qForm, isTrue);
    expect(full.interact(kindle: true, now: now).qForm, isTrue);
  });

  test('an existing save at full heat can judge again after a failed result', () {
    final restored = PlayfulFormState.decode('{"heat":100,"qForm":false,'
        '"breakthroughReady":false}');
    expect(restored.breakthroughDue, isTrue);
    expect(restored.advance(PlayfulInteraction.mutual, 'replay', now,
        breakthrough: true).qForm, isTrue);
  });

  test('offered initiative is stable and does not change heat by itself', () {
    final ids = List<String>.generate(100, (i) => 'turn_$i');
    final offers = ids.where(
      (id) => PlayfulInitiativePolicy.offer(id, opportunity: true),
    );
    expect(offers.length, inInclusiveRange(15, 45));
    expect(PlayfulInitiativePolicy.offer(ids.first, opportunity: false),
        isFalse);
    expect(PlayfulInitiativePolicy.offer('', opportunity: true), isFalse);
    for (final id in ids) {
      expect(
        PlayfulInitiativePolicy.offer(id, opportunity: true),
        PlayfulInitiativePolicy.offer(id, opportunity: true),
      );
    }
  });
}
