class GenerationPresentationPolicy {
  const GenerationPresentationPolicy._();

  /// A provider failure may leave a usable fragment in [notice] instead of
  /// [error]. It still needs the same warning color as a hard API failure.
  static bool isErrorNotice(String? notice) {
    final text = notice?.trim() ?? '';
    if (text.isEmpty) return false;
    return text.contains('Gemini') ||
        text.contains('调用失败') ||
        text.contains('回复已截断') ||
        text.contains('回复仍未完整') ||
        text.contains('异常中断');
  }

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

  /// Controller listeners also carry TTS, language-cache, unread, and other
  /// non-layout state. Those notifications may rebuild the chat, but only a
  /// real timeline/stream transition is allowed to move the scroll position.
  static bool shouldFollowChatNotification({
    required bool followLatest,
    required bool generationActive,
    required bool generationEnded,
    required bool streamChanged,
    required bool discoveredUser,
    required bool discoveredAssistant,
  }) =>
      discoveredUser ||
      (followLatest &&
          (generationEnded ||
              discoveredAssistant ||
              (generationActive && streamChanged)));
}
