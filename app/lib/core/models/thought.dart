class CompanionThought {
  const CompanionThought({
    required this.id,
    required this.text,
    required this.driveKey,
    required this.kind,
    required this.strength,
    required this.bornAt,
    required this.updatedAt,
    this.fedCount = 0,
    this.source = 'internal',
    this.lastFedAt,
    this.lifecycleState = 'active',
    this.actionCount = 0,
    this.lastActedAt,
    this.lastSatisfiedAt,
    this.lastResurfacedAt,
    this.resurfacedCount = 0,
    this.residualStrength = 0,
    this.lastOutboundMessageId,
    this.topicKey = '',
    this.mergedCount = 0,
    this.lastMergedAt,
    this.snoozedUntil,
  });

  final String id;
  final String text;
  final String driveKey;
  final String kind;
  final double strength;
  final DateTime bornAt;
  final DateTime updatedAt;
  final int fedCount;
  final String source;
  final DateTime? lastFedAt;
  final String lifecycleState;
  final int actionCount;
  final DateTime? lastActedAt;
  final DateTime? lastSatisfiedAt;
  final DateTime? lastResurfacedAt;
  final int resurfacedCount;
  final double residualStrength;
  final String? lastOutboundMessageId;
  final String topicKey;
  final int mergedCount;
  final DateTime? lastMergedAt;
  final DateTime? snoozedUntil;

  bool get isFixation => kind == 'fixation';
  bool get isSnoozed => snoozedUntil?.isAfter(DateTime.now()) ?? false;
  bool get canDriveIntent =>
      !isSnoozed && (lifecycleState == 'active' || lifecycleState == 'fixation');
  bool get isResidual => lifecycleState == 'residual';
  bool get isDormant => lifecycleState == 'dormant';

  factory CompanionThought.fromDb(Map<String, Object?> row) {
    DateTime? date(String key) => row[key] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row[key] as int);
    return CompanionThought(
      id: row['id'] as String,
      text: row['text'] as String,
      driveKey: row['drive_key'] as String,
      kind: row['kind'] as String,
      strength: (row['strength'] as num).toDouble(),
      bornAt: DateTime.fromMillisecondsSinceEpoch(row['born_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      fedCount: row['fed_count'] as int? ?? 0,
      source: row['source'] as String? ?? 'internal',
      lastFedAt: date('last_fed_at'),
      lifecycleState: row['lifecycle_state'] as String? ??
          ((row['kind'] as String? ?? 'flit') == 'fixation' ? 'fixation' : 'active'),
      actionCount: row['action_count'] as int? ?? 0,
      lastActedAt: date('last_acted_at'),
      lastSatisfiedAt: date('last_satisfied_at'),
      lastResurfacedAt: date('last_resurfaced_at'),
      resurfacedCount: row['resurfaced_count'] as int? ?? 0,
      residualStrength: (row['residual_strength'] as num?)?.toDouble() ?? 0,
      lastOutboundMessageId: row['last_outbound_message_id'] as String?,
      topicKey: row['topic_key'] as String? ?? '',
      mergedCount: row['merged_count'] as int? ?? 0,
      lastMergedAt: date('last_merged_at'),
      snoozedUntil: date('snoozed_until'),
    );
  }
}
