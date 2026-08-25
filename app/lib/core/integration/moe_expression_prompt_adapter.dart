import '../database/app_database.dart';
import '../moe/application/moe_dynamics_policy.dart';
import '../moe/domain/moe_models.dart';
import '../moe/infrastructure/sqlite_moe_repository.dart';

/// D3's only bridge from persisted Moe state into model-visible expression
/// advice. It never exposes axes, recipe names, values, thresholds or event
/// provenance, and it has no write path into another domain.
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
      if ((await db.getSetting('moe_expression_enabled')) == '0') return '';
      final plan = _policy.expressionPlan(await _repository.loadState());
      return MoeExpressionPromptPresentation.render(plan);
    } catch (_) {
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
