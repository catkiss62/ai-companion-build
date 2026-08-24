import 'dart:convert';

import 'package:ai_companion_localfirst/core/moe/application/moe_dynamics_policy.dart';
import 'package:ai_companion_localfirst/core/moe/domain/moe_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 8, 24, 12);

  test('nine axes and nine named recipes keep the locked vocabulary', () {
    expect(MoeAxis.values, hasLength(9));
    expect(MoeRecipe.values, hasLength(9));
    expect(MoeRecipe.blackBelly.label, '腹黑');
    expect(MoeStateSnapshot.initial(now: start).expressionMode,
        MoeExpressionMode.obvious);
  });

  test('state serialization is bounded and ignores unknown keys', () {
    final restored = MoeStateSnapshot.fromJson({
      'updated_at': start.millisecondsSinceEpoch,
      'expression_mode': 'manga',
      'baselines': {'defensive_mask': -9, 'future_axis': 77},
      'current': {'defensive_mask': 155, 'future_axis': 88},
      'recipes': {
        'black_belly': {'strength': 130, 'active': true},
        'future_recipe': {'strength': 99, 'active': true},
      },
    });
    expect(restored.baselines[MoeAxis.defensiveMask], 0);
    expect(restored.current[MoeAxis.defensiveMask], 100);
    expect(restored.recipes[MoeRecipe.blackBelly]!.strength, 100);
    expect(restored.expressionMode, MoeExpressionMode.manga);
    expect(restored.toJson()['contract_version'], moeContractVersion);
  });

  test('pulse, bounded coupling and baseline return are deterministic', () {
    const policy = MoeDynamicsPolicy();
    final initial = MoeStateSnapshot.initial(now: start);
    final input = MoeInputSnapshot(
      capturedAt: start,
      event: MoeObservedEvent(
        idempotencyKey: 'turn-1',
        sourceType: 'test_fixture',
        causeTag: 'care_seen',
        occurredAt: start,
        axisPulses: const {
          MoeAxis.defensiveMask: 40,
          MoeAxis.verbalSpice: 30,
          MoeAxis.closenessBid: 40,
        },
        contextTags: const {'care_exposed'},
      ),
    );
    final first = policy.advance(previous: initial, input: input, now: start);
    final same = policy.advance(previous: initial, input: input, now: start);
    expect(jsonEncode(first.toJson()), jsonEncode(same.toJson()));
    expect(first.current[MoeAxis.cuteDisplay], greaterThan(28));
    expect(first.recipes[MoeRecipe.tsundere]!.active, isTrue);

    final later = policy.advance(
      previous: first,
      input: MoeInputSnapshot(capturedAt: start.add(const Duration(hours: 8))),
      now: start.add(const Duration(hours: 8)),
    );
    expect(later.current[MoeAxis.defensiveMask]!,
        lessThan(first.current[MoeAxis.defensiveMask]!));
  });

  test('high axes without a factual context gate do not activate a trope', () {
    const policy = MoeDynamicsPolicy();
    final high = MoeStateSnapshot(
      baselines: {for (final axis in MoeAxis.values) axis: 100},
      current: {for (final axis in MoeAxis.values) axis: 100},
      recipes: const {},
      updatedAt: start,
    );
    final next = policy.advance(
      previous: high,
      input: MoeInputSnapshot(capturedAt: start),
      now: start,
    );
    expect(next.recipes.values.where((value) => value.active), isEmpty);
  });

  test('hysteresis exit creates cooldown and prevents immediate re-entry', () {
    const policy = MoeDynamicsPolicy();
    final initial = MoeStateSnapshot.initial(now: start);
    MoeObservedEvent event(String id, double pulse) => MoeObservedEvent(
          idempotencyKey: id,
          sourceType: 'test_fixture',
          causeTag: 'care_seen',
          occurredAt: start,
          axisPulses: {
            MoeAxis.defensiveMask: pulse,
            MoeAxis.verbalSpice: pulse,
            MoeAxis.closenessBid: pulse,
          },
          contextTags: const {'care_exposed'},
        );
    final active = policy.advance(
      previous: initial,
      input: MoeInputSnapshot(capturedAt: start, event: event('enter', 40)),
      now: start,
    );
    final exitAt = start.add(const Duration(minutes: 1));
    final exited = policy.advance(
      previous: active,
      input: MoeInputSnapshot(capturedAt: exitAt, event: event('exit', -40)),
      now: exitAt,
    );
    expect(exited.recipes[MoeRecipe.tsundere]!.active, isFalse);
    expect(exited.recipes[MoeRecipe.tsundere]!.cooldownUntil, isNotNull);

    final retryAt = exitAt.add(const Duration(minutes: 1));
    final retry = policy.advance(
      previous: exited,
      input: MoeInputSnapshot(capturedAt: retryAt, event: event('retry', 40)),
      now: retryAt,
    );
    expect(retry.recipes[MoeRecipe.tsundere]!.active, isFalse);
  });

  test('one thousand ticks stay bounded', () {
    const policy = MoeDynamicsPolicy();
    var state = MoeStateSnapshot.initial(now: start);
    for (var i = 1; i <= 1000; i++) {
      final now = start.add(Duration(minutes: i));
      state = policy.advance(
        previous: state,
        input: MoeInputSnapshot(capturedAt: now),
        now: now,
      );
    }
    for (final value in state.current.values) {
      expect(value, inInclusiveRange(0, 100));
    }
    for (final value in state.recipes.values) {
      expect(value.strength, inInclusiveRange(0, 100));
    }
  });

  test('primary and secondary are compatible and modes change visibility only', () {
    const policy = MoeDynamicsPolicy();
    MoeStateSnapshot state(MoeExpressionMode mode) => MoeStateSnapshot(
          baselines: {for (final axis in MoeAxis.values) axis: axis.defaultBaseline},
          current: {for (final axis in MoeAxis.values) axis: axis.defaultBaseline},
          recipes: const {
            MoeRecipe.blackBelly: MoeRecipeStatus(strength: 72, active: true),
            MoeRecipe.prankster: MoeRecipeStatus(strength: 68, active: true),
          },
          updatedAt: start,
          expressionMode: mode,
        );
    final natural = policy.expressionPlan(state(MoeExpressionMode.natural));
    final obvious = policy.expressionPlan(state(MoeExpressionMode.obvious));
    final manga = policy.expressionPlan(state(MoeExpressionMode.manga));
    expect(natural.primary, MoeRecipe.blackBelly);
    expect(natural.secondary, MoeRecipe.prankster);
    expect(natural.visibleStrengths[MoeRecipe.blackBelly]!,
        lessThan(obvious.visibleStrengths[MoeRecipe.blackBelly]!));
    expect(manga.visibleStrengths[MoeRecipe.blackBelly]!,
        greaterThan(obvious.visibleStrengths[MoeRecipe.blackBelly]!));
    expect(manga.styleDirectives.join(), contains('小聪明'));
    expect(manga.safetyDirectives.join(), contains('不写入 Desire'));
  });

  test('disabled or incompatible contract fails open to neutral', () {
    const policy = MoeDynamicsPolicy();
    final next = policy.advance(
      previous: MoeStateSnapshot.initial(now: start),
      input: MoeInputSnapshot(contractVersion: 999, capturedAt: start),
      now: start,
    );
    expect(next.enabled, isFalse);
    expect(policy.expressionPlan(next).neutral, isTrue);
  });
}
