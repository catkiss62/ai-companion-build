import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../database/conversation_source_store.dart';
import '../database/generation_attempt_fence.dart';
import 'turn_execution_contract.dart';

export 'turn_execution_contract.dart';

/// Local goal/acceptance facts. HTTP dispatch and reconciliation are owned by
/// the Cedar executor; this store never interprets a model plan as a result.
class TurnExecutionStore {
  TurnExecutionStore(this.db);
  final AppDatabase db;
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
