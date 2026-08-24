import 'dart:math' as math;

import '../domain/moe_models.dart';

class MoeDynamicsPolicy {
  const MoeDynamicsPolicy({
    this.entryThreshold = 46.0,
    this.exitThreshold = 34.0,
    this.cooldown = const Duration(minutes: 20),
  });

  final double entryThreshold;
  final double exitThreshold;
  final Duration cooldown;

  MoeStateSnapshot advance({
    required MoeStateSnapshot previous,
    required MoeInputSnapshot input,
    required DateTime now,
  }) {
    if (!previous.enabled || input.contractVersion != moeContractVersion) {
      return MoeStateSnapshot.neutral(
        now: now,
        expressionMode: previous.expressionMode,
      );
    }

    final elapsedHours = now
        .difference(previous.updatedAt)
        .inMilliseconds
        .clamp(0, const Duration(hours: 72).inMilliseconds) /
        const Duration(hours: 1).inMilliseconds;
    final next = <MoeAxis, double>{};
    for (final axis in MoeAxis.values) {
      final baseline = previous.baselines[axis] ?? axis.defaultBaseline;
      final current = previous.current[axis] ?? baseline;
      final retention = math.exp(-_returnRate(axis) * elapsedHours);
      next[axis] = clampMoeValue(baseline + (current - baseline) * retention);
    }

    final event = input.event;
    if (event != null && !event.occurredAt.isAfter(now.add(const Duration(minutes: 5)))) {
      for (final entry in event.axisPulses.entries) {
        next[entry.key] = clampMoeValue((next[entry.key] ?? 0) + entry.value);
      }
      _applyBoundedCoupling(next, event.axisPulses);
    }

    final tags = event?.contextTags ?? const <String>{};
    final resolved = _resolveRecipes(
      axes: next,
      previous: previous,
      tags: tags,
      now: now,
    );
    return MoeStateSnapshot(
      baselines: previous.baselines,
      current: next,
      recipes: resolved,
      updatedAt: now,
      policyVersion: moePolicyVersion,
      expressionMode: previous.expressionMode,
    );
  }

  MoeExpressionPlan expressionPlan(MoeStateSnapshot state) {
    if (!state.enabled) {
      return MoeExpressionPlan.neutral(expressionMode: state.expressionMode);
    }
    final active = state.recipes.entries
        .where((entry) => entry.value.active)
        .toList()
      ..sort((a, b) {
        final byStrength = b.value.strength.compareTo(a.value.strength);
        return byStrength != 0 ? byStrength : a.key.index.compareTo(b.key.index);
      });
    if (active.isEmpty) {
      return MoeExpressionPlan.neutral(expressionMode: state.expressionMode);
    }
    final primary = active.first.key;
    MoeRecipe? secondary;
    for (final candidate in active.skip(1)) {
      if (candidate.value.strength >= active.first.value.strength * 0.70 &&
          _compatible(primary, candidate.key)) {
        secondary = candidate.key;
        break;
      }
    }
    final selected = <MoeRecipe>[primary, if (secondary != null) secondary];
    return MoeExpressionPlan(
      expressionMode: state.expressionMode,
      primary: primary,
      secondary: secondary,
      visibleStrengths: {
        for (final recipe in selected)
          recipe: _visibleStrength(
            state.recipes[recipe]?.strength ?? 0,
            state.expressionMode,
          ),
      },
      styleDirectives: selected.map(_directive).toList(growable: false),
      safetyDirectives: const [
        '只改变文字表现，不改变事实、边界、决定或现实行动。',
        '没有对应情境证据时，不凭空表演强烈属性。',
      ],
    );
  }

  double _returnRate(MoeAxis axis) => switch (axis) {
        MoeAxis.closenessBid || MoeAxis.bashfulInhibition => 0.24,
        MoeAxis.defensiveMask || MoeAxis.strategicSubtext => 0.32,
        _ => 0.42,
      };

  void _applyBoundedCoupling(
    Map<MoeAxis, double> values,
    Map<MoeAxis, double> pulses,
  ) {
    void add(MoeAxis target, double amount) {
      values[target] = clampMoeValue((values[target] ?? 0) + amount.clamp(-6.0, 6.0));
    }

    add(MoeAxis.cuteDisplay, (pulses[MoeAxis.closenessBid] ?? 0) * 0.10);
    add(MoeAxis.flusteredBumble, (pulses[MoeAxis.bashfulInhibition] ?? 0) * 0.12);
    add(MoeAxis.verbalSpice, (pulses[MoeAxis.playfulImpulse] ?? 0) * 0.07);
    add(MoeAxis.strategicSubtext, (pulses[MoeAxis.playfulImpulse] ?? 0) * 0.06);
    add(MoeAxis.closenessBid, (pulses[MoeAxis.defensiveMask] ?? 0) * 0.04);
  }

  Map<MoeRecipe, MoeRecipeStatus> _resolveRecipes({
    required Map<MoeAxis, double> axes,
    required MoeStateSnapshot previous,
    required Set<String> tags,
    required DateTime now,
  }) {
    final result = <MoeRecipe, MoeRecipeStatus>{};
    for (final recipe in MoeRecipe.values) {
      final old = previous.recipes[recipe] ?? const MoeRecipeStatus();
      final contextReady = _contextTags(recipe).any(tags.contains);
      final raw = _score(recipe, axes);
      // A named trope is not treated as factual without a matching context.
      final grounded = contextReady ? raw : math.min(raw, entryThreshold - 7.0);
      final cooling = old.cooldownUntil?.isAfter(now) ?? false;
      final active = old.active
          ? grounded >= exitThreshold
          : !cooling && contextReady && grounded >= entryThreshold;
      if (active) {
        result[recipe] = MoeRecipeStatus(
          strength: grounded,
          active: true,
          enteredAt: old.active ? old.enteredAt : now,
          exitedAt: old.exitedAt,
          cooldownUntil: null,
        );
      } else if (old.active) {
        result[recipe] = MoeRecipeStatus(
          strength: math.min(grounded, exitThreshold - 1.0),
          exitedAt: now,
          cooldownUntil: now.add(cooldown),
        );
      } else {
        final afterglow = cooling ? math.min(old.strength * 0.72, exitThreshold - 1.0) : grounded;
        result[recipe] = MoeRecipeStatus(
          strength: clampMoeValue(afterglow),
          enteredAt: old.enteredAt,
          exitedAt: old.exitedAt,
          cooldownUntil: old.cooldownUntil,
        );
      }
    }
    return result;
  }

  double _score(MoeRecipe recipe, Map<MoeAxis, double> v) {
    double axis(MoeAxis key) => v[key] ?? key.defaultBaseline;
    final score = switch (recipe) {
      MoeRecipe.tsundere =>
        axis(MoeAxis.defensiveMask) * .46 + axis(MoeAxis.verbalSpice) * .24 + axis(MoeAxis.closenessBid) * .30,
      MoeRecipe.sharpTongue =>
        axis(MoeAxis.verbalSpice) * .58 + axis(MoeAxis.unfilteredDirectness) * .24 + axis(MoeAxis.strategicSubtext) * .18,
      MoeRecipe.cuteDisplay =>
        axis(MoeAxis.cuteDisplay) * .60 + axis(MoeAxis.playfulImpulse) * .25 + axis(MoeAxis.flusteredBumble) * .15,
      MoeRecipe.coaxing =>
        axis(MoeAxis.closenessBid) * .55 + axis(MoeAxis.cuteDisplay) * .27 + axis(MoeAxis.bashfulInhibition) * .18,
      MoeRecipe.shy =>
        axis(MoeAxis.bashfulInhibition) * .62 + axis(MoeAxis.flusteredBumble) * .25 + axis(MoeAxis.closenessBid) * .13,
      MoeRecipe.goofyCute =>
        axis(MoeAxis.flusteredBumble) * .60 + axis(MoeAxis.playfulImpulse) * .25 + axis(MoeAxis.cuteDisplay) * .15,
      MoeRecipe.naturalDirect =>
        axis(MoeAxis.unfilteredDirectness) * .68 + axis(MoeAxis.closenessBid) * .17 + axis(MoeAxis.cuteDisplay) * .15,
      MoeRecipe.blackBelly =>
        axis(MoeAxis.strategicSubtext) * .55 + axis(MoeAxis.playfulImpulse) * .27 + axis(MoeAxis.unfilteredDirectness) * .18,
      MoeRecipe.prankster =>
        axis(MoeAxis.playfulImpulse) * .55 + axis(MoeAxis.strategicSubtext) * .27 + axis(MoeAxis.verbalSpice) * .18,
    };
    return clampMoeValue(score);
  }

  Set<String> _contextTags(MoeRecipe recipe) => switch (recipe) {
        MoeRecipe.tsundere => const {'care_exposed', 'concern', 'affection_exposed'},
        MoeRecipe.sharpTongue => const {'safe_teasing', 'real_flaw', 'boundary_displeasure'},
        MoeRecipe.cuteDisplay => const {'play', 'celebration', 'softening'},
        MoeRecipe.coaxing => const {'seeking_closeness', 'seeking_care'},
        MoeRecipe.shy => const {'praised', 'intimacy_exposed', 'sensitive_topic'},
        MoeRecipe.goofyCute => const {'surprise', 'confusion', 'small_mistake'},
        MoeRecipe.naturalDirect => const {'honest_disclosure', 'clear_affection'},
        MoeRecipe.blackBelly => const {'harmless_plot', 'safe_teasing'},
        MoeRecipe.prankster => const {'playful_prank', 'safe_teasing'},
      };

  bool _compatible(MoeRecipe a, MoeRecipe b) {
    const conflicts = <Set<MoeRecipe>>[
      {MoeRecipe.tsundere, MoeRecipe.naturalDirect},
      {MoeRecipe.shy, MoeRecipe.sharpTongue},
      {MoeRecipe.cuteDisplay, MoeRecipe.sharpTongue},
      {MoeRecipe.coaxing, MoeRecipe.sharpTongue},
    ];
    return !conflicts.any((pair) => pair.contains(a) && pair.contains(b));
  }

  double _visibleStrength(double value, MoeExpressionMode mode) => switch (mode) {
        MoeExpressionMode.natural => (value * .82).clamp(0.0, 100.0).toDouble(),
        MoeExpressionMode.obvious => value.clamp(55.0, 100.0).toDouble(),
        MoeExpressionMode.manga => (value * 1.15).clamp(68.0, 100.0).toDouble(),
      };

  String _directive(MoeRecipe recipe) => switch (recipe) {
        MoeRecipe.tsundere => '先短暂嘴硬，再让真实关心清楚落地。',
        MoeRecipe.sharpTongue => '可以有锋利吐槽，但只针对已知情境，不贬低人格。',
        MoeRecipe.cuteDisplay => '用清楚可感的可爱语气和小幅俏皮表达。',
        MoeRecipe.coaxing => '直接表达想靠近或被在意，不用暗中施压。',
        MoeRecipe.shy => '允许停顿和不好意思，但不要故意含糊关键事实。',
        MoeRecipe.goofyCute => '把小慌乱或小失误写得鲜活，不装傻逃避责任。',
        MoeRecipe.naturalDirect => '把喜欢、在意或判断直接说清楚。',
        MoeRecipe.blackBelly => '只用无害的小聪明和轻微反转；不欺骗、不操纵、不制造现实后果。',
        MoeRecipe.prankster => '做可随时收回的文字小玩笑，立刻尊重不适反馈。',
      };
}
