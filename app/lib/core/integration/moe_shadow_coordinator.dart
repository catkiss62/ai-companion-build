import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../database/conversation_source_store.dart';
import '../models/chat_message.dart';
import '../moe/application/moe_dynamics_policy.dart';
import '../moe/domain/moe_models.dart';
import '../moe/domain/moe_observation.dart';
import '../moe/infrastructure/sqlite_moe_repository.dart';
import 'moe_input_adapter.dart';

export '../moe/domain/moe_observation.dart';

/// Fail-open observer of committed facts; it does not own the chat reply.
class MoeShadowCoordinator {
  MoeShadowCoordinator(this.db, {
    MoeInputAdapter adapter = const MoeInputAdapter(),
    MoeDynamicsPolicy policy = const MoeDynamicsPolicy(),
    this.beforeInput,
    this.observationTimeout = const Duration(seconds: 3),
  }) : _adapter = adapter, _policy = policy,
       _repository = SqliteMoeRepository(() => db.database);

  static const scanKey = 'moe_shadow_scan_v1';
  static const pageSize = 120;
  final AppDatabase db;
  final MoeInputAdapter _adapter;
  final MoeDynamicsPolicy _policy;
  final SqliteMoeRepository _repository;
  /// Optional dependency barrier; persistence and policy remain real in tests.
  final Future<void> Function(ChatMessage message)? beforeInput;
  final Duration observationTimeout;

  Future<MoeObservationResult> observeCompletedTurn(ChatMessage assistant, {
    required BrainWorkFence originalFence,
    required ConversationSourceStamp committedSource,
  }) async {
    if (!assistant.isAssistant || committedSource.id != assistant.id) {
      return const MoeObservationResult(MoeObservationStatus.rejected);
    }
    try {
      final handle = await db.database;
      final source = await handle.transaction((txn) async {
        if (!await originalFence.matches(txn) || !await committedSource.matchesCapturedVersion(txn)) return null;
        final captured = await _capture(txn, assistant.id);
        // The committed caller's actual adapter input cannot be refreshed.
        if (captured?.message.emotionKey != assistant.emotionKey) return null;
        return captured;
      }).timeout(observationTimeout);
      if (source == null) return const MoeObservationResult(MoeObservationStatus.rejected);
      return _observe(source, originalFence);
    } catch (_) {
      return const MoeObservationResult(MoeObservationStatus.failed);
    }
  }

  Future<_MoeSource?> _capture(DatabaseExecutor txn, String id) async {
    final rows = await txn.query('messages', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _MoeSource(rows.single, await ConversationSourceStore.qualifyMessage(txn, id));
  }

  Future<MoeObservationResult> _observe(_MoeSource source, BrainWorkFence fence, {
    _MoeScanCursor? cursor,
  }) async {
    var current = true;
    Future<bool> validate(DatabaseExecutor txn) async =>
        current && await fence.matches(txn) && await source.matches(txn) &&
        (cursor == null || await BrainWorkFence.value(txn, scanKey) == cursor.expected);
    Future<MoeObservationResult> work() async {
      final message = source.message;
      final excluded = !message.isAssistant || source.qualified?.eligibility == ConversationSourceEligibility.roleplay ||
          (cursor != null && (cursor.legacyCovers(source) ||
            // Legacy same-millisecond order cannot become reliable by waiting.
            // Its real qualification writers requeue it if the inputs change.
            source.qualified?.reason == 'legacy_pair_order_unknown'));
      if (!excluded && source.qualified?.isOrdinary != true) {
        return const MoeObservationResult(MoeObservationStatus.rejected);
      }
      MoeInputSnapshot? input;
      if (!excluded) {
        await beforeInput?.call(message);
        input = _adapter.fromCompletedTurn(assistant: message, desire: await db.loadDesire(),
          relationshipDay: (await db.relationshipAge(now: message.createdAt)).dayNumber,
          personalityTrial: await db.activePersonalityTrial(now: message.createdAt),
          specialStyleTrial: await db.activeSpecialStyleTrial(now: message.createdAt));
      }
      return _repository.commitObservation(event: input?.event,
        isCurrent: () => current, validate: validate,
        advance: (previous) => _policy.advance(previous: previous, input: input!, now: message.createdAt),
        writeAccepted: (txn, state) async {
          if (state != null) {
            final plan = _policy.expressionPlan(state);
            await _writeSettings(txn, {
              'moe_shadow_last_observed_at': message.createdAt.millisecondsSinceEpoch.toString(),
              'moe_shadow_last_message_id': message.id,
              'moe_shadow_last_primary': plan.primary?.key ?? '',
              'moe_shadow_status': 'healthy', 'moe_shadow_last_error_category': '',
            });
          }
          if (cursor != null) {
            await _writeSettings(txn, {scanKey: cursor.advance(source.seq).encode()});
          }
        });
    }
    try {
      return await work().timeout(observationTimeout, onTimeout: () {
        current = false;
        return const MoeObservationResult(MoeObservationStatus.failed);
      });
    } catch (error) {
      // A stale source/epoch cannot write even a health diagnostic. Failure
      // does not consume scan position; retry sees the same durable material.
      try {
        final handle = await db.database;
        await handle.transaction((txn) async {
          if (!await validate(txn)) return;
          await _writeSettings(txn, {'moe_shadow_status': 'degraded',
            'moe_shadow_last_error_category': error.runtimeType.toString()});
        });
      } catch (_) { /* Observation must never fail delivery. */ }
      return const MoeObservationResult(MoeObservationStatus.failed);
    } finally {
      current = false;
    }
  }

  /// A direct observation never advances this scan cursor. Each bounded scan
  /// consumes only accepted/known-excluded rows under its original fence.
  Future<void> reconcileRecentCommittedTurns() async {
    try {
      final handle = await db.database;
      final prepared = await handle.transaction((txn) async {
        final fence = await db.captureBrainWorkFenceInTransaction(txn);
        if (fence == null) return null;
        final raw = await BrainWorkFence.value(txn, scanKey);
        if (raw.isNotEmpty) {
          final cursor = _MoeScanCursor.decode(raw);
          return cursor == null ? null : (fence: fence, cursor: cursor, initialized: false);
        }
        final maximum = Sqflite.firstIntValue(await txn.rawQuery('SELECT MAX(source_ingest_seq) FROM messages')) ?? 0;
        final legacy = int.tryParse(await BrainWorkFence.value(txn, 'moe_shadow_reconciled_at'));
        final now = DateTime.now().millisecondsSinceEpoch;
        final cursor = _MoeScanCursor(after: legacy == null ? maximum : 0,
          legacyCutoff: legacy, legacyCeiling: legacy == null ? null : maximum);
        await _writeSettings(txn, {scanKey: cursor.encode(),
          if (legacy == null) 'moe_shadow_started_at': '$now',
          if (legacy == null) 'moe_shadow_reconciled_at': '$now',
          'moe_shadow_status': 'ready'});
        return (fence: fence, cursor: cursor, initialized: legacy == null);
      });
      if (prepared == null || prepared.initialized) return;
      var cursor = prepared.cursor;
      final sources = await handle.transaction((txn) async {
        if (!await prepared.fence.matches(txn) || await BrainWorkFence.value(txn, scanKey) != cursor.expected) {
          return const <_MoeSource>[];
        }
        final rows = await txn.query('messages', where: 'source_ingest_seq > ?',
          whereArgs: [cursor.after], orderBy: 'source_ingest_seq ASC', limit: pageSize);
        return [for (final row in rows) _MoeSource(row,
          await ConversationSourceStore.qualifyMessage(txn, row['id'] as String))];
      });
      for (final source in sources) {
        final result = await _observe(source, prepared.fence, cursor: cursor);
        if (!result.consumed) return;
        cursor = cursor.advance(source.seq);
      }
    } catch (_) { /* Recovery remains bounded and retryable at the saved cursor. */ }
  }

  static Future<void> _writeSettings(DatabaseExecutor txn, Map<String, String> values) async {
    for (final entry in values.entries) {
      await txn.insert('settings', {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}

class _MoeSource {
  _MoeSource(this.row, this.qualified) : message = ChatMessage.fromDb(row);
  final Map<String, Object?> row;
  final QualifiedConversationSource? qualified;
  final ChatMessage message;
  int get seq => (row['source_ingest_seq'] as num?)?.toInt() ?? 0;
  Future<bool> matches(DatabaseExecutor txn) async {
    if (seq <= 0 || (qualified != null && !await qualified!.matches(txn))) return false;
    final current = await txn.query('messages', where: 'id = ?', whereArgs: [message.id], limit: 1);
    if (current.isEmpty || current.single['source_ingest_seq'] != seq ||
        (current.single['emotion_key'] ?? '') != message.emotionKey) return false;
    // Non-message/system rows cannot carry a qualified stamp, but an exclusion
    // still consumes only the exact row that was actually inspected.
    return qualified != null || jsonEncode(current.single) == jsonEncode(row);
  }
}

class _MoeScanCursor {
  const _MoeScanCursor({required this.after, this.legacyCutoff, this.legacyCeiling, this.raw});
  final int after;
  final String? raw;
  String get expected => raw ?? encode();
  final int? legacyCutoff, legacyCeiling;
  bool legacyCovers(_MoeSource source) => legacyCutoff != null && legacyCeiling != null &&
      source.seq <= legacyCeiling! && source.message.createdAt.millisecondsSinceEpoch <= legacyCutoff!;
  _MoeScanCursor advance(int seq) => _MoeScanCursor(after: seq,
    legacyCutoff: legacyCutoff, legacyCeiling: legacyCeiling);
  String encode() => jsonEncode({'schema': 1, 'after_seq': after,
    'legacy_cutoff': legacyCutoff, 'legacy_ceiling': legacyCeiling});
  static _MoeScanCursor? decode(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data['schema'] != 1 || data['after_seq'] is! int || data['after_seq'] < 0 ||
          (data['legacy_cutoff'] != null && data['legacy_cutoff'] is! int) ||
          (data['legacy_ceiling'] != null && data['legacy_ceiling'] is! int) ||
          (data['legacy_cutoff'] == null) != (data['legacy_ceiling'] == null)) return null;
      return _MoeScanCursor(after: data['after_seq'] as int,
        legacyCutoff: data['legacy_cutoff'] as int?, legacyCeiling: data['legacy_ceiling'] as int?, raw: raw);
    } catch (_) { return null; }
  }
}
