class ThoughtLifecycleEvent {
  const ThoughtLifecycleEvent({
    required this.id,
    required this.thoughtId,
    required this.eventType,
    required this.createdAt,
    this.detail = '',
    this.messageId,
  });

  final String id;
  final String thoughtId;
  final String eventType;
  final String detail;
  final String? messageId;
  final DateTime createdAt;

  factory ThoughtLifecycleEvent.fromDb(Map<String, Object?> row) =>
      ThoughtLifecycleEvent(
        id: row['id'] as String,
        thoughtId: row['thought_id'] as String,
        eventType: row['event_type'] as String,
        detail: row['detail'] as String? ?? '',
        messageId: row['message_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      );
}
