import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/moe_models.dart';
import 'moe_repository.dart';

/// SQLite adapter owned by the Moe module.
///
/// A database provider is injected so this file never imports AppDatabase or
/// any other domain's persistence implementation.
class SqliteMoeRepository implements MoeRepository {
  const SqliteMoeRepository(this._databaseProvider);

  final Future<Database> Function() _databaseProvider;

  @override
  Future<MoeExpressionMode> loadExpressionMode() async {
    try {
      final db = await _databaseProvider();
      final rows = await db.query('moe_config', where: 'id = 1', limit: 1);
      if (rows.isEmpty) return MoeExpressionMode.obvious;
      return moeExpressionModeFromKey(rows.first['expression_mode']?.toString());
    } catch (_) {
      return MoeExpressionMode.obvious;
    }
  }

  @override
  Future<MoeStateSnapshot> loadState() async {
    final now = DateTime.now();
    try {
      return _loadStateFrom(await _databaseProvider(), now);
    } catch (_) {
      return MoeStateSnapshot.neutral(
        now: now,
        expressionMode: MoeExpressionMode.obvious,
      );
    }
  }

  Future<MoeStateSnapshot> _loadStateFrom(
    DatabaseExecutor executor,
    DateTime now,
  ) async {
    final configRows =
        await executor.query('moe_config', where: 'id = 1', limit: 1);
    final config =
        configRows.isEmpty ? const <String, Object?>{} : configRows.first;
    final mode =
        moeExpressionModeFromKey(config['expression_mode']?.toString());
    if (config['enabled'] == 0) {
      return MoeStateSnapshot.neutral(now: now, expressionMode: mode);
    }

    final axisRows = await executor.query('moe_axis_state');
    if (axisRows.isEmpty) {
      return MoeStateSnapshot.initial(now: now, expressionMode: mode);
    }
    final baselines = <MoeAxis, double>{};
    final current = <MoeAxis, double>{};
    var updatedAt = 0;
    var policyVersion = moePolicyVersion;
    for (final row in axisRows) {
      final axis = moeAxisFromKey(row['axis_key']?.toString() ?? '');
      if (axis == null) continue;
      baselines[axis] =
          clampMoeValue((row['baseline'] as num?) ?? axis.defaultBaseline);
      current[axis] = clampMoeValue(
        (row['current_value'] as num?) ?? baselines[axis]!,
      );
      updatedAt = mathMax(
        updatedAt,
        (row['updated_at'] as num?)?.toInt() ?? 0,
      );
      policyVersion =
          (row['policy_version'] as num?)?.toInt() ?? policyVersion;
    }

    final recipeRows = await executor.query('moe_recipe_state');
    final recipes = <MoeRecipe, MoeRecipeStatus>{};
    DateTime? date(Object? value) => value is num
        ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
        : null;
    for (final row in recipeRows) {
      final recipe = moeRecipeFromKey(row['recipe_key']?.toString() ?? '');
      if (recipe == null) continue;
      recipes[recipe] = MoeRecipeStatus(
        strength: clampMoeValue((row['strength'] as num?) ?? 0),
        active: row['active'] == 1,
        enteredAt: date(row['entered_at']),
        exitedAt: date(row['exited_at']),
        cooldownUntil: date(row['cooldown_until']),
      );
      updatedAt = mathMax(
        updatedAt,
        (row['updated_at'] as num?)?.toInt() ?? 0,
      );
    }
    return MoeStateSnapshot(
      baselines: baselines,
      current: current,
      recipes: recipes,
      updatedAt: updatedAt == 0
          ? now
          : DateTime.fromMillisecondsSinceEpoch(updatedAt),
      policyVersion: policyVersion,
      expressionMode: mode,
    );
  }

  @override
  Future<void> saveState(MoeStateSnapshot state) async {
    final db = await _databaseProvider();
    await db.transaction((txn) => _saveStateTo(txn, state));
  }

  Future<void> _saveStateTo(
    DatabaseExecutor executor,
    MoeStateSnapshot state,
  ) async {
    for (final axis in MoeAxis.values) {
      await executor.insert(
        'moe_axis_state',
        {
          'axis_key': axis.key,
          'baseline': state.baselines[axis] ?? axis.defaultBaseline,
          'current_value': state.current[axis] ?? axis.defaultBaseline,
          'updated_at': state.updatedAt.millisecondsSinceEpoch,
          'policy_version': state.policyVersion,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final recipe in MoeRecipe.values) {
      final value = state.recipes[recipe] ?? const MoeRecipeStatus();
      await executor.insert(
        'moe_recipe_state',
        {
          'recipe_key': recipe.key,
          'strength': clampMoeValue(value.strength),
          'active': value.active ? 1 : 0,
          'entered_at': value.enteredAt?.millisecondsSinceEpoch,
          'exited_at': value.exitedAt?.millisecondsSinceEpoch,
          'cooldown_until': value.cooldownUntil?.millisecondsSinceEpoch,
          'updated_at': state.updatedAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await executor.insert(
      'moe_config',
      {
        'id': 1,
        'enabled': state.enabled ? 1 : 0,
        'expression_mode': state.expressionMode.key,
        'contract_version': moeContractVersion,
        'policy_version': state.policyVersion,
        'updated_at': state.updatedAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, Object?> _eventRow(MoeObservedEvent event) => {
        'idempotency_key': event.idempotencyKey,
        'source_type': event.sourceType,
        'cause_tag': event.causeTag,
        'pulses_json': jsonEncode({
          for (final entry in event.axisPulses.entries)
            entry.key.key: entry.value,
        }),
        'context_tags_json': jsonEncode(event.contextTags.toList()..sort()),
        'occurred_at': event.occurredAt.millisecondsSinceEpoch,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

  @override
  Future<bool> recordEventIfNew(MoeObservedEvent event) async {
    final db = await _databaseProvider();
    final inserted = await db.insert(
      'moe_events',
      _eventRow(event),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return inserted > 0;
  }

  @override
  Future<MoeStateSnapshot> advanceEventIfNew(
    MoeObservedEvent event, {
    required MoeStateSnapshot Function(MoeStateSnapshot previous) advance,
  }) async {
    final db = await _databaseProvider();
    return db.transaction((txn) async {
      final inserted = await txn.insert(
        'moe_events',
        _eventRow(event),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final previous = await _loadStateFrom(txn, event.occurredAt);
      if (inserted <= 0) return previous;
      final next = advance(previous);
      await _saveStateTo(txn, next);
      return next;
    });
  }

  @override
  Future<void> setExpressionMode(MoeExpressionMode mode) async {
    final db = await _databaseProvider();
    await db.insert(
      'moe_config',
      {
        'id': 1,
        'enabled': 1,
        'expression_mode': mode.key,
        'contract_version': moeContractVersion,
        'policy_version': moePolicyVersion,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

int mathMax(int a, int b) => a > b ? a : b;
