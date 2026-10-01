import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_session_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_transition_log.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late String epoch;
  const channel = MethodChannel('ai_companion/system');
  final base = DateTime(2026, 10, 1, 12);

  setUp(() async {
    epoch = 'runtime-one';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async =>
            call.method == 'runtimeProcessEpoch' ? epoch : null);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
  });
  tearDown(() async {
    await db.closeForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> start({int minutes = 30, String turn = 'first', DateTime? at,
      AppDatabase? database}) async {
    final target = database ?? db;
    final session = await CedarToyActivityStore(target).recordGuide(
        gameId: 'white_room', guide: '单人游戏。start 开始；explore 探索。');
    await target.insertMessage(ChatMessage(id: 'reply-$turn', role: 'assistant',
        content: '好，我去玩一会儿。', createdAt: at ?? base));
    final tasks = CedarTimedPlayTaskStore(target);
    await tasks.stage(turnId: turn, assistantId: 'reply-$turn',
        session: session, minutes: minutes);
    // Keep the test's clock deterministic without bypassing committed admission.
    final raw = CedarTimedPlayTaskStore.decode(
        await target.getSetting(CedarTimedPlayTaskStore.pendingKey))!;
    await target.setSetting(CedarTimedPlayTaskStore.pendingKey,
        jsonEncode({...raw, 'requestedAt': (at ?? base).millisecondsSinceEpoch}));
    await tasks.activateCommitted(turnId: turn, now: at ?? base);
  }

  Future<void> spend(int seconds) async {
    final periods = CedarPlaySessionStore(db);
    final period = (await periods.load())!;
    expect(await periods.save(period.tick(base.add(Duration(seconds: seconds)))), true);
  }

  test('a two-minute step plus eight seconds of requests counts all 128 seconds', () {
    final timed = CedarPlaySession(gameId: 'white_room', startedAt: base,
        lastTickAt: base, taskId: 'committed');
    expect(timed.tick(base.add(const Duration(seconds: 128))).usedMs, 128000);
    expect(timed.tick(base.add(const Duration(minutes: 20))).usedMs, 0);
  });

  test('ordinary Desire grants keep their original suspension and expiry rules', () {
    final ordinary = CedarPlaySession(gameId: 'white_room', startedAt: base,
        lastTickAt: base);
    expect(ordinary.tick(base.add(const Duration(seconds: 128))).usedMs, 0);
    expect(ordinary.validAt(base.add(const Duration(days: 1)), 'white_room'), false);
    final task = CedarPlaySession(gameId: 'white_room', startedAt: base,
        lastTickAt: base, taskId: 'committed');
    expect(task.validAt(base.add(const Duration(days: 1)), 'white_room'), true);
  });

  test('recovery checkpoints count waiting cadence before any game step is due', () async {
    await start();
    final store = CedarToyActivityStore(db);
    final before = (await store.load())!;
    final tasks = CedarTimedPlayTaskStore(db);
    for (var seconds = 30; seconds <= 150; seconds += 30) {
      await tasks.reconcile(base.add(Duration(seconds: seconds)));
    }
    expect((await CedarPlaySessionStore(db).load())!.usedMs, 150000);
    expect((await tasks.active())!['usedMs'], 150000);
    expect((await store.load())!.events.length, before.events.length);
    expect(await tasks.pendingReports(), isEmpty);
  });

  test('crash or package update resumes only saved budget and excludes offline time', () async {
    await start(minutes: 20);
    await spend(120);
    epoch = 'runtime-after-update';
    final periods = CedarPlaySessionStore(db);
    expect(await periods.load(), isNull);
    final returned = base.add(const Duration(hours: 4));
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.reconcile(returned);
    final resumed = (await periods.load())!;
    expect(resumed.usedMs, 120000);
    expect(resumed.limitMs, 1200000);
    expect(resumed.lastTickAt, returned);
    await tasks.reconcile(returned.add(const Duration(seconds: 30)));
    expect((await periods.load())!.usedMs, 150000);
    expect(await tasks.pendingReports(), isEmpty);
  });

  test('same-process restore creates a new clock and rejects the old late writer', () async {
    await start();
    await spend(60);
    final periods = CedarPlaySessionStore(db);
    final old = (await periods.load())!;
    await db.setSetting(CedarPlaySessionStore.key, '');
    await CedarTimedPlayTaskStore(db).reconcile(base.add(const Duration(minutes: 5)));
    final resumed = (await periods.load())!;
    expect(resumed.usedMs, 60000);
    expect(resumed.clockId, isNot(old.clockId));
    expect(await periods.save(old.tick(base.add(const Duration(minutes: 6)))), false);
    expect((await periods.load())!.usedMs, 60000);
  });

  test('foreground chat temporarily freezes the clock and then resumes the task', () async {
    await start();
    final periods = CedarPlaySessionStore(db);
    await periods.pause(base.add(const Duration(seconds: 30)));
    expect(await db.tryAcquireLocalLease('chat_turn_lease'), true);
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.reconcile(base.add(const Duration(minutes: 8)));
    expect((await periods.load())!.usedMs, 30000);
    expect(await tasks.pendingReports(), isEmpty);
    await db.releaseLocalLease('chat_turn_lease');
    await tasks.reconcile(base.add(const Duration(minutes: 8)));
    await tasks.reconcile(base.add(const Duration(minutes: 8, seconds: 30)));
    expect((await periods.load())!.usedMs, 60000);
  });

  for (final blocker in ['active_brain', 'transfer_lock']) {
    test('$blocker blocks a fresh execution grant without ending durable intent', () async {
      await start();
      epoch = 'runtime-two';
      await db.setSetting(blocker, blocker == 'active_brain' ? '0' : '1');
      final tasks = CedarTimedPlayTaskStore(db);
      await tasks.reconcile(base.add(const Duration(hours: 1)));
      expect(await CedarPlaySessionStore(db).load(), isNull);
      expect(await tasks.active(), isNotNull);
      expect(await tasks.pendingReports(), isEmpty);
      await db.setSetting(blocker, blocker == 'active_brain' ? '1' : '0');
      await tasks.reconcile(base.add(const Duration(hours: 1)));
      expect((await CedarPlaySessionStore(db).load())!.usedMs, 0);
    });
  }

  test('an action still owned by the live engine is never stolen by reconciliation', () async {
    await start();
    final store = CedarToyActivityStore(db);
    expect(await db.tryAcquireLocalLease('cedar_toy_action_lease_until'), true);
    final execution = await store.beginExecution(gameId: 'white_room', action: 'explore');
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.reconcile(base.add(const Duration(seconds: 30)));
    expect((await store.loadState()).execution!.id, execution);
    expect((await CedarPlaySessionStore(db).load())!.usedMs, 0);
    await store.finishExecution(executionId: execution);
    await db.releaseLocalLease('cedar_toy_action_lease_until');
    await tasks.reconcile(base.add(const Duration(seconds: 30)));
    expect((await CedarPlaySessionStore(db).load())!.usedMs, 30000);
  });

  test('local Pause remains Stop with the original neutral report and never resumes', () async {
    await start();
    await spend(60);
    final store = CedarToyActivityStore(db);
    await store.pauseAndRelease();
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.reconcile(base.add(const Duration(minutes: 1)));
    expect(await tasks.active(), isNull);
    expect((await tasks.pendingReports()).single['reason'], 'finished_or_waiting_user');
    epoch = 'next-runtime';
    await tasks.reconcile(base.add(const Duration(days: 1)));
    expect(await tasks.active(), isNull);
    expect(await CedarPlaySessionStore(db).load(), isNull);
    expect(await store.load(), isNull);
    expect((await store.loadSession('white_room'))!.phase, CedarActivityPhase.paused);
  });

  test('explicit Stop can end a restored task even before its clock is rebuilt', () async {
    await start();
    await spend(60);
    await db.setSetting(CedarPlaySessionStore.key, '');
    expect(await CedarPlaySessionStore(db).end('user_pause'), true);
    final tasks = CedarTimedPlayTaskStore(db);
    expect(await tasks.active(), isNull);
    expect((await tasks.pendingReports()).single['usedMs'], 60000);
    await tasks.reconcile(base.add(const Duration(hours: 1)));
    expect(await tasks.active(), isNull);
  });

  test('new thirty minutes replaces old remainder without stacking or stale revival', () async {
    await start(minutes: 20);
    await spend(120);
    final periods = CedarPlaySessionStore(db);
    final old = (await periods.load())!;
    await start(minutes: 30, turn: 'replacement', at: base.add(const Duration(minutes: 3)));
    final fresh = (await periods.load())!;
    expect(fresh.taskId, 'cedar-task:replacement');
    expect(fresh.usedMs, 0);
    expect(fresh.limitMs, 1800000);
    expect(await periods.save(old.tick(base.add(const Duration(minutes: 4)))), false);
    final tasks = CedarTimedPlayTaskStore(db);
    expect((await tasks.pendingReports()).single['reason'], 'replaced_by_user_task');
    expect((await tasks.pendingReports()).single['usedMs'], 120000);
    await tasks.activateCommitted(turnId: 'replacement', now: base.add(const Duration(minutes: 4)));
    expect((await periods.load())!.startedAt, fresh.startedAt);
  });

  test('waiting for a real human preserves the task without consuming wait time', () async {
    await start();
    final store = CedarToyActivityStore(db);
    final session = (await store.load())!;
    await store.save(session.copyWith(phase: CedarActivityPhase.waitingUser, nextActor: 'user'));
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.reconcile(base.add(const Duration(seconds: 30)));
    await tasks.reconcile(base.add(const Duration(minutes: 10)));
    expect((await CedarPlaySessionStore(db).load())!.usedMs, 30000);
    expect(await tasks.active(), isNotNull);
    expect(await tasks.pendingReports(), isEmpty);
    await store.save(session.copyWith(phase: CedarActivityPhase.active, nextActor: 'companion'));
    await tasks.reconcile(base.add(const Duration(minutes: 10)));
    await tasks.reconcile(base.add(const Duration(minutes: 10, seconds: 30)));
    expect((await CedarPlaySessionStore(db).load())!.usedMs, 60000);
  });

  test('unroutable server wait is distinct from a local Stop and remains nonterminal', () async {
    await start();
    await CedarToyActivityStore(db).recordPlay(gameId: 'white_room', action: 'explore',
        outcome: const McpToolOutcome(isError: false, content: [
          McpContentBlock(kind: McpContentKind.text, text: '等待服务端事件'),
        ]), mode: CedarParticipationMode.solo, nextActor: 'wait',
        shareLevel: 'quiet', invitationApproved: false);
    await CedarTimedPlayTaskStore(db).reconcile(base.add(const Duration(seconds: 30)));
    expect(await CedarTimedPlayTaskStore(db).active(), isNotNull);
    expect(await CedarTimedPlayTaskStore(db).pendingReports(), isEmpty);
    expect((await CedarPlaySessionStore(db).load())!.paused, true);
  });

  test('budget completes once on a checkpoint without another remote game move', () async {
    await start(minutes: 1);
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.reconcile(base.add(const Duration(seconds: 30)));
    await tasks.reconcile(base.add(const Duration(minutes: 1)));
    await tasks.reconcile(base.add(const Duration(minutes: 2)));
    expect(await tasks.active(), isNull);
    expect((await tasks.pendingReports()).single['reason'], 'budget_complete');
    expect((await tasks.pendingReports()).single['usedMs'], 60000);
    expect(await CedarToyActivityStore(db).load(), isNull);
  });

  for (final terminal in ['finished', 'failed']) {
    test('actual $terminal result ends the task with its precise reason', () async {
      await start();
      final store = CedarToyActivityStore(db);
      final session = (await store.load())!;
      await store.save(session.copyWith(phase: terminal == 'finished'
          ? CedarActivityPhase.completed : CedarActivityPhase.failed,
          nextActor: terminal == 'finished' ? 'finished' : 'companion'));
      await CedarTimedPlayTaskStore(db).reconcile(base);
      expect((await CedarTimedPlayTaskStore(db).pendingReports()).single['reason'],
          terminal == 'finished' ? 'game_finished' : 'game_failed');
    });
  }

  test('disabled or switched games are not silently revived by runtime recovery', () async {
    await start();
    epoch = 'new';
    await db.setSetting('cedar_toy_enabled', '0');
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.reconcile(base);
    expect((await tasks.pendingReports()).single['reason'], 'game_disabled');
    expect(await tasks.active(), isNull);
  });

  test('two engines rebuilding a lost clock cannot duplicate the task or budget', () async {
    final directory = await Directory.systemTemp.createTemp('cedar-task-two-engines');
    final one = await AppDatabase.createForTesting(databaseFactoryFfi,
        path: '${directory.path}/state.db');
    final two = await AppDatabase.createForTesting(databaseFactoryFfi,
        path: '${directory.path}/state.db', reopenExisting: true);
    try {
      await start(database: one);
      await one.setSetting(CedarPlaySessionStore.key, '');
      await Future.wait([
        CedarTimedPlayTaskStore(one).reconcile(base.add(const Duration(hours: 1))),
        CedarTimedPlayTaskStore(two).reconcile(base.add(const Duration(hours: 1))),
      ]);
      final resumed = (await CedarPlaySessionStore(one).load())!;
      expect(resumed.usedMs, 0);
      expect(resumed.taskId, 'cedar-task:first');
      expect(await CedarTimedPlayTaskStore(one).pendingReports(), isEmpty);
    } finally {
      await two.closeForTesting();
      await one.closeForTesting();
      await directory.delete(recursive: true);
    }
  });

  test('bounded transition evidence stays in diagnostics and out of result reports', () async {
    await start();
    for (var i = 0; i < 40; i++) {
      await CedarPlayTransitionLog(db).record(source: 'test', reason: 'pause_$i');
    }
    final entries = jsonDecode((await db.getSetting(CedarPlayTransitionLog.key))!) as List;
    expect(entries.length, 32);
    expect(entries.first['reason'], 'pause_8');
    await CedarPlaySessionStore(db).end('user_pause');
    final report = jsonEncode((await CedarTimedPlayTaskStore(db).pendingReports()).single);
    expect(report, isNot(contains('pause_39')));
    expect(report, isNot(contains('processEpoch')));
    expect(report, isNot(contains('clockId')));
  });

  test('background completion cannot park a game after foreground fencing changes', () async {
    await start();
    final store = CedarToyActivityStore(db);
    final session = (await store.load())!;
    final oldFence = await db.getSetting(CedarToyActivityStore.executionFenceSettingKey) ?? '';
    await db.setSetting(CedarToyActivityStore.executionFenceSettingKey, 'new-foreground');
    expect(await store.pauseCompletedTask(sessionId: session.id,
        source: 'budget_complete', expectedSettings: {
          CedarToyActivityStore.executionFenceSettingKey: oldFence,
        }), false);
    expect((await store.load())!.phase, isNot(CedarActivityPhase.paused));
  });

  test('large state guards compare in SQLite and stale content cannot commit', () async {
    final large = List.filled(300000, '完整状态').join();
    await db.setSetting('large-task-state', large);
    expect(await db.setSettingsAtomically({'guarded-write': 'yes'},
        expectedSettings: {'large-task-state': large}), true);
    expect(await db.setSettingsAtomically({'guarded-write': 'late'},
        expectedSettings: {'large-task-state': large.substring(1)}), false);
    expect(await db.getSetting('guarded-write'), 'yes');
  });
}
