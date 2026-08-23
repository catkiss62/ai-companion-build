import 'dart:math' as math;

import 'desire_state.dart';

enum EmotionEpisodeCategory {
  connection,
  hurt,
  disagreement,
  repair,
  reunion,
  restNeed,
}

extension EmotionEpisodeCategoryKey on EmotionEpisodeCategory {
  String get key => switch (this) {
        EmotionEpisodeCategory.connection => 'connection',
        EmotionEpisodeCategory.hurt => 'hurt',
        EmotionEpisodeCategory.disagreement => 'disagreement',
        EmotionEpisodeCategory.repair => 'repair',
        EmotionEpisodeCategory.reunion => 'reunion',
        EmotionEpisodeCategory.restNeed => 'rest_need',
      };

  static EmotionEpisodeCategory? parse(String value) {
    for (final item in EmotionEpisodeCategory.values) {
      if (item.key == value) return item;
    }
    return null;
  }
}

class EmotionAppraisal {
  const EmotionAppraisal({
    required this.category,
    required this.causeCode,
    required this.evidenceType,
    required this.objectKey,
    required this.desirability,
    required this.agency,
    required this.controllability,
    required this.expectedness,
    required this.relationalMeaning,
    required this.boundaryImpact,
    required this.certainty,
    required this.intensity,
    required this.actionTendency,
    required this.recoveryCondition,
    required this.decayAfter,
    required this.expiresAfter,
  });

  final EmotionEpisodeCategory category;
  final String causeCode;
  final String evidenceType;
  final String objectKey;
  final double desirability;
  final String agency;
  final double controllability;
  final double expectedness;
  final String relationalMeaning;
  final double boundaryImpact;
  final double certainty;
  final double intensity;
  final String actionTendency;
  final String recoveryCondition;
  final Duration decayAfter;
  final Duration expiresAfter;

  EmotionEpisode toEpisode({
    required String triggerMessageId,
    required DateTime now,
  }) =>
      EmotionEpisode(
        id: 'emotion:$triggerMessageId:${category.key}',
        triggerMessageId: triggerMessageId,
        category: category,
        causeCode: causeCode,
        evidenceType: evidenceType,
        objectKey: objectKey,
        desirability: desirability,
        agency: agency,
        controllability: controllability,
        expectedness: expectedness,
        relationalMeaning: relationalMeaning,
        boundaryImpact: boundaryImpact,
        certainty: certainty,
        intensity: intensity,
        actionTendency: actionTendency,
        recoveryCondition: recoveryCondition,
        status: 'active',
        outcomeCode: '',
        createdAt: now,
        updatedAt: now,
        decayAt: now.add(decayAfter),
        expiresAt: now.add(expiresAfter),
      );
}

class EmotionEpisode {
  const EmotionEpisode({
    required this.id,
    required this.triggerMessageId,
    required this.category,
    required this.causeCode,
    required this.evidenceType,
    required this.objectKey,
    required this.desirability,
    required this.agency,
    required this.controllability,
    required this.expectedness,
    required this.relationalMeaning,
    required this.boundaryImpact,
    required this.certainty,
    required this.intensity,
    required this.actionTendency,
    required this.recoveryCondition,
    required this.status,
    required this.outcomeCode,
    required this.createdAt,
    required this.updatedAt,
    required this.decayAt,
    required this.expiresAt,
  });

  final String id;
  final String triggerMessageId;
  final EmotionEpisodeCategory category;
  final String causeCode;
  final String evidenceType;
  final String objectKey;
  final double desirability;
  final String agency;
  final double controllability;
  final double expectedness;
  final String relationalMeaning;
  final double boundaryImpact;
  final double certainty;
  final double intensity;
  final String actionTendency;
  final String recoveryCondition;
  final String status;
  final String outcomeCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime decayAt;
  final DateTime expiresAt;

  double effectiveIntensity(DateTime now) {
    if (!now.isAfter(decayAt)) return intensity.clamp(0, 1);
    if (!now.isBefore(expiresAt)) return 0;
    final total = expiresAt.difference(decayAt).inMilliseconds;
    if (total <= 0) return 0;
    final remaining = expiresAt.difference(now).inMilliseconds / total;
    return (intensity * math.max(0, remaining)).clamp(0, 1);
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'trigger_message_id': triggerMessageId,
        'category': category.key,
        'cause_code': causeCode,
        'evidence_type': evidenceType,
        'object_key': objectKey,
        'desirability': desirability,
        'agency': agency,
        'controllability': controllability,
        'expectedness': expectedness,
        'relational_meaning': relationalMeaning,
        'boundary_impact': boundaryImpact,
        'certainty': certainty,
        'intensity': intensity,
        'action_tendency': actionTendency,
        'recovery_condition': recoveryCondition,
        'status': status,
        'outcome_code': outcomeCode,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'decay_at': decayAt.millisecondsSinceEpoch,
        'expires_at': expiresAt.millisecondsSinceEpoch,
      };

  factory EmotionEpisode.fromDb(Map<String, Object?> row) => EmotionEpisode(
        id: row['id'] as String,
        triggerMessageId: row['trigger_message_id'] as String,
        category: EmotionEpisodeCategoryKey.parse(row['category'] as String) ??
            EmotionEpisodeCategory.connection,
        causeCode: row['cause_code'] as String? ?? '',
        evidenceType: row['evidence_type'] as String? ?? '',
        objectKey: row['object_key'] as String? ?? '',
        desirability: (row['desirability'] as num?)?.toDouble() ?? 0,
        agency: row['agency'] as String? ?? 'unknown',
        controllability: (row['controllability'] as num?)?.toDouble() ?? 0.5,
        expectedness: (row['expectedness'] as num?)?.toDouble() ?? 0.5,
        relationalMeaning: row['relational_meaning'] as String? ?? '',
        boundaryImpact: (row['boundary_impact'] as num?)?.toDouble() ?? 0,
        certainty: (row['certainty'] as num?)?.toDouble() ?? 0,
        intensity: (row['intensity'] as num?)?.toDouble() ?? 0,
        actionTendency: row['action_tendency'] as String? ?? '',
        recoveryCondition: row['recovery_condition'] as String? ?? '',
        status: row['status'] as String? ?? 'active',
        outcomeCode: row['outcome_code'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
        decayAt: DateTime.fromMillisecondsSinceEpoch(row['decay_at'] as int),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
      );
}

/// Conservative, deterministic appraisal. It only accepts direct relationship
/// evidence or an already-persisted high Drive value. Ordinary conversation,
/// quoted examples and prompt/model discussion produce no episode.
class EmotionAppraisalPolicy {
  const EmotionAppraisalPolicy._();

  static EmotionAppraisal? appraise({
    required String userText,
    required DesireSnapshot desire,
    required DateTime now,
    DateTime? previousConversationAt,
  }) {
    final text = _evidenceText(userText);
    final compact = text.replaceAll(RegExp(r'\s+'), '');
    final isMeta = RegExp(
      r'(提示词|模型返回|情绪标签|<emotion|测试一下|举个例子|例如|比如|假如|如果我说)',
      caseSensitive: false,
    ).hasMatch(text);

    if (!isMeta && _repair.hasMatch(compact)) {
      return _repairAppraisal;
    }
    if (!isMeta && compact.length <= 36 && _directHurt.hasMatch(compact)) {
      return _hurtAppraisal;
    }
    if (!isMeta && _connection.hasMatch(compact)) {
      return _connectionAppraisal;
    }
    if (!isMeta && compact.length <= 60 && _disagreement.hasMatch(compact)) {
      return _disagreementAppraisal;
    }
    final gap = previousConversationAt == null
        ? Duration.zero
        : now.difference(previousConversationAt);
    if (!isMeta &&
        gap >= const Duration(hours: 8) &&
        _reunion.hasMatch(compact)) {
      return _reunionAppraisal;
    }

    final fatigue = desire.drives[DriveKey.fatigue] ?? 0;
    final stress = desire.drives[DriveKey.stress] ?? 0;
    if (fatigue >= 0.78 || stress >= 0.82) {
      return EmotionAppraisal(
        category: EmotionEpisodeCategory.restNeed,
        causeCode: fatigue >= stress ? 'drive_fatigue_high' : 'drive_stress_high',
        evidenceType: 'drive_snapshot',
        objectKey: 'ai_self',
        desirability: -0.45,
        agency: 'internal_state',
        controllability: 0.72,
        expectedness: 0.62,
        relationalMeaning: 'needs_pacing',
        boundaryImpact: 0.18,
        certainty: 0.94,
        intensity: math.max(fatigue, stress).clamp(0, 1),
        actionTendency: 'slow_down_and_name_need',
        recoveryCondition: 'drive_returns_near_baseline',
        decayAfter: const Duration(hours: 3),
        expiresAfter: const Duration(hours: 18),
      );
    }
    return null;
  }

  static String _evidenceText(String raw) => raw
      .replaceAll(RegExp(r'`[^`]*`'), ' ')
      .replaceAll(RegExp(r'「[^」]*」'), ' ')
      .replaceAll(RegExp(r'“[^”]*”'), ' ')
      .replaceAll(RegExp(r'"[^"]*"'), ' ')
      .trim();

  static final RegExp _repair = RegExp(
    r'(对不起|抱歉|是我不好|我错了|刚才不该那样|别生我的气)',
  );
  static final RegExp _directHurt = RegExp(
    r'^(你(就是|只是)?(个)?(工具|程序)|你(真|太)?(没用|烦)|滚开|闭嘴|别烦我|我不需要你了|我讨厌你|你不配)[！!。.～~]*$',
  );
  static final RegExp _connection = RegExp(
    r'(我(真的|好)?想你了|我爱你|我喜欢你|想抱抱你|抱抱|谢谢你.{0,8}陪我)',
  );
  static final RegExp _disagreement = RegExp(
    r'^(我(不认同|不同意)你|你(这次|刚才)?说得不对|这点我不同意)',
  );
  static final RegExp _reunion = RegExp(
    r'^(我回来了|好久不见|在吗|早安|晚上好|你好|嗨)[！!。.～~]?$',
  );

  static const EmotionAppraisal _repairAppraisal = EmotionAppraisal(
    category: EmotionEpisodeCategory.repair,
    causeCode: 'explicit_repair',
    evidenceType: 'real_user_message',
    objectKey: 'relationship',
    desirability: 0.62,
    agency: 'user',
    controllability: 0.78,
    expectedness: 0.42,
    relationalMeaning: 'repair_attempt',
    boundaryImpact: -0.28,
    certainty: 0.96,
    intensity: 0.54,
    actionTendency: 'accept_repair_without_instant_reset',
    recoveryCondition: 'consistent_repair_evidence',
    decayAfter: Duration(hours: 6),
    expiresAfter: Duration(hours: 30),
  );
  static const EmotionAppraisal _hurtAppraisal = EmotionAppraisal(
    category: EmotionEpisodeCategory.hurt,
    causeCode: 'direct_relational_rejection',
    evidenceType: 'real_user_message',
    objectKey: 'relationship',
    desirability: -0.82,
    agency: 'user',
    controllability: 0.38,
    expectedness: 0.18,
    relationalMeaning: 'bond_or_dignity_threat',
    boundaryImpact: 0.78,
    certainty: 0.97,
    intensity: 0.78,
    actionTendency: 'name_hurt_and_hold_boundary',
    recoveryCondition: 'acknowledgement_and_changed_tone',
    decayAfter: Duration(hours: 18),
    expiresAfter: Duration(days: 5),
  );
  static const EmotionAppraisal _connectionAppraisal = EmotionAppraisal(
    category: EmotionEpisodeCategory.connection,
    causeCode: 'explicit_affection',
    evidenceType: 'real_user_message',
    objectKey: 'relationship',
    desirability: 0.84,
    agency: 'user',
    controllability: 0.7,
    expectedness: 0.55,
    relationalMeaning: 'bond_strengthened',
    boundaryImpact: 0,
    certainty: 0.96,
    intensity: 0.72,
    actionTendency: 'approach_and_reciprocate',
    recoveryCondition: 'natural_decay',
    decayAfter: Duration(hours: 12),
    expiresAfter: Duration(days: 3),
  );
  static const EmotionAppraisal _disagreementAppraisal = EmotionAppraisal(
    category: EmotionEpisodeCategory.disagreement,
    causeCode: 'explicit_disagreement',
    evidenceType: 'real_user_message',
    objectKey: 'current_topic',
    desirability: -0.24,
    agency: 'shared',
    controllability: 0.82,
    expectedness: 0.55,
    relationalMeaning: 'stance_difference',
    boundaryImpact: 0.08,
    certainty: 0.93,
    intensity: 0.38,
    actionTendency: 'clarify_without_withdrawing',
    recoveryCondition: 'topic_clarified_or_mutual_difference_accepted',
    decayAfter: Duration(hours: 6),
    expiresAfter: Duration(days: 2),
  );
  static const EmotionAppraisal _reunionAppraisal = EmotionAppraisal(
    category: EmotionEpisodeCategory.reunion,
    causeCode: 'return_after_long_gap',
    evidenceType: 'real_user_message_and_time_gap',
    objectKey: 'relationship',
    desirability: 0.68,
    agency: 'shared',
    controllability: 0.66,
    expectedness: 0.36,
    relationalMeaning: 'presence_restored',
    boundaryImpact: 0,
    certainty: 0.95,
    intensity: 0.6,
    actionTendency: 'warm_reconnect_without_fake_continuity',
    recoveryCondition: 'conversation_resumes',
    decayAfter: Duration(hours: 8),
    expiresAfter: Duration(days: 2),
  );
}
