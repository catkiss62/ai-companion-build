import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_registry.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_runner.dart';
import 'package:ai_companion_localfirst/core/agent/turn_execution_store.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_control.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/creative/creative_worker.dart';
import 'package:ai_companion_localfirst/core/creative/creative_workspace.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/generation_attempt_fence.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/generation_job.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:ai_companion_localfirst/core/storage/pending_media_owner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'creative_agent_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CreativeStore store;
  const text = '请做一件可以互动的小作品';
  const channel = MethodChannel('ai_companion/system');
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CreativeStore(db);
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'fixture-only'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CreativeWorker.preview, (method) async => fixture.nativePreviewResult(method.arguments));
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CreativeWorker.preview, null);
    await db.closeForTesting();
  });
  Future<Map<String, dynamic>> seeded([String request = 'old-work']) => store.commission(
    deepThinking: true, requestId: request, messageId: 'card-$request',
    brief: '一盏灯', requestQuote: '灯', latestText: '做一盏灯');
  Future<GenerationJob> start() async {
    final job = await db.createGenerationTurn(user: ChatMessage(id: 'user', role: 'user',
      content: text, createdAt: DateTime.now()), assistantMessageId: 'reply',
      model: 'deepseek-flash', reasoningEffort: 'high', deepThinking: true);
    return (await db.claimGenerationJob(job.id))!;
  }
  Future<CreativeCommissionResult> register(GenerationAttemptFence attempt,
      {String brief = '一盏互动的灯', String interaction = 'unspecified', String workId = '',
      String? expectedRequestId, bool Function()? isCancelled}) => store.commissionResult(deepThinking: true,
        requestId: turnEffectId(attempt.userMessageId, TurnEffectSlot.creativeCommission),
        messageId: attempt.assistantMessageId, userMessageId: attempt.userMessageId,
        brief: brief, requestQuote: text, latestText: text, workId: workId,
        interaction: interaction, attemptFence: attempt, isCancelled: isCancelled,
        expectedRequestId: expectedRequestId);
  Future<void> goal(GenerationAttemptFence attempt, TurnEffectSlot slot,
      {Map<String, String> target = const {}}) async {
    expect(await TurnExecutionStore(db).saveGoals(attempt, [TurnTaskGoal(
      turnId: attempt.userMessageId, slot: slot, description: text,
      target: slot == TurnEffectSlot.creativeCommission && target.isEmpty
        ? const {'work_id': '', 'request_id': '', 'target_kind': 'new_work'} : target)]), isTrue);
  }
  Future<List<AgentToolResult>> run(GenerationAttemptFence attempt,
      {bool commission = true, String workId = '', String brief = '一盏互动的灯',
      String? targetKind,
      GenerationCancellationToken? cancellation, AgentToolActivityCallback? onActivity,
      bool includeOwner = true}) => AgentToolRunner(db: db, android: AndroidBridge.instance).runPlan(
        AgentToolPlan(calls: [AgentToolCall(
          toolId: commission ? AgentToolRegistry.creativeCommission.id : AgentToolRegistry.creativeStop.id,
          reasonTag: 'explicit_request', arguments: {'brief': brief, 'request_quote': text, 'work_id': workId,
            if (commission) 'target_kind': targetKind ?? (workId.isEmpty ? 'new_work' : 'existing')})]),
        deepThinking: commission, eventScopeId: attempt.jobId,
        userMessageId: attempt.userMessageId, assistantMessageId: attempt.assistantMessageId,
        latestUserText: text, pendingMediaOwner: includeOwner ? PendingMediaOwner.generation(attempt) : null,
        cancellationToken: cancellation, onActivity: onActivity);

  test('card target survives a worker checkpoint queued before Stop; late checkpoint cannot undo Stop', () async {
    final before = await seeded();
    final target = (await store.captureControlTarget(before))!;
    final handle = await db.database;
    final entered = Completer<void>(), release = Completer<void>();
    final checkpoint = handle.transaction((txn) async {
      entered.complete(); await release.future;
      await txn.update('settings', {'value': jsonEncode({...before, 'status': 'building', 'agent_step': 9})},
        where: 'key = ?', whereArgs: [CreativeStore.key(target.workId)]);
    });
    await entered.future;
    final stop = store.stopTarget(target);
    await Future<void>.delayed(Duration.zero);
    release.complete(); await checkpoint;
    expect((await stop).status, CreativeControlStatus.applied);
    expect((await store.get(target.workId))['agent_step'], 9);
    expect((await store.get(target.workId))['status'], 'paused');
    expect(await store.write(before, {...before, 'status': 'building', 'agent_step': 10}), isFalse);
    expect((await store.resumeTarget(target)).applied, isTrue);
    expect(await store.write(before, {...before, 'status': 'ready'}), isFalse);
    expect((await store.get(target.workId))['status'], 'queued');
  });

  test('Delete reads latest checkpoint in its transaction and late worker cannot recreate sources', () async {
    final before = await seeded();
    final target = (await store.captureControlTarget(before))!;
    final hash = CreativeContract.hash('<p>draft</p>');
    expect(await store.write(before, {...before, 'agent_step': 7, 'draft': hash},
      extra: {'${CreativeContract.sourcePrefix}$hash': '<p>draft</p>'}), isTrue);
    expect((await store.deleteTarget(target)).status, CreativeControlStatus.deleted);
    expect((await store.get(target.workId))['status'], 'deleted');
    expect(await db.getSetting('${CreativeContract.sourcePrefix}$hash'), isNull);
    expect(await store.write(before, {...before, 'status': 'building'},
      extra: {'${CreativeContract.sourcePrefix}$hash': '<p>draft</p>'}), isFalse);
    expect(await db.getSetting('${CreativeContract.sourcePrefix}$hash'), isNull);
  });

  test('ready completion wins over old Stop and Resume menus', () async {
    final before = await seeded();
    final target = (await store.captureControlTarget(before))!;
    final hash = CreativeContract.hash('<p>ready</p>');
    await store.write(before, {...before, 'status': 'ready', 'current': hash,
      'completed_request': before['request_id']}, extra: {'${CreativeContract.sourcePrefix}$hash': '<p>ready</p>'});
    expect((await store.stopTarget(target)).status, CreativeControlStatus.alreadyFinished);
    expect((await store.resumeTarget(target)).status, CreativeControlStatus.alreadyFinished);
    final ready = await store.get(target.workId);
    expect(ready['status'], 'ready'); expect(ready['current'], hash);
    expect(ready['completed_request'], before['request_id']);
  });

  test('old delete dialog cannot target a newer commission or imported same ID', () async {
    final before = await seeded();
    final target = (await store.captureControlTarget(before))!;
    await store.stopTarget(target);
    await store.commission(deepThinking: true, requestId: 'new-request', messageId: 'new-card',
      brief: '改蓝色', requestQuote: '改蓝色', latestText: '改蓝色', workId: target.workId);
    expect((await store.deleteTarget(target)).status, CreativeControlStatus.staleTarget);
    final newer = await store.get(target.workId);
    final importTarget = (await store.captureControlTarget(newer))!;
    await db.importAll(jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>,
      runtimeSettingOverrides: {'runtime_state_epoch_v1': 'different-install'});
    expect((await store.deleteTarget(importTarget)).status, CreativeControlStatus.staleTarget);
    expect((await store.get(target.workId))['request_id'], 'new-request');
  });

  test('queued registration loses to synchronous Stop even when durable cancellation is also queued', () async {
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    final handle = await db.database;
    final entered = Completer<void>(), release = Completer<void>();
    final blocker = handle.transaction((txn) async { entered.complete(); await release.future; });
    await entered.future;
    var cancelled = false;
    final registration = register(attempt, isCancelled: () => cancelled);
    await Future<void>.delayed(Duration.zero);
    cancelled = true;
    final stop = db.cancelGenerationJobByUser(job.id);
    release.complete(); await blocker; await stop;
    expect((await registration).status, CreativeCommissionStatus.staleAttempt);
    expect(await store.list(), isEmpty);
    expect(await TurnExecutionStore(db).readEffect(attempt.userMessageId, TurnEffectSlot.creativeCommission), isNull);
    expect(await db.getSetting('${CreativeContract.receiptPrefix}${attempt.assistantMessageId}'), isNull);
  });

  test('Stop after tentative commission writes rolls back work, workspace, card and effect together', () async {
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    final entered = Completer<void>(), release = Completer<void>();
    var cancelled = false;
    store = CreativeStore(db, beforeLocalCommit: (txn) async {
      expect(await txn.query('settings', where: 'key LIKE ?',
        whereArgs: ['${CreativeContract.metaPrefix}%']), hasLength(1));
      expect(await txn.query('settings', where: 'key LIKE ?',
        whereArgs: ['${CreativeWorkspace.prefix}%']), hasLength(1));
      expect(await txn.query('settings', where: 'key = ?',
        whereArgs: [TurnExecutionStore.effectKey(attempt.userMessageId, TurnEffectSlot.creativeCommission)]), hasLength(1));
      entered.complete(); await release.future;
    });
    final registration = register(attempt, isCancelled: () => cancelled);
    await entered.future;
    cancelled = true;
    final stop = db.cancelGenerationJobByUser(job.id);
    release.complete();
    expect((await registration).status, CreativeCommissionStatus.staleAttempt);
    await stop;
    expect(await store.list(), isEmpty);
    final handle = await db.database;
    expect(await handle.query('settings', where: 'key LIKE ?', whereArgs: ['${CreativeWorkspace.prefix}%']), isEmpty);
    expect(await db.getSetting('${CreativeContract.receiptPrefix}${attempt.assistantMessageId}'), isNull);
    expect(await TurnExecutionStore(db).readEffect(attempt.userMessageId, TurnEffectSlot.creativeCommission), isNull);
  });

  test('chat Stop after tentative work-control writes rolls back both pause and control receipt', () async {
    final before = await seeded();
    final target = (await store.captureControlTarget(before))!;
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    final entered = Completer<void>(), release = Completer<void>();
    var cancelled = false;
    store = CreativeStore(db, beforeLocalCommit: (txn) async {
      final row = (await txn.query('settings', where: 'key = ?', whereArgs: [CreativeStore.key(target.workId)])).single;
      expect(CreativeContract.decode(row['value'] as String)['status'], 'paused');
      expect(await TurnExecutionStore.readEffectInTransaction(txn,
        turnId: attempt.userMessageId, slot: TurnEffectSlot.creativeControl), isNotNull);
      entered.complete(); await release.future;
    });
    final pause = store.stopTarget(target, attemptFence: attempt, isCancelled: () => cancelled);
    await entered.future;
    cancelled = true;
    final stop = db.cancelGenerationJobByUser(job.id);
    release.complete();
    expect((await pause).status, CreativeControlStatus.staleTarget);
    await stop;
    expect(await store.get(target.workId), before);
    expect(await TurnExecutionStore(db).readEffect(attempt.userMessageId, TurnEffectSlot.creativeControl), isNull);
  });

  test('same turn replays exactly once, different full brief, interaction or target conflicts', () async {
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    final longBrief = '${List.filled(8100, '灯').join()}甲';
    final first = await register(attempt, brief: longBrief);
    expect(first.accepted, isTrue);
    expect((await register(attempt, brief: longBrief)).replayed, isTrue);
    for (final outcome in [
      await register(attempt, brief: '${longBrief.substring(0, longBrief.length - 1)}乙'),
      await register(attempt, brief: longBrief, interaction: 'companion'),
      await register(attempt, brief: longBrief, workId: first.work['id'] as String),
    ]) { expect(outcome.status, CreativeCommissionStatus.conflict); }
    expect(await store.list(), hasLength(1));
    expect((await store.get(first.work['id'] as String))['brief'], hasLength(8000));
    await db.cancelGenerationJobByUser(job.id);
    expect((await register(attempt, brief: longBrief)).replayed, isTrue);
    expect((await store.get(first.work['id'] as String))['status'], 'queued');
  });

  test('proven legacy registration occupies the stable slot before a later different target', () async {
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    final legacy = await store.commission(deepThinking: true, requestId: job.id,
      messageId: job.assistantMessageId, userMessageId: job.userMessageId,
      brief: '一盏互动的灯', requestQuote: text, latestText: text);
    final historical = {...legacy}..remove('commission_payload_hash')..remove('commission_interaction');
    await store.write(legacy, historical);
    final replay = await register(attempt);
    expect(replay.replayed, isTrue); expect(replay.work['id'], legacy['id']);
    final receipt = (await TurnExecutionStore(db).readEffect(attempt.userMessageId, TurnEffectSlot.creativeCommission))!;
    expect(receipt.result['request_id'], job.id);
    final other = await seeded('other');
    expect((await register(attempt, workId: other['id'] as String,
      expectedRequestId: other['request_id'] as String)).status, CreativeCommissionStatus.conflict);
    expect(await store.list(), hasLength(2));
  });

  for (final legacyKind in ['new work', 'revision', 'superseded revision']) {
    test('first upgraded Agent call cannot bypass a legacy $legacyKind by selecting another work', () async {
      final original = legacyKind == 'new work' ? null : await seeded('original');
      if (original != null) await store.stop(original['id'] as String);
      final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
      final legacy = await store.commission(deepThinking: true, requestId: job.id,
        messageId: job.assistantMessageId, userMessageId: job.userMessageId,
        brief: '一盏互动的灯', requestQuote: text, latestText: text,
        workId: original?['id'] as String? ?? '');
      await store.write(legacy, {...legacy}..remove('commission_payload_hash')..remove('commission_interaction'));
      if (legacyKind == 'superseded revision') {
        await store.stop(legacy['id'] as String);
        await store.commission(deepThinking: true, requestId: 'later', messageId: 'later-card',
          brief: '新委托', requestQuote: '新委托', latestText: '新委托', workId: legacy['id'] as String);
      }
      final other = await seeded('other'); final otherId = other['id'] as String;
      await store.stop(otherId);
      final before = await store.get(otherId);
      await goal(attempt, TurnEffectSlot.creativeCommission, target: {
        'work_id': otherId, 'request_id': other['request_id'] as String, 'target_kind': 'existing'});
      expect((await run(attempt, workId: otherId)).single.status, AgentToolStatus.blocked);
      expect(await store.get(otherId), before);
      expect(await store.list(), hasLength(2));
      expect(await TurnExecutionStore(db).readEffect(attempt.userMessageId, TurnEffectSlot.creativeCommission), isNull);
    });
  }

  test('a revision proposal cannot apply to a later request on the same work ID', () async {
    final old = await seeded(); final id = old['id'] as String;
    await store.stop(id);
    await store.commission(deepThinking: true, requestId: 'replacement', messageId: 'replacement-card',
      brief: '新委托', requestQuote: '新委托', latestText: '新委托', workId: id);
    await store.stop(id);
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    expect((await register(attempt, workId: id, expectedRequestId: old['request_id'] as String)).status,
      CreativeCommissionStatus.conflict);
    expect((await store.get(id))['request_id'], 'replacement');
    expect((await store.get(id))['status'], 'paused');
    expect(await TurnExecutionStore(db).readEffect(attempt.userMessageId, TurnEffectSlot.creativeCommission), isNull);
  });

  for (final invalidation in ['new-attempt', 'source-removed', 'source-edited', 'import']) {
    test('$invalidation refuses the original unregistered attempt', () async {
      final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
      final handle = await db.database;
      if (invalidation == 'new-attempt') {
        await handle.update('generation_jobs', {'updated_at': 0}, where: 'id = ?', whereArgs: [job.id]);
        expect((await db.claimGenerationJob(job.id))!.runToken, isNot(job.runToken));
      } else if (invalidation == 'source-removed') {
        await handle.delete('messages', where: 'id = ?', whereArgs: [job.userMessageId]);
      } else if (invalidation == 'source-edited') {
        await handle.update('messages', {'content': '不要制作了'}, where: 'id = ?', whereArgs: [job.userMessageId]);
      } else {
        await db.setSetting('runtime_state_epoch_v1', 'restored');
      }
      expect((await register(attempt)).status, CreativeCommissionStatus.staleAttempt);
      expect(await store.list(), isEmpty);
    });
  }

  test('real Agent commission cannot fall back without its original attempt and semantic goal', () async {
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    expect((await run(attempt)).single.status, AgentToolStatus.blocked);
    await goal(attempt, TurnEffectSlot.creativeCommission);
    expect((await run(attempt, includeOwner: false)).single.status, AgentToolStatus.blocked);
    expect(await store.list(), isEmpty);
    final source = await File('lib/core/agent/agent_tool_runner.dart').readAsString();
    expect(source, contains('.commissionResult('));
    expect(source, isNot(contains('.commission(')));
  });

  test('real Agent cannot turn a goal to revise work A into a tool call revising work B', () async {
    final a = await seeded('A'), b = await seeded('B');
    await store.stop(a['id'] as String); await store.stop(b['id'] as String);
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    await goal(attempt, TurnEffectSlot.creativeCommission, target: {
      'work_id': a['id'] as String, 'request_id': a['request_id'] as String, 'target_kind': 'existing'});
    expect((await run(attempt, workId: b['id'] as String)).single.status, AgentToolStatus.blocked);
    expect((await store.get(a['id'] as String))['request_id'], 'A');
    expect((await store.get(b['id'] as String))['request_id'], 'B');
    expect(await TurnExecutionStore(db).readEffect(attempt.userMessageId, TurnEffectSlot.creativeCommission), isNull);
  });

  test('real Agent new-work goal cannot become a revision of an existing work', () async {
    final work = await seeded(); final id = work['id'] as String;
    await store.stop(id);
    final before = await store.get(id);
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    await goal(attempt, TurnEffectSlot.creativeCommission);
    expect((await run(attempt, workId: id, targetKind: 'new_work')).single.status, AgentToolStatus.blocked);
    expect(await store.get(id), before);
    expect(await TurnExecutionStore(db).readEffect(attempt.userMessageId, TurnEffectSlot.creativeCommission), isNull);
  });

  test('real Agent revision retries its original goal without resetting work or claiming a later revision', () async {
    final old = await seeded(); final id = old['id'] as String;
    await store.stop(id);
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    await goal(attempt, TurnEffectSlot.creativeCommission, target: {
      'work_id': id, 'request_id': old['request_id'] as String, 'target_kind': 'existing'});
    expect((await run(attempt, workId: id)).single.status, AgentToolStatus.succeeded);
    final registered = await store.get(id);
    expect(registered['request_id'], turnEffectId(attempt.userMessageId, TurnEffectSlot.creativeCommission));
    await store.write(registered, {...registered, 'model_turns': 5, 'agent_step': 9});
    expect((await run(attempt, workId: id)).single.status, AgentToolStatus.succeeded);
    expect((await store.get(id))['model_turns'], 5);
    expect((await store.get(id))['agent_step'], 9);
    await store.stop(id);
    final later = await store.commission(deepThinking: true, requestId: 'later', messageId: 'later-card',
      brief: '新委托', requestQuote: '新委托', latestText: '新委托', workId: id);
    final replay = (await run(attempt, workId: id)).single;
    expect(replay.status, AgentToolStatus.succeeded);
    expect(replay.promptData, contains('superseded'));
    expect(await store.get(id), later);
    final receipt = (await TurnExecutionStore(db).readEffect(attempt.userMessageId, TurnEffectSlot.creativeCommission))!;
    expect(receipt.result['request_id'], registered['request_id']);
  });

  test('real Agent Stop while its database work is queued cannot leave work or a receipt', () async {
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    await goal(attempt, TurnEffectSlot.creativeCommission);
    final entered = Completer<void>(), release = Completer<void>();
    final handle = await db.database;
    final blocker = handle.transaction((txn) async { entered.complete(); await release.future; });
    await entered.future;
    final cancellation = GenerationCancellationToken();
    final running = run(attempt, cancellation: cancellation).catchError((Object error) {
      if (error is GenerationCancelledByUserException) return <AgentToolResult>[];
      throw error;
    });
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    final stopped = db.cancelGenerationJobByUser(job.id);
    release.complete(); await blocker; await stopped;
    // The public runner may report cancelled or propagate its cancellation.
    await running;
    expect(await store.list(), isEmpty);
    expect(await TurnExecutionStore(db).readEffect(attempt.userMessageId, TurnEffectSlot.creativeCommission), isNull);
  });

  test('real Agent accepted commission keeps building after chat Stop, with one stable receipt', () async {
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    await goal(attempt, TurnEffectSlot.creativeCommission);
    expect((await run(attempt)).single.status, AgentToolStatus.succeeded);
    expect((await run(attempt)).single.status, AgentToolStatus.succeeded);
    expect((await run(attempt, brief: '第二个完全不同的作品')).single.status, AgentToolStatus.blocked);
    await db.cancelGenerationJobByUser(job.id);
    final id = (await store.list()).single['id'] as String;
    var models = 0;
    final worker = CreativeWorker(db, clientFactory: (abort) => DeepSeekClient(abortWhen: abort,
      streamClientFactory: () => MockClient((_) async {
        models++;
        return fixture.response(fixture.sse([fixture.plan(), fixture.write(fixture.repaired),
          fixture.previewCall(), fixture.call('work_finish', {})]));
      })));
    await worker.runOnce();
    expect(models, 1); expect((await store.get(id))['status'], 'ready');
    final effect = (await TurnExecutionStore(db).readEffect(attempt.userMessageId, TurnEffectSlot.creativeCommission))!;
    expect(effect.committed, isTrue); expect(effect.result['work_id'], id);
  });

  test('real Agent control replay never stops a work resumed after the first committed Stop', () async {
    final work = await seeded(); final id = work['id'] as String;
    final job = await start(); final attempt = (await db.captureGenerationAttemptFence(job))!;
    await goal(attempt, TurnEffectSlot.creativeControl, target: {
      'work_id': id, 'request_id': work['request_id'] as String, 'operation': 'stop'});
    expect((await run(attempt, commission: false, workId: id)).single.status, AgentToolStatus.succeeded);
    expect((await store.get(id))['status'], 'paused');
    await store.resume(id);
    final repeated = (await run(attempt, commission: false, workId: id)).single;
    expect(repeated.status, AgentToolStatus.succeeded);
    expect(repeated.promptData, contains('queued'));
    expect((await store.get(id))['status'], 'queued');
  });
}
