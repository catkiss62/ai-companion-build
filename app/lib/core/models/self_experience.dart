class SelfReviewCandidate {
  const SelfReviewCandidate({
    required this.id,
    required this.dedupeKey,
    required this.sourceKind,
    required this.sourceRef,
    required this.sourceHash,
    required this.topicKey,
    required this.driveKey,
    required this.importance,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    this.selectedAt,
    this.completedAt,
  });

  final String id;
  final String dedupeKey;
  final String sourceKind;
  final String sourceRef;
  final String sourceHash;
  final String topicKey;
  final String driveKey;
  final double importance;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final DateTime? selectedAt;
  final DateTime? completedAt;

  factory SelfReviewCandidate.fromDb(Map<String, Object?> row) {
    DateTime? time(String key) {
      final millis = (row[key] as num?)?.toInt();
      return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
    }

    return SelfReviewCandidate(
      id: row['id'] as String,
      dedupeKey: row['dedupe_key'] as String? ?? '',
      sourceKind: row['source_kind'] as String? ?? '',
      sourceRef: row['source_ref'] as String? ?? '',
      sourceHash: row['source_hash'] as String? ?? '',
      topicKey: row['topic_key'] as String? ?? '',
      driveKey: row['drive_key'] as String? ?? 'reflection',
      importance: (row['importance'] as num?)?.toDouble() ?? 0.5,
      status: row['status'] as String? ?? 'pending',
      createdAt: time('created_at')!,
      updatedAt: time('updated_at')!,
      expiresAt: time('expires_at')!,
      selectedAt: time('selected_at'),
      completedAt: time('completed_at'),
    );
  }
}

class SelfExperienceRecord {
  const SelfExperienceRecord({
    required this.id,
    required this.candidateId,
    required this.sourceKind,
    required this.sourceHash,
    required this.topicKey,
    required this.driveKey,
    required this.appraisal,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.expiresAt,
    this.thoughtId,
  });

  final String id;
  final String candidateId;
  final String sourceKind;
  final String sourceHash;
  final String topicKey;
  final String driveKey;
  final String appraisal;
  final String status;
  final String? thoughtId;
  final DateTime startedAt;
  final DateTime finishedAt;
  final DateTime expiresAt;
}
