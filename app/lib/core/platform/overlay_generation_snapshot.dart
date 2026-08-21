class OverlayGenerationSnapshot {
  const OverlayGenerationSnapshot({
    required this.sending,
    required this.cancelling,
    required this.reasoning,
    required this.content,
    this.assistantMessageId = '',
    this.statusText = '',
    this.runtimePhase = '',
  });

  final bool sending;
  final bool cancelling;
  final String reasoning;
  final String content;
  final String assistantMessageId;
  final String statusText;
  final String runtimePhase;

  String get phase {
    if (cancelling) return 'cancelling';
    if (!sending) return 'idle';
    if (runtimePhase == 'thinking' || runtimePhase == 'answering') {
      return runtimePhase;
    }
    if (content.isNotEmpty) return 'answering';
    return 'thinking';
  }

  Map<String, Object> toChannelMap() => <String, Object>{
        'sending': sending,
        'cancelling': cancelling,
        'reasoning': reasoning,
        'content': content,
        'phase': phase,
        'assistant_message_id': assistantMessageId,
        'status_text': statusText,
      };
}
