class PersonalityTrial {
  const PersonalityTrial({
    required this.id,
    required this.baseKey,
    required this.postureKey,
    required this.content,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    required this.effectiveTurns,
    required this.interactionWindows,
    this.lastInteractionAt,
    this.endedAt,
  });

  final String id;
  final String baseKey;
  final String postureKey;
  final String content;
  final String status;
  final DateTime startedAt;
  final DateTime expiresAt;
  final int effectiveTurns;
  final int interactionWindows;
  final DateTime? lastInteractionAt;
  final DateTime? endedAt;

  Duration remaining([DateTime? now]) =>
      expiresAt.difference(now ?? DateTime.now());

  Duration elapsed([DateTime? now]) =>
      (now ?? DateTime.now()).difference(startedAt);

  bool isActiveAt([DateTime? now]) =>
      status == 'active' && remaining(now).isNegative == false;

  bool get adoptionEligible =>
      elapsed() >= const Duration(hours: 6) &&
      effectiveTurns >= 20 &&
      interactionWindows >= 2;

  bool isAdoptableAt([DateTime? now]) {
    final point = now ?? DateTime.now();
    final recentEnough = point.difference(expiresAt) <= const Duration(days: 7);
    return status != 'adopted' && status != 'replaced' && recentEnough &&
        point.difference(startedAt) >= const Duration(hours: 6) &&
        effectiveTurns >= 20 && interactionWindows >= 2;
  }

  factory PersonalityTrial.fromDb(Map<String, Object?> row) => PersonalityTrial(
        id: row['id'] as String,
        baseKey: row['base_key'] as String,
        postureKey: row['posture_key'] as String,
        content: row['content'] as String? ?? '',
        status: row['status'] as String? ?? 'active',
        startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
        effectiveTurns: row['effective_turns'] as int? ?? 0,
        interactionWindows: row['interaction_windows'] as int? ?? 0,
        lastInteractionAt: (row['last_interaction_at'] as int?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['last_interaction_at'] as int),
        endedAt: (row['ended_at'] as int?) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
      );
}

class SpecialStyleTrial {
  const SpecialStyleTrial({
    required this.id,
    required this.styleKey,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
  });

  final String id;
  final String styleKey;
  final String status;
  final DateTime startedAt;
  final DateTime expiresAt;

  Duration remaining([DateTime? now]) =>
      expiresAt.difference(now ?? DateTime.now());

  bool isActiveAt([DateTime? now]) =>
      status == 'active' && remaining(now).isNegative == false;

  factory SpecialStyleTrial.fromDb(Map<String, Object?> row) => SpecialStyleTrial(
        id: row['id'] as String,
        styleKey: row['style_key'] as String,
        status: row['status'] as String? ?? 'active',
        startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
      );
}
