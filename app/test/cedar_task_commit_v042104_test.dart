import 'dart:async';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/agent/turn_execution_store.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_session_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_task_presentation.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/cedar_task_fixture.dart';

const _barrierTimeout = Duration(seconds: 30);

Future<void> _waitForBarrier<T>(
  Future<void> entered,
  Future<T> operation,
) => Future.any<void>([
  entered,
  operation.then<void>((_) {
    throw StateError('Operation completed before reaching its test barrier');
  }),
]).timeout(_barrierTimeout);

// Observe errors immediately and drain after releasing the gate. The test body
// separately awaits the original operation so its failures still fail the test.
Future<void> _drainForCleanup<T>(Future<T> operation) async {
  try {
    await operation.timeout(_barrierTimeout);
  } catch (_) { /* Preserve the original test failure during cleanup. */ }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const channel = MethodChannel('ai_companion/system');
  final at = DateTime(2026, 10, 13, 12);
  late AppDatabase db;
  late CedarToyActivityStore activity;
  late CedarTimedPlayTaskStore tasks;
  Completer<void>? epochEntered;
  Completer<void>? epochRelease;

  setUp(() async {
    epochEntered = null;
    epochRelease = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'runtimeProcessEpoch') return null;
      final release = epochRelease;
      if (release != null) {
        if (!epochEntered!.isCompleted) epochEntered!.complete();
        await release.future.timeout(_barrierTimeout);
      }
      return 'timed-test-runtime';
    });
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    activity = CedarToyActivityStore(db);
    tasks = CedarTimedPlayTaskStore(db);
  });
  tearDown(() async {
    if (epochRelease != null && !epochRelease!.isCompleted) epochRelease!.complete();
    try {
      await db.closeForTesting().timeout(_barrierTimeout);
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  Future<StagedCedarTask> stage([String turn = 'first']) async {
    final session = await activity.recordGuide(gameId: 'white_room',
        guide: '单人游戏。start 开始；explore 探索。');
    return stageCedarTask(db, session: session, turnId: turn,
        assistantId: 'reply-$turn', minutes: 10, now: at);
  }

  Future<LocalEffectReceipt?> receipt(String turn) => TurnExecutionStore(db)
      .readEffect(turn, TurnEffectSlot.cedarTimedRegistration);

  Future<Map<String, dynamic>> finishTask([String turn = 'first']) async {
    final staged = await stage(turn);
    expect(await commitCedarTask(db, staged), isTrue);
    await tasks.activateCommitted(now: at);
    final active = (await tasks.active())!;
    expect(await tasks.finish(active, usedMs: 20000,
        reason: 'budget_complete', now: at.add(const Duration(seconds: 20)), onlyIfActive: true), isTrue);
    return (await tasks.pendingReports()).last;
  }

  test('stable assistant id is not a committed registration ticket', () async {
    await stage();
    await db.insertMessage(ChatMessage(id: 'reply-first', role: 'assistant',
        content: '一条旧正文', createdAt: at));
    await tasks.activateCommitted(now: at);
    expect(await tasks.active(), isNull);
    expect(await CedarPlaySessionStore(db).load(), isNull);
    expect((await receipt('first'))!.state, LocalEffectState.staged);
    expect((await CedarTaskPresentation.load(db, (await activity.loadSession('white_room'))!))!.label, '待回复提交');
  });

  test('commit and activation are distinct and repeated activation cannot recharge', () async {
    final staged = await stage();
    expect(await commitCedarTask(db, staged), isTrue);
    expect(await tasks.active(), isNull);
    expect((await receipt('first'))!.committed, isTrue);
    expect((await CedarTaskPresentation.load(db, (await activity.loadSession('white_room'))!))!.label, '已登记 · 待启动');
    await tasks.activateCommitted(now: at);
    final periods = CedarPlaySessionStore(db);
    final original = (await periods.load())!;
    expect(await periods.save(original.tick(at.add(const Duration(seconds: 45)))), isTrue);
    await tasks.activateCommitted(now: at.add(const Duration(minutes: 1)));
    final after = (await periods.load())!;
    expect(after.usedMs, 45000);
    expect(after.clockId, original.clockId);
    expect((await receipt('first'))!.result['activationState'], 'active');
    final replay = await tasks.stage(turnId: 'first', assistantId: 'reply-first',
        session: (await activity.load())!, minutes: 10, attemptFence: staged.attempt,
        goalId: staged.effectId, effectId: staged.effectId);
    expect(replay.state, LocalEffectAdmissionState.replay);
    expect(await db.getSetting(CedarTimedPlayTaskStore.pendingKey), '');
    expect((await periods.load())!.usedMs, 45000);
  });

  test('pause before final commit rejects message and ticket atomically', () async {
    final staged = await stage();
    await activity.pauseAndRelease();
    expect(await commitCedarTask(db, staged), isFalse);
    expect(await db.messageById('reply-first'), isNull);
    expect((await receipt('first'))!.committed, isFalse);
    expect(await tasks.pendingReports(), isEmpty);
    expect(await tasks.active(), isNull);
  });

  test('UI pause cancels the stable staged effect across a new run token', () async {
    final staged = await stage();
    await activity.pause();
    expect((await receipt('first'))!.result['cancelledReason'], isNotNull);
    expect(await db.suspendGenerationJob(staged.job.id,
        reason: 'process_interruption', runToken: staged.job.runToken), isTrue);
    final rerun = (await db.claimGenerationJob(staged.job.id))!;
    final attempt = (await db.captureGenerationAttemptFence(rerun))!;
    final registration = await tasks.stage(turnId: 'first', assistantId: 'reply-first',
        session: (await activity.loadSession('white_room'))!, minutes: 10,
        attemptFence: attempt, goalId: staged.effectId, effectId: staged.effectId, now: at);
    expect(registration.state, LocalEffectAdmissionState.blocked);
    expect(await commitCedarTask(db, StagedCedarTask(rerun, attempt, staged.effectId, at)), isFalse);
    expect(await tasks.active(), isNull);
    // A genuinely new request is allowed to authorize the paused game again.
    expect(await db.cancelGenerationJobByUser(rerun.id), isTrue);
    final newTask = await stage('new-request');
    expect(await commitCedarTask(db, newTask), isTrue);
    await tasks.activateCommitted(now: at);
    expect((await tasks.active())!['turnId'], 'new-request');
  });

  for (final pauseBeforeGuide in [false, true]) {
    test('first guide ${pauseBeforeGuide ? 'cannot revive a paused original request' : 'preserves original user control authority'}', () async {
      final pending = await db.createGenerationTurn(user: ChatMessage(id: 'fresh', role: 'user',
          content: '请玩white_room10分钟。', createdAt: at), assistantMessageId: 'fresh-reply',
          model: 'deepseek-v4-flash', reasoningEffort: 'high');
      final job = (await db.claimGenerationJob(pending.id))!;
      final attempt = (await db.captureGenerationAttemptFence(job))!;
      final userRevision = (await TurnExecutionStore(db).originalUserControlRevision('fresh'))!;
      final goal = TurnTaskGoal(turnId: 'fresh', slot: TurnEffectSlot.cedarTimedRegistration,
          description: '首次游戏计时', minutes: 10, durationText: '10分钟',
          target: {'game_id': 'white_room', 'user_control_revision': userRevision});
      expect(await TurnExecutionStore(db).saveGoals(attempt, [goal]), isTrue);
      if (pauseBeforeGuide) await activity.pause();
      final session = await activity.recordGuide(gameId: 'white_room', guide: '单人游戏。explore 探索。');
      final registration = await tasks.stage(turnId: 'fresh', assistantId: 'fresh-reply',
          session: session, minutes: 10, attemptFence: attempt, goalId: goal.id, effectId: goal.id, now: at);
      expect(registration.canCreate, !pauseBeforeGuide);
      if (pauseBeforeGuide) {
        expect(await db.getSetting(CedarTimedPlayTaskStore.pendingKey), anyOf(isNull, isEmpty));
        expect(await tasks.active(), isNull);
        // A retry must not convert a fresh control snapshot into original
        // authority merely by rewriting the mutable goal envelope.
        expect(await TurnExecutionStore(db).saveGoals(attempt, [TurnTaskGoal(
          turnId: 'fresh', slot: TurnEffectSlot.cedarTimedRegistration, description: '旧请求重试',
          minutes: 10, durationText: '10分钟', target: {'game_id': 'white_room',
            'user_control_revision': (await db.getSetting(CedarToyActivityStore.userControlRevisionKey))!},
        )]), isTrue);
        expect((await tasks.stage(turnId: 'fresh', assistantId: 'fresh-reply', session: session,
            minutes: 10, attemptFence: attempt, goalId: goal.id, effectId: goal.id, now: at)).canCreate, isFalse);
      } else {
        expect(await commitCedarTask(db, StagedCedarTask(job, attempt, goal.id, at)), isTrue);
        await tasks.activateCommitted(now: at);
        expect((await tasks.active())!['turnId'], 'fresh');
      }
    });
  }

  test('unstarted cancellation never borrows existing game outcomes or terminal ownership', () async {
    final staged = await stage();
    expect(await commitCedarTask(db, staged), isTrue);
    final session = (await activity.load())!;
    await activity.save(session.copyWith(events: [...session.events,
      CedarGameEvent(id: 'old-task-outcome', kind: 'outcome', action: 'explore',
        summary: '另一段游玩得到的结果', createdAt: at.add(const Duration(seconds: 1))),
    ], pendingTerminalKey: 'other-task-terminal', pendingTerminalSummary: '另一任务结果'));
    await activity.pause();
    final report = (await tasks.pendingReports()).single;
    expect(report['usedMs'], 0);
    expect(report['progressCount'], 0);
    expect(report['outcomes'], isEmpty);
    expect(report['terminalKey'], isEmpty);
    await commitCedarDelivery(db, CedarTimedPlayTaskStore.reportClaim(report), messageId: 'zero-report');
    expect(await tasks.acknowledge(report['id'] as String), isTrue);
    expect((await activity.loadSession('white_room'))!.pendingTerminalKey, 'other-task-terminal');
  });

  test('old semantic resume cannot overrule a newer UI pause', () async {
    final session = await activity.recordGuide(gameId: 'white_room', guide: '单人游戏。explore 探索。');
    await activity.pause();
    final pending = await db.createGenerationTurn(user: ChatMessage(id: 'resume-turn', role: 'user',
        content: '继续这局。', createdAt: at), assistantMessageId: 'resume-reply',
        model: 'deepseek-v4-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(pending.id))!;
    final attempt = (await db.captureGenerationAttemptFence(job))!;
    await activity.pause();
    final result = await activity.applyControl(operation: 'resume', gameId: session.gameId,
        sessionId: session.id, attemptFence: attempt);
    expect(result.state, LocalEffectAdmissionState.blocked);
    expect((await activity.loadSession(session.gameId))!.phase, CedarActivityPhase.paused);
    expect(await TurnExecutionStore(db).readEffect('resume-turn', TurnEffectSlot.cedarControl), isNull);
  });

  test('committed semantic control replays its fact without reversing later UI control', () async {
    final session = await activity.recordGuide(gameId: 'white_room', guide: '单人游戏。explore 探索。');
    await activity.pause();
    final pending = await db.createGenerationTurn(user: ChatMessage(id: 'resume-once', role: 'user',
        content: '现在继续。', createdAt: at), assistantMessageId: 'resume-once-reply',
        model: 'deepseek-v4-flash', reasoningEffort: 'high');
    final job = (await db.claimGenerationJob(pending.id))!;
    final attempt = (await db.captureGenerationAttemptFence(job))!;
    final first = await activity.applyControl(operation: 'resume', gameId: session.gameId,
        sessionId: session.id, attemptFence: attempt);
    expect(first.canCreate, isTrue);
    expect(first.receipt!.committed, isTrue);
    expect((await activity.loadSession(session.gameId))!.phase, isNot(CedarActivityPhase.paused));
    await activity.pause();
    final replay = await activity.applyControl(operation: 'resume', gameId: session.gameId,
        sessionId: session.id, attemptFence: attempt);
    expect(replay.state, LocalEffectAdmissionState.replay);
    expect((await activity.loadSession(session.gameId))!.phase, CedarActivityPhase.paused);
  });

  for (final path in ['normal', 'confirm', 'pause_before_stage', 'pause_after_stage', 'different_target']) {
    test('resume and twenty-minute task preserves original authority: $path', () async {
      var session = await activity.recordGuide(gameId: 'white_room', guide: '单人游戏。explore 探索。');
      await activity.pause();
      final pending = await db.createGenerationTurn(user: ChatMessage(id: 'resume-timed', role: 'user',
          content: '恢复这个游戏再玩20分钟。', createdAt: at), assistantMessageId: 'resume-timed-reply',
          model: 'deepseek-v4-flash', reasoningEffort: 'high');
      final job = (await db.claimGenerationJob(pending.id))!;
      final attempt = (await db.captureGenerationAttemptFence(job))!;
      final originalRevision = (await TurnExecutionStore(db).originalUserControlRevision('resume-timed'))!;
      final timerGoal = TurnTaskGoal(turnId: 'resume-timed', slot: TurnEffectSlot.cedarTimedRegistration,
          description: '恢复后继续20分钟', minutes: 20, durationText: '20分钟', target: {
            'game_id': path == 'different_target' ? 'other_game' : session.gameId,
            'user_control_revision': originalRevision,
          });
      expect(await TurnExecutionStore(db).saveGoals(attempt, [timerGoal]), isTrue);
      final resumed = await activity.applyControl(operation: 'resume', gameId: session.gameId,
          sessionId: session.id, attemptFence: attempt);
      expect(resumed.canCreate, isTrue);
      final resumedRevision = resumed.receipt!.result['userControlRevision'];
      expect(resumed.receipt!.result['previousUserControlRevision'], originalRevision);
      expect(resumedRevision, isNot(originalRevision));
      expect(await db.getSetting(CedarToyActivityStore.userControlRevisionKey), resumedRevision);
      if (path == 'pause_before_stage') await activity.pause();
      if (path == 'different_target') {
        session = await activity.recordGuide(gameId: 'other_game', guide: '单人游戏。explore 探索。');
      }
      final staged = await tasks.stage(turnId: 'resume-timed', assistantId: 'resume-timed-reply',
          session: session, minutes: 20, attemptFence: attempt,
          goalId: timerGoal.id, effectId: timerGoal.id, now: at);
      if (path == 'pause_before_stage' || path == 'different_target') {
        expect(staged.state, LocalEffectAdmissionState.blocked);
        expect(await tasks.active(), isNull);
        expect(await CedarPlaySessionStore(db).load(), isNull);
        return;
      }
      expect(staged.canCreate, isTrue);
      final saved = CedarTimedPlayTaskStore.decode(await db.getSetting(CedarTimedPlayTaskStore.pendingKey))!;
      expect(saved['originalUserControlRevision'], originalRevision);
      expect(saved['userControlRevision'], resumedRevision);
      if (path == 'pause_after_stage') {
        await activity.pause();
        expect(await commitCedarTask(db, StagedCedarTask(job, attempt, timerGoal.id, at)), isFalse);
        expect(await db.messageById('resume-timed-reply'), isNull);
        expect(await tasks.active(), isNull);
        return;
      }
      if (path == 'confirm') {
        await db.holdGenerationJobForUserDecision(job.id, runToken: job.runToken,
            partialReasoning: '', partialContent: '恢复后按20分钟计时。');
        final confirmed = (await db.claimGenerationDraftForConfirmation(job.id))!;
        final confirmedAttempt = (await db.captureGenerationAttemptFence(confirmed))!;
        final handoff = await tasks.prepareConfirmationHandoff(confirmedAttempt);
        expect(handoff, isNotNull);
        expect(await db.completeGenerationJobIfCurrent(jobId: confirmed.id, runToken: confirmed.runToken,
            generationAttempt: confirmedAttempt,
            turnCommitEvidence: TurnCommitEvidence(timedEffectIds: [timerGoal.id], timedHandoff: handoff),
            assistant: ChatMessage(id: confirmed.assistantMessageId, role: 'assistant',
                content: confirmed.partialContent, createdAt: at)), isTrue);
      } else {
        expect(await commitCedarTask(db, StagedCedarTask(job, attempt, timerGoal.id, at)), isTrue);
      }
      await tasks.activateCommitted(now: at);
      expect((await tasks.active())!['minutes'], 20);
      expect((await CedarPlaySessionStore(db).load())!.limitMs, 1200000);
      expect((await receipt('resume-timed'))!.result['activationState'], 'active');
    });
  }

  test('queued final transaction observes synchronous cancellation', () async {
    final staged = await stage();
    final handle = await db.database;
    final entered = Completer<void>();
    final release = Completer<void>();
    final holder = handle.transaction((txn) async {
      await txn.rawQuery('SELECT 1');
      entered.complete();
      await release.future.timeout(_barrierTimeout);
    });
    final holderCleanup = _drainForCleanup(holder);
    Future<void>? commitCleanup;
    try {
      await _waitForBarrier(entered.future, holder);
      var cancelled = false;
      final commit = commitCedarTask(db, staged, isCancelled: () => cancelled);
      commitCleanup = _drainForCleanup(commit);
      cancelled = true;
      release.complete();
      await holder.timeout(_barrierTimeout);
      expect(await commit.timeout(_barrierTimeout), isFalse);
      expect(await db.messageById('reply-first'), isNull);
      expect((await receipt('first'))!.state, LocalEffectState.staged);
      expect(CedarTimedPlayTaskStore.decode(await db.getSetting(
          CedarTimedPlayTaskStore.pendingKey))!['commitTicket'], isNull);
      final jobs = await handle.query('post_turn_jobs');
      expect(jobs, isEmpty);
    } finally {
      if (!release.isCompleted) release.complete();
      await holderCleanup;
      if (commitCleanup != null) await commitCleanup;
    }
  });

  test('explicit incomplete confirmation hands off only the original staged facts', () async {
    final staged = await stage();
    expect(await db.holdGenerationJobForUserDecision(staged.job.id,
        runToken: staged.job.runToken, partialReasoning: '', partialContent: '答应这次计时。'), isNotNull);
    final confirmed = (await db.claimGenerationDraftForConfirmation(staged.job.id))!;
    expect(confirmed.runToken, isNot(staged.job.runToken));
    final attempt = (await db.captureGenerationAttemptFence(confirmed))!;
    final handoff = await tasks.prepareConfirmationHandoff(attempt);
    expect(handoff, isNotNull);
    expect(await db.completeGenerationJobIfCurrent(jobId: confirmed.id,
        runToken: confirmed.runToken, generationAttempt: attempt,
        turnCommitEvidence: TurnCommitEvidence(timedEffectIds: [staged.effectId], timedHandoff: handoff),
        assistant: ChatMessage(id: confirmed.assistantMessageId, role: 'assistant',
            content: confirmed.partialContent, createdAt: at)), isTrue);
    await tasks.activateCommitted(now: at);
    expect((await tasks.active())!['id'], 'cedar-task:first');
    expect((await receipt('first'))!.runToken, staged.job.runToken);
  });

  test('regeneration cannot inherit an old stage and arbitrary handoff', () async {
    final staged = await stage();
    await db.holdGenerationJobForUserDecision(staged.job.id,
        runToken: staged.job.runToken, partialReasoning: '', partialContent: '旧草稿');
    expect(await db.restartGenerationDraft(staged.job.id), isTrue);
    final rerun = (await db.claimGenerationJob(staged.job.id))!;
    final attempt = (await db.captureGenerationAttemptFence(rerun))!;
    expect(await tasks.prepareConfirmationHandoff(attempt), isNull);
    expect(await commitCedarTask(db, StagedCedarTask(rerun, attempt, staged.effectId, at)), isFalse);
    expect(await db.messageById('reply-first'), isNull);
    expect((await receipt('first'))!.committed, isFalse);
  });

  for (final mutation in ['user', 'control']) {
    test('confirmation rejects changed $mutation after capturing the handoff', () async {
      final staged = await stage();
      await db.holdGenerationJobForUserDecision(staged.job.id,
          runToken: staged.job.runToken, partialReasoning: '', partialContent: '待确认');
      final confirmed = (await db.claimGenerationDraftForConfirmation(staged.job.id))!;
      final attempt = (await db.captureGenerationAttemptFence(confirmed))!;
      final handoff = await tasks.prepareConfirmationHandoff(attempt);
      expect(handoff, isNotNull);
      if (mutation == 'user') {
        await (await db.database).update('messages', {'content': '已经改变的请求'},
            where: 'id = ?', whereArgs: ['first']);
      } else {
        await activity.pause();
      }
      var committed = false;
      try {
        committed = await db.completeGenerationJobIfCurrent(jobId: confirmed.id,
            runToken: confirmed.runToken, generationAttempt: attempt,
            turnCommitEvidence: TurnCommitEvidence(timedEffectIds: [staged.effectId], timedHandoff: handoff),
            assistant: ChatMessage(id: 'reply-first', role: 'assistant', content: '待确认', createdAt: at));
      } on TurnCommitRejected { /* Expected transactional rejection. */ }
      expect(committed, isFalse);
      expect(await db.messageById('reply-first'), isNull);
      expect(await tasks.active(), isNull);
    });
  }

  for (final control in ['pause', 'switch_off']) {
    test('$control wins while activation awaits the real platform epoch', () async {
      final staged = await stage();
      expect(await commitCedarTask(db, staged), isTrue);
      // Prime the production lease's cached owner epoch so the barrier below
      // is exactly encodedPeriod's platform await after fence capture.
      expect(await db.tryAcquireLocalLease(CedarTimedPlayTaskStore.leaseKey), isTrue);
      await db.releaseLocalLease(CedarTimedPlayTaskStore.leaseKey);
      epochEntered = Completer<void>();
      epochRelease = Completer<void>();
      final activating = tasks.activateCommitted(now: at);
      final activatingCleanup = _drainForCleanup(activating);
      try {
        await _waitForBarrier(epochEntered!.future, activating);
        expect(await db.isLocalLeaseHeld(CedarTimedPlayTaskStore.leaseKey)
            .timeout(_barrierTimeout), isTrue);
        if (control == 'pause') {
          await activity.pauseAndRelease().timeout(_barrierTimeout);
        } else {
          await db.setSetting('cedar_toy_enabled', '0').timeout(_barrierTimeout);
          await activity.suspendForSwitch().timeout(_barrierTimeout);
        }
        epochRelease!.complete();
        await activating.timeout(_barrierTimeout);
        expect(await tasks.active(), isNull);
        expect(await CedarPlaySessionStore(db).load(), isNull);
        expect((await activity.loadSession('white_room'))!.phase, CedarActivityPhase.paused);
        expect((await tasks.pendingReports()).single['usedMs'], 0);
        expect((await receipt('first'))!.result['activationState'], 'ended');
        expect((await CedarTaskPresentation.load(db, (await activity.loadSession('white_room'))!))!.label, isNot(contains('待启动')));
      } finally {
        if (!epochRelease!.isCompleted) epochRelease!.complete();
        await activatingCleanup;
      }
    });
  }

  test('newly queued switch invalidates replacement without ending older active budget', () async {
    final first = await stage();
    expect(await commitCedarTask(db, first), isTrue);
    await tasks.activateCommitted(now: at);
    final periods = CedarPlaySessionStore(db);
    final old = (await periods.load())!;
    expect(await periods.save(old.tick(at.add(const Duration(seconds: 30)))), isTrue);
    final replacement = await stage('replacement');
    expect(await commitCedarTask(db, replacement), isTrue);
    await activity.queueSwitch(targetGameId: 'other_game');
    await tasks.activateCommitted(now: at.add(const Duration(minutes: 1)));
    expect((await tasks.active())!['id'], 'cedar-task:first');
    expect((await periods.load())!.usedMs, 30000);
    expect((await periods.load())!.clockId, old.clockId);
    expect((await tasks.pendingReports()).single['id'], 'cedar-task:replacement');
    expect((await tasks.pendingReports()).single['reason'], 'cannot_start');
  });

  test('SQL failure during replacement rolls back old report, clock and new activation', () async {
    final first = await stage();
    expect(await commitCedarTask(db, first), isTrue);
    await tasks.activateCommitted(now: at);
    final clockBefore = await db.getSetting(CedarPlaySessionStore.key);
    final second = await stage('replacement');
    expect(await commitCedarTask(db, second), isTrue);
    final pendingBefore = await db.getSetting(CedarTimedPlayTaskStore.pendingKey);
    final handle = await db.database;
    await handle.execute('''CREATE TEMP TRIGGER reject_replacement BEFORE INSERT ON settings
      WHEN NEW.key = 'cedar_timed_play_active_v1' AND NEW.value LIKE '%cedar-task:replacement%'
      BEGIN SELECT RAISE(ABORT, 'test replacement write failure'); END''');
    await expectLater(tasks.activateCommitted(now: at), throwsA(isA<DatabaseException>()));
    expect((await tasks.active())!['id'], 'cedar-task:first');
    expect(await tasks.pendingReports(), isEmpty);
    expect(await db.getSetting(CedarPlaySessionStore.key), clockBefore);
    expect(await db.getSetting(CedarTimedPlayTaskStore.pendingKey), pendingBefore);
    expect((await receipt('replacement'))!.result.containsKey('activationState'), isFalse);
    await handle.execute('DROP TRIGGER reject_replacement');
    await tasks.activateCommitted(now: at);
    expect((await tasks.active())!['id'], 'cedar-task:replacement');
    expect((await tasks.pendingReports()).single['reason'], 'replaced_by_user_task');
  });

  for (final committed in [false, true]) {
    test('restore normalizes ${committed ? 'accepted' : 'uncommitted'} pending in the import transaction', () async {
      final staged = await stage();
      if (committed) expect(await commitCedarTask(db, staged), isTrue);
      final backup = jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;
      await db.importAll(backup, runtimeSettingOverrides: {
        CedarTimedPlayTaskStore.pendingKey: '', CedarPlaySessionStore.key: '',
      });
      expect(await db.getSetting(CedarTimedPlayTaskStore.pendingKey), '');
      await tasks.activateCommitted(now: at);
      expect(await tasks.active(), isNull);
      expect(await CedarPlaySessionStore(db).load(), isNull);
      if (committed) {
        final report = (await tasks.pendingReports()).single;
        expect(report['reason'], 'restored_before_activation');
        expect(report['usedMs'], 0);
        expect((await receipt('first'))!.result['activationState'], 'ended');
        expect((await CedarTaskPresentation.load(db, (await activity.loadSession('white_room'))!))!.label, isNot(contains('待启动')));
      } else {
        expect(await tasks.pendingReports(), isEmpty);
      }
    });
  }

  test('message existence or revised message body cannot acknowledge a report', () async {
    final report = await finishTask();
    final claim = CedarTimedPlayTaskStore.reportClaim(report);
    final shareId = 'cedar-share:cedar-report:${report['id']}';
    await db.insertMessage(ChatMessage(id: shareId, role: 'assistant', content: '你好', createdAt: at));
    expect(await tasks.acknowledge(report['id'] as String), isFalse);
    expect(await tasks.queueReport(), 'cedar-report:${report['id']}');
    await commitCedarDelivery(db, claim, messageId: 'real-report');
    await (await db.database).update('messages', {'content': '换成无关正文'},
        where: 'id = ?', whereArgs: ['real-report']);
    expect(await tasks.acknowledge(report['id'] as String), isFalse);
    expect(await tasks.pendingReports(), hasLength(1));
    await commitCedarDelivery(db, claim, messageId: 'real-report-again');
    expect(await tasks.acknowledge(report['id'] as String), isTrue);
    expect(await tasks.pendingReports(), isEmpty);
    expect((await receipt('first'))!.result['activationState'], 'ended');
  });

  test('queued acknowledgement preserves a report appended by the winning transaction', () async {
    final report = await finishTask();
    await commitCedarDelivery(db, CedarTimedPlayTaskStore.reportClaim(report), messageId: 'delivered');
    final next = {...report, 'id': 'cedar-task:other', 'turnId': 'other'};
    final handle = await db.database;
    final entered = Completer<void>();
    final release = Completer<void>();
    final holder = handle.transaction((txn) async {
      entered.complete();
      await release.future.timeout(_barrierTimeout);
      await CedarTimedPlayTaskStore.finishInTransaction(txn, next,
          usedMs: 0, reason: 'cannot_start', now: at);
    });
    final holderCleanup = _drainForCleanup(holder);
    Future<void>? ackCleanup;
    try {
      await _waitForBarrier(entered.future, holder);
      final ack = tasks.acknowledge(report['id'] as String);
      ackCleanup = _drainForCleanup(ack);
      release.complete();
      await holder.timeout(_barrierTimeout);
      expect(await ack.timeout(_barrierTimeout), isTrue);
      expect((await tasks.pendingReports()).single['id'], 'cedar-task:other');
    } finally {
      if (!release.isCompleted) release.complete();
      await holderCleanup;
      if (ackCleanup != null) await ackCleanup;
    }
  });

  test('temporarily excluded report stays pending while the next report is selected', () async {
    final first = await finishTask('first');
    final second = await finishTask('second');
    expect(await tasks.queueReport(excludedReportIds: {first['id'] as String}),
        'cedar-report:${second['id']}');
    expect(await tasks.pendingReports(), hasLength(2));
    expect(await tasks.queueReport(excludedReportIds: {first['id'] as String, second['id'] as String}), isNull);
    expect(await tasks.pendingReports(), hasLength(2));
    expect(await tasks.queueReport(), 'cedar-report:${first['id']}');
  });

  test('report delivery only clears its exact terminal and preserves a newer one', () async {
    final staged = await stage();
    expect(await commitCedarTask(db, staged), isTrue);
    await tasks.activateCommitted(now: at);
    var session = (await activity.load())!;
    session = session.copyWith(pendingTerminalKey: 'terminal-one', pendingTerminalSummary: '第一局结果');
    await activity.save(session);
    await tasks.finish((await tasks.active())!, usedMs: 1000, reason: 'game_finished', now: at);
    final report = (await tasks.pendingReports()).single;
    expect(report['terminalKey'], 'terminal-one');
    await commitCedarDelivery(db, CedarTimedPlayTaskStore.reportClaim(report), messageId: 'report-body');
    await activity.save(session.copyWith(pendingTerminalKey: 'terminal-two', pendingTerminalSummary: '第二局结果'));
    expect(await tasks.acknowledge(report['id'] as String), isTrue);
    expect((await activity.loadSession('white_room'))!.pendingTerminalKey, 'terminal-two');
    expect(await activity.markTerminalDelivered(gameId: 'white_room', terminalKey: 'terminal-two'), isFalse);
    final current = (await activity.loadSession('white_room'))!;
    await commitCedarDelivery(db, CedarToyActivityStore.terminalClaim(current), messageId: 'terminal-body');
    expect(await activity.markTerminalDelivered(gameId: 'white_room', sessionId: 'wrong-session',
        terminalKey: 'terminal-two'), isFalse);
    expect(await activity.markTerminalDelivered(gameId: 'white_room', sessionId: current.id,
        terminalKey: 'terminal-two'), isTrue);
    expect((await activity.loadSession('white_room'))!.pendingTerminalKey, isEmpty);
  });
}
