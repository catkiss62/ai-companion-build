class OverlayGenerationSnapshot {
  const OverlayGenerationSnapshot({
    required this.sending,
    required this.cancelling,
    required this.reasoning,
    required this.content,
  });

  final bool sending;
  final bool cancelling;
  final String reasoning;
  final String content;

  String get phase {
    if (cancelling) return 'cancelling';
    if (!sending) return 'idle';
    if (content.isNotEmpty) return 'answering';
    return 'thinking';
  }

  Map<String, Object> toChannelMap() => <String, Object>{
        'sending': sending,
        'cancelling': cancelling,
        'reasoning': reasoning,
        'content': content,
        'phase': phase,
      };
}
