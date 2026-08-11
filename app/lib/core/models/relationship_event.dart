import 'dart:convert';

class RelationshipEvent {
  const RelationshipEvent({
    required this.id,
    required this.kind,
    required this.summary,
    required this.createdAt,
    this.intensity = 0.5,
    this.valence = 0.0,
    this.sourceMessageId,
    this.metadata = const {},
    this.internalizedAt,
  });

  final String id;
  final String kind;
  final String summary;
  final double intensity;
  final double valence;
  final String? sourceMessageId;
  final Map<String, Object?> metadata;
  final DateTime createdAt;
  final DateTime? internalizedAt;

  factory RelationshipEvent.fromDb(Map<String, Object?> row) {
    final raw = row['metadata_json'] as String? ?? '{}';
    Map<String, Object?> metadata = const {};
    try {
      metadata = Map<String, Object?>.from(jsonDecode(raw) as Map);
    } catch (_) {}
    return RelationshipEvent(
      id: row['id'] as String,
      kind: row['kind'] as String,
      summary: row['summary'] as String,
      intensity: (row['intensity'] as num?)?.toDouble() ?? 0.5,
      valence: (row['valence'] as num?)?.toDouble() ?? 0.0,
      sourceMessageId: row['source_message_id'] as String?,
      metadata: metadata,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      internalizedAt: row['internalized_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['internalized_at'] as int),
    );
  }
}
