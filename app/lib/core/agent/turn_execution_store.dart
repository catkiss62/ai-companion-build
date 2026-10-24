import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../database/conversation_source_store.dart';
import '../database/generation_attempt_fence.dart';
import 'turn_execution_contract.dart';
import '../mcp/cedar_game_protocol.dart';

export 'turn_execution_contract.dart';

/// Local goal/acceptance facts. HTTP dispatch and reconciliation are owned by
/// the Cedar executor; this store never interprets a model plan as a result.
class TurnExecutionStore {
  TurnExecutionStore(this.db);
  final AppDatabase db;
  static const remoteEffectPrefix = 'agent_remote_effect_v1:';
  static const remoteJournalPrefix = 'agent_remote_effect_v2:';

  Future<List<Map<String,dynamic>>> remoteHistory(String turnId) async {
    final handle=await db.database;
    final raw=_decode(await BrainWorkFence.value(handle,'$remoteJournalPrefix$turnId'));
    if(raw is List)return raw.whereType<Map>().map((r)=>Map<String,dynamic>.from(r)).toList();
    final legacy=await remoteEffect(turnId);
    return legacy==null ? [] : [legacy];
  }

  /// A fresh same-target snapshot permits a NEW plan, not replay or success
  /// attribution for the original unknown operation. Runs in the game fence.
  static Future<void> reconcileRemoteInTransaction(DatabaseExecutor txn,
      {required String turnId, required Object payload, required String snapshot}) async {
    if (turnId.isEmpty) return;
    final rows = await txn.query('settings', columns: ['key','value'],
      where: 'key = ?', whereArgs: ['$remoteJournalPrefix$turnId']);
    final hash = turnPayloadHash(payload);
    for (final row in rows) {
      final raw = _decode(row['value']?.toString() ?? '');
      if (raw is! List) continue;
      var changed = false;
      for (var i=0; i<raw.length; i++) {
        final receipt = raw[i];
        if (receipt is! Map || receipt['state'] != 'dispatching' || receipt['payload_hash'] != hash) continue;
        raw[i] = {...receipt, 'state':'reconciled', 'goal_satisfied':false,
          'reconciliation_snapshot':snapshot, 'reconciled_at':DateTime.now().millisecondsSinceEpoch};
        changed = true;
      }
      if (changed) await txn.update('settings', {'value':jsonEncode(raw)},
        where:'key = ? AND value = ?', whereArgs:[row['key'],row['value']]);
    }
  }

  Future<Map<String, dynamic>?> remoteEffect(String turnId, {int effectIndex = 0}) async {
    final handle = await db.database;
    final journal = _decode(await BrainWorkFence.value(handle, '$remoteJournalPrefix$turnId'));
    if (journal is List && effectIndex >= 0 && effectIndex < journal.length && journal[effectIndex] is Map) {
      return Map<String, dynamic>.from(journal[effectIndex] as Map);
    }
    final legacy = _decode(await BrainWorkFence.value(handle, '$remoteEffectPrefix$turnId'));
    return legacy is Map ? Map<String, dynamic>.from(legacy) : null;
  }

  Future<void> initializeRemoteReads(GenerationAttemptFence attempt) async {
    final handle = await db.database;
    await handle.transaction((txn) async {
      final key = '$remoteJournalPrefix${attempt.userMessageId}';
      if ((await BrainWorkFence.value(txn, key)).isNotEmpty ||
          (await BrainWorkFence.value(txn, '$remoteEffectPrefix${attempt.userMessageId}')).isNotEmpty ||
          !await attempt.matches(txn)) return;
      final old = await txn.query('agent_tool_outcomes', columns: ['id'],
        where: 'id LIKE ? AND tool_id = ? AND status IN (?, ?, ?)',
        whereArgs: ['user_turn:${attempt.jobId}:cedar_toy.play:%', 'cedar_toy.play', 'succeeded', 'failed', 'stopped'], limit: 1);
      if (old.isEmpty) await txn.insert('settings', {'key': key, 'value': '[]'});
    });
  }

  /// Only writes occupy ordered slots. Reads and model call IDs are not action
  /// identity. A new generation may replay this sequence, never extend it.
  Future<Map<String, dynamic>?> reserveRemoteEffect(GenerationAttemptFence attempt, Object payload,
      {int effectIndex = 0, bool allowKnownContinuation = false, bool Function()? isCancelled}) async {
    final handle = await db.database;
    return handle.transaction((txn) async {
      requireTurnNotCancelled(isCancelled);
      final key = '$remoteJournalPrefix${attempt.userMessageId}';
      final raw = _decode(await BrainWorkFence.value(txn, key));
      if (raw != null && raw is! List) return {'state': 'conflict'};
      final journal = raw is List ? List<Object?>.from(raw) : <Object?>[];
      // Earlier builds journaled cmd queries as writes. Remove only receipts
      // whose complete submitted payload proves a read; unknown verbs remain.
      final lengthBefore = journal.length;
      journal.removeWhere((r) {
        if (r is! Map || r['submitted_arguments'] is! Map) return false;
        final p = r['submitted_arguments'] as Map;
        return p['params'] is Map && CedarPlatformActionPolicy.isReadOnlyCall(
          p['action']?.toString() ?? '', Map<String,Object?>.from(p['params'] as Map));
      });
      if(journal.length!=lengthBefore && await attempt.matches(txn)) {
        await txn.insert('settings', {'key':key,'value':jsonEncode(journal)},
          conflictAlgorithm:ConflictAlgorithm.replace);
      }
      final legacy = _decode(await BrainWorkFence.value(txn, '$remoteEffectPrefix${attempt.userMessageId}'));
      if (legacy is Map) {
        return {...Map<String, dynamic>.from(legacy),
          if (legacy['payload_hash'] != turnPayloadHash(payload)) 'state': 'conflict'};
      }
      final priorRun=journal.any((r)=>r is Map && r['run_token']!=attempt.runToken);
      if(allowKnownContinuation && (priorRun || journal.any((r)=>r is Map && r['state']=='reconciled')) &&
          journal.every((r)=>r is Map && const {'known','reconciled'}.contains(r['state'])) &&
          !(effectIndex<journal.length && CedarPlatformActionPolicy.explicitlyRejected(
            (journal[effectIndex] as Map)['outcome']?.toString() ?? ''))) {
        final hash=turnPayloadHash(payload);
        for(final r in journal) {
          if(r is Map && r['payload_hash']==hash)return Map<String,dynamic>.from(r);
        }
        if(journal.isNotEmpty && (journal.last as Map)['goal_satisfied']!=true && await attempt.matches(txn)) {
          final index=journal.length;
          journal.add({'schema':2,'turn_id':attempt.userMessageId,'run_token':attempt.runToken,
            'payload_hash':hash,'submitted_arguments':payload,'state':'dispatching',
            'created_at':DateTime.now().millisecondsSinceEpoch});
          await txn.insert('settings',{'key':key,'value':jsonEncode(journal)},conflictAlgorithm:ConflictAlgorithm.replace);
          return {'state':'reserved','effect_index':index};
        }
      }
      if (effectIndex < 0 || effectIndex > journal.length) return {'state': 'conflict'};
      if (effectIndex < journal.length) {
        final receipt = journal[effectIndex];
        if (receipt is! Map) return {'state': 'conflict'};
        if (receipt['payload_hash'] != turnPayloadHash(payload) &&
            receipt['state']=='known' &&
            (receipt['failed']==true || CedarPlatformActionPolicy.explicitlyRejected(receipt['outcome']?.toString() ?? '')) &&
            await attempt.matches(txn)) {
          final previous=Map<String,dynamic>.from(receipt)..remove('prior_rejections');
          journal[effectIndex]={'schema':2,'turn_id':attempt.userMessageId,'run_token':attempt.runToken,
            'payload_hash':turnPayloadHash(payload),'submitted_arguments':payload,
            'state':'dispatching','created_at':DateTime.now().millisecondsSinceEpoch,
            'prior_rejections':[...(receipt['prior_rejections'] as List? ?? []),previous]};
          await txn.insert('settings',{'key':key,'value':jsonEncode(journal)},conflictAlgorithm:ConflictAlgorithm.replace);
          return null;
        }
        return {...Map<String, dynamic>.from(receipt),
          if (receipt['payload_hash'] != turnPayloadHash(payload)) 'state': 'conflict'};
      }
      if (journal.any((r) => r is! Map || r['state'] != 'known')) return {'state': 'dispatching'};
      if (journal.any((r) => (r as Map)['run_token'] != attempt.runToken)) return {'state': 'prior_run_complete'};
      if (!await attempt.matches(txn)) return {'state': 'stale'};
      if (raw == null) {
        final legacyOutcomes = await txn.query('agent_tool_outcomes', columns: ['id'],
          where: 'id LIKE ? AND tool_id = ? AND status IN (?, ?, ?)',
          whereArgs: ['user_turn:${attempt.jobId}:cedar_toy.play:%', 'cedar_toy.play', 'succeeded', 'failed', 'stopped'], limit: 1);
        // Old outcomes cannot prove whether the operation was read-only.
        if (legacyOutcomes.isNotEmpty) return {'state': 'legacy_unknown'};
      }
      journal.add({'schema': 2, 'turn_id': attempt.userMessageId, 'run_token': attempt.runToken,
        'payload_hash': turnPayloadHash(payload), 'submitted_arguments': payload,
        'state': 'dispatching', 'created_at': DateTime.now().millisecondsSinceEpoch});
      await txn.insert('settings', {'key': key, 'value': jsonEncode(journal)}, conflictAlgorithm: ConflictAlgorithm.replace);
      requireTurnNotCancelled(isCancelled);
      return null;
    });
  }

  Future<void> completeRemoteEffect(String turnId, Object payload, {
    required String outcome, required bool failed, int effectIndex = 0,
    String nextActor = 'wait', bool continuationRecommended = false,
    bool? goalSatisfied,
  }) async {
    final handle = await db.database;
    await handle.transaction((txn) async {
      final key = '$remoteJournalPrefix$turnId';
      final raw = _decode(await BrainWorkFence.value(txn, key));
      if (raw is! List || effectIndex < 0 || effectIndex >= raw.length) return;
      final receipt = raw[effectIndex];
      if (receipt is! Map || receipt['payload_hash'] != turnPayloadHash(payload) || !const {'dispatching', 'known'}.contains(receipt['state'])) return;
      raw[effectIndex] = {...receipt, 'state': 'known', 'outcome': outcome, 'failed': failed,
        'next_actor': nextActor, 'continuation_recommended': continuationRecommended,
        if(goalSatisfied!=null)'goal_satisfied':goalSatisfied};
      await txn.insert('settings', {'key': key, 'value': jsonEncode(raw)}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Roll back only a reservation that never reached the network. Unknown
  /// remote effects, and receipts owned by other attempts, remain durable.
  Future<void> releaseUnsentRemoteEffect(GenerationAttemptFence attempt,
      Object payload, {required int effectIndex}) async {
    final handle = await db.database;
    await handle.transaction((txn) async {
      final key = '$remoteJournalPrefix${attempt.userMessageId}';
      final raw = _decode(await BrainWorkFence.value(txn, key));
      if (raw is! List || effectIndex != raw.length - 1) return;
      final receipt = raw.last;
      if (receipt is! Map || receipt['state'] != 'dispatching' ||
          receipt['run_token'] != attempt.runToken ||
          receipt['payload_hash'] != turnPayloadHash(payload)) return;
      raw.removeLast();
      await txn.insert('settings', {'key': key, 'value': jsonEncode(raw)},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
  static const effectPrefix = 'agent_effect_receipt_v1:';
  static const turnContextPrefix = 'agent_turn_context_v1:';
  static const goalPrefix = 'agent_turn_contract_v1:';
  static const deliveryPrefix = 'cedar_delivery_receipt_v1:';
  static String effectKey(String turnId, TurnEffectSlot slot) =>
      '$effectPrefix${turnEffectId(turnId, slot)}';
  static String deliveryKey(CedarDeliveryClaim claim) =>
      '$deliveryPrefix${turnPayloadHash(claim.resultId)}';

  static Object? _decode(String raw) {
    try { return jsonDecode(raw); } catch (_) { return null; }
  }
  Future<LocalEffectReceipt?> readEffect(String turnId, TurnEffectSlot slot) async =>
      readEffectInTransaction(await db.database, turnId: turnId, slot: slot);
  static Future<LocalEffectReceipt?> readEffectInTransaction(DatabaseExecutor txn,
      {required String turnId, required TurnEffectSlot slot}) async {
    final receipt = LocalEffectReceipt.fromJson(_decode(await BrainWorkFence.value(
      txn, effectKey(turnId, slot))));
    return receipt?.turnId == turnId && receipt?.slot == slot ? receipt : null;
  }

  /// Read old facts before checking the attempt, but never accept another
  /// payload as a replay of those facts. New effects require current ownership.
  static Future<LocalEffectAdmission> inspectLocalInTransaction(DatabaseExecutor txn,
      {required GenerationAttemptFence attempt, required TurnEffectSlot slot,
      required Object? payload, bool Function()? isCancelled}) async {
    requireTurnNotCancelled(isCancelled);
    final raw = await BrainWorkFence.value(txn, effectKey(attempt.userMessageId, slot));
    final existing = LocalEffectReceipt.fromJson(_decode(raw));
    if (raw.isNotEmpty && (existing == null ||
        existing.turnId != attempt.userMessageId || existing.slot != slot)) {
      return const LocalEffectAdmission(LocalEffectAdmissionState.conflict);
    }
    if (existing != null) {
      if (existing.payloadHash != turnPayloadHash(payload)) {
        return LocalEffectAdmission(LocalEffectAdmissionState.conflict, existing);
      }
      if (existing.committed) {
        return LocalEffectAdmission(LocalEffectAdmissionState.replay, existing);
      }
      // A previous uncommitted stage may be replaced by the new owner. It is
      // not a committed grant and cannot activate through a reused message ID.
    }
    if (!await attempt.matches(txn)) {
      return const LocalEffectAdmission(LocalEffectAdmissionState.staleAttempt);
    }
    requireTurnNotCancelled(isCancelled);
    if (existing != null && existing.runToken == attempt.runToken) {
      return LocalEffectAdmission(LocalEffectAdmissionState.replay, existing);
    }
    return const LocalEffectAdmission(LocalEffectAdmissionState.create);
  }

  static Future<void> writeEffectInTransaction(DatabaseExecutor txn,
      LocalEffectReceipt receipt) => txn.insert('settings', {
        'key': effectKey(receipt.turnId, receipt.slot),
        'value': jsonEncode(receipt.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace).then((_) {});

  Future<List<TurnTaskGoal>> goals(GenerationAttemptFence attempt) async =>
      readGoalsInTransaction(await db.database, attempt: attempt);

  static Future<List<TurnTaskGoal>> readGoalsInTransaction(DatabaseExecutor txn,
      {required GenerationAttemptFence attempt}) async {
    final raw = _decode(await BrainWorkFence.value(txn, '$goalPrefix${attempt.userMessageId}'));
    if (raw is! Map || raw['schema'] != 2 || raw['goals'] is! List) return const [];
    final source = ConversationSourceStamp.fromJson(raw['user_source']);
    final expected = attempt.userSource;
    if (source == null || expected == null || source.id != attempt.userMessageId ||
        source.role != 'user' || source.contentHash != expected.contentHash ||
        source.revision != expected.revision || !await source.matches(txn)) return const [];
    return (raw['goals'] as List).map(TurnTaskGoal.fromJson)
      .whereType<TurnTaskGoal>().where((goal) => goal.turnId == attempt.userMessageId).toList();
  }

  Future<String?> originalUserControlRevision(String turnId) async =>
      originalUserControlRevisionInTransaction(await db.database, turnId);

  static Future<String?> originalUserControlRevisionInTransaction(
      DatabaseExecutor txn, String turnId) async {
    final raw = _decode(await BrainWorkFence.value(txn, '$turnContextPrefix$turnId'));
    return raw is Map && raw['schema'] == 1 && raw['turn_id'] == turnId && raw['user_control_revision'] is String
        ? raw['user_control_revision'] as String : null;
  }

  Future<bool> saveGoals(GenerationAttemptFence attempt, List<TurnTaskGoal> goals,
      {bool Function()? isCancelled}) async {
    if (attempt.userSource == null ||
        goals.any((goal) => goal.turnId != attempt.userMessageId)) return false;
    final handle = await db.database;
    try {
      return await handle.transaction((txn) async {
        requireTurnNotCancelled(isCancelled);
        if (!await attempt.matches(txn)) return false;
        await txn.insert('settings', {'key': '$goalPrefix${attempt.userMessageId}',
          'value': jsonEncode({'schema': 2, 'user_source': attempt.userSource!.toJson(), 'goals': goals.map((g) => g.toJson()).toList()})},
          conflictAlgorithm: ConflictAlgorithm.replace);
        requireTurnNotCancelled(isCancelled);
        return true;
      });
    } on TurnCommitCancelled { return false; }
  }

  static Future<void> writeDeliveryInTransaction(DatabaseExecutor txn,
      CedarDeliveryReceipt receipt) async {
    if (!receipt.claim.valid || receipt.messageId.isEmpty || receipt.messageHash.isEmpty) {
      throw const FormatException('invalid_cedar_delivery_receipt');
    }
    await txn.insert('settings', {'key': deliveryKey(receipt.claim),
      'value': jsonEncode(receipt.toJson())}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<CedarDeliveryReceipt?> readDeliveryInTransaction(
      DatabaseExecutor txn, CedarDeliveryClaim claim) async {
    final receipt = CedarDeliveryReceipt.fromJson(_decode(
      await BrainWorkFence.value(txn, deliveryKey(claim))));
    return receipt?.claim.resultHash == claim.resultHash ? receipt : null;
  }

  static Future<bool> deliveryMatchesInTransaction(DatabaseExecutor txn,
      CedarDeliveryReceipt receipt) async {
    final saved = await readDeliveryInTransaction(txn, receipt.claim);
    if (saved == null || turnPayloadHash(saved.toJson()) != turnPayloadHash(receipt.toJson())) return false;
    final source = await ConversationSourceStore.captureMessage(txn, receipt.messageId);
    return source != null && source.role == 'assistant' &&
        source.contentHash == receipt.messageHash && source.revision == receipt.messageRevision;
  }
}
