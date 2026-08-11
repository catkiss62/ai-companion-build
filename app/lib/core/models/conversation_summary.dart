class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.summary,
    required this.fromAt,
    required this.toAt,
    required this.createdAt,
    this.keyPoints = const [],
  });

  final String id;
  final String summary;
  final DateTime fromAt;
  final DateTime toAt;
  final DateTime createdAt;
  final List<String> keyPoints;

  factory ConversationSummary.fromDb(Map<String, Object?> row) {
    final raw = (row['key_points'] as String?) ?? '';
    return ConversationSummary(
      id: row['id'] as String,
      summary: row['summary'] as String,
      fromAt: DateTime.fromMillisecondsSinceEpoch(row['from_at'] as int),
      toAt: DateTime.fromMillisecondsSinceEpoch(row['to_at'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      keyPoints: raw.isEmpty
          ? const []
          : raw.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    );
  }
}
