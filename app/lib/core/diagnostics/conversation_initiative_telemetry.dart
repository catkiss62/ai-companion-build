import 'dart:convert';

import '../database/app_database.dart';
import '../desire/conversation_initiative_policy.dart';

class ConversationInitiativeTelemetry {
  const ConversationInitiativeTelemetry._();

  static const settingKey = 'conversation_initiative_telemetry_v1';
  static const _outcomes = <String>{
    'none',
    'engaged',
    'acknowledged',
    'deferred',
    'dodged',
    'refused',
    'redirected',
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
      counts[plan.primary.key] = (counts[plan.primary.key] ?? 0) + 1;
      state
        ..['planCounts'] = counts
        ..['lastPlan'] = plan.primary.key
        ..['lastDrive'] = plan.drive.name
        ..['lastAction'] = _safeAction(plan.action)
        ..['lastPlanAt'] = (now ?? DateTime.now()).millisecondsSinceEpoch;
      await db.setSetting(settingKey, jsonEncode(state));
    } catch (_) {
      // Diagnostics must never block prompt construction.
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
    return <String, Object?>{
      'planCounts': plans,
      'outcomeCounts': outcomes,
      'lastPlan': plans.containsKey(raw['lastPlan'])
          ? raw['lastPlan'].toString()
          : 'never',
      'lastDrive': _safeDrive(raw['lastDrive']?.toString() ?? ''),
      'lastAction': _safeAction(raw['lastAction']?.toString() ?? ''),
      'lastPlanAt': _safeTime(raw['lastPlanAt']),
      'lastOutcome': _outcomes.contains(raw['lastOutcome'])
          ? raw['lastOutcome'].toString()
          : 'none',
      'lastHadAiBid': raw['lastHadAiBid'] == true,
      'lastSatisfactionApplied': raw['lastSatisfactionApplied'] == true,
      'lastOutcomeAt': _safeTime(raw['lastOutcomeAt']),
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

  static int _safeTime(Object? value) =>
      ((value as num?)?.toInt() ?? 0).clamp(0, 4102444800000).toInt();

  static Map<String, Object?> _empty() =>
      _sanitize(const <String, Object?>{});
}
