import 'package:ai_companion_localfirst/core/desire/interaction_reciprocity_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one or two short acknowledgements cannot create dissatisfaction', () {
    var state = InteractionReciprocityPolicy.next(
      previousStreak: 0,
      hadAiBid: true,
      outcome: 'acknowledged',
    );
    expect(state.streak, 1);
    expect(state.activateEpisode, isFalse);
    state = InteractionReciprocityPolicy.next(
      previousStreak: state.streak,
      hadAiBid: true,
      outcome: 'acknowledged',
    );
    expect(state.streak, 2);
    expect(state.activateEpisode, isFalse);
  });

  test('repeated semantic non-engagement creates only a bounded mild episode', () {
    var state = const InteractionReciprocityState();
    for (var i = 0; i < 4; i++) {
      state = InteractionReciprocityPolicy.next(
        previousStreak: state.streak,
        hadAiBid: true,
        outcome: 'acknowledged',
      );
    }
    expect(state.activateEpisode, isTrue);
    expect(
      InteractionReciprocityPolicy.episodeIntensity(state.streak),
      inInclusiveRange(.24, .52),
    );
  });

  test('engagement recovers quickly and busy or refusal is not punished', () {
    final engaged = InteractionReciprocityPolicy.next(
      previousStreak: 7,
      hadAiBid: true,
      outcome: 'engaged',
    );
    expect(engaged.streak, 0);
    expect(engaged.resolveEpisode, isTrue);

    final deferred = InteractionReciprocityPolicy.next(
      previousStreak: 2,
      hadAiBid: true,
      outcome: 'deferred',
    );
    expect(deferred.streak, 2);
    expect(deferred.activateEpisode, isFalse);

    final refused = InteractionReciprocityPolicy.next(
      previousStreak: 5,
      hadAiBid: true,
      outcome: 'refused',
    );
    expect(refused.streak, 0);
    expect(refused.resolveEpisode, isTrue);
  });
}
