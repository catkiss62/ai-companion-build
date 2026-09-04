class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.kind,
    required this.content,
    required this.importance,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.confidence = 0.7,
    this.source = 'conversation',
    this.status = 'active',
    this.subjectKey = '',
    this.topicKey = '',
    this.pinned = false,
    this.supersededBy,
    this.lastRecalledAt,
    this.recallCount = 0,
    this.lastExpressedAt,
    this.expressionCount = 0,
    this.retentionScore = 1.0,
    this.retentionCheckedAt,
    this.semanticType = 'current_fact',
    this.evidenceCount = 1,
    DateTime? firstObservedAt,
    DateTime? lastEvidenceAt,
    this.factVersion = 1,
  })  : firstObservedAt = firstObservedAt ?? createdAt,
        lastEvidenceAt = lastEvidenceAt ?? updatedAt;

  final String id;
  final String kind;
  final String content;
  final double importance;
  final double confidence;
  final List<String> tags;
  final String source;
  final String status;
  final String subjectKey;
  final String topicKey;
  final bool pinned;
  final String? supersededBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastRecalledAt;
  final int recallCount;
  final DateTime? lastExpressedAt;
  final int expressionCount;
  final double retentionScore;
  final DateTime? retentionCheckedAt;
  final String semanticType;
  final int evidenceCount;
  final DateTime firstObservedAt;
  final DateTime lastEvidenceAt;
  final int factVersion;

  bool get isActive => status == 'active';
  bool get isCurrentFact => semanticType == 'current_fact' && status == 'active';
  bool get isInference => semanticType == 'inference' && status == 'active';
  bool get isSharedExperience => semanticType == 'shared_experience';
  bool get isHistorical => status == 'superseded';

  factory MemoryItem.fromDb(Map<String, Object?> row) {
    final rawTags = (row['tags'] as String?) ?? '';
    final createdAt = DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int);
    return MemoryItem(
      id: row['id'] as String,
      kind: row['kind'] as String,
      content: row['content'] as String,
      importance: (row['importance'] as num).toDouble(),
      confidence: (row['confidence'] as num?)?.toDouble() ?? 0.7,
      tags: rawTags.isEmpty
          ? const []
          : rawTags.split('|').where((e) => e.isNotEmpty).toList(),
      source: row['source'] as String? ?? 'conversation',
      status: row['status'] as String? ?? 'active',
      subjectKey: row['subject_key'] as String? ?? '',
      topicKey: row['topic_key'] as String? ?? '',
      pinned: (row['pinned'] as int? ?? 0) == 1,
      supersededBy: row['superseded_by'] as String?,
      createdAt: createdAt,
      updatedAt: row['updated_at'] == null
          ? createdAt
          : DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      lastRecalledAt: row['last_recalled_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['last_recalled_at'] as int),
      recallCount: row['recall_count'] as int? ?? 0,
      lastExpressedAt: row['last_expressed_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['last_expressed_at'] as int),
      expressionCount: row['expression_count'] as int? ?? 0,
      retentionScore: (row['retention_score'] as num?)?.toDouble() ?? 1.0,
      retentionCheckedAt: row['retention_checked_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['retention_checked_at'] as int),
      semanticType: row['semantic_type'] as String? ??
          ((row['kind'] as String?) == 'shared_experience'
              ? 'shared_experience'
              : 'current_fact'),
      evidenceCount: row['evidence_count'] as int? ?? 1,
      firstObservedAt: row['first_observed_at'] == null
          ? createdAt
          : DateTime.fromMillisecondsSinceEpoch(row['first_observed_at'] as int),
      lastEvidenceAt: row['last_evidence_at'] == null
          ? (row['updated_at'] == null
              ? createdAt
              : DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int))
          : DateTime.fromMillisecondsSinceEpoch(row['last_evidence_at'] as int),
      factVersion: row['fact_version'] as int? ?? 1,
    );
  }
}
