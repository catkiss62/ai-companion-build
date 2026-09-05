import 'dart:convert';

class InteractionSession {
  const InteractionSession({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.startedAt,
    required this.updatedAt,
    this.premise = '',
    this.boundaries = const [],
    this.continuityNote = '',
    this.sourceMessageId,
    this.sourceReferenceDocumentId = '',
    this.sourceReferenceDocumentVersion = 0,
    this.endedAt,
  });

  final String id;
  final String kind;
  final String title;
  final String status;
  final String premise;
  final List<String> boundaries;
  final String continuityNote;
  final String? sourceMessageId;
  final String sourceReferenceDocumentId;
  final int sourceReferenceDocumentVersion;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? endedAt;

  bool get isActive => status == 'active';

  factory InteractionSession.fromDb(Map<String, Object?> row) {
    final raw = row['boundaries_json'] as String? ?? '[]';
    List<String> boundaries = const [];
    try {
      boundaries = (jsonDecode(raw) as List)
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {}
    return InteractionSession(
      id: row['id'] as String,
      kind: row['kind'] as String,
      title: row['title'] as String,
      status: row['status'] as String,
      premise: row['premise'] as String? ?? '',
      boundaries: boundaries,
      continuityNote: row['continuity_note'] as String? ?? '',
      sourceMessageId: row['source_message_id'] as String?,
      sourceReferenceDocumentId:
          row['source_reference_document_id'] as String? ?? '',
      sourceReferenceDocumentVersion:
          (row['source_reference_document_version'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      endedAt: row['ended_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
    );
  }
}
