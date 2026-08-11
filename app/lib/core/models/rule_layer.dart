class RuleLayer {
  const RuleLayer({
    required this.key,
    required this.title,
    required this.content,
    required this.loadPolicy,
    required this.updatedAt,
    this.enabled = true,
    this.locked = false,
  });

  final String key;
  final String title;
  final String content;
  final String loadPolicy;
  final bool enabled;
  final bool locked;
  final DateTime updatedAt;

  factory RuleLayer.fromDb(Map<String, Object?> row) => RuleLayer(
        key: row['key'] as String,
        title: row['title'] as String? ?? '',
        content: row['content'] as String? ?? '',
        loadPolicy: row['load_policy'] as String? ?? 'always',
        enabled: (row['enabled'] as int? ?? 1) == 1,
        locked: (row['locked'] as int? ?? 0) == 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      );
}
