class InteractionReciprocityState {
  const InteractionReciprocityState({
    this.streak = 0,
    this.activateEpisode = false,
    this.resolveEpisode = false,
  });

  final int streak;
  final bool activateEpisode;
  final bool resolveEpisode;
}

/// Converts semantic outcomes of a real AI interaction bid into a very small
/// cumulative reciprocity signal. Message length is intentionally absent.
class InteractionReciprocityPolicy {
  const InteractionReciprocityPolicy._();

  static InteractionReciprocityState next({
    required int previousStreak,
    required bool hadAiBid,
    required String outcome,
  }) {
    final old = previousStreak.clamp(0, 12).toInt();
    if (!hadAiBid || outcome == 'none') {
      final next = (old - 1).clamp(0, 12).toInt();
      return InteractionReciprocityState(
        streak: next,
        resolveEpisode: next == 0,
      );
    }
    switch (outcome) {
      case 'engaged':
        return const InteractionReciprocityState(resolveEpisode: true);
      case 'deferred':
        // Explicitly being busy/tired is not rejection and does not add debt.
        return InteractionReciprocityState(streak: old);
      case 'refused':
        // Respect a clear boundary instead of turning it into pressure.
        return const InteractionReciprocityState(resolveEpisode: true);
      case 'dodged':
        final next = (old + 2).clamp(0, 12).toInt();
        return InteractionReciprocityState(
          streak: next,
          activateEpisode: next >= 3,
        );
      case 'acknowledged':
      case 'redirected':
        final next = (old + 1).clamp(0, 12).toInt();
        return InteractionReciprocityState(
          streak: next,
          // Several partial acknowledgements are needed; one or two never
          // become evidence of dissatisfaction.
          activateEpisode: next >= 4,
        );
      default:
        return InteractionReciprocityState(streak: old);
    }
  }

  static double episodeIntensity(int streak) =>
      (0.24 + (streak.clamp(3, 12) - 3) * 0.055)
          .clamp(0.24, 0.52)
          .toDouble();
}
