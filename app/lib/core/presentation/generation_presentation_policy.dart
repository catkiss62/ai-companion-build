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
}
