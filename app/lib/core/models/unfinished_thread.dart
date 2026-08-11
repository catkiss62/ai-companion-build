class UnfinishedThread {
  const UnfinishedThread({
    required this.id,
    required this.title,
    required this.detail,
    required this.importance,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.sourceMessageId,
    this.topicKey = '',
    this.followupDueAt,
    this.followupSeededAt,
    this.followupCount = 0,
    this.lastFollowupAt,
    this.retiredAt,
    this.retireReason = '',
  });

  final String id;
  final String title;
  final String detail;
  final double importance;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sourceMessageId;
  final String topicKey;
  final DateTime? followupDueAt;
  final DateTime? followupSeededAt;
  final int followupCount;
  final DateTime? lastFollowupAt;
  final DateTime? retiredAt;
  final String retireReason;

  bool get isActive => status == 'active';
  bool get followupScheduled => followupDueAt != null && isActive;
  bool followupDue(DateTime now) =>
      followupScheduled && !followupDueAt!.isAfter(now);

  factory UnfinishedThread.fromDb(Map<String, Object?> row) {
    DateTime? time(Object? value) => value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value as int);
    return UnfinishedThread(
      id: row['id'] as String,
      title: row['title'] as String,
      detail: row['detail'] as String,
      importance: (row['importance'] as num).toDouble(),
      status: row['status'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      sourceMessageId: row['source_message_id'] as String?,
      topicKey: row['topic_key'] as String? ?? '',
      followupDueAt: time(row['followup_due_at']),
      followupSeededAt: time(row['followup_seeded_at']),
      followupCount: row['followup_count'] as int? ?? 0,
      lastFollowupAt: time(row['last_followup_at']),
      retiredAt: time(row['retired_at']),
      retireReason: row['retire_reason'] as String? ?? '',
    );
  }
}
