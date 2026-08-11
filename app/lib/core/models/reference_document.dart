class ReferenceDocument {
  const ReferenceDocument({
    required this.id,
    required this.name,
    required this.kind,
    required this.rawContent,
    required this.createdAt,
    required this.updatedAt,
    this.aliases = const [],
    this.enabled = true,
  });

  final String id;
  final String name;
  final String kind;
  final String rawContent;
  final List<String> aliases;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ReferenceDocument.fromDb(Map<String, Object?> row) {
    final rawAliases = row['aliases'] as String? ?? '';
    return ReferenceDocument(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      kind: row['kind'] as String? ?? 'character',
      rawContent: row['raw_content'] as String? ?? '',
      aliases: rawAliases.isEmpty
          ? const []
          : rawAliases.split('|').where((e) => e.trim().isNotEmpty).toList(),
      enabled: (row['enabled'] as int? ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
