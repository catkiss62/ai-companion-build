/// Independent, versioned domain types for the dynamic moe-attribute engine.
///
/// This file intentionally imports no Desire, relationship, prompt, emotion,
/// TTS, tool, or proactive-action implementation.
const int moeContractVersion = 1;
const int moePolicyVersion = 1;

double clampMoeValue(num value) => value.toDouble().clamp(0.0, 100.0).toDouble();

enum MoeAxis {
  defensiveMask,
  verbalSpice,
  closenessBid,
  playfulImpulse,
  cuteDisplay,
  bashfulInhibition,
  unfilteredDirectness,
  strategicSubtext,
  flusteredBumble,
}

extension MoeAxisMetadata on MoeAxis {
  String get key => switch (this) {
        MoeAxis.defensiveMask => 'defensive_mask',
        MoeAxis.verbalSpice => 'verbal_spice',
        MoeAxis.closenessBid => 'closeness_bid',
        MoeAxis.playfulImpulse => 'playful_impulse',
        MoeAxis.cuteDisplay => 'cute_display',
        MoeAxis.bashfulInhibition => 'bashful_inhibition',
        MoeAxis.unfilteredDirectness => 'unfiltered_directness',
        MoeAxis.strategicSubtext => 'strategic_subtext',
        MoeAxis.flusteredBumble => 'flustered_bumble',
      };

  String get label => switch (this) {
        MoeAxis.defensiveMask => '嘴硬防御',
        MoeAxis.verbalSpice => '言语辛辣',
        MoeAxis.closenessBid => '亲近索求',
        MoeAxis.playfulImpulse => '玩心',
        MoeAxis.cuteDisplay => '可爱展示',
        MoeAxis.bashfulInhibition => '羞涩抑制',
        MoeAxis.unfilteredDirectness => '天然直率',
        MoeAxis.strategicSubtext => '小心思',
        MoeAxis.flusteredBumble => '慌乱笨拙',
      };

  double get defaultBaseline => switch (this) {
        MoeAxis.defensiveMask => 24.0,
        MoeAxis.verbalSpice => 18.0,
        MoeAxis.closenessBid => 32.0,
        MoeAxis.playfulImpulse => 34.0,
        MoeAxis.cuteDisplay => 28.0,
        MoeAxis.bashfulInhibition => 22.0,
        MoeAxis.unfilteredDirectness => 30.0,
        MoeAxis.strategicSubtext => 20.0,
        MoeAxis.flusteredBumble => 18.0,
      };
}

MoeAxis? moeAxisFromKey(String key) {
  for (final axis in MoeAxis.values) {
    if (axis.key == key) return axis;
  }
  return null;
}

enum MoeRecipe {
  tsundere,
  sharpTongue,
  cuteDisplay,
  coaxing,
  shy,
  goofyCute,
  naturalDirect,
  blackBelly,
  prankster,
}

extension MoeRecipeMetadata on MoeRecipe {
  String get key => switch (this) {
        MoeRecipe.tsundere => 'tsundere',
        MoeRecipe.sharpTongue => 'sharp_tongue',
        MoeRecipe.cuteDisplay => 'cute_display',
        MoeRecipe.coaxing => 'coaxing',
        MoeRecipe.shy => 'shy',
        MoeRecipe.goofyCute => 'goofy_cute',
        MoeRecipe.naturalDirect => 'natural_direct',
        MoeRecipe.blackBelly => 'black_belly',
        MoeRecipe.prankster => 'prankster',
      };

  String get label => switch (this) {
        MoeRecipe.tsundere => '傲娇',
        MoeRecipe.sharpTongue => '毒舌',
        MoeRecipe.cuteDisplay => '卖萌',
        MoeRecipe.coaxing => '撒娇',
        MoeRecipe.shy => '害羞',
        MoeRecipe.goofyCute => '呆萌',
        MoeRecipe.naturalDirect => '天然直球',
        MoeRecipe.blackBelly => '腹黑',
        MoeRecipe.prankster => '恶作剧',
      };
}

MoeRecipe? moeRecipeFromKey(String key) {
  for (final recipe in MoeRecipe.values) {
    if (recipe.key == key) return recipe;
  }
  return null;
}

enum MoeExpressionMode { natural, obvious, manga }

extension MoeExpressionModeMetadata on MoeExpressionMode {
  String get key => name;

  String get label => switch (this) {
        MoeExpressionMode.natural => '自然',
        MoeExpressionMode.obvious => '明显',
        MoeExpressionMode.manga => '漫画化',
      };
}

MoeExpressionMode moeExpressionModeFromKey(String? key) {
  for (final mode in MoeExpressionMode.values) {
    if (mode.key == key) return mode;
  }
  return MoeExpressionMode.obvious;
}

class MoeObservedEvent {
  MoeObservedEvent._({
    required this.idempotencyKey,
    required this.sourceType,
    required this.causeTag,
    required this.occurredAt,
    required this.axisPulses,
    required this.contextTags,
  });

  factory MoeObservedEvent({
    required String idempotencyKey,
    required String sourceType,
    required String causeTag,
    required DateTime occurredAt,
    Map<MoeAxis, double> axisPulses = const <MoeAxis, double>{},
    Set<String> contextTags = const <String>{},
  }) {
    if (idempotencyKey.trim().isEmpty ||
        sourceType.trim().isEmpty ||
        causeTag.trim().isEmpty) {
      throw ArgumentError('Moe events require idempotency, source and cause tags.');
    }
    return MoeObservedEvent._(
      idempotencyKey: idempotencyKey.trim(),
      sourceType: sourceType.trim(),
      causeTag: causeTag.trim(),
      occurredAt: occurredAt,
      axisPulses: Map.unmodifiable({
        for (final entry in axisPulses.entries)
          entry.key: entry.value.clamp(-40.0, 40.0).toDouble(),
      }),
      contextTags: Set.unmodifiable(
        contextTags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty),
      ),
    );
  }

  final String idempotencyKey;
  final String sourceType;
  final String causeTag;
  final DateTime occurredAt;
  final Map<MoeAxis, double> axisPulses;
  final Set<String> contextTags;
}

/// Read-only primitive contract supplied by a future adapter.
///
/// Signal keys are deliberately strings so this package never imports another
/// domain's repository, policy, or persistence model.
class MoeInputSnapshot {
  MoeInputSnapshot({
    this.contractVersion = moeContractVersion,
    required this.capturedAt,
    this.relationshipStage = 'unknown',
    Map<String, double> normalizedSignals = const <String, double>{},
    this.event,
  }) : normalizedSignals = Map.unmodifiable({
          for (final entry in normalizedSignals.entries)
            entry.key: entry.value.clamp(0.0, 1.0).toDouble(),
        });

  final int contractVersion;
  final DateTime capturedAt;
  final String relationshipStage;
  final Map<String, double> normalizedSignals;
  final MoeObservedEvent? event;
}

class MoeRecipeStatus {
  const MoeRecipeStatus({
    this.strength = 0.0,
    this.active = false,
    this.enteredAt,
    this.exitedAt,
    this.cooldownUntil,
  });

  final double strength;
  final bool active;
  final DateTime? enteredAt;
  final DateTime? exitedAt;
  final DateTime? cooldownUntil;

  Map<String, Object?> toJson() => {
        'strength': clampMoeValue(strength),
        'active': active,
        'entered_at': enteredAt?.millisecondsSinceEpoch,
        'exited_at': exitedAt?.millisecondsSinceEpoch,
        'cooldown_until': cooldownUntil?.millisecondsSinceEpoch,
      };

  static MoeRecipeStatus fromJson(Object? raw) {
    if (raw is! Map) return const MoeRecipeStatus();
    DateTime? date(Object? value) => value is num
        ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
        : null;
    return MoeRecipeStatus(
      strength: clampMoeValue((raw['strength'] as num?) ?? 0),
      active: raw['active'] == true || raw['active'] == 1,
      enteredAt: date(raw['entered_at']),
      exitedAt: date(raw['exited_at']),
      cooldownUntil: date(raw['cooldown_until']),
    );
  }
}

class MoeStateSnapshot {
  MoeStateSnapshot({
    required Map<MoeAxis, double> baselines,
    required Map<MoeAxis, double> current,
    required Map<MoeRecipe, MoeRecipeStatus> recipes,
    required this.updatedAt,
    this.policyVersion = moePolicyVersion,
    this.expressionMode = MoeExpressionMode.obvious,
    this.enabled = true,
  })  : baselines = Map.unmodifiable({
          for (final axis in MoeAxis.values)
            axis: clampMoeValue(baselines[axis] ?? axis.defaultBaseline),
        }),
        current = Map.unmodifiable({
          for (final axis in MoeAxis.values)
            axis: clampMoeValue(current[axis] ?? baselines[axis] ?? axis.defaultBaseline),
        }),
        recipes = Map.unmodifiable({
          for (final recipe in MoeRecipe.values)
            recipe: recipes[recipe] ?? const MoeRecipeStatus(),
        });

  factory MoeStateSnapshot.initial({
    required DateTime now,
    MoeExpressionMode expressionMode = MoeExpressionMode.obvious,
  }) {
    final baseline = {
      for (final axis in MoeAxis.values) axis: axis.defaultBaseline,
    };
    return MoeStateSnapshot(
      baselines: baseline,
      current: baseline,
      recipes: const {},
      updatedAt: now,
      expressionMode: expressionMode,
    );
  }

  factory MoeStateSnapshot.neutral({
    required DateTime now,
    MoeExpressionMode expressionMode = MoeExpressionMode.obvious,
  }) => MoeStateSnapshot(
        baselines: {for (final axis in MoeAxis.values) axis: axis.defaultBaseline},
        current: {for (final axis in MoeAxis.values) axis: axis.defaultBaseline},
        recipes: const {},
        updatedAt: now,
        expressionMode: expressionMode,
        enabled: false,
      );

  final Map<MoeAxis, double> baselines;
  final Map<MoeAxis, double> current;
  final Map<MoeRecipe, MoeRecipeStatus> recipes;
  final DateTime updatedAt;
  final int policyVersion;
  final MoeExpressionMode expressionMode;
  final bool enabled;

  Map<String, Object?> toJson() => {
        'contract_version': moeContractVersion,
        'policy_version': policyVersion,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'expression_mode': expressionMode.key,
        'enabled': enabled,
        'baselines': {for (final e in baselines.entries) e.key.key: e.value},
        'current': {for (final e in current.entries) e.key.key: e.value},
        'recipes': {for (final e in recipes.entries) e.key.key: e.value.toJson()},
      };

  static MoeStateSnapshot fromJson(Map<String, Object?> json) {
    final updated = (json['updated_at'] as num?)?.toInt();
    final baselineRaw = json['baselines'];
    final currentRaw = json['current'];
    final recipeRaw = json['recipes'];
    final baselines = <MoeAxis, double>{};
    final current = <MoeAxis, double>{};
    final recipes = <MoeRecipe, MoeRecipeStatus>{};
    if (baselineRaw is Map) {
      for (final entry in baselineRaw.entries) {
        final axis = moeAxisFromKey(entry.key.toString());
        if (axis != null && entry.value is num) {
          baselines[axis] = clampMoeValue(entry.value as num);
        }
      }
    }
    if (currentRaw is Map) {
      for (final entry in currentRaw.entries) {
        final axis = moeAxisFromKey(entry.key.toString());
        if (axis != null && entry.value is num) {
          current[axis] = clampMoeValue(entry.value as num);
        }
      }
    }
    if (recipeRaw is Map) {
      for (final entry in recipeRaw.entries) {
        final recipe = moeRecipeFromKey(entry.key.toString());
        if (recipe != null) recipes[recipe] = MoeRecipeStatus.fromJson(entry.value);
      }
    }
    return MoeStateSnapshot(
      baselines: baselines,
      current: current,
      recipes: recipes,
      updatedAt: updated == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(updated),
      policyVersion: (json['policy_version'] as num?)?.toInt() ?? moePolicyVersion,
      expressionMode: moeExpressionModeFromKey(json['expression_mode']?.toString()),
      enabled: json['enabled'] != false && json['enabled'] != 0,
    );
  }
}

/// One-way presentation advice. It cannot schedule behavior or bypass gates.
class MoeExpressionPlan {
  MoeExpressionPlan({
    required this.expressionMode,
    required this.primary,
    required this.secondary,
    required Map<MoeRecipe, double> visibleStrengths,
    required List<String> styleDirectives,
    required List<String> safetyDirectives,
    this.neutral = false,
  })  : visibleStrengths = Map.unmodifiable(visibleStrengths),
        styleDirectives = List.unmodifiable(styleDirectives),
        safetyDirectives = List.unmodifiable(safetyDirectives);

  factory MoeExpressionPlan.neutral({
    MoeExpressionMode expressionMode = MoeExpressionMode.obvious,
  }) => MoeExpressionPlan(
        expressionMode: expressionMode,
        primary: null,
        secondary: null,
        visibleStrengths: const {},
        styleDirectives: const [],
        safetyDirectives: const ['萌属性保持只读呈现，不调用工具或改写其他系统。'],
        neutral: true,
      );

  final MoeExpressionMode expressionMode;
  final MoeRecipe? primary;
  final MoeRecipe? secondary;
  final Map<MoeRecipe, double> visibleStrengths;
  final List<String> styleDirectives;
  final List<String> safetyDirectives;
  final bool neutral;
}
