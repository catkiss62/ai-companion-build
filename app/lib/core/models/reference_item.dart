class ReferenceItem {
  const ReferenceItem({
    required this.id,
    required this.sourceName,
    required this.section,
    required this.title,
    required this.content,
    required this.weight,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.enabled = true,
    this.documentId,
  });

  final String id;
  final String sourceName;
  final String section;
  final String title;
  final String content;
  final List<String> tags;
  final double weight;
  final bool enabled;
  final String? documentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ReferenceItem.fromDb(Map<String, Object?> row) {
    final rawTags = row['tags'] as String? ?? '';
    return ReferenceItem(
      id: row['id'] as String,
      sourceName: row['source_name'] as String? ?? '',
      section: row['section'] as String? ?? 'other',
      title: row['title'] as String? ?? '',
      content: row['content'] as String? ?? '',
      tags: rawTags.isEmpty
          ? const []
          : rawTags.split('|').where((e) => e.isNotEmpty).toList(),
      weight: (row['weight'] as num?)?.toDouble() ?? 0.55,
      enabled: (row['enabled'] as int? ?? 1) == 1,
      documentId: row['document_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
