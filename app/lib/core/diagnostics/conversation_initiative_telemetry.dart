import 'dart:convert';

import '../database/app_database.dart';
import '../desire/conversation_initiative_policy.dart';
import '../desire/conversation_outcome_verifier.dart';

class CommittedConversationPlan {
  const CommittedConversationPlan({
    required this.assistantMessageId,
    required this.primary,
    required this.topicMove,
    required this.plannedSpeechAct,
    required this.speechAct,
    required this.drive,
    required this.action,
    required this.askAuthorized,
    required this.curiosityGateReason,
    required this.hasThought,
    required this.sourceProvenance,
    required this.hadAiBid,
    required this.sourceThoughtExpressed,
    required this.expressionMatchReason,
  });

  final String assistantMessageId;
  final String primary;
  final String topicMove;
  final String plannedSpeechAct;
  final String speechAct;
  final String drive;
  final String action;
  final bool askAuthorized;
  final String curiosityGateReason;
  final bool hasThought;
  final String sourceProvenance;
  final bool hadAiBid;
  final bool sourceThoughtExpressed;
  final String expressionMatchReason;
}

class ConversationInitiativeTelemetry {
  const ConversationInitiativeTelemetry._();

  // v2 starts a clean post-Phase-2A.5 observation window. The v1 aggregate
  // remains untouched in old backups so historical probe bias stays auditable.
  static const settingKey = 'conversation_initiative_telemetry_v2';
  static const committedPlanKey = 'conversation_initiative_committed_plan_v2';
  static const _outcomes = <String>{
    'none',
    'engaged',
    'acknowledged',
    'deferred',
    'dodged',
    'refused',
    'redirected',
  };
  static const _expressionReasons = <String>{
    'expressed_match',
    'no_expressed_bid',
    'planned_bid_not_expressed',
    'source_thought_not_expressed',
    'ask_source_mismatch',
    'legacy_plan_only',
  };

  static Future<void> recordPlan(
    AppDatabase db,
    ConversationInitiativePlan plan, {
    DateTime? now,
  }) async {
    try {
      final state = _sanitize(_decode(await db.getSetting(settingKey)));
      final counts = Map<String, int>.from(
        state['planCounts']! as Map<String, int>,
      );
      final topicCounts = Map<String, int>.from(
        state['topicMoveCounts']! as Map<String, int>,
      );
      final speechCounts = Map<String, int>.from(
        state['speechActCounts']! as Map<String, int>,
      );
      final gateCounts = Map<String, int>.from(
        state['curiosityGateCounts']! as Map<String, int>,
      );
      counts[plan.primary.key] = (counts[plan.primary.key] ?? 0) + 1;
      topicCounts[plan.topicMove.key] =
          (topicCounts[plan.topicMove.key] ?? 0) + 1;
      speechCounts[plan.speechAct.key] =
          (speechCounts[plan.speechAct.key] ?? 0) + 1;
      gateCounts[plan.curiosityGateReason] =
          (gateCounts[plan.curiosityGateReason] ?? 0) + 1;
      state
        ..['planCounts'] = counts
        ..['topicMoveCounts'] = topicCounts
        ..['speechActCounts'] = speechCounts
        ..['curiosityGateCounts'] = gateCounts
        ..['askAuthorizedCount'] =
            ((state['askAuthorizedCount'] as int?) ?? 0) +
                (plan.askAuthorized ? 1 : 0)
        ..['askBlockedCount'] =
            ((state['askBlockedCount'] as int?) ?? 0) +
                (plan.askAuthorized ? 0 : 1)
        ..['lastPlan'] = plan.primary.key
        ..['lastTopicMove'] = plan.topicMove.key
        ..['lastSpeechAct'] = plan.speechAct.key
        ..['lastAskAuthorized'] = plan.askAuthorized
        ..['lastCuriosityGateReason'] = plan.curiosityGateReason
        ..['lastQuestionPressureBand'] = plan.questionPressureBand
        ..['lastHasThought'] = plan.hasThought
        ..['lastSourceProvenance'] = plan.sourceProvenance
        ..['lastDrive'] = plan.drive.name
        ..['lastAction'] = _safeAction(plan.action)
        ..['lastPlanAt'] = (now ?? DateTime.now()).millisecondsSinceEpoch;
      await db.setSetting(settingKey, jsonEncode(state));
    } catch (_) {
      // Diagnostics must never block prompt construction.
    }
  }

  static Future<void> recordCommittedPlan(
    AppDatabase db, {
    required String assistantMessageId,
    required ConversationInitiativePlan plan,
    required ConversationExpressionVerification verification,
  }) async {
    try {
      final previous = _decodeCommittedPlans(
        await db.getSetting(committedPlanKey),
      );
      final plans = <Map<String, Object?>>[
        ...previous.where(
          (item) => item['assistant_message_id'] != assistantMessageId,
        ),
        {
          'assistant_message_id': assistantMessageId,
          'primary': plan.primary.key,
          'topic_move': plan.topicMove.key,
          'planned_speech_act': plan.speechAct.key,
          'speech_act': verification.expressedSpeechAct,
          'drive': plan.drive.name,
          'action': _safeAction(plan.action),
          'ask_authorized': plan.askAuthorized,
          'curiosity_gate_reason': plan.curiosityGateReason,
          'has_thought': plan.hasThought,
          'source_provenance': plan.sourceProvenance,
          'expressed_had_ai_bid': verification.hadAiBid,
          'source_thought_expressed': verification.sourceThoughtExpressed,
          'expression_match_reason': verification.reason,
        },
      ];
      await db.setSetting(
        committedPlanKey,
        jsonEncode({
          'plans': plans.reversed.take(12).toList().reversed.toList(),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      await _recordExpressionVerification(db, verification);
    } catch (_) {
      // A committed chat message remains valid even if diagnostics cannot bind.
    }
  }

  static Future<void> _recordExpressionVerification(
    AppDatabase db,
    ConversationExpressionVerification verification,
  ) async {
    final state = _sanitize(_decode(await db.getSetting(settingKey)));
    final reasonCounts = Map<String, int>.from(
      state['expressionReasonCounts']! as Map<String, int>,
    );
    final speechCounts = Map<String, int>.from(
      state['expressedSpeechActCounts']! as Map<String, int>,
    );
    final reason = _safeExpressionReason(verification.reason);
    final speechAct = _safeSpeechAct(verification.expressedSpeechAct);
    reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
    speechCounts[speechAct] = (speechCounts[speechAct] ?? 0) + 1;
    state
      ..['expressionReasonCounts'] = reasonCounts
      ..['expressedSpeechActCounts'] = speechCounts
      ..['committedPlanCount'] =
          ((state['committedPlanCount'] as int?) ?? 0) + 1
      ..['expressionMismatchCount'] =
          ((state['expressionMismatchCount'] as int?) ?? 0) +
              (verification.reason == 'expressed_match' ||
                      verification.reason == 'no_expressed_bid'
                  ? 0
                  : 1)
      ..['lastExpressedSpeechAct'] = speechAct
      ..['lastExpressionMatchReason'] = reason
      ..['lastSourceThoughtExpressed'] =
          verification.sourceThoughtExpressed
      ..['lastExpressionVerifiedAt'] =
          DateTime.now().millisecondsSinceEpoch;
    await db.setSetting(settingKey, jsonEncode(state));
  }

  static Future<CommittedConversationPlan?> planForAssistant(
    AppDatabase db,
    String assistantMessageId,
  ) async {
    try {
      final raw = await db.getSetting(committedPlanKey);
      if (raw == null || raw.trim().isEmpty) return null;
      Map<String, Object?>? item;
      for (final candidate in _decodeCommittedPlans(raw)) {
        if (candidate['assistant_message_id'] == assistantMessageId) {
          item = candidate;
          break;
        }
      }
      if (item == null) return null;
      final drive = _safeDrive(item['drive']?.toString() ?? '');
      final action = _safeAction(item['action']?.toString() ?? '');
      if (drive == 'none' || action == 'unknown') return null;
      final plannedSpeechAct = _safeSpeechAct(
        item['planned_speech_act']?.toString() ??
            item['speech_act']?.toString() ??
            '',
      );
      final expressedSpeechAct = _safeSpeechAct(
        item['speech_act']?.toString() ?? '',
      );
      final hasExpressionTruth = item.containsKey('expressed_had_ai_bid');
      return CommittedConversationPlan(
        assistantMessageId: assistantMessageId,
        primary: item['primary']?.toString() ?? 'unknown',
        topicMove: item['topic_move']?.toString() ?? 'stay',
        plannedSpeechAct: plannedSpeechAct,
        speechAct: expressedSpeechAct,
        drive: drive,
        action: action,
        askAuthorized: item['ask_authorized'] == true,
        curiosityGateReason:
            item['curiosity_gate_reason']?.toString() ?? 'unknown',
        hasThought: item['has_thought'] == true,
        sourceProvenance:
            item['source_provenance']?.toString() ?? 'internal',
        hadAiBid: hasExpressionTruth && item['expressed_had_ai_bid'] == true,
        sourceThoughtExpressed:
            hasExpressionTruth && item['source_thought_expressed'] == true,
        expressionMatchReason: hasExpressionTruth
            ? _safeExpressionReason(
                item['expression_match_reason']?.toString() ?? '',
              )
            : 'legacy_plan_only',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> recordOutcome(
    AppDatabase db, {
    required String outcome,
    required bool hadAiBid,
    required bool satisfactionApplied,
    DateTime? now,
  }) async {
    try {
      final state = _sanitize(_decode(await db.getSetting(settingKey)));
      final normalized = _outcomes.contains(outcome) ? outcome : 'none';
      final counts = Map<String, int>.from(
        state['outcomeCounts']! as Map<String, int>,
      );
      counts[normalized] = (counts[normalized] ?? 0) + 1;
      state
        ..['outcomeCounts'] = counts
        ..['lastOutcome'] = normalized
        ..['lastHadAiBid'] = hadAiBid
        ..['lastSatisfactionApplied'] = satisfactionApplied
        ..['lastOutcomeAt'] = (now ?? DateTime.now()).millisecondsSinceEpoch;
      await db.setSetting(settingKey, jsonEncode(state));
    } catch (_) {
      // Diagnostics must never block durable post-turn work.
    }
  }

  static Future<void> recordReset(
    AppDatabase db, {
    required DateTime at,
  }) async {
    try {
      final state = _sanitize(_decode(await db.getSetting(settingKey)));
      state
        ..['resetCount'] = ((state['resetCount'] as int?) ?? 0) + 1
        ..['lastResetAt'] = at.millisecondsSinceEpoch;
      await db.setSetting(settingKey, jsonEncode(state));
    } catch (_) {
      // The authoritative reset boundary is stored separately by AppDatabase.
    }
  }

  static Future<Map<String, Object?>> snapshot(AppDatabase db) async {
    try {
      return _sanitize(_decode(await db.getSetting(settingKey)));
    } catch (_) {
      return _empty();
    }
  }

  static Map<String, Object?> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return _empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _empty();
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return _empty();
    }
  }

  static List<Map<String, Object?>> _decodeCommittedPlans(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final map = decoded.cast<String, dynamic>();
      final plans = map['plans'];
      if (plans is List) {
        return plans
            .whereType<Map>()
            .map(
              (item) => item.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
            .toList(growable: false);
      }
      // v2 was first shipped as one safe, redacted object. Keep reading that
      // shape so an interrupted development install remains compatible.
      if (map['assistant_message_id'] is String) {
        return [map.cast<String, Object?>()];
      }
    } catch (_) {}
    return const [];
  }

  static Map<String, Object?> _sanitize(Map<String, Object?> raw) {
    final planRaw = raw['planCounts'];
    final outcomeRaw = raw['outcomeCounts'];
    final plans = <String, int>{
      for (final mode in ConversationInitiativeMode.values)
        mode.key: planRaw is Map
            ? ((planRaw[mode.key] as num?)?.toInt() ?? 0)
                .clamp(0, 1000000000)
                .toInt()
            : 0,
    };
    final outcomes = <String, int>{
      for (final outcome in _outcomes)
        outcome: outcomeRaw is Map
            ? ((outcomeRaw[outcome] as num?)?.toInt() ?? 0)
                .clamp(0, 1000000000)
                .toInt()
            : 0,
    };
    final topicRaw = raw['topicMoveCounts'];
    final topicMoves = <String, int>{
      for (final item in ConversationTopicMove.values)
        item.key: topicRaw is Map
            ? ((topicRaw[item.key] as num?)?.toInt() ?? 0)
                .clamp(0, 1000000000)
                .toInt()
            : 0,
    };
    final speechRaw = raw['speechActCounts'];
    final speechActs = <String, int>{
      for (final item in ConversationSpeechAct.values)
        item.key: speechRaw is Map
            ? ((speechRaw[item.key] as num?)?.toInt() ?? 0)
                .clamp(0, 1000000000)
                .toInt()
            : 0,
    };
    final expressedSpeechRaw = raw['expressedSpeechActCounts'];
    final expressedSpeechActs = <String, int>{
      for (final item in ConversationSpeechAct.values)
        item.key: expressedSpeechRaw is Map
            ? ((expressedSpeechRaw[item.key] as num?)?.toInt() ?? 0)
                .clamp(0, 1000000000)
                .toInt()
            : 0,
    };
    final expressionReasonRaw = raw['expressionReasonCounts'];
    final expressionReasonCounts = <String, int>{
      for (final reason in _expressionReasons)
        reason: expressionReasonRaw is Map
            ? ((expressionReasonRaw[reason] as num?)?.toInt() ?? 0)
                .clamp(0, 1000000000)
                .toInt()
            : 0,
    };
    const curiosityGateReasons = <String>{
      'no_source',
      'no_specific_gap',
      'no_self_relevance',
      'already_known',
      'recently_asked',
      'user_redirected',
      'topic_exhausted',
      'question_pressure',
      'fatigue',
      'boundary',
      'authorized',
    };
    final gateRaw = raw['curiosityGateCounts'];
    final gateCounts = <String, int>{
      for (final reason in curiosityGateReasons)
        reason: gateRaw is Map
            ? ((gateRaw[reason] as num?)?.toInt() ?? 0)
                .clamp(0, 1000000000)
                .toInt()
            : 0,
    };
    return <String, Object?>{
      'planCounts': plans,
      'topicMoveCounts': topicMoves,
      'speechActCounts': speechActs,
      'expressedSpeechActCounts': expressedSpeechActs,
      'expressionReasonCounts': expressionReasonCounts,
      'curiosityGateCounts': gateCounts,
      'askAuthorizedCount': _safeCount(raw['askAuthorizedCount']),
      'askBlockedCount': _safeCount(raw['askBlockedCount']),
      'outcomeCounts': outcomes,
      'lastPlan': plans.containsKey(raw['lastPlan'])
          ? raw['lastPlan'].toString()
          : 'never',
      'lastTopicMove': topicMoves.containsKey(raw['lastTopicMove'])
          ? raw['lastTopicMove'].toString()
          : 'stay',
      'lastSpeechAct': speechActs.containsKey(raw['lastSpeechAct'])
          ? raw['lastSpeechAct'].toString()
          : 'react',
      'lastAskAuthorized': raw['lastAskAuthorized'] == true,
      'lastCuriosityGateReason': gateCounts.containsKey(
        raw['lastCuriosityGateReason'],
      )
          ? raw['lastCuriosityGateReason'].toString()
          : 'no_source',
      'lastQuestionPressureBand': const {'none', 'soft', 'high'}.contains(
        raw['lastQuestionPressureBand'],
      )
          ? raw['lastQuestionPressureBand'].toString()
          : 'none',
      'lastHasThought': raw['lastHasThought'] == true,
      'lastSourceProvenance': _safeSourceProvenance(
        raw['lastSourceProvenance']?.toString() ?? '',
      ),
      'lastDrive': _safeDrive(raw['lastDrive']?.toString() ?? ''),
      'lastAction': _safeAction(raw['lastAction']?.toString() ?? ''),
      'lastPlanAt': _safeTime(raw['lastPlanAt']),
      'lastOutcome': _outcomes.contains(raw['lastOutcome'])
          ? raw['lastOutcome'].toString()
          : 'none',
      'lastHadAiBid': raw['lastHadAiBid'] == true,
      'lastSatisfactionApplied': raw['lastSatisfactionApplied'] == true,
      'lastOutcomeAt': _safeTime(raw['lastOutcomeAt']),
      'committedPlanCount': _safeCount(raw['committedPlanCount']),
      'expressionMismatchCount': _safeCount(raw['expressionMismatchCount']),
      'lastExpressedSpeechAct': _safeSpeechAct(
        raw['lastExpressedSpeechAct']?.toString() ?? '',
      ),
      'lastExpressionMatchReason': _safeExpressionReason(
        raw['lastExpressionMatchReason']?.toString() ?? '',
      ),
      'lastSourceThoughtExpressed':
          raw['lastSourceThoughtExpressed'] == true,
      'lastExpressionVerifiedAt':
          _safeTime(raw['lastExpressionVerifiedAt']),
      'resetCount': ((raw['resetCount'] as num?)?.toInt() ?? 0)
          .clamp(0, 1000000000)
          .toInt(),
      'lastResetAt': _safeTime(raw['lastResetAt']),
      'messageLengthUsedForDisengagement': false,
      'promptBodiesIncluded': false,
      'messageBodiesIncluded': false,
      'thoughtBodiesIncluded': false,
      'memoryBodiesIncluded': false,
      'messageIdsIncluded': false,
      'topicKeysIncluded': false,
      'rawModelJsonIncluded': false,
    };
  }

  static String _safeDrive(String value) => const {
        'attachment',
        'curiosity',
        'reflection',
        'duty',
        'social',
        'libido',
        'stress',
        'fatigue',
      }.contains(value)
          ? value
          : 'none';

  static String _safeAction(String value) => const {
        'reach_out',
        'continue_thread',
        'share_thought',
        'check_in',
        'tease_or_intimacy',
        'comfort_or_ground',
        'discover_interest',
        'remember_shared_experience',
        'wildcard_share',
        'rest',
        'wait',
      }.contains(value)
          ? value
          : 'unknown';

  static String _safeSpeechAct(String value) {
    for (final speechAct in ConversationSpeechAct.values) {
      if (speechAct.key == value) return value;
    }
    return ConversationSpeechAct.react.key;
  }

  static String _safeExpressionReason(String value) =>
      _expressionReasons.contains(value) ? value : 'no_expressed_bid';

  static int _safeTime(Object? value) =>
      ((value as num?)?.toInt() ?? 0).clamp(0, 4102444800000).toInt();

  static int _safeCount(Object? value) =>
      ((value as num?)?.toInt() ?? 0).clamp(0, 1000000000).toInt();

  static String _safeSourceProvenance(String value) => const {
        'user_message',
        'awareness',
        'memory',
        'self_experience',
        'inference',
        'public_web_candidate',
        'internal',
        'drive_state',
      }.contains(value)
          ? value
          : 'internal';

  static Map<String, Object?> _empty() =>
      _sanitize(const <String, Object?>{});
}
