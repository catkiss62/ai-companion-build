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
        '萌属性只读取已提交的状态，不写入 Desire、关系、情绪或规则系统。',
        '没有对应情境信号时保持自然，不机械报出属性名称。',
      ],
    );
  }

  /// Read-only projection used immediately before a prompt is built. It fixes
  /// the former first-turn-after-silence bug without writing a synthetic Moe
  /// event or changing ownership of the persisted D2 state.
  MoeStateSnapshot projectForPrompt({
    required MoeStateSnapshot previous,
    required DateTime now,
  }) {
    if (!previous.enabled) return previous;
    final elapsedHours = now
        .difference(previous.updatedAt)
        .inMilliseconds
        .clamp(0, const Duration(hours: 72).inMilliseconds) /
        const Duration(hours: 1).inMilliseconds;
    final axes = <MoeAxis, double>{};
    for (final axis in MoeAxis.values) {
      final baseline = previous.baselines[axis] ?? axis.defaultBaseline;
      final current = previous.current[axis] ?? baseline;
      final retention = math.exp(-_returnRate(axis) * elapsedHours);
      axes[axis] = clampMoeValue(
        baseline + (current - baseline) * retention,
      );
    }
    final stale = elapsedHours >= 6.0;
    final recipes = <MoeRecipe, MoeRecipeStatus>{};
    for (final recipe in MoeRecipe.values) {
      final old = previous.recipes[recipe] ?? const MoeRecipeStatus();
      final strength = math.min(
        _score(recipe, axes),
        old.strength * math.exp(-0.30 * elapsedHours),
      );
      recipes[recipe] = MoeRecipeStatus(
        strength: clampMoeValue(strength),
        active: old.active && !stale && strength >= 24.0,
        enteredAt: old.enteredAt,
        exitedAt: old.exitedAt,
        cooldownUntil: old.cooldownUntil,
      );
    }
    return MoeStateSnapshot(
      baselines: previous.baselines,
      current: axes,
      recipes: recipes,
      // Preserve the committed timestamp. Consumers use it to identify which
      // durable state supplied this read-only projection.
      updatedAt: previous.updatedAt,
      policyVersion: previous.policyVersion,
      expressionMode: previous.expressionMode,
    );
  }

  MoeExpressionPlan expressionPlanForTurn(
    MoeStateSnapshot state, {
    Set<String> contextTags = const <String>{},
    bool allowAfterglow = true,
    MoeRecipe? recentPrimary,
    int recentPrimaryRun = 0,
    int selectionSeed = 0,
    double selectionUnit = 0.0,
    double neutralUnit = 1.0,
    double intensityUnit = 0.5,
  }) {
    if (!state.enabled) {
      return MoeExpressionPlan.neutral(expressionMode: state.expressionMode);
    }
    final candidates = <({
      MoeRecipe recipe,
      double strength,
      bool contextReady,
      double weight,
    })>[];
    for (final recipe in MoeRecipe.values) {
      final status = state.recipes[recipe] ?? const MoeRecipeStatus();
      final contextReady = _contextTags(recipe).any(contextTags.contains);
      final scored = _score(recipe, state.current);
      final afterglowReady = allowAfterglow && status.active;
      if (!(contextReady && scored >= entryThreshold - 8.0) &&
          !afterglowReady) {
        continue;
      }
      final strength = contextReady
          ? math.max(scored, status.strength)
          : status.strength;
      var weight = 0.45 + strength / 100.0;
      if (recipe == recentPrimary) {
        weight *= recentPrimaryRun >= 2 ? 0.30 : 0.58;
      }
      candidates.add((
        recipe: recipe,
        strength: strength,
        contextReady: contextReady,
        weight: weight,
      ));
    }
    if (candidates.isEmpty) {
      return MoeExpressionPlan.neutral(expressionMode: state.expressionMode);
    }
    final contextual = candidates
        .where((candidate) => candidate.contextReady)
        .toList(growable: false);
    // A real current-turn context outranks a leftover afterglow. Afterglow is
    // considered only when no currently grounded recipe is available.
    final eligible = contextual.isNotEmpty ? contextual : candidates;
    eligible.sort((a, b) {
      final byWeight = b.weight.compareTo(a.weight);
      return byWeight != 0
          ? byWeight
          : a.recipe.index.compareTo(b.recipe.index);
    });
    final hasContext = contextual.isNotEmpty;
    final neutralChance = hasContext ? 0.08 : 0.20;
    if (neutralUnit.clamp(0.0, 1.0) < neutralChance &&
        eligible.first.strength < 76.0) {
      return MoeExpressionPlan(
        expressionMode: state.expressionMode,
        primary: null,
        secondary: null,
        visibleStrengths: const {},
        styleDirectives: const [],
        safetyDirectives: const ['萌属性保持只读呈现，不调用工具或改写其他系统。'],
        neutral: true,
        selectionSeed: selectionSeed,
        candidateCount: eligible.length,
        contextGrounded: hasContext,
        afterglowOnly: !hasContext,
      );
    }
    final total = eligible.fold<double>(
      0.0,
      (sum, value) => sum + value.weight,
    );
    var cursor = selectionUnit.clamp(0.0, 0.999999999) * total;
    var selected = eligible.first;
    for (final candidate in eligible) {
      cursor -= candidate.weight;
      if (cursor < 0) {
        selected = candidate;
        break;
      }
    }
    final intensityJitter =
        ((intensityUnit.clamp(0.0, 1.0) - 0.5) * 8.0).toDouble();
    final compatible = eligible
        .where(
          (candidate) =>
              candidate.recipe != selected.recipe &&
              candidate.strength >= selected.strength * 0.76 &&
              _compatible(selected.recipe, candidate.recipe),
        )
        .toList(growable: false);
    final secondary = compatible.isNotEmpty &&
            ((selectionUnit * 997.0) % 1.0) >= 0.62
        ? compatible.first.recipe
        : null;
    final chosen = <MoeRecipe>[
      selected.recipe,
      if (secondary != null) secondary,
    ];
    return MoeExpressionPlan(
      expressionMode: state.expressionMode,
      primary: selected.recipe,
      secondary: secondary,
      visibleStrengths: {
        for (final recipe in chosen)
          recipe: (_visibleStrength(
                    state.recipes[recipe]?.strength ??
                        _score(recipe, state.current),
                    state.expressionMode,
                  ) +
                  intensityJitter)
              .clamp(0.0, 100.0)
              .toDouble(),
      },
      styleDirectives: chosen.map(_directive).toList(growable: false),
      safetyDirectives: const [
        '萌属性只读取已提交的状态，不写入 Desire、关系、情绪或规则系统。',
        '没有对应情境信号时保持自然，不机械报出属性名称。',
      ],
      selectionSeed: selectionSeed,
      candidateCount: eligible.length,
      contextGrounded: selected.contextReady,
      afterglowOnly: !hasContext,
      intensityJitter: intensityJitter,
    );
  }

  static Set<String> contextTagsForUserText(String raw) {
    final text = raw.replaceAll(RegExp(r'\s+'), '');
    if (text.isEmpty) return const <String>{};
    final tags = <String>{};
    if (RegExp(r'(爱你|喜欢你|想你|抱抱|亲亲|宝贝|老婆)').hasMatch(text)) {
      tags.addAll(const {
        'clear_affection',
        'seeking_closeness',
        'intimacy_exposed',
      });
    }
    if (RegExp(r'(你好棒|真棒|厉害|可爱|漂亮|聪明|好乖|夸夸)').hasMatch(text)) {
      tags.addAll(const {'praised', 'softening'});
    }
    if (RegExp(r'(哈哈|嘿嘿|逗你|骗你的|开玩笑|捉弄|调皮|坏蛋|笨蛋|玩一下)').hasMatch(text)) {
      tags.addAll(const {
        'play',
        'playful_prank',
        'playful_plot',
        'expressive_teasing',
      });
    }
    if (RegExp(r'(怎么了|没事吧|累不累|困了吗|早点休息|担心你|照顾好)').hasMatch(text)) {
      tags.addAll(const {'concern', 'care_exposed', 'seeking_care'});
    }
    if (RegExp(r'(不对|不同意|才不是|胡说|别闹|讨厌你|闭嘴)').hasMatch(text)) {
      tags.addAll(const {'assertive_response', 'real_flaw'});
    }
    if (RegExp(r'(什么情况|为什么|怎么会|没懂|不明白)').hasMatch(text)) {
      tags.addAll(const {'confusion', 'surprise'});
    }
    if (RegExp(r'(其实|我觉得|我想告诉你|认真说|说真的)').hasMatch(text)) {
      tags.add('honest_disclosure');
    }
    return tags;
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
          ? contextReady && grounded >= exitThreshold
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
        MoeRecipe.sharpTongue => const {'expressive_teasing', 'real_flaw', 'assertive_response'},
        MoeRecipe.cuteDisplay => const {'play', 'celebration', 'softening'},
        MoeRecipe.coaxing => const {'seeking_closeness', 'seeking_care'},
        MoeRecipe.shy => const {'praised', 'intimacy_exposed', 'sensitive_topic'},
        MoeRecipe.goofyCute => const {'surprise', 'confusion', 'small_mistake'},
        MoeRecipe.naturalDirect => const {'honest_disclosure', 'clear_affection'},
        MoeRecipe.blackBelly => const {'playful_plot', 'expressive_teasing'},
        MoeRecipe.prankster => const {'playful_prank', 'expressive_teasing'},
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
        MoeRecipe.sharpTongue => '允许锋利、鲜明、有来有回的吐槽，不必自动软化语气。',
        MoeRecipe.cuteDisplay => '用清楚可感的可爱语气和小幅俏皮表达。',
        MoeRecipe.coaxing => '直接表达想靠近、想被在意或想继续互动。',
        MoeRecipe.shy => '允许停顿、不好意思和欲言又止，让反应更鲜活。',
        MoeRecipe.goofyCute => '把小慌乱、小失误或反应慢半拍写得鲜活。',
        MoeRecipe.naturalDirect => '把喜欢、在意或判断直接说清楚。',
        MoeRecipe.blackBelly => '允许带小聪明、藏话和反转感的腹黑表达。',
        MoeRecipe.prankster => '允许更主动的文字玩笑、捉弄和出其不意。',
      };
}
