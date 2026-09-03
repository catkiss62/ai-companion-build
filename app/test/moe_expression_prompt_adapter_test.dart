import 'dart:convert';

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
    expect(prompt, contains('本轮动态表达倾向'));
    expect(prompt, contains('清楚可感'));
    expect(prompt, contains('不能只存在于 reasoning'));
    expect(prompt, contains('负面倾向不自动可爱化'));
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
    expect(natural, contains('至少一个用词、判断、断句或选择'));
    expect(obvious, contains('清楚可感'));
    expect(manga, contains('放大反差'));
  });

  test('D3 telemetry records applied and disabled paths without prompt data', () {
    final applied = MoeExpressionPromptTelemetry.nextSnapshot(
      status: 'applied',
      mode: 'obvious',
      primaryPresent: true,
      secondaryPresent: false,
      now: DateTime.fromMillisecondsSinceEpoch(1234),
    );
    expect((applied['counts'] as Map)['applied'], 1);
    expect(applied['lastStatus'], 'applied');
    expect(applied['lastMode'], 'obvious');
    expect(applied['primaryPresent'], isTrue);
    expect(applied['secondaryPresent'], isFalse);
    expect(applied['selectionSeed'], 0);
    expect(applied['candidateCount'], 0);
    expect(applied['promptBodiesIncluded'], isFalse);
    expect(applied['styleDirectivesIncluded'], isFalse);
    expect(applied['axisOrRecipeNamesIncluded'], isFalse);
    expect(applied['valuesOrThresholdsIncluded'], isFalse);

    final disabled = MoeExpressionPromptTelemetry.nextSnapshot(
      raw: jsonEncode(applied),
      status: 'disabled',
      primaryPresent: true,
      secondaryPresent: true,
      now: DateTime.fromMillisecondsSinceEpoch(2345),
    );
    expect((disabled['counts'] as Map)['applied'], 1);
    expect((disabled['counts'] as Map)['disabled'], 1);
    expect(disabled['lastStatus'], 'disabled');
    expect(disabled['primaryPresent'], isFalse);
    expect(disabled['secondaryPresent'], isFalse);
  });

  test('D3 telemetry exposes reproducible decision metadata but no recipe', () {
    final snapshot = MoeExpressionPromptTelemetry.nextSnapshot(
      status: 'applied',
      mode: 'obvious',
      primaryPresent: true,
      selectionSeed: 123456,
      candidateCount: 3,
      contextGrounded: true,
      afterglowOnly: false,
      projectedAgeMinutes: 12,
      now: DateTime.fromMillisecondsSinceEpoch(4567),
    );
    expect(snapshot['selectionSeed'], 123456);
    expect(snapshot['candidateCount'], 3);
    expect(snapshot['contextGrounded'], isTrue);
    expect(snapshot['afterglowOnly'], isFalse);
    expect(snapshot['projectedAgeMinutes'], 12);
    expect(snapshot['axisOrRecipeNamesIncluded'], isFalse);
    expect(snapshot['messageIdsIncluded'], isFalse);
  });

  test('D3 telemetry fails closed to redacted error counters', () {
    final snapshot = MoeExpressionPromptTelemetry.nextSnapshot(
      raw: '{broken',
      status: 'unexpected',
      mode: 'private-mode',
      primaryPresent: true,
      now: DateTime.fromMillisecondsSinceEpoch(3456),
    );
    expect((snapshot['counts'] as Map)['error'], 1);
    expect(snapshot['lastStatus'], 'error');
    expect(snapshot['lastMode'], 'unknown');
    expect(snapshot['primaryPresent'], isFalse);
    expect(snapshot['messageIdsIncluded'], isFalse);
  });
}
