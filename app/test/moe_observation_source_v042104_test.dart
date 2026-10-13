import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/brain_work_fence.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/integration/moe_shadow_coordinator.dart';
import 'package:ai_companion_localfirst/core/integration/moe_input_adapter.dart';
import 'package:ai_companion_localfirst/core/moe/application/moe_dynamics_policy.dart';
import 'package:ai_companion_localfirst/core/moe/infrastructure/sqlite_moe_repository.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef _Committed = ({ChatMessage assistant, BrainWorkFence fence, ConversationSourceStamp source});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
  tearDown(() async { await db.closeForTesting(); });
  final at = DateTime(2026, 10, 13, 10);

  Future<_Committed> commit(String id, {DateTime? time, String rpSide = ''}) async {
    final date = time ?? at;
    final rp = const WorldBookTurnContext(roleplaySessionId: 'fiction').encode();
    final pending = await db.createGenerationTurn(user: ChatMessage(id: 'u-$id', role: 'user',
      content: '真实用户 $id', createdAt: date, worldBookContextJson: rpSide == 'user' ? rp : ''),
      assistantMessageId: 'a-$id', model: 'deepseek-v4-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(pending.id))!;
    final attempt = (await db.captureGenerationAttemptFence(job))!;
    final assistant = ChatMessage(id: 'a-$id', role: 'assistant', content: '回应 $id',
      createdAt: date.add(const Duration(milliseconds: 1)), emotionKey: 'playful',
      worldBookContextJson: rpSide == 'assistant' ? rp : '');
    ConversationSourceStamp? source;
    expect(await db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
      generationAttempt: attempt, assistant: assistant, onCommittedSource: (value) => source = value), isTrue);
    expect(source, isNotNull);
    expect(await source!.matchesCapturedVersion(await db.database), isTrue);
    return (assistant: assistant, fence: attempt.brainFence, source: source!);
  }
  Future<List<Map<String, Object?>>> events() async => (await db.database).query('moe_events');
  Future<int> cursor() async => (jsonDecode((await db.getSetting(MoeShadowCoordinator.scanKey))!) as Map)['after_seq'] as int;
  Future<MoeObservationResult> observe(_Committed value, {MoeShadowCoordinator? coordinator}) =>
    (coordinator ?? MoeShadowCoordinator(db)).observeCompletedTurn(value.assistant,
      originalFence: value.fence, committedSource: value.source);
  Future<void> settle(Future<MoeObservationResult> run, {required bool bodyFailed}) async {
    try {
      await run.timeout(const Duration(seconds: 3));
    } catch (_) {
      // Cleanup remains bounded without replacing the primary assertion.
      if (!bodyFailed) rethrow;
    }
  }

  test('committed original source is accepted once; direct observation does not move scan cursor', () async {
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    final baseline = await cursor();
    final value = await commit('once');
    expect((await observe(value)).status, MoeObservationStatus.accepted);
    final state = await (await db.database).query('moe_axis_state');
    expect((await observe(value)).status, MoeObservationStatus.alreadyApplied);
    expect(await events(), hasLength(1));
    expect(await (await db.database).query('moe_axis_state'), state);
    expect(await cursor(), baseline);
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect(await cursor(), greaterThan(baseline));
    expect(await events(), hasLength(1));
  });

  for (final change in ['epoch', 'restore', 'content', 'delete', 'same_content_new_sequence', 'emotion', 'paired_roleplay']) {
    test('original source/fence rejects late observation after $change', () async {
      final value = await commit(change);
      final entered = Completer<void>();
      final release = Completer<void>();
      final coordinator = MoeShadowCoordinator(db, beforeInput: (_) async {
        entered.complete();
        await release.future;
      });
      final run = observe(value, coordinator: coordinator);
      var bodyFailed = false;
      try {
        await entered.future.timeout(const Duration(seconds: 2));
        switch (change) {
          case 'epoch':
            await db.setSetting('runtime_state_epoch_v1', 'replacement-epoch');
            break;
          case 'restore':
            final snapshot = await db.exportAll();
            await db.importAll(snapshot);
            break;
          case 'content':
            await db.insertMessage(ChatMessage(id: value.assistant.id, role: 'assistant',
              content: '已改变来源正文', createdAt: value.assistant.createdAt, emotionKey: 'playful'));
            break;
          case 'delete':
            await (await db.database).delete('messages', where: 'id = ?', whereArgs: [value.assistant.id]);
            break;
          case 'same_content_new_sequence':
            await (await db.database).transaction((txn) => ConversationSourceStore.sourceChanged(txn, value.assistant.id));
            expect(await value.source.matches(await db.database), isTrue);
            expect(await value.source.matchesCapturedVersion(await db.database), isFalse);
            break;
          case 'emotion':
            await (await db.database).update('messages', {'emotion_key': 'angry'},
              where: 'id = ?', whereArgs: [value.assistant.id]);
            expect(await value.source.matchesCapturedVersion(await db.database), isTrue);
            break;
          case 'paired_roleplay':
            await db.insertMessage(ChatMessage(id: 'u-$change', role: 'user', content: '真实用户 $change',
              createdAt: at, worldBookContextJson: const WorldBookTurnContext(roleplaySessionId: 'new-rp').encode()));
            break;
        }
        final beforeSettings = await (await db.database).query('settings', where: 'key LIKE ?', whereArgs: ['moe_shadow_%']);
        release.complete();
        expect((await run.timeout(const Duration(seconds: 2))).status, MoeObservationStatus.rejected);
        expect(await events(), isEmpty);
        expect(await (await db.database).query('moe_axis_state'), isEmpty);
        expect(await (await db.database).query('settings', where: 'key LIKE ?', whereArgs: ['moe_shadow_%']), beforeSettings);
      } catch (_) {
        bodyFailed = true;
        rethrow;
      } finally {
        if (!release.isCompleted) release.complete();
        await settle(run, bodyFailed: bodyFailed);
      }
    });
  }

  for (final side in ['user', 'assistant']) {
    test('paired $side roleplay never becomes an observed ordinary pulse', () async {
      final value = await commit('rp-$side', rpSide: side);
      expect((await observe(value)).status, MoeObservationStatus.excluded);
      expect(await events(), isEmpty);
    });
  }

  test('bounded sequence scan keeps failed item retryable and direct new observation cannot skip it', () async {
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    final first = await commit('first');
    final second = await commit('second', time: at); // Same event time, distinct scan versions.
    var fail = true;
    final coordinator = MoeShadowCoordinator(db, beforeInput: (message) async {
      if (fail && message.id == first.assistant.id) throw StateError('controlled_input_failure');
    });
    await coordinator.reconcileRecentCommittedTurns();
    final stopped = await cursor();
    expect(stopped, lessThan(first.source.ingestSeq));
    expect(await events(), isEmpty);
    expect((await observe(second)).status, MoeObservationStatus.accepted);
    expect(await cursor(), stopped);
    fail = false;
    await coordinator.reconcileRecentCommittedTurns();
    expect((await events()).map((e) => e['idempotency_key']).toSet(), {'turn:a-first', 'turn:a-second'});
    expect(await cursor(), greaterThanOrEqualTo(second.source.ingestSeq));
    final backdated = await commit('clock-back', time: at.subtract(const Duration(days: 30)));
    await coordinator.reconcileRecentCommittedTurns();
    expect((await events()).map((e) => e['idempotency_key']), contains('turn:a-clock-back'));
    expect(await cursor(), greaterThanOrEqualTo(backdated.source.ingestSeq));
  });

  test('startup baseline and legacy coverage do not replay old history; new backdated sequence is reachable', () async {
    await commit('before-enable', time: at.subtract(const Duration(days: 2)));
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect(await events(), isEmpty);
    final next = await commit('after-enable', time: at.subtract(const Duration(days: 3)));
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect((await events()).single['idempotency_key'], 'turn:a-after-enable');
    expect(await cursor(), greaterThanOrEqualTo(next.source.ingestSeq));

    await (await db.database).delete('settings', where: 'key = ?', whereArgs: [MoeShadowCoordinator.scanKey]);
    await db.setSetting('moe_shadow_reconciled_at', '${at.millisecondsSinceEpoch}');
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect(await events(), hasLength(1));
    await commit('after-migration', time: at.subtract(const Duration(days: 4)));
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect((await events()).map((e) => e['idempotency_key']), contains('turn:a-after-migration'));
  });

  test('repository final decision rolls event state diagnostics and cursor back together', () async {
    final value = await commit('atomic');
    final qualified = (await ConversationSourceStore.qualifyMessage(await db.database, value.assistant.id))!;
    final input = const MoeInputAdapter().fromCompletedTurn(assistant: value.assistant,
      desire: await db.loadDesire(), relationshipDay: 1);
    final entered = Completer<void>();
    final release = Completer<void>();
    var current = true;
    final run = SqliteMoeRepository(() => db.database).commitObservation(event: input.event,
      isCurrent: () => current,
      validate: (txn) async => await value.fence.matches(txn) && await qualified.matches(txn),
      advance: (previous) => const MoeDynamicsPolicy().advance(previous: previous,
        input: input, now: value.assistant.createdAt),
      writeAccepted: (txn, state) async {
        await txn.insert('settings', {'key': MoeShadowCoordinator.scanKey, 'value': 'must-rollback'},
          conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.insert('settings', {'key': 'moe_shadow_status', 'value': 'healthy'},
          conflictAlgorithm: ConflictAlgorithm.replace);
        entered.complete();
        await release.future;
      });
    var bodyFailed = false;
    try {
      await entered.future.timeout(const Duration(seconds: 2));
      current = false; // Timeout/Stop wins before the final transaction decision.
      release.complete();
      expect((await run.timeout(const Duration(seconds: 2))).status, MoeObservationStatus.rejected);
      expect(await events(), isEmpty);
      expect(await (await db.database).query('moe_axis_state'), isEmpty);
      expect(await (await db.database).query('moe_recipe_state'), isEmpty);
      expect(await db.getSetting(MoeShadowCoordinator.scanKey), isNull);
      expect(await db.getSetting('moe_shadow_status'), isNull);
    } catch (_) {
      bodyFailed = true;
      rethrow;
    } finally {
      if (!release.isCompleted) release.complete();
      await settle(run, bodyFailed: bodyFailed);
    }
  });

  test('scan remains bounded after long excluded prefix and preserves its position through import', () async {
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    final raw = await db.database;
    await raw.transaction((txn) async {
      for (var i = 0; i < MoeShadowCoordinator.pageSize + 1; i++) {
        await ConversationSourceStore.insertMessage(txn, ChatMessage(id: 'excluded-$i', role: 'system',
          content: 'non-observable system row', createdAt: at).toDb());
      }
    });
    await commit('after-prefix');
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect(await events(), isEmpty);
    final savedCursor = await db.getSetting(MoeShadowCoordinator.scanKey);
    final snapshot = await db.exportAll();
    await db.importAll(snapshot);
    expect(await db.getSetting(MoeShadowCoordinator.scanKey), savedCursor);
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect((await events()).single['idempotency_key'], 'turn:a-after-prefix');
  });

  test('legacy order ambiguity does not block scan; qualification changes requeue without duplicate pulse', () async {
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    final user = ChatMessage(id: 'legacy-u', role: 'user', content: '旧普通用户', createdAt: at);
    final assistant = ChatMessage(id: 'legacy-a', role: 'assistant', content: '同毫秒旧回复',
      createdAt: at, emotionKey: 'playful');
    await db.insertMessage(user);
    await db.insertMessage(assistant);
    final ambiguous = (await ConversationSourceStore.qualifyMessage(await db.database, assistant.id))!;
    expect(ambiguous.reason, 'legacy_pair_order_unknown');
    expect(ambiguous.isOrdinary, isFalse);
    final later = await commit('after-ambiguous', time: at.add(const Duration(minutes: 1)));

    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect((await events()).single['idempotency_key'], 'turn:a-after-ambiguous');
    expect(await cursor(), greaterThanOrEqualTo(later.source.ingestSeq));
    final oldCursor = await cursor();

    // The production writer changes the original bucket and requeues its peer.
    await db.insertMessage(ChatMessage(id: user.id, role: 'user', content: user.content,
      createdAt: at.subtract(const Duration(milliseconds: 1))));
    final resolved = (await ConversationSourceStore.qualifyMessage(await db.database, assistant.id))!;
    expect(resolved.isOrdinary, isTrue);
    expect(resolved.stamp.ingestSeq, greaterThan(oldCursor));
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect((await events()).map((row) => row['idempotency_key']).toSet(),
      {'turn:legacy-a', 'turn:a-after-ambiguous'});

    final state = await (await db.database).query('moe_axis_state');
    await db.insertMessage(ChatMessage(id: assistant.id, role: 'assistant', content: '同 ID 正文修订',
      createdAt: assistant.createdAt, emotionKey: assistant.emotionKey));
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect(await events(), hasLength(2));
    expect(await (await db.database).query('moe_axis_state'), state);
  });

  test('temporarily incomplete durable assistant is not consumed as legacy ambiguity', () async {
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    final pending = await db.createGenerationTurn(user: ChatMessage(id: 'waiting-u', role: 'user',
      content: '尚未完成的原回合', createdAt: at), assistantMessageId: 'waiting-a',
      model: 'deepseek-v4-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(pending.id))!;
    final attempt = (await db.captureGenerationAttemptFence(job))!;
    final assistant = ChatMessage(id: 'waiting-a', role: 'assistant', content: '尚未正式提交',
      createdAt: at.add(const Duration(milliseconds: 1)), emotionKey: 'playful');
    await db.insertMessage(assistant);
    final incomplete = (await ConversationSourceStore.qualifyMessage(await db.database, assistant.id))!;
    expect(incomplete.reason, 'incomplete_durable_turn');
    await commit('after-waiting', time: at.add(const Duration(minutes: 1)));
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect(await cursor(), lessThan(incomplete.stamp.ingestSeq));
    expect(await events(), isEmpty);

    expect(await db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
      generationAttempt: attempt, assistant: assistant), isTrue);
    await MoeShadowCoordinator(db).reconcileRecentCommittedTurns();
    expect((await events()).map((row) => row['idempotency_key']).toSet(),
      {'turn:waiting-a', 'turn:a-after-waiting'});
  });

  test('timeout invalidates queued old work instead of accepting its late input', () async {
    final value = await commit('timeout');
    final entered = Completer<void>();
    final release = Completer<void>();
    final inputEnded = Completer<void>();
    final coordinator = MoeShadowCoordinator(db, observationTimeout: const Duration(milliseconds: 50),
      beforeInput: (_) async {
        entered.complete();
        await release.future;
        inputEnded.complete();
        throw StateError('late_dependency_finished');
      });
    final run = observe(value, coordinator: coordinator);
    var bodyFailed = false;
    try {
      await entered.future.timeout(const Duration(seconds: 2));
      expect((await run.timeout(const Duration(seconds: 2))).status, MoeObservationStatus.failed);
      release.complete();
      await inputEnded.future.timeout(const Duration(seconds: 2));
      expect(await events(), isEmpty);
      expect(await db.getSetting('moe_shadow_status'), isNull);
    } catch (_) {
      bodyFailed = true;
      rethrow;
    } finally {
      if (!release.isCompleted) release.complete();
      await settle(run, bodyFailed: bodyFailed);
    }
  });
}
