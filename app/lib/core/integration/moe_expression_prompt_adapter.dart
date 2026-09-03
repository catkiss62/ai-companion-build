import 'dart:convert';
import 'dart:math';

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

  static const selectionStateKey = 'moe_expression_selection_state_v2';

  Future<String> buildPromptSection({
    DateTime? now,
    String latestUserText = '',
    String turnKey = '',
  }) async {
    try {
      final instant = now ?? DateTime.now();
      if ((await db.getSetting('moe_expression_enabled')) == '0') {
        await MoeExpressionPromptTelemetry.record(
          db,
          status: 'disabled',
        );
        return '';
      }
      final committed = await _repository.loadState();
      final projected = _policy.projectForPrompt(
        previous: committed,
        now: instant,
      );
      final tags = MoeDynamicsPolicy.contextTagsForUserText(latestUserText);
      final turnHash = _stableHash(
        turnKey.isNotEmpty
            ? turnKey
            : 'fallback:${instant.millisecondsSinceEpoch ~/ 60000}',
      );
      final prior = _decodeSelectionState(
        await db.getSetting(selectionStateKey),
      );
      final sameTurn = prior['lastTurnHash'] == turnHash;
      final oldLastPrimary = moeRecipeFromKey(
        prior['lastPrimary']?.toString() ?? '',
      );
      final priorPrimaryForTurn = sameTurn
          ? moeRecipeFromKey(
              prior['priorPrimaryForTurn']?.toString() ?? '',
            )
          : oldLastPrimary;
      final priorRunForTurn = sameTurn
          ? ((prior['priorRunForTurn'] as num?)?.toInt() ?? 0)
          : ((prior['repeatRun'] as num?)?.toInt() ?? 0);
      final previousNoContext =
          ((prior['noContextTurns'] as num?)?.toInt() ?? 0)
              .clamp(0, 99);
      final noContextTurns = sameTurn
          ? previousNoContext
          : tags.isEmpty
              ? previousNoContext + 1
              : 0;
      final afterglowBudget = 1 +
          ((committed.updatedAt.millisecondsSinceEpoch ^ turnHash).abs() % 3);
      final selectionSeed = _stableHash(
        '$turnHash:${committed.updatedAt.millisecondsSinceEpoch}',
      );
      final random = Random(selectionSeed);
      final plan = _policy.expressionPlanForTurn(
        projected,
        contextTags: tags,
        allowAfterglow: tags.isNotEmpty || noContextTurns <= afterglowBudget,
        recentPrimary: priorPrimaryForTurn,
        recentPrimaryRun: priorRunForTurn,
        selectionSeed: selectionSeed,
        selectionUnit: random.nextDouble(),
        neutralUnit: random.nextDouble(),
        intensityUnit: random.nextDouble(),
      );
      final section = MoeExpressionPromptPresentation.render(plan);
      final selectedKey = plan.primary?.key ?? '';
      final repeatRun = sameTurn
          ? ((prior['repeatRun'] as num?)?.toInt() ?? 0)
          : selectedKey.isEmpty
              ? 0
              : oldLastPrimary?.key == selectedKey
                  ? (((prior['repeatRun'] as num?)?.toInt() ?? 0) + 1)
                      .clamp(1, 99)
                  : 1;
      await db.setSetting(
        selectionStateKey,
        jsonEncode({
          'lastTurnHash': turnHash,
          'sourceStateUpdatedAt':
              committed.updatedAt.millisecondsSinceEpoch,
          'lastPrimary': selectedKey,
          'priorPrimaryForTurn': priorPrimaryForTurn?.key ?? '',
          'priorRunForTurn': priorRunForTurn,
          'repeatRun': repeatRun,
          'noContextTurns': noContextTurns,
          'afterglowBudget': afterglowBudget,
          'selectionSeed': selectionSeed,
          'candidateCount': plan.candidateCount,
          'contextGrounded': plan.contextGrounded,
          'afterglowOnly': plan.afterglowOnly,
          'updatedAt': instant.millisecondsSinceEpoch,
          'rawTextIncluded': false,
        }),
      );
      await MoeExpressionPromptTelemetry.record(
        db,
        status: section.isEmpty ? 'neutral' : 'applied',
        mode: plan.expressionMode.key,
        primaryPresent: plan.primary != null,
        secondaryPresent: plan.secondary != null,
        selectionSeed: selectionSeed,
        candidateCount: plan.candidateCount,
        contextGrounded: plan.contextGrounded,
        afterglowOnly: plan.afterglowOnly,
        projectedAgeMinutes: instant
            .difference(committed.updatedAt)
            .inMinutes
            .clamp(0, 999999)
            .toInt(),
        now: instant,
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

  static Map<String, Object?> _decodeSelectionState(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    } catch (_) {
      return const {};
    }
  }

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

class MoeExpressionPromptPresentation {
  const MoeExpressionPromptPresentation._();

  static String render(MoeExpressionPlan plan) {
    if (plan.neutral || plan.styleDirectives.isEmpty) return '';
    final intensity = switch (plan.expressionMode) {
      MoeExpressionMode.natural =>
        '保留自然口语，但本轮主要倾向必须在至少一个用词、判断、断句或选择中留下可辨痕迹。',
      MoeExpressionMode.obvious =>
        '让这种反应在本轮对白的用词、判断、节奏或表达缺口中清楚可感；不能只存在于 reasoning 或情绪标签。',
      MoeExpressionMode.manga =>
        '可以明显放大反差、节奏与语言冲击，但仍只写自然对白，不能添加不存在的事实或把一句话写成属性展示。',
    };
    final directives = plan.styleDirectives
        .take(2)
        .map(_withoutInternalVocabulary)
        .map((value) => '- $value')
        .join('\n');
    return '''
【本轮动态表达倾向】
$intensity
$directives
负面倾向不自动可爱化，锋利之后不追加温柔解释；主要倾向若只写在内心而没有改变最终对白，视为没有执行。
这只是本轮怎样表达的临时建议：不要说出任何属性、配方、档位、数值、阈值或系统机制；不要据此改变事实、记忆、关系身份、工具选择、主动联系资格或情绪标签。
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
    int selectionSeed = 0,
    int candidateCount = 0,
    bool contextGrounded = false,
    bool afterglowOnly = false,
    int projectedAgeMinutes = 0,
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
        selectionSeed: selectionSeed,
        candidateCount: candidateCount,
        contextGrounded: contextGrounded,
        afterglowOnly: afterglowOnly,
        projectedAgeMinutes: projectedAgeMinutes,
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
    int selectionSeed = 0,
    int candidateCount = 0,
    bool contextGrounded = false,
    bool afterglowOnly = false,
    int projectedAgeMinutes = 0,
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
      'selectionSeed': selectionSeed.clamp(0, 0x7fffffff),
      'candidateCount': candidateCount.clamp(0, MoeRecipe.values.length),
      'contextGrounded': normalizedStatus == 'applied' && contextGrounded,
      'afterglowOnly': normalizedStatus == 'applied' && afterglowOnly,
      'projectedAgeMinutes': projectedAgeMinutes.clamp(0, 999999),
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
      'selectionSeed':
          ((source['selectionSeed'] as num?)?.toInt() ?? 0)
              .clamp(0, 0x7fffffff),
      'candidateCount':
          ((source['candidateCount'] as num?)?.toInt() ?? 0)
              .clamp(0, MoeRecipe.values.length),
      'contextGrounded': source['contextGrounded'] == true,
      'afterglowOnly': source['afterglowOnly'] == true,
      'projectedAgeMinutes':
          ((source['projectedAgeMinutes'] as num?)?.toInt() ?? 0)
              .clamp(0, 999999),
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
        'selectionSeed': 0,
        'candidateCount': 0,
        'contextGrounded': false,
        'afterglowOnly': false,
        'projectedAgeMinutes': 0,
        'promptBodiesIncluded': false,
        'styleDirectivesIncluded': false,
        'axisOrRecipeNamesIncluded': false,
        'valuesOrThresholdsIncluded': false,
        'messageIdsIncluded': false,
      };
}
