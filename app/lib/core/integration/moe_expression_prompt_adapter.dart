import 'dart:convert';

import '../database/app_database.dart';
import '../moe/application/moe_dynamics_policy.dart';
import '../moe/domain/moe_models.dart';
import '../moe/infrastructure/sqlite_moe_repository.dart';

/// D3's only bridge from persisted Moe state into model-visible expression
/// advice. It never exposes axes, recipe names, values, thresholds or event
/// provenance. Its only write is a redacted status counter used by diagnostics;
/// it has no write path into another companion domain.
class MoeExpressionPromptAdapter {
  MoeExpressionPromptAdapter(
    this.db, {
    MoeDynamicsPolicy policy = const MoeDynamicsPolicy(),
  })  : _policy = policy,
        _repository = SqliteMoeRepository(() => db.database);

  final AppDatabase db;
  final MoeDynamicsPolicy _policy;
  final SqliteMoeRepository _repository;

  Future<String> buildPromptSection() async {
    try {
      if ((await db.getSetting('moe_expression_enabled')) == '0') {
        await MoeExpressionPromptTelemetry.record(
          db,
          status: 'disabled',
        );
        return '';
      }
      final plan = _policy.expressionPlan(await _repository.loadState());
      final section = MoeExpressionPromptPresentation.render(plan);
      await MoeExpressionPromptTelemetry.record(
        db,
        status: section.isEmpty ? 'neutral' : 'applied',
        mode: plan.expressionMode.key,
        primaryPresent: plan.primary != null,
        secondaryPresent: plan.secondary != null,
      );
      return section;
    } catch (_) {
      await MoeExpressionPromptTelemetry.record(
        db,
        status: 'error',
      );
      // Expression colouring is optional. Chat must remain equivalent to the
      // v0.38.2 path when storage is unavailable or state is damaged.
      return '';
    }
  }
}

class MoeExpressionPromptPresentation {
  const MoeExpressionPromptPresentation._();

  static String render(MoeExpressionPlan plan) {
    if (plan.neutral || plan.styleDirectives.isEmpty) return '';
    final intensity = switch (plan.expressionMode) {
      MoeExpressionMode.natural =>
        '轻微染色即可，优先保留自然口语；不必每句都体现。',
      MoeExpressionMode.obvious =>
        '让这种反应在本轮语气、停顿、动作或表达缺口中清楚可感，但不要机制化。',
      MoeExpressionMode.manga =>
        '可以放大反差、节奏和动作感，但不能添加不存在的事实或把一句话写成属性展示。',
    };
    final directives = plan.styleDirectives
        .take(2)
        .map(_withoutInternalVocabulary)
        .map((value) => '- $value')
        .join('\n');
    return '''
【本轮动态表达染色】
$intensity
$directives
这只是“怎么自然表达”的临时建议：不要说出任何属性、配方、档位、数值、阈值或系统机制；不要据此改变事实、记忆、关系身份、工具选择、主动联系资格或情绪标签。
'''.trim();
  }

  static String _withoutInternalVocabulary(String value) {
    var visible = value;
    for (final recipe in MoeRecipe.values) {
      visible = visible.replaceAll(recipe.label, '');
      visible = visible.replaceAll(recipe.key, '');
    }
    for (final axis in MoeAxis.values) {
      visible = visible.replaceAll(axis.label, '');
      visible = visible.replaceAll(axis.key, '');
    }
    return visible.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }
}


/// Redacted D3 prompt-consumption telemetry.
///
/// The single JSON setting contains counters and booleans only. It never stores
/// prompt text, directives, recipe/axis names, values, thresholds or message IDs.
class MoeExpressionPromptTelemetry {
  const MoeExpressionPromptTelemetry._();

  static const settingKey = 'moe_expression_prompt_telemetry_v1';
  static const _statuses = <String>{
    'applied',
    'neutral',
    'disabled',
    'error',
  };
  static const _modes = <String>{
    'natural',
    'obvious',
    'manga',
    'unknown',
  };

  static Future<void> record(
    AppDatabase db, {
    required String status,
    String mode = 'unknown',
    bool primaryPresent = false,
    bool secondaryPresent = false,
    DateTime? now,
  }) async {
    try {
      final raw = await db.getSetting(settingKey);
      final next = nextSnapshot(
        raw: raw,
        status: status,
        mode: mode,
        primaryPresent: primaryPresent,
        secondaryPresent: secondaryPresent,
        now: now,
      );
      await db.setSetting(settingKey, jsonEncode(next));
    } catch (_) {
      // Telemetry must never change the generated prompt or block a turn.
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
    required String status,
    String mode = 'unknown',
    bool primaryPresent = false,
    bool secondaryPresent = false,
    DateTime? now,
  }) {
    final normalizedStatus =
        _statuses.contains(status) ? status : 'error';
    final normalizedMode = _modes.contains(mode) ? mode : 'unknown';
    final previous = _sanitize(_decode(raw));
    final counts = Map<String, int>.from(
      previous['counts']! as Map<String, int>,
    );
    counts[normalizedStatus] =
        ((counts[normalizedStatus] ?? 0) + 1)
            .clamp(0, 1000000000)
            .toInt();
    return <String, Object?>{
      'counts': counts,
      'lastStatus': normalizedStatus,
      'lastAt': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'lastMode': normalizedMode,
      'primaryPresent':
          normalizedStatus == 'applied' && primaryPresent,
      'secondaryPresent':
          normalizedStatus == 'applied' && secondaryPresent,
      'promptBodiesIncluded': false,
      'styleDirectivesIncluded': false,
      'axisOrRecipeNamesIncluded': false,
      'valuesOrThresholdsIncluded': false,
      'messageIdsIncluded': false,
    };
  }

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
    final rawCounts = source['counts'];
    final counts = <String, int>{
      for (final status in _statuses)
        status: rawCounts is Map
            ? ((rawCounts[status] as num?)?.toInt() ?? 0)
                .clamp(0, 1000000000)
                .toInt()
            : 0,
    };
    final status = source['lastStatus']?.toString() ?? 'never';
    final mode = source['lastMode']?.toString() ?? 'unknown';
    return <String, Object?>{
      'counts': counts,
      'lastStatus': _statuses.contains(status) ? status : 'never',
      'lastAt': ((source['lastAt'] as num?)?.toInt() ?? 0)
          .clamp(0, 4102444800000),
      'lastMode': _modes.contains(mode) ? mode : 'unknown',
      'primaryPresent': source['primaryPresent'] == true,
      'secondaryPresent': source['secondaryPresent'] == true,
      'promptBodiesIncluded': false,
      'styleDirectivesIncluded': false,
      'axisOrRecipeNamesIncluded': false,
      'valuesOrThresholdsIncluded': false,
      'messageIdsIncluded': false,
    };
  }

  static Map<String, Object?> _empty() => <String, Object?>{
        'counts': <String, int>{
          for (final status in _statuses) status: 0,
        },
        'lastStatus': 'never',
        'lastAt': 0,
        'lastMode': 'unknown',
        'primaryPresent': false,
        'secondaryPresent': false,
        'promptBodiesIncluded': false,
        'styleDirectivesIncluded': false,
        'axisOrRecipeNamesIncluded': false,
        'valuesOrThresholdsIncluded': false,
        'messageIdsIncluded': false,
      };
}
