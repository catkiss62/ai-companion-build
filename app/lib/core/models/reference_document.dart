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
    this.entryType = 'knowledge',
    this.activationMode = 'keyword',
    this.priority = 500,
    this.activationProbability = 100,
    this.scope = 'all',
    this.manualActive = false,
    this.exclusiveGroup = '',
    this.builtin = false,
  });

  final String id;
  final String name;
  final String kind;
  final String rawContent;
  final List<String> aliases;
  final bool enabled;
  /// `knowledge` stays bounded/on-demand data; `behavior` is an explicit
  /// world-book instruction module that may affect expression only.
  final String entryType;
  final String activationMode;
  final int priority;
  final int activationProbability;
  final String scope;
  final bool manualActive;
  final String exclusiveGroup;
  final bool builtin;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isBehavior => entryType == 'behavior';
  bool get isKnowledge => !isBehavior;

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
      entryType: row['entry_type'] as String? ?? 'knowledge',
      activationMode: row['activation_mode'] as String? ?? 'keyword',
      priority:
          ((row['priority'] as num?)?.toInt() ?? 500).clamp(0, 1000).toInt(),
      activationProbability:
          ((row['activation_probability'] as num?)?.toInt() ?? 100)
              .clamp(0, 100)
              .toInt(),
      scope: row['scope'] as String? ?? 'all',
      manualActive: (row['manual_active'] as int? ?? 0) == 1,
      exclusiveGroup: row['exclusive_group'] as String? ?? '',
      builtin: (row['builtin'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }
}
