import 'dart:convert';

import '../ai/dialogue_expression_plan.dart';
import '../database/app_database.dart';

/// Redacted counters for the per-turn dialogue expression router.
///
/// This stores enum names and aggregate counts only. It never stores user
/// text, prompt text, generated text, message IDs or reasoning.
class DialogueExpressionTelemetry {
  const DialogueExpressionTelemetry._();

  static const settingKey = 'dialogue_expression_telemetry_v1';

  static Future<void> record(
    AppDatabase db,
    DialogueExpressionPlan plan, {
    DateTime? now,
  }) async {
    try {
      final next = nextSnapshot(
        raw: await db.getSetting(settingKey),
        mode: plan.mode.name,
        humor: plan.humor.name,
        now: now,
      );
      await db.setSetting(settingKey, jsonEncode(next));
    } catch (_) {
      // Diagnostics must never alter a prompt or block a response.
    }
  }

  static Future<Map<String, Object?>> snapshot(AppDatabase db) async {
    try {
      return _sanitize(_decode(await db.getSetting(settingKey)));
    } catch (_) {
      return _empty();
    }
  }

  static Map<String, Object?> nextSnapshot({
    String? raw,
    required String mode,
    required String humor,
    DateTime? now,
  }) {
    final previous = _sanitize(_decode(raw));
    final safeMode = _modeNames.contains(mode) ? mode : 'casual';
    final safeHumor = _humorNames.contains(humor) ? humor : 'none';
    final modeCounts = Map<String, int>.from(
      previous['modeCounts']! as Map<String, int>,
    );
    final humorCounts = Map<String, int>.from(
      previous['humorCounts']! as Map<String, int>,
    );
    modeCounts[safeMode] = _increment(modeCounts[safeMode]);
    humorCounts[safeHumor] = _increment(humorCounts[safeHumor]);
    return <String, Object?>{
      'modeCounts': modeCounts,
      'humorCounts': humorCounts,
      'lastMode': safeMode,
      'lastHumor': safeHumor,
      'lastAt': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'userTextIncluded': false,
      'promptBodiesIncluded': false,
      'generatedTextIncluded': false,
      'reasoningIncluded': false,
      'messageIdsIncluded': false,
    };
  }

  static int _increment(int? value) =>
      ((value ?? 0) + 1).clamp(0, 1000000000).toInt();

  static Set<String> get _modeNames =>
      DialogueResponseMode.values.map((value) => value.name).toSet();

  static Set<String> get _humorNames =>
      DialogueHumorDevice.values.map((value) => value.name).toSet();

  static Map<String, Object?> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return _empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _empty();
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    } catch (_) {
      return _empty();
    }
  }

  static Map<String, Object?> _sanitize(Map<String, Object?> source) {
    final rawModes = source['modeCounts'];
    final rawHumor = source['humorCounts'];
    final modeCounts = <String, int>{
      for (final mode in _modeNames)
        mode: _safeCount(rawModes is Map ? rawModes[mode] : null),
    };
    final humorCounts = <String, int>{
      for (final humor in _humorNames)
        humor: _safeCount(rawHumor is Map ? rawHumor[humor] : null),
    };
    final mode = source['lastMode']?.toString() ?? 'never';
    final humor = source['lastHumor']?.toString() ?? 'never';
    return <String, Object?>{
      'modeCounts': modeCounts,
      'humorCounts': humorCounts,
      'lastMode': _modeNames.contains(mode) ? mode : 'never',
      'lastHumor': _humorNames.contains(humor) ? humor : 'never',
      'lastAt': ((source['lastAt'] as num?)?.toInt() ?? 0)
          .clamp(0, 4102444800000),
      'userTextIncluded': false,
      'promptBodiesIncluded': false,
      'generatedTextIncluded': false,
      'reasoningIncluded': false,
      'messageIdsIncluded': false,
    };
  }

  static int _safeCount(Object? value) =>
      ((value as num?)?.toInt() ?? 0).clamp(0, 1000000000).toInt();

  static Map<String, Object?> _empty() => <String, Object?>{
        'modeCounts': <String, int>{
          for (final mode in _modeNames) mode: 0,
        },
        'humorCounts': <String, int>{
          for (final humor in _humorNames) humor: 0,
        },
        'lastMode': 'never',
        'lastHumor': 'never',
        'lastAt': 0,
        'userTextIncluded': false,
        'promptBodiesIncluded': false,
        'generatedTextIncluded': false,
        'reasoningIncluded': false,
        'messageIdsIncluded': false,
      };
}
