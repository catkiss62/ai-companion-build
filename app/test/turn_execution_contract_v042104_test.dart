import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/agent/turn_execution_store.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/database/generation_attempt_fence.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/generation_job.dart';
import 'package:ai_companion_localfirst/core/storage/pending_media_owner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Contract/SQLite boundary tests. Runner, timer and creative entry-point tests
// separately verify how callers construct goals and commit real work.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late TurnExecutionStore store;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = TurnExecutionStore(db);
  });
  tearDown(() => db.closeForTesting());

  ChatMessage user(String id, {String text = '请开始一项定时游戏'}) => ChatMessage(
    id: id, role: 'user', content: text,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1000));
  Future<GenerationJob> start(String id) async {
    final pending = await db.createGenerationTurn(user: user('u-$id'),
      assistantMessageId: 'a-$id', model: 'deepseek-v4-flash',
      reasoningEffort: 'high');
    return (await db.claimGenerationJob(pending.id))!;
  }
  Future<GenerationAttemptFence> capture(GenerationJob job) async =>
      (await db.captureGenerationAttemptFence(job))!;
  const slot = TurnEffectSlot.cedarTimedRegistration;
  const payload = <String, Object?>{'game': 'synthetic-game', 'minutes': 20};
  LocalEffectReceipt receipt(GenerationAttemptFence attempt,
      {LocalEffectState state = LocalEffectState.committed,
      String? turnId, TurnEffectSlot effectSlot = slot}) => LocalEffectReceipt(
        turnId: turnId ?? attempt.userMessageId, slot: effectSlot,
        payloadHash: turnPayloadHash(payload), state: state,
        result: const {'registration_id': 'registration-1'},
        runToken: attempt.runToken, createdAt: 2000);
  TurnTaskGoal goal(GenerationAttemptFence attempt) => TurnTaskGoal(
    turnId: attempt.userMessageId, slot: slot, description: '登记二十分钟游戏',
    target: const {'game_id': 'synthetic-game'}, minutes: 20,
    durationText: '二十分钟');

  test('current user can save goals before reply, but rewritten source revokes cached authorization', () async {
    final job = await start('goals');
    final attempt = await capture(job);
    final sql = await db.database;
    expect((await ConversationSourceStore.qualifyMessage(sql, job.userMessageId))!
        .eligibility, ConversationSourceEligibility.unresolved);
    expect(await store.saveGoals(attempt, [goal(attempt)]), isTrue);
    expect((await store.goals(attempt)).single.minutes, 20);
    // The message ID and running job remain unchanged. Only the real source
    // changes, so a turn-ID-only route cache would incorrectly remain valid.
    await db.insertMessage(user(job.userMessageId, text: '现在不要登记游戏'));
    expect(await attempt.matches(sql), isFalse);
    expect(await store.goals(attempt), isEmpty);
    final replacement = await capture(job);
    expect(await replacement.matches(sql), isTrue);
    expect(await store.goals(replacement), isEmpty);
  });

  test('goals for another user turn never enter the current authorization record', () async {
    final attempt = await capture(await start('wrong-goal'));
    expect(await store.saveGoals(attempt, [const TurnTaskGoal(
      turnId: 'another-user', slot: slot, description: 'unrelated')]), isFalse);
    expect(await db.getSetting('${TurnExecutionStore.goalPrefix}${attempt.userMessageId}'), isNull);
  });

  test('known local acceptance survives stopped expression, but changed payload is a conflict', () async {
    final job = await start('known');
    final attempt = await capture(job);
    final sql = await db.database;
    await sql.transaction((txn) async {
      expect((await TurnExecutionStore.inspectLocalInTransaction(txn,
        attempt: attempt, slot: slot, payload: payload)).canCreate, isTrue);
      await TurnExecutionStore.writeEffectInTransaction(txn, receipt(attempt));
    });
    expect(await db.cancelGenerationJobByUser(job.id), isTrue);
    expect(await attempt.matches(sql), isFalse);
    final known = await TurnExecutionStore.inspectLocalInTransaction(sql,
      attempt: attempt, slot: slot, payload: {'minutes': 20, 'game': 'synthetic-game'});
    expect(known.state, LocalEffectAdmissionState.replay);
    expect(known.receipt!.result['registration_id'], 'registration-1');
    final changed = await TurnExecutionStore.inspectLocalInTransaction(sql,
      attempt: attempt, slot: slot, payload: {...payload, 'minutes': 30});
    expect(changed.state, LocalEffectAdmissionState.conflict);
    expect((await store.readEffect(attempt.userMessageId, slot))!.payloadHash,
      turnPayloadHash(payload));
  });

  for (final wrongField in ['turn', 'slot', 'malformed']) {
    test('a $wrongField receipt under the current key cannot authorize replay or new work', () async {
      final attempt = await capture(await start('wrong-$wrongField'));
      final value = wrongField == 'malformed' ? '{' : jsonEncode(receipt(attempt,
        turnId: wrongField == 'turn' ? 'other-user' : null,
        effectSlot: wrongField == 'slot' ? TurnEffectSlot.creativeCommission : slot).toJson());
      await db.setSetting(TurnExecutionStore.effectKey(attempt.userMessageId, slot), value);
      expect(await store.readEffect(attempt.userMessageId, slot), isNull);
      final admission = await TurnExecutionStore.inspectLocalInTransaction(await db.database,
        attempt: attempt, slot: slot, payload: payload);
      expect(admission.state, LocalEffectAdmissionState.conflict);
    });
  }

  test('retry may replace an uncommitted stage, while the abandoned attempt stays stale', () async {
    final job = await start('retry');
    final old = await capture(job);
    final sql = await db.database;
    await sql.transaction((txn) => TurnExecutionStore.writeEffectInTransaction(txn,
      receipt(old, state: LocalEffectState.staged)));
    await sql.update('generation_jobs', {'updated_at': 0}, where: 'id = ?', whereArgs: [job.id]);
    final recoveredJob = (await db.claimGenerationJob(job.id))!;
    final recovered = await capture(recoveredJob);
    expect(recovered.runToken, isNot(old.runToken));
    expect((await TurnExecutionStore.inspectLocalInTransaction(sql,
      attempt: old, slot: slot, payload: payload)).state, LocalEffectAdmissionState.staleAttempt);
    expect((await TurnExecutionStore.inspectLocalInTransaction(sql,
      attempt: recovered, slot: slot, payload: payload)).state, LocalEffectAdmissionState.create);
    await sql.transaction((txn) => TurnExecutionStore.writeEffectInTransaction(txn,
      receipt(recovered, state: LocalEffectState.staged)));
    expect((await store.readEffect(old.userMessageId, slot))!.runToken, recovered.runToken);
  });

  test('cancellation after SQLite writes rolls back both work and receipt', () async {
    final attempt = await capture(await start('rollback'));
    final token = GenerationCancellationToken();
    final written = Completer<void>();
    final release = Completer<void>();
    final sql = await db.database;
    final transaction = sql.transaction((txn) async {
      final admission = await TurnExecutionStore.inspectLocalInTransaction(txn,
        attempt: attempt, slot: slot, payload: payload,
        isCancelled: () => token.isCancelled);
      expect(admission.canCreate, isTrue);
      await txn.insert('settings', {'key': 'synthetic-work', 'value': 'accepted'});
      await TurnExecutionStore.writeEffectInTransaction(txn, receipt(attempt));
      written.complete();
      await release.future;
      requireTurnNotCancelled(() => token.isCancelled);
    });
    // Observe failures immediately, while retaining the actual transaction
    // error for the rollback assertion after the gate has been released.
    final outcome = transaction.then<Object?>((_) => null,
      onError: (Object error, StackTrace stack) => error);
    Object? transactionError;
    var bodyFailed = false;
    try {
      await Future.any<void>([
        written.future,
        transaction.then<void>((_) => throw StateError(
          'Transaction completed before the tentative-write barrier')),
      ]).timeout(const Duration(seconds: 10));
      token.cancel();
    } catch (_) {
      bodyFailed = true;
      rethrow;
    } finally {
      token.cancel();
      if (!release.isCompleted) release.complete();
      try {
        transactionError = await outcome.timeout(const Duration(seconds: 10));
      } catch (_) {
        if (!bodyFailed) rethrow;
      }
    }
    expect(transactionError, isA<TurnCommitCancelled>());
    expect(await db.getSetting('synthetic-work'), isNull);
    expect(await store.readEffect(attempt.userMessageId, slot), isNull);
    expect(await attempt.matches(sql), isTrue);
  });

  test('delivery acknowledgement is bound to the exact committed visible reply and result', () async {
    final job = await start('delivery');
    final assistant = ChatMessage(id: job.assistantMessageId, role: 'assistant',
      content: '这局已经结束，结果是平局。', createdAt: DateTime.fromMillisecondsSinceEpoch(2000));
    expect(await db.completeGenerationJobIfCurrent(jobId: job.id,
      runToken: job.runToken, assistant: assistant), isTrue);
    final sql = await db.database;
    final source = (await ConversationSourceStore.captureMessage(sql, assistant.id))!;
    const claim = CedarDeliveryClaim(kind: CedarDeliveryKind.terminal,
      gameId: 'synthetic-game', sessionId: 'session-1', terminalKey: 'terminal-1', summary: '平局');
    final proof = CedarDeliveryReceipt(claim: claim, messageId: source.id,
      messageHash: source.contentHash, messageRevision: source.revision, committedAt: 2000);
    await sql.transaction((txn) => TurnExecutionStore.writeDeliveryInTransaction(txn, proof));
    expect(await TurnExecutionStore.deliveryMatchesInTransaction(sql, proof), isTrue);
    const changedClaim = CedarDeliveryClaim(kind: CedarDeliveryKind.terminal,
      gameId: 'synthetic-game', sessionId: 'session-1', terminalKey: 'terminal-1', summary: '胜利');
    expect(await TurnExecutionStore.readDeliveryInTransaction(sql, changedClaim), isNull);
    await db.insertMessage(assistant.copyWith(content: '我们聊聊别的。'));
    expect(await TurnExecutionStore.deliveryMatchesInTransaction(sql, proof), isFalse);
    // Historical delivery remains a fact; this old proof just cannot consume
    // a pending result on behalf of the replacement text.
    expect(await TurnExecutionStore.readDeliveryInTransaction(sql, claim), isNotNull);
  });

  test('pending media schema 2 preserves original source and temporary freeze ownership', () async {
    final attempt = await capture(await start('media'));
    final encoded = jsonDecode(jsonEncode(PendingMediaOwner.generation(attempt).toJson()))
      as Map<String, dynamic>;
    final decoded = PendingMediaOwner.decode(encoded)!;
    expect(decoded.attempt!.userSource!.contentHash, attempt.userSource!.contentHash);
    final sql = await db.database;
    expect(await decoded.matches(sql), isTrue);
    await db.setSetting('transfer_lock', '1');
    expect(await decoded.matches(sql), isFalse);
    expect(await decoded.retainsOwnership(sql), isTrue);
    await db.setSetting('transfer_lock', '0');
    await db.insertMessage(user(attempt.userMessageId, text: '换了真实请求'));
    expect(await decoded.matches(sql), isFalse);
    expect(await decoded.retainsOwnership(sql), isFalse);
  });

  test('pending owner rejects downgraded, missing and mismatched source capabilities', () async {
    final attempt = await capture(await start('invalid-media'));
    final encoded = PendingMediaOwner.generation(attempt).toJson();
    Map<String, dynamic> roundtrip(Map<String, Object?> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
    expect(PendingMediaOwner.decode(roundtrip({...encoded, 'schema': 1})), isNull);
    expect(PendingMediaOwner.decode(roundtrip({...encoded}..remove('user_source'))), isNull);
    expect(PendingMediaOwner.decode(roundtrip({...encoded, 'user_source': null})), isNull);
    expect(PendingMediaOwner.decode(roundtrip({...encoded,
      'user_source': {...attempt.userSource!.toJson(), 'id': 'another-user'}})), isNull);
    expect(PendingMediaOwner.decode(roundtrip({...encoded,
      'user_source': {...attempt.userSource!.toJson(), 'content_hash': 'invalid'}})), isNull);
  });
}
