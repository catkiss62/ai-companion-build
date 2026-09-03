class GenerationPresentationPolicy {
  const GenerationPresentationPolicy._();

  /// The transient reasoning/activity row is replaced atomically once the
  /// durable assistant message exists. Generation may still be finishing
  /// post-turn work, but the UI must never render both copies in one frame.
  static bool showDraft({
    required bool generationActive,
    required String? assistantMessageId,
    required Iterable<String> committedMessageIds,
  }) {
    if (!generationActive) return false;
    final id = assistantMessageId?.trim() ?? '';
    if (id.isEmpty) return true;
    return !committedMessageIds.contains(id);
  }

  /// A durable answer may be inserted before post-turn work has released the
  /// generation state. Starting the local typewriter at that commit boundary
  /// lets a long reasoning panel or memory extraction consume the animation
  /// before the answer is actually presented to the user.
  static bool typewriterPlaybackReady({
    required bool animateRequested,
    required bool generationActive,
  }) =>
      animateRequested && !generationActive;

  /// The presentation cursor represents a completed presentation, not merely
  /// discovery of a durable row. With typewriter disabled, discovery and
  /// presentation are the same event.
  static bool markPresentedOnDiscovery({
    required bool typewriterEnabled,
  }) =>
      !typewriterEnabled;
}
