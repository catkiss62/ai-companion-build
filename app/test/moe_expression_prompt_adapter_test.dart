import 'package:ai_companion_localfirst/core/integration/moe_expression_prompt_adapter.dart';
import 'package:ai_companion_localfirst/core/moe/application/moe_dynamics_policy.dart';
import 'package:ai_companion_localfirst/core/moe/domain/moe_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MoeStateSnapshot activeState(MoeExpressionMode mode) => MoeStateSnapshot(
        baselines: {
          for (final axis in MoeAxis.values) axis: axis.defaultBaseline,
        },
        current: {
          for (final axis in MoeAxis.values) axis: axis.defaultBaseline,
        },
        recipes: const {
          MoeRecipe.blackBelly: MoeRecipeStatus(
            strength: 76,
            active: true,
          ),
          MoeRecipe.prankster: MoeRecipeStatus(
            strength: 70,
            active: true,
          ),
        },
        updatedAt: DateTime(2026, 8, 25),
        expressionMode: mode,
      );

  test('D3 renders at most primary and secondary as concrete advice', () {
    const policy = MoeDynamicsPolicy();
    final plan = policy.expressionPlan(
      activeState(MoeExpressionMode.obvious),
    );
    final prompt = MoeExpressionPromptPresentation.render(plan);
    expect(plan.primary, isNotNull);
    expect(plan.secondary, isNotNull);
    expect(plan.styleDirectives, hasLength(2));
    expect(prompt, contains('本轮动态表达染色'));
    expect(prompt, contains('清楚可感'));
  });

  test('D3 never exposes recipe labels, axes, values or control abilities', () {
    const policy = MoeDynamicsPolicy();
    final prompt = MoeExpressionPromptPresentation.render(
      policy.expressionPlan(activeState(MoeExpressionMode.manga)),
    );
    for (final recipe in MoeRecipe.values) {
      expect(prompt, isNot(contains(recipe.label)));
      expect(prompt, isNot(contains(recipe.key)));
    }
    for (final axis in MoeAxis.values) {
      expect(prompt, isNot(contains(axis.label)));
      expect(prompt, isNot(contains(axis.key)));
    }
    expect(prompt, isNot(contains('76')));
    expect(prompt, isNot(contains('70')));
    expect(prompt, isNot(contains('send')));
    expect(prompt, isNot(contains('tool')));
    expect(prompt, isNot(contains('gate')));
  });

  test('neutral plan produces no prompt and mode changes only intensity wording', () {
    expect(
      MoeExpressionPromptPresentation.render(MoeExpressionPlan.neutral()),
      isEmpty,
    );
    const policy = MoeDynamicsPolicy();
    final natural = MoeExpressionPromptPresentation.render(
      policy.expressionPlan(activeState(MoeExpressionMode.natural)),
    );
    final obvious = MoeExpressionPromptPresentation.render(
      policy.expressionPlan(activeState(MoeExpressionMode.obvious)),
    );
    final manga = MoeExpressionPromptPresentation.render(
      policy.expressionPlan(activeState(MoeExpressionMode.manga)),
    );
    expect(natural, contains('轻微染色'));
    expect(obvious, contains('清楚可感'));
    expect(manga, contains('放大反差'));
  });
}
