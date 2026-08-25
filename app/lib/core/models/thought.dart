enum ThoughtProvenance {
  realUserMessage,
  awareness,
  memory,
  selfExperience,
  inference,
  publicWebCandidate,
  internal,
}

extension ThoughtProvenanceLabel on ThoughtProvenance {
  String get key => switch (this) {
        ThoughtProvenance.realUserMessage => 'user_message',
        ThoughtProvenance.awareness => 'awareness',
        ThoughtProvenance.memory => 'memory',
        ThoughtProvenance.selfExperience => 'self_experience',
        ThoughtProvenance.inference => 'inference',
        ThoughtProvenance.publicWebCandidate => 'public_web_candidate',
        ThoughtProvenance.internal => 'internal',
      };

  String get zhLabel => switch (this) {
        ThoughtProvenance.realUserMessage => '真实用户消息',
        ThoughtProvenance.awareness => '环境感知',
        ThoughtProvenance.memory => '长期记忆',
        ThoughtProvenance.selfExperience => '自身经历',
        ThoughtProvenance.inference => '内部推断',
        ThoughtProvenance.publicWebCandidate => '公开网页候选',
        ThoughtProvenance.internal => '内部状态',
      };
}

class ThoughtProvenancePolicy {
  const ThoughtProvenancePolicy._();

  static ThoughtProvenance fromSource(String source) {
    final normalized = source.trim().toLowerCase();
    if (normalized == 'conversation' ||
        normalized.startsWith('conversation_turn:') ||
        normalized.startsWith('user_message:')) {
      return ThoughtProvenance.realUserMessage;
    }
    if (normalized.startsWith('presence/') ||
        normalized.startsWith('perception/') ||
        normalized.startsWith('awareness/')) {
      return ThoughtProvenance.awareness;
    }
    if (normalized.startsWith('public_web_candidate:')) {
      return ThoughtProvenance.publicWebCandidate;
    }
    if (normalized.contains('memory')) return ThoughtProvenance.memory;
    if (normalized.startsWith('self_drive/') ||
        normalized.startsWith('self_reflection_run:')) {
      return ThoughtProvenance.selfExperience;
    }
    if (normalized.startsWith('inference/') || normalized.contains('guess')) {
      return ThoughtProvenance.inference;
    }
    return ThoughtProvenance.internal;
  }
}

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
  bool get isSnoozed => isSnoozedAt(DateTime.now());
  bool isSnoozedAt(DateTime now) => snoozedUntil?.isAfter(now) ?? false;
  bool get canDriveIntent => canDriveIntentAt(DateTime.now());
  bool canDriveIntentAt(DateTime now) =>
      !isSnoozedAt(now) &&
      (lifecycleState == 'active' || lifecycleState == 'fixation');
  bool get isResidual => lifecycleState == 'residual';
  bool get isDormant => lifecycleState == 'dormant';
  ThoughtProvenance get provenance => ThoughtProvenancePolicy.fromSource(source);

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
