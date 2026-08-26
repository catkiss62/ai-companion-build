class GenerationPresentationPolicy {
  const GenerationPresentationPolicy._();

  /// Shows the transient reasoning/activity row only until its durable reply
  /// exists. This is the atomic presentation hand-off that prevents one frame
  /// from containing both the completed draft and the final local playback.
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
}
