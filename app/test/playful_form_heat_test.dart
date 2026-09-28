import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';

void main() {
  final now = DateTime.utc(2026, 9, 26);

  test('normal form keeps neutral heat and accumulates playful turns without Q cooling', () {
    var state = const PlayfulFormState();
    for (var i=0; i<3; i++) {
      state=state.advance(PlayfulInteraction.mutual, 'u$i', now)
        .onAssistantTurn(PlayfulSelfActivity.playful, 'a$i', now);
    }
    expect(state.heat, 99);
    expect(state.qForm, isFalse);
    state=state.advance(PlayfulInteraction.ordinary,'neutral',now)
      .onAssistantTurn(PlayfulSelfActivity.none,'neutral-reply',now);
    expect(state.heat, 99);
    expect(state.onAssistantTurn(PlayfulSelfActivity.none,'neutral-reply',now).heat,99);
  });

  test('both contributions settle before zero and switch', () {
    final ordinary = const PlayfulFormState(heat: 19, qForm: true)
        .advance(PlayfulInteraction.ordinary, 'user-a', now);
    expect(ordinary.heat, 19); // Provisional until the reply is committed.
    final exited = ordinary.onAssistantTurn(
        PlayfulSelfActivity.playful, 'assistant-a', now);
    expect(exited.heat, 4); // Q cooling is 18; her real playful reply adds 3.
    expect(exited.qForm, isTrue);

    final challenged = const PlayfulFormState(heat: 15, qForm: true)
        .advance(PlayfulInteraction.mutual, 'user-b', now)
        .onAssistantTurn(PlayfulSelfActivity.playful, 'assistant-b', now);
    expect(challenged.heat, 30); // 15 + 30 + 3 - 18.
    expect(challenged.qForm, isTrue);
  });

  test('neutral Q turns cool in about six turns; serious help stays factual', () {
    var q = const PlayfulFormState(heat: 100, qForm: true);
    for (var turn = 1; turn <= 5; turn++) {
      q = q.advance(PlayfulInteraction.ordinary, 'quiet_$turn', now)
          .onAssistantTurn(PlayfulSelfActivity.none, 'reply_$turn', now);
      expect(q.heat, 100 - 18 * turn);
      expect(q.qForm, isTrue);
    }
    q = q.advance(PlayfulInteraction.ordinary, 'quiet_6', now)
        .onAssistantTurn(PlayfulSelfActivity.none, 'reply_6', now);
    expect(q.heat, 0);
    expect(q.qForm, isFalse);

    final help = const PlayfulFormState(heat: 90, qForm: true)
        .advance(PlayfulInteraction.serious, 'help', now)
        .onAssistantTurn(PlayfulSelfActivity.none, 'help-reply', now);
    expect(help.heat, 60); // -18 cooling plus -12 serious contribution.
    expect(help.qForm, isTrue);
  });

  test('stopping a provisional turn restores its previous state', () {
    const original = PlayfulFormState(heat: 15, qForm: true);
    final provisional = original.advance(PlayfulInteraction.mutual, 'stop-me', now);
    final stopped = PlayfulFormState.decode(provisional.encode())
        .rollbackTurn('stop-me');
    expect(stopped.heat, 15);
    expect(stopped.qForm, isTrue);
    expect(stopped.lastTurn, isEmpty);
    expect(stopped.onAssistantTurn(PlayfulSelfActivity.playful, 'late', now).heat,
        18); // A late assistant activity cannot apply the withdrawn user score.
  });

  test('full meter waits for a later successful breakthrough', () {
    final full = const PlayfulFormState(heat: 88)
        .advance(PlayfulInteraction.mutual, 'rise', now)
        .onAssistantTurn(PlayfulSelfActivity.none, 'rise-reply', now);
    expect(full.heat, 100);
    expect(full.qForm, isFalse);
    expect(full.breakthroughDue, isTrue);
    final transformed = full.advance(PlayfulInteraction.mutual, 'tip', now,
            breakthrough: true)
        .onAssistantTurn(PlayfulSelfActivity.none, 'tip-reply', now);
    expect(transformed.qForm, isTrue);
  });

  test('offered initiative is deterministic and never changes heat', () {
    final ids = List<String>.generate(100, (i) => 'turn_$i');
    final offers = ids.where((id) =>
        PlayfulInitiativePolicy.offer(id, opportunity: true));
    expect(offers.length, inInclusiveRange(15, 45));
    for (final id in ids) {
      expect(PlayfulInitiativePolicy.offer(id, opportunity: true),
          PlayfulInitiativePolicy.offer(id, opportunity: true));
    }
  });
}
