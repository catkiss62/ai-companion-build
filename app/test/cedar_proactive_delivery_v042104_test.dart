import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/agent/turn_execution_store.dart';
import 'package:ai_companion_localfirst/core/agent/turn_execution_contract.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_delivery_verifier.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_delivery_attempt_store.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late DeepSeekClient ai;
  var writerCalls = 0;
  late DateTime retryClock;
  const channel = MethodChannel('ai_companion/system');
  final at = DateTime.fromMillisecondsSinceEpoch(2000000);
  const thoughtId = 'cedar-report:task-1';
  const messageId = 'cedar-share:$thoughtId';
  const visible = '这次二十分钟的游戏任务已经结束，我完成了三轮，最后一轮是平局。';
  final report = <String, dynamic>{'id': 'task-1', 'turnId': 'original-user',
    'gameId': 'duel', 'sessionId': 'session-1', 'title': '双弈', 'minutes': 20,
    'usedMs': 1200000, 'finishedAt': at.millisecondsSinceEpoch,
    'reason': 'time_limit', 'progressCount': 3, 'outcomes': ['平局'], 'terminalKey': ''};

  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    writerCalls = 0;
    // Retry deadlines are persisted as epoch milliseconds.
    retryClock = DateTime.utc(2026, 10, 13, 12);
    http.Client writer() => MockClient((_) async {
      writerCalls++;
      return http.Response('unexpected writer request', 500);
    });
    ai = DeepSeekClient(client: writer(), streamClientFactory: writer,
      jsonClientFactory: writer);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async =>
        call.method == 'isImmersiveChatPageVisible' ? false : null);
  });
  tearDown(() async {
    ai.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
    await db.closeForTesting();
  });

  http.Response decision(String? answer) => http.Response(jsonEncode({
    'answers': {if (answer != null) 'delivery_0': {'type': 'choice',
      'choice': answer, 'confidence': .99,
      'probabilities': {'yes': answer == 'yes' ? .99 : .01,
        'no': answer == 'no' ? .99 : .01}}},
  }), 200);
  CedarDeliveryVerifier verifier(Future<http.Response> Function(http.Request) respond,
      {bool enabled = true}) => CedarDeliveryVerifier(gateway: JevDecisionGateway(
    enabledReader: () async => enabled, keyReader: () async => 'test-key',
    clientFactory: () => MockClient(respond)));
  ProactiveEngine engine(CedarDeliveryVerifier verification) => ProactiveEngine(
    db: db, desireEngine: DesireEngine(db), ai: ai, android: AndroidBridge.instance,
    cedarDeliveryVerifier: verification,
    cedarDeliveryAttempts: CedarDeliveryAttemptStore(db, clock: () => retryClock));
  Future<ChatMessage> seedReport({String text = visible, bool withMessage = true}) async {
    await db.setSetting(CedarTimedPlayTaskStore.reportsKey, jsonEncode([report]));
    await CedarToyActivityStore(db).queueDirectShare(thoughtId);
    final message = ChatMessage(id: messageId, role: 'assistant', content: text,
      reasoningContent: '内部意图不是可见交付', createdAt: at, isProactive: true);
    if (withMessage) await db.insertMessage(message);
    return message;
  }
  Future<int> messageCount() async =>
      (await (await db.database).query('messages', columns: ['id'])).length;

  test('actual recovered share verifies original visible body and atomically backfills proof without a new reply', () async {
    await seedReport();
    var calls = 0;
    final result = await engine(verifier((request) async {
      calls++;
      final body = jsonDecode(request.body) as Map;
      expect((body['state'] as Map)['final_visible_reply'], visible);
      expect(jsonEncode(body).contains('内部意图'), isFalse);
      final candidates = (body['state'] as Map)['delivery_candidates'] as List;
      expect(candidates.single, CedarTimedPlayTaskStore.reportClaim(report).toJson());
      return decision('yes');
    })).deliverPendingCedarShareIfAny();
    expect(result.reason, 'cedar_share_already_committed');
    expect(result.sent, isFalse);
    expect(calls, 1);
    expect(writerCalls, 0);
    expect(await messageCount(), 1);
    expect(await CedarTimedPlayTaskStore(db).pendingReports(), isEmpty);
    expect(await CedarToyActivityStore(db).pendingDirectShares(), isEmpty);
    final sql = await db.database;
    final proof = await TurnExecutionStore.readDeliveryInTransaction(sql,
      CedarTimedPlayTaskStore.reportClaim(report));
    expect(proof!.messageId, messageId);
    expect(await TurnExecutionStore.deliveryMatchesInTransaction(sql, proof), isTrue);
    expect((await db.thoughtById(thoughtId))!.lastActedAt, isNotNull);
  });

  for (final outcome in ['no', 'missing', 'http_failure', 'disabled']) {
    test('$outcome verification preserves report and thought with no writer fallback', () async {
      await seedReport(text: '我们待会儿再说这局结果。');
      var calls = 0;
      final result = await engine(verifier((_) async {
        calls++;
        return outcome == 'http_failure' ? http.Response('{}', 402)
          : decision(outcome == 'missing' ? null : 'no');
      }, enabled: outcome != 'disabled')).deliverPendingCedarShareIfAny();
      expect(result.reason, 'cedar_share_delivery_unverified');
      expect(calls, outcome == 'disabled' ? 0 : 1);
      expect(writerCalls, 0);
      expect(await messageCount(), 1);
      expect(await CedarTimedPlayTaskStore(db).pendingReports(), hasLength(1));
      expect(await CedarToyActivityStore(db).pendingDirectShares(), contains(thoughtId));
      expect((await db.thoughtById(thoughtId))!.lastActedAt, isNull);
      expect(await TurnExecutionStore.readDeliveryInTransaction(await db.database,
        CedarTimedPlayTaskStore.reportClaim(report)), isNull);
    });
  }

  for (final change in ['body', 'epoch', 'result']) {
    test('$change changes while recovered verification waits cannot acknowledge the replacement', () async {
      final message = await seedReport();
      final entered = Completer<void>();
      final release = Completer<void>();
      final run = engine(verifier((_) async {
        entered.complete();
        await release.future.timeout(_barrierTimeout);
        return decision('yes');
      })).deliverPendingCedarShareIfAny();
      var bodyFailed = false;
      try {
        await _waitForBarrier(entered.future, run);
        if (change == 'body') await db.insertMessage(message.copyWith(content: '换了一条无关正文'));
        if (change == 'epoch') await db.setSetting('runtime_state_epoch_v1', 'different-runtime');
        if (change == 'result') await db.setSetting(CedarTimedPlayTaskStore.reportsKey,
          jsonEncode([{...report, 'outcomes': ['胜利']} ]));
      } catch (_) {
        bodyFailed = true;
        rethrow;
      } finally {
        if (!release.isCompleted) release.complete();
        try {
          await run.timeout(_barrierTimeout);
        } catch (_) {
          if (!bodyFailed) rethrow;
        }
      }
      final result = await run;
      expect(result.reason, 'cedar_share_delivery_unverified');
      expect(await CedarTimedPlayTaskStore(db).pendingReports(), hasLength(1));
      expect(await CedarToyActivityStore(db).pendingDirectShares(), contains(thoughtId));
      expect(writerCalls, 0);
      expect(await messageCount(), 1);
      if (change != 'result') {
        expect(await TurnExecutionStore.readDeliveryInTransaction(await db.database,
          CedarTimedPlayTaskStore.reportClaim(report)), isNull);
      }
    });
  }

  test('a malformed legacy report remains pending rather than becoming an empty responsibility', () async {
    await seedReport();
    // The legacy thought already existed before its stored report became bad.
    expect(await CedarTimedPlayTaskStore(db).queueReport(), thoughtId);
    expect(await db.thoughtById(thoughtId), isNotNull);
    await db.setSetting(CedarTimedPlayTaskStore.reportsKey,
      jsonEncode([{...report, 'sessionId': ''}]));
    var calls = 0;
    final result = await engine(verifier((_) async { calls++; return decision('yes'); }))
      .deliverPendingCedarShareIfAny();
    expect(result.reason, 'cedar_share_delivery_deferred');
    expect(calls, 0);
    expect(writerCalls, 0);
    expect(await CedarTimedPlayTaskStore(db).pendingReports(), hasLength(1));
    expect(await CedarToyActivityStore(db).pendingDirectShares(), contains(thoughtId));
    expect((await db.thoughtById(thoughtId))!.lastActedAt, isNull);
  });

  test('two heartbeats with a declined saved body make one check and retain responsibility', () async {
    await seedReport(text: '待会儿再汇报。');
    var calls = 0;
    final worker = engine(verifier((_) async { calls++; return decision('no'); }));
    expect((await worker.deliverPendingCedarShareIfAny()).reason, 'cedar_share_delivery_unverified');
    // A new engine reads the durable memo; this is not an in-memory cache.
    expect((await engine(verifier((_) async { calls++; return decision('yes'); }))
      .deliverPendingCedarShareIfAny()).reason, 'cedar_share_delivery_deferred');
    expect(calls, 1);
    expect(writerCalls, 0);
    expect(await messageCount(), 1);
    expect(await CedarTimedPlayTaskStore(db).pendingReports(), hasLength(1));
  });

  for (final outcome in ['no', 'technical']) {
    test('$outcome memo is rechecked after a competing heartbeat waited before acquiring the lease', () async {
      await seedReport();
      var calls = 0;
      final service = verifier((_) async {
        calls++;
        return outcome == 'no' ? decision('no') : http.Response('{}', 402);
      });
      final paused = _PausingAttemptStore(db, clock: () => retryClock);
      final delayed = ProactiveEngine(db: db, desireEngine: DesireEngine(db), ai: ai,
        android: AndroidBridge.instance, cedarDeliveryVerifier: service,
        cedarDeliveryAttempts: paused).deliverPendingCedarShareIfAny();
      var bodyFailed = false;
      try {
        await _waitForBarrier(paused.entered.future, delayed);
        await engine(service).deliverPendingCedarShareIfAny().timeout(_barrierTimeout);
      } catch (_) {
        bodyFailed = true;
        rethrow;
      } finally {
        if (!paused.release.isCompleted) paused.release.complete();
        try {
          await delayed.timeout(_barrierTimeout);
        } catch (_) {
          if (!bodyFailed) rethrow;
        }
      }
      expect(calls, 1);
      expect(await CedarTimedPlayTaskStore(db).pendingReports(), hasLength(1));
      expect(await messageCount(), 1);
      expect(writerCalls, 0);
    });
  }

  test('a cooled R1 does not block a saved R2 result from being verified and settled', () async {
    await seedReport(text: '待会儿再汇报。');
    var calls = 0;
    final worker = engine(verifier((_) async {
      calls++;
      return decision(calls == 1 ? 'no' : 'yes');
    }));
    await worker.deliverPendingCedarShareIfAny();
    final second = {...report, 'id': 'task-2', 'sessionId': 'session-2'};
    await db.setSetting(CedarTimedPlayTaskStore.reportsKey, jsonEncode([report, second]));
    await db.insertMessage(ChatMessage(id: 'cedar-share:cedar-report:task-2', role: 'assistant',
      content: visible, createdAt: at, isProactive: true));
    expect((await worker.deliverPendingCedarShareIfAny()).reason, 'cedar_share_already_committed');
    final remaining = await CedarTimedPlayTaskStore(db).pendingReports();
    expect(remaining.map((item) => item['id']), ['task-1']);
    expect(calls, 2);
    expect(writerCalls, 0);
    expect(await messageCount(), 2);
  });

  for (final changed in ['source', 'claim']) {
    test('$changed changes invalidate the exact declined memo before its retry date', () async {
      final old = await seedReport(text: '待会儿再汇报。');
      var calls = 0;
      final worker = engine(verifier((_) async {
        calls++;
        return decision(calls == 1 ? 'no' : 'yes');
      }));
      await worker.deliverPendingCedarShareIfAny();
      if (changed == 'source') await db.insertMessage(old.copyWith(content: visible));
      if (changed == 'claim') await db.setSetting(CedarTimedPlayTaskStore.reportsKey,
        jsonEncode([{...report, 'reason': 'user_stop'}]));
      expect((await worker.deliverPendingCedarShareIfAny()).reason, 'cedar_share_already_committed');
      expect(calls, 2);
      expect(await CedarTimedPlayTaskStore(db).pendingReports(), isEmpty);
      expect(writerCalls, 0);
      expect(await messageCount(), 1);
    });
  }

  test('technical failure retries the same persisted body only after its durable due time', () async {
    await seedReport();
    var calls = 0;
    final service = verifier((request) async {
      calls++;
      expect(((jsonDecode(request.body) as Map)['state'] as Map)['final_visible_reply'], visible);
      return calls == 1 ? http.Response('{}', 402) : decision('yes');
    });
    await engine(service).deliverPendingCedarShareIfAny();
    expect((await engine(service).deliverPendingCedarShareIfAny()).reason, 'cedar_share_delivery_deferred');
    expect(calls, 1);
    retryClock = retryClock.add(const Duration(minutes: 1));
    expect((await engine(service).deliverPendingCedarShareIfAny()).reason, 'cedar_share_already_committed');
    expect(calls, 2);
    expect(writerCalls, 0);
    expect(await messageCount(), 1);
  });

  test('crash after fixed successor commit recovers its proof and never inserts another message', () async {
    await seedReport(text: '待会儿再汇报。');
    await engine(verifier((_) async => decision('no'))).deliverPendingCedarShareIfAny();
    final claim = CedarTimedPlayTaskStore.reportClaim(report);
    final successor = CedarDeliveryAttemptStore.successorId(thoughtId, [claim]);
    final fence = (await db.captureBrainWorkFence())!;
    // Actual winning DB commit, then omit acknowledgement as a process crash.
    expect(await db.commitProactiveMessageIfCurrent(message: ChatMessage(id: successor,
      role: 'assistant', content: visible, createdAt: at, isProactive: true),
      evaluationStartedAt: DateTime.now(), workFence: fence, cedarDeliveries: [claim]), isNull);
    var calls = 0;
    final worker = engine(verifier((_) async { calls++; return decision('yes'); }));
    await worker.deliverPendingCedarShareIfAny();
    await worker.deliverPendingCedarShareIfAny();
    expect(await CedarTimedPlayTaskStore(db).pendingReports(), isEmpty);
    expect(await CedarToyActivityStore(db).pendingDirectShares(), isEmpty);
    expect(await messageCount(), 2);
    expect(await db.messageById(messageId), isNotNull);
    expect(await db.messageById(successor), isNotNull);
    expect(calls, 0);
    expect(writerCalls, 0);
  });

  test('a saved successor without proof settles progress even if the canonical history was deleted', () async {
    await seedReport(text: '待会儿再汇报。');
    await engine(verifier((_) async => decision('no'))).deliverPendingCedarShareIfAny();
    final claim = CedarTimedPlayTaskStore.reportClaim(report);
    final successor = CedarDeliveryAttemptStore.successorId(thoughtId, [claim]);
    await db.insertMessage(ChatMessage(id: successor, role: 'assistant', content: visible,
      createdAt: at, isProactive: true));
    await (await db.database).delete('messages', where: 'id = ?', whereArgs: [messageId]);
    const progressId = 'older-progress';
    await db.upsertThought(id: progressId, text: '旧进展', drive: DriveKey.curiosity,
      kind: 'flit', strength: .5, bornAt: at, source: 'mcp/cedar_game:duel:event-old');
    await CedarToyActivityStore(db).queueDirectShare(progressId);
    final session = CedarGameSession(id: 'session-1', gameId: 'duel', guide: 'guide',
      guideComplete: true, mode: CedarParticipationMode.solo,
      phase: CedarActivityPhase.completed, updatedAt: at);
    await db.setSetting(CedarToyActivityStore.stateSettingKey, jsonEncode(CedarToyActivityState(
      activeGameId: 'duel', sessions: {'duel': session}, updatedAt: at).toJson()));
    var calls = 0;
    final worker = engine(verifier((request) async {
      calls++;
      expect(((jsonDecode(request.body) as Map)['state'] as Map)['final_visible_reply'], visible);
      return decision('yes');
    }));
    await worker.deliverPendingCedarShareIfAny();
    await worker.deliverPendingCedarShareIfAny();
    expect(await CedarTimedPlayTaskStore(db).pendingReports(), isEmpty);
    expect(await CedarToyActivityStore(db).pendingDirectShares(), isEmpty);
    expect(await messageCount(), 1);
    expect(calls, 1);
    expect(writerCalls, 0);
  });

  test('an acted legacy thought with a pending result reaches the next draft after cooldown', () async {
    await seedReport(text: '待会儿再汇报。');
    final service = verifier((_) async => decision('no'));
    await engine(service).deliverPendingCedarShareIfAny();
    await db.updateThoughtLifecycle(thoughtId, lifecycleState: 'acted',
      actionCount: 1, lastActedAt: retryClock);
    retryClock = retryClock.add(const Duration(minutes: 1));
    final worker = _DraftAdmissionEngine(db: db, ai: ai,
      verifier: service, attempts: CedarDeliveryAttemptStore(db, clock: () => retryClock));
    expect((await worker.deliverPendingCedarShareIfAny()).reason, 'draft_admitted');
    expect(worker.thoughtId, thoughtId);
    expect(await CedarTimedPlayTaskStore(db).pendingReports(), hasLength(1));
    expect(await CedarToyActivityStore(db).pendingDirectShares(), contains(thoughtId));
    expect(writerCalls, 0);
  });

  test('failed new drafts preserve canonical no memo and back off 1, 5, then 30 minutes', () async {
    final original = await seedReport(text: '待会儿再汇报。');
    final claim = CedarTimedPlayTaskStore.reportClaim(report);
    final store = CedarDeliveryAttemptStore(db, clock: () => retryClock);
    final source = (await ConversationSourceStore.captureMessage(await db.database, original.id))!;
    final fence = (await db.captureBrainWorkFence())!;
    expect(await store.recordFailure(claims: [claim], declined: true, fence: fence, source: source), isTrue);
    expect((await store.read([claim]))!.retryAt.difference(retryClock), const Duration(minutes: 1));
    expect(await store.recordFailure(claims: [claim], declined: true, fence: fence), isTrue);
    final second = (await store.read([claim]))!;
    expect(second.retryAt.difference(retryClock), const Duration(minutes: 5));
    expect(second.declinedFor(source), isTrue);
    expect(await store.recordFailure(claims: [claim], declined: false, fence: fence), isTrue);
    expect((await store.read([claim]))!.retryAt.difference(retryClock), const Duration(minutes: 30));
    expect(await messageCount(), 1);
  });

  test('ordinary process share with an existing message buys no verifier call', () async {
    const id = 'cedar-progress:one';
    await db.upsertThought(id: id, text: '一次已知进展', drive: DriveKey.curiosity,
      kind: 'flit', strength: .8, source: 'mcp/cedar_game:fishing:event-1');
    await CedarToyActivityStore(db).queueDirectShare(id);
    await db.insertMessage(ChatMessage(id: 'cedar-share:$id', role: 'assistant',
      content: '之前钓到一条鱼。', createdAt: at, isProactive: true));
    var calls = 0;
    final result = await engine(verifier((_) async { calls++; return decision('yes'); }))
      .deliverPendingCedarShareIfAny();
    expect(result.reason, 'cedar_share_already_committed');
    expect(calls, 0);
    expect(writerCalls, 0);
  });

  test('terminal recovery acknowledges only the source-matched game and session', () async {
    CedarGameSession session(String id, String game) => CedarGameSession(id: id,
      gameId: game, guide: 'synthetic guide', guideComplete: true,
      mode: CedarParticipationMode.solo, phase: CedarActivityPhase.completed,
      updatedAt: at, pendingTerminalKey: 'terminal:one', pendingTerminalSummary: '$game 平局');
    final duel = session('session-duel', 'duel');
    final other = session('session-other', 'other');
    await db.setSetting(CedarToyActivityStore.stateSettingKey, jsonEncode(CedarToyActivityState(
      activeGameId: 'duel', sessions: {'duel': duel, 'other': other}, updatedAt: at).toJson()));
    const id = 'terminal-thought';
    await db.upsertThought(id: id, text: '双弈结束', drive: DriveKey.curiosity,
      kind: 'flit', strength: .8, source: 'mcp/cedar_game:duel:terminal:one');
    await CedarToyActivityStore(db).queueDirectShare(id);
    await db.insertMessage(ChatMessage(id: 'cedar-share:$id', role: 'assistant',
      content: '这局双弈是平局。', createdAt: at, isProactive: true));
    await engine(verifier((request) async {
      final candidates = ((jsonDecode(request.body) as Map)['state'] as Map)['delivery_candidates'] as List;
      expect(candidates.single, CedarToyActivityStore.terminalClaim(duel).toJson());
      return decision('yes');
    })).deliverPendingCedarShareIfAny();
    final state = await CedarToyActivityStore(db).loadState();
    expect(state.sessions['duel']!.hasPendingTerminalDelivery, isFalse);
    expect(state.sessions['other']!.hasPendingTerminalDelivery, isTrue);
    expect(writerCalls, 0);
  });

  test('new visible candidate proof belongs to the real proactive commit and current source', () async {
    final message = await seedReport(withMessage: false);
    final claim = CedarTimedPlayTaskStore.reportClaim(report);
    final full = '${List.filled(1700, '前').join()}最后：$visible';
    final claims = await verifier((request) async {
      expect(((jsonDecode(request.body) as Map)['state'] as Map)['final_visible_reply'], full);
      return decision('yes');
    }).verify(visibleText: full, candidates: [claim]);
    final fence = (await db.captureBrainWorkFence())!;
    expect(await db.commitProactiveMessageIfCurrent(message: message.copyWith(content: full),
      evaluationStartedAt: DateTime.now(), workFence: fence, cedarDeliveries: claims.verified), isNull);
    final sql = await db.database;
    final proof = await TurnExecutionStore.readDeliveryInTransaction(sql, claim);
    final source = (await ConversationSourceStore.captureMessage(sql, message.id))!;
    expect(proof!.messageHash, source.contentHash);
    expect(proof.messageRevision, source.revision);
    expect(await CedarTimedPlayTaskStore(db).acknowledge('task-1'), isTrue);
    expect(writerCalls, 0);
  });

  test('saved empty text is a structural no and reaches a later fixed successor without buying JEV', () async {
    await seedReport(text: '');
    var calls = 0;
    final service = verifier((_) async { calls++; return decision('yes'); });
    expect((await engine(service).deliverPendingCedarShareIfAny()).reason, 'cedar_share_delivery_unverified');
    final claim = CedarTimedPlayTaskStore.reportClaim(report);
    final source = (await ConversationSourceStore.captureMessage(await db.database, messageId))!;
    expect((await CedarDeliveryAttemptStore(db).read([claim]))!.declinedFor(source), isTrue);
    retryClock = retryClock.add(const Duration(minutes: 1));
    final worker = _DraftAdmissionEngine(db: db, ai: ai, verifier: service,
      attempts: CedarDeliveryAttemptStore(db, clock: () => retryClock));
    expect((await worker.deliverPendingCedarShareIfAny()).reason, 'draft_admitted');
    expect(calls, 0);
    expect(writerCalls, 0);
    expect(await messageCount(), 1);
    expect(await CedarTimedPlayTaskStore(db).pendingReports(), hasLength(1));
  });

  test('first-candidate optional-unavailable contract preserves the real message but no proof or acknowledgement', () async {
    final message = await seedReport(withMessage: false);
    final claim = CedarTimedPlayTaskStore.reportClaim(report);
    final verification = await verifier((_) async => http.Response('{}', 402))
      .verify(visibleText: message.content, candidates: [claim]);
    expect(verification.allowsNewMessage(successor: false, claimCount: 1), isTrue);
    final fence = (await db.captureBrainWorkFence())!;
    expect(await db.commitProactiveMessageIfCurrent(message: message,
      evaluationStartedAt: DateTime.now(), workFence: fence,
      cedarDeliveries: verification.verified), isNull);
    final source = (await ConversationSourceStore.captureMessage(await db.database, message.id))!;
    expect(await CedarDeliveryAttemptStore(db, clock: () => retryClock).recordFailure(
      claims: [claim], declined: false, fence: fence, source: source), isTrue);
    expect(await CedarTimedPlayTaskStore(db).acknowledge('task-1'), isFalse);
    var retryCalls = 0;
    expect((await engine(verifier((_) async { retryCalls++; return decision('yes'); }))
      .deliverPendingCedarShareIfAny()).reason, 'cedar_share_delivery_deferred');
    expect(await messageCount(), 1);
    expect(await db.messageById(messageId), isNotNull);
    expect(await CedarTimedPlayTaskStore(db).pendingReports(), hasLength(1));
    expect(retryCalls, 0);
    expect(writerCalls, 0);
  });

  test('successor admission requires verification even when the optional service is unavailable', () async {
    await seedReport(text: '待会儿再汇报。');
    final claim = CedarTimedPlayTaskStore.reportClaim(report);
    final service = verifier((_) async => http.Response('{}', 402));
    final unavailable = await service.verify(visibleText: visible, candidates: [claim]);
    expect(unavailable.declined, isFalse);
    expect(unavailable.allowsNewMessage(successor: true, claimCount: 1), isFalse);
    final declined = await verifier((_) async => decision('no'))
      .verify(visibleText: visible, candidates: [claim]);
    expect(declined.allowsNewMessage(successor: false, claimCount: 1), isFalse);
    expect(declined.allowsNewMessage(successor: true, claimCount: 1), isFalse);
    expect(await messageCount(), 1);
    expect(await db.messageById(CedarDeliveryAttemptStore.successorId(thoughtId, [claim])), isNull);
    expect(await CedarTimedPlayTaskStore(db).pendingReports(), hasLength(1));
    expect(writerCalls, 0);
  });

  test('no candidates or a sticker-only empty body never requests or certifies delivery', () async {
    var calls = 0;
    final service = verifier((_) async { calls++; return decision('yes'); });
    expect((await service.verify(visibleText: '普通主动聊天', candidates: [])).verified, isEmpty);
    final blank = await service.verify(visibleText: '', candidates: [CedarTimedPlayTaskStore.reportClaim(report)]);
    expect(blank.verified, isEmpty);
    expect(blank.declined, isTrue);
    expect(blank.allowsNewMessage(successor: false, claimCount: 1), isFalse);
    expect(calls, 0);
  });
}

const _barrierTimeout = Duration(seconds: 10);

// If the real operation fails or returns before reaching the awaited point,
// surface that outcome immediately instead of waiting on an orphaned latch.
Future<void> _waitForBarrier<T>(Future<void> entered, Future<T> operation) =>
    Future.any<void>([
      entered,
      operation.then<void>((_) {
        throw StateError('Operation completed before reaching the test barrier');
      }),
    ]).timeout(_barrierTimeout);

// A spy only at the expensive writer boundary. The test above exercises real
// report selection, persistent cooldown, legacy lifecycle and draft admission;
// it does not claim to execute the full model-generation pipeline.
class _DraftAdmissionEngine extends ProactiveEngine {
  _DraftAdmissionEngine({required AppDatabase db, required DeepSeekClient ai,
    required CedarDeliveryVerifier verifier, required CedarDeliveryAttemptStore attempts})
      : super(db: db, desireEngine: DesireEngine(db), ai: ai,
          android: AndroidBridge.instance, cedarDeliveryVerifier: verifier,
          cedarDeliveryAttempts: attempts);
  String? thoughtId;
  @override
  Future<ProactiveDecision> evaluate({bool forceForDebug = false,
    String? forcedThoughtIdForDebug,
    Duration perceptionMinInterval = const Duration(minutes: 4)}) async {
    thoughtId = forcedThoughtIdForDebug;
    return const ProactiveDecision(sent: false, reason: 'draft_admitted');
  }
}

class _PausingAttemptStore extends CedarDeliveryAttemptStore {
  _PausingAttemptStore(super.db, {super.clock});
  final entered = Completer<void>();
  final release = Completer<void>();
  var reads = 0;
  @override
  Future<CedarDeliveryAttempt?> read(List<CedarDeliveryClaim> claims) async {
    final captured = await super.read(claims);
    // Exclusion scan is first; direct queue selection is second. Hold its old
    // snapshot while another real engine records a no/unavailable and releases.
    if (++reads == 2) {
      entered.complete();
      await release.future.timeout(_barrierTimeout);
    }
    return captured;
  }
}
