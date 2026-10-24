import 'dart:convert';

import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_runner.dart';
import 'package:ai_companion_localfirst/core/agent/turn_execution_store.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_summary_store.dart';
import 'package:ai_companion_localfirst/core/database/generation_attempt_fence.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_http_client.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:ai_companion_localfirst/core/storage/pending_media_owner.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

McpToolOutcome snapshot({bool error = false}) => McpToolOutcome(content: const [],
  isError: error, structuredContent: {'ok': !error, 'status': 'playing',
    'your_turn': true, 'next_actor': 'companion'});

class FakeCedar extends CedarToyClient {
  FakeCedar() : super(token: 'ctai_v1_test');
  final actions = <String>[];
  bool failNext = false;
  Map<String, Object?>? rooms;
  @override
  Future<McpToolOutcome> play(String game, String action, Map<String, Object?> params,
      {GenerationCancellationToken? cancellationToken}) async {
    actions.add(action);
    if (failNext) { failNext = false; throw const McpHttpException('network_or_timeout'); }
    if (rooms != null) return McpToolOutcome(content: const [], isError: false,
      structuredContent: action == 'rooms' ? rooms : {'ok': true, 'status': 'playing',
        'room_id': 'ROOM', 'your_turn': false, 'next_actor': 'wait', 'next_call': {
          'game': game, 'action': 'state', 'params': {'room_id': 'ROOM', 'wait': true}}});
    return snapshot();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CedarToyActivityStore activity;
  const channel = MethodChannel('ai_companion/system');
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'cedar_toy_token': 'ctai_v1_test'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async =>
          call.method == 'runtimeProcessEpoch' ? 'review-runtime' : null);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    activity = CedarToyActivityStore(db);
  });
  tearDown(() async {
    await db.closeForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
  });

  Future<GenerationAttemptFence> turn([String id = 'u']) async {
    final pending = await db.createGenerationTurn(user: ChatMessage(id: id,
      role: 'user', content: '去花园看看再种花浇水', createdAt: DateTime.now().subtract(const Duration(seconds: 2))),
      assistantMessageId: 'a-$id', model: 'deepseek-v4-flash', reasoningEffort: 'high');
    return (await db.captureGenerationAttemptFence((await db.claimGenerationJob(pending.id))!))!;
  }
  Future<GenerationAttemptFence> regenerate(GenerationAttemptFence old) async {
    expect(await db.completeGenerationJobIfCurrent(jobId: old.jobId, runToken: old.runToken,
      assistant: ChatMessage(id: old.assistantMessageId, role: 'assistant', content: '照料过花了',
        createdAt: DateTime.now().subtract(const Duration(seconds: 1)))), isTrue);
    final reopened = (await db.restartLatestCompletedReply(old.assistantMessageId))!;
    return (await db.captureGenerationAttemptFence((await db.claimGenerationJob(reopened.id))!))!;
  }
  Future<void> garden() async {
    await activity.saveCatalog('garden 花园与猫');
    await activity.recordGuide(gameId: 'garden', guide: 'solo 单人；actions: look state plant water');
  }
  AgentToolRunner runner(FakeCedar client) => AgentToolRunner(db: db,
    android: AndroidBridge.instance, cedarClientFactory: (_) => client);
  Future<AgentToolResult> play(AgentToolRunner runner, GenerationAttemptFence attempt,
      String action, {int index = 0}) async => (await runner.runPlan(AgentToolPlan(calls: [
        AgentToolCall(toolId: 'cedar_toy.play', reasonTag: 'explicit_request', arguments: {
          'game': 'garden', 'action': action, 'params_json': '{}', 'participation_mode': 'solo'})]),
      userMessageId: attempt.userMessageId, assistantMessageId: attempt.assistantMessageId,
      eventScopeId: 'user_turn:${attempt.jobId}', callIndexOffset: index,
      pendingMediaOwner: PendingMediaOwner.generation(attempt))).single;

  test('look then two writes execute, regeneration only replays matching writes', () async {
    await garden();
    final attempt = await turn();
    final client = FakeCedar();
    final original = runner(client);
    for (final action in ['look', 'plant', 'water']) {
      expect((await play(original, attempt, action, index: client.actions.length)).status,
        AgentToolStatus.succeeded);
    }
    expect(client.actions, ['look', 'plant', 'water']);
    final retry = await regenerate(attempt);
    final regenerated = runner(client);
    final plant = await play(regenerated, retry, 'plant');
    expect(plant.status, AgentToolStatus.succeeded);
    expect(plant.submittedArguments['action'], 'plant');
    expect((await play(regenerated, retry, 'water', index: 1)).status, AgentToolStatus.succeeded);
    expect((await play(regenerated, retry, 'plant', index: 2)).status, AgentToolStatus.blocked);
    expect(client.actions, ['look', 'plant', 'water']);
  });

  test('an unsent write frees its slot and a recovered snapshot does not replay the unknown write', () async {
    await garden();
    final attempt = await turn();
    final client = FakeCedar();
    final current = runner(client);
    final old = await activity.beginExecution(gameId: 'garden', action: 'plant');
    expect(await activity.admitRemoteDispatch(gameId: 'garden', action: 'plant', params: {}, executionId: old), isTrue);
    expect((await play(current, attempt, 'water')).errorCode, 'cedar_unresolved_write');
    expect(await TurnExecutionStore(db).remoteEffect('u'), isNull);
    expect((await play(current, attempt, 'state', index: 1)).status, AgentToolStatus.succeeded);
    client.failNext = true;
    expect((await play(current, attempt, 'water', index: 2)).status, AgentToolStatus.failed);
    final receipt = (await TurnExecutionStore(db).remoteEffect('u'))!;
    expect(receipt['state'], 'dispatching');
    expect((await play(current, attempt, 'state', index: 3)).status, AgentToolStatus.succeeded);
    final retry = await regenerate(attempt);
    expect((await play(runner(client), retry, 'water')).status, AgentToolStatus.blocked);
    expect(client.actions.where((a) => a == 'water'), hasLength(1));
    final reconciled=(await TurnExecutionStore(db).remoteEffect('u'))!;
    expect(reconciled['state'], 'reconciled');
    expect(reconciled['goal_satisfied'],false);
    expect(reconciled.containsKey('outcome'),false);
  });

  test('ordered receipt rejects a changed action and preserves unknown writes', () async {
    final attempt = await turn();
    final store = TurnExecutionStore(db);
    const first = {'action': 'plant'};
    expect(await store.reserveRemoteEffect(attempt, first), isNull);
    expect((await store.reserveRemoteEffect(attempt, {'action': 'water'}))!['state'], 'conflict');
    expect((await store.reserveRemoteEffect(attempt, {'action': 'water'}, effectIndex: 1))!['state'], 'dispatching');
    await store.releaseUnsentRemoteEffect(attempt, first, effectIndex: 0);
    expect(await store.remoteEffect('u'), isNull);
    expect(await store.reserveRemoteEffect(attempt, {'action': 'water'}), isNull);
  });

  test('read call carrying a room message is a write', () {
    expect(CedarPlatformActionPolicy.isReadOnlyCall('state', {}), isTrue);
    expect(CedarPlatformActionPolicy.isReadOnlyCall('state', {'message': '你好'}), isFalse);
  });

  test('legacy receipts still prevent an unprovable replay or a different write', () async {
    final attempt = await turn();
    const payload = {'action': 'plant'};
    await db.setSetting('${TurnExecutionStore.remoteEffectPrefix}u', jsonEncode({
      'state': 'known', 'payload_hash': turnPayloadHash(payload), 'outcome': '旧版真实结果'}));
    final store = TurnExecutionStore(db);
    expect((await store.reserveRemoteEffect(attempt, payload))!['outcome'], '旧版真实结果');
    expect((await store.reserveRemoteEffect(attempt, {'action': 'water'}, effectIndex: 1))!['state'], 'conflict');
  });

  for (final target in [<String, Object?>{}, <String, Object?>{'slot': 2}, <String, Object?>{'room_id': 'ROOM'}]) {
    test('a fresh successful snapshot reconciles the same target $target', () async {
      await garden();
      final write = await activity.beginExecution(gameId: 'garden', action: 'plant');
      expect(await activity.admitRemoteDispatch(gameId: 'garden', action: 'plant', params: target, executionId: write), isTrue);
      await activity.markWriteOutcomeUncertain(gameId: 'garden', action: 'plant', params: target, executionId: write);
      expect((await activity.load())!.continuationAction, 'state');
      final query = await activity.beginExecution(gameId: 'garden', action: 'state');
      await activity.resolveRemoteDispatch(gameId: 'garden', executionId: query, action: 'state',
        params: target, authoritative: true, outcome: snapshot(error: true));
      expect(await activity.admitRemoteDispatch(gameId: 'garden', action: 'water', params: target, executionId: query), isFalse);
      await activity.resolveRemoteDispatch(gameId: 'garden', executionId: query, action: 'state',
        params: target, authoritative: true, outcome: snapshot());
      expect(await activity.admitRemoteDispatch(gameId: 'garden', action: 'water', params: target, executionId: query), isTrue);
    });
  }

  test('other target, late query, rooms list and message-bearing query cannot clear uncertainty', () async {
    await garden();
    final write = await activity.beginExecution(gameId: 'garden', action: 'plant');
    expect(await activity.admitRemoteDispatch(gameId: 'garden', action: 'plant', params: {'slot': 2}, executionId: write), isTrue);
    final query = await activity.beginExecution(gameId: 'garden', action: 'state');
    for (final args in [
      (id: write, action: 'state', params: <String, Object?>{'slot': 2}),
      (id: query, action: 'state', params: <String, Object?>{'slot': 3}),
      (id: query, action: 'state', params: <String, Object?>{'slot': 2, 'message': 'hello'}),
      (id: query, action: 'rooms', params: <String, Object?>{}),
    ]) {
      await activity.resolveRemoteDispatch(gameId: 'garden', executionId: args.id,
        action: args.action, params: args.params, authoritative: true, outcome: snapshot());
      expect(await activity.admitRemoteDispatch(gameId: 'garden', action: 'water', params: {}, executionId: query), isFalse);
    }
  });

  test('a definite remote failure releases the write guard without claiming success', () async {
    await garden();
    final execution = await activity.beginExecution(gameId: 'garden', action: 'plant');
    expect(await activity.admitRemoteDispatch(gameId: 'garden', action: 'plant', params: {}, executionId: execution), isTrue);
    await activity.resolveRemoteDispatch(gameId: 'garden', executionId: execution, action: 'plant',
      authoritative: true, outcome: snapshot(error: true));
    expect(await activity.admitRemoteDispatch(gameId: 'garden', action: 'water', params: {}, executionId: execution), isTrue);
  });

  test('independent evidence restores withdrawn content with a new active record', () async {
    final source = await turn('source');
    expect(await db.completeGenerationJobIfCurrent(jobId: source.jobId, runToken: source.runToken,
      assistant: ChatMessage(id: source.assistantMessageId, role: 'assistant', content: '我喜欢橡木桌', createdAt: DateTime.now())), isTrue);
    expect(await db.insertMemory(kind: 'ai_self', content: '喜欢橡木桌', importance: .8,
      source: 'conversation_turn:a-source@r0', sourceAssistantMessageId: 'a-source',
      subjectKey: 'self.desk', sourceContextJson: jsonEncode({'dependency': 'assistant_basis'})), isTrue);
    final old = (await db.listMemories()).single;
    await db.restartLatestCompletedReply('a-source');
    expect(await db.listMemories(), isEmpty);
    expect(await db.insertMemory(kind: 'ai_self', content: '喜欢橡木桌', importance: .8,
      source: 'independent-new-evidence', subjectKey: 'self.desk'), isTrue);
    final renewed = (await db.listMemories()).single;
    expect(renewed.id, isNot(old.id));
    expect(renewed.isCurrentFact, isTrue);
    expect((await (await db.database).query('memory_items', where: 'id = ?', whereArgs: [old.id])).single['source_valid'], 0);
  });

  for (final ambiguous in [false, true]) {
    test('room creation reconciliation reads a unique room state; ambiguous=$ambiguous', () async {
      await db.setSetting('active_brain', '1');
      await db.setSetting('cedar_toy_enabled', '1');
      await db.setSetting(CedarToyAutonomyEngine.enabledKey, '1');
      await activity.recordGuide(gameId: 'duel', guide: 'actions: new rooms state move');
      // This is a user-accepted shared room, not optional solo play. Without
      // that fixture, the existing wake guard blocks this test before 08:00
      // on the CI runner, before reconciliation is reached at all.
      await activity.recordPlay(gameId: 'duel', action: 'state', outcome: snapshot(),
        mode: CedarParticipationMode.coPlay, nextActor: 'companion',
        shareLevel: 'none', invitationApproved: true);
      final write = await activity.beginExecution(gameId: 'duel', action: 'new');
      expect(await activity.admitRemoteDispatch(gameId: 'duel', action: 'new', params: {}, executionId: write), isTrue);
      await activity.markWriteOutcomeUncertain(gameId: 'duel', action: 'new', executionId: write);
      final client = FakeCedar()..rooms = {'rooms': [
        {'room_id': 'ROOM'}, if (ambiguous) {'room_id': 'OTHER'}]};
      final ai = DeepSeekClient();
      try {
        final engine = CedarToyAutonomyEngine(db: db, ai: ai, secureConfig: SecureConfig.instance,
          tokenReader: () async => 'ctai_v1_test', apiKeyReader: () async => 'test-key',
          endpointReader: () async => DeepSeekClient.defaultEndpoint, clientFactory: (_) => client);
        await engine.continueDue(now: DateTime.now().add(const Duration(minutes: 1)));
        expect(client.actions, ambiguous ? ['rooms'] : ['rooms', 'state']);
        final unresolved = await db.getSetting('${CedarToyActivityStore.uncertainWritePrefix}duel');
        expect(unresolved?.isNotEmpty ?? false, ambiguous);
      } finally { ai.close(); }
    });
  }

  test('regeneration requeues every surviving summary source and excludes the old reply revision', () async {
    for (var i = 0; i < 12; i++) {
      await db.insertMessage(ChatMessage(id: 'history-$i', role: 'user', content: '历史材料$i',
        createdAt: DateTime.now().subtract(Duration(seconds: 30 - i))));
    }
    final source = await turn();
    final retry = await regenerate(source);
    expect(await db.completeGenerationJobIfCurrent(jobId: retry.jobId, runToken: retry.runToken,
      assistant: ChatMessage(id: retry.assistantMessageId, role: 'assistant', content: '新的照料记录',
        sourceRevision: 1, createdAt: DateTime.now().subtract(const Duration(milliseconds: 100)))), isTrue);
    Future<ConversationSummaryWork?> prepare() async => db.prepareConversationSummary(
      workFence: (await db.captureBrainWorkFence(settingKeys: const [
        'conversation_context_reset_at', 'conversation_context_reset_count']))!);
    final first = (await prepare())!;
    expect(first.materials, hasLength(14));
    expect(await db.commitConversationSummaryIfCurrent(work: first, summary: '第一版摘要'), isTrue);
    final reopened = (await db.restartLatestCompletedReply('a-u'))!;
    expect(await db.recentConversationSummaries(), isEmpty);
    final pending = await (await db.database).query(ConversationSummaryStore.table, where: "state = 'pending'");
    expect(pending.length, greaterThanOrEqualTo(13));
    final newJob = (await db.claimGenerationJob(reopened.id))!;
    expect(await db.completeGenerationJobIfCurrent(jobId: newJob.id, runToken: newJob.runToken,
      assistant: ChatMessage(id: 'a-u', role: 'assistant', content: '第三版照料记录', sourceRevision: 2,
        createdAt: DateTime.now().subtract(const Duration(milliseconds: 50)))), isTrue);
    final second = (await prepare())!;
    expect(second.materials, hasLength(14));
    expect(second.batchHash, isNot(first.batchHash));
    expect(second.materials.singleWhere((m) => m.message.id == 'a-u').source.stamp.revision, 2);
    expect(await db.commitConversationSummaryIfCurrent(work: second, summary: '恢复的摘要'), isTrue);
    expect((await db.recentConversationSummaries()).single.summary, '恢复的摘要');
    expect(await prepare(), isNull);
  });

  test('bounded repair recovers imported invalid coverage without an invisible summary loop', () async {
    for (var i = 0; i < 14; i++) {
      await db.insertMessage(ChatMessage(id: 'imported-$i', role: 'user', content: '有效原始材料$i',
        createdAt: DateTime.now().subtract(Duration(seconds: 30 - i))));
    }
    Future<ConversationSummaryWork?> prepare(int limit) async => db.prepareConversationSummary(
      scanLimit: limit, workFence: (await db.captureBrainWorkFence(settingKeys: const [
        'conversation_context_reset_at', 'conversation_context_reset_count']))!);
    final first = (await prepare(256))!;
    expect(await db.commitConversationSummaryIfCurrent(work: first, summary: '已失效的导入摘要'), isTrue);
    final sql = await db.database;
    await sql.update('conversation_summaries', {'source_valid': 0});
    await sql.update('derived_source_links', {'valid': 0}, where: 'owner_kind = ?', whereArgs: ['summary']);
    ConversationSummaryWork? repaired;
    for (var i = 0; i < 6 && repaired == null; i++) { repaired = await prepare(3); }
    expect(repaired, isNotNull);
    expect(repaired!.batchHash, first.batchHash);
    expect(await db.commitConversationSummaryIfCurrent(work: repaired, summary: '重建后的有效摘要'), isTrue);
    expect((await db.recentConversationSummaries()).single.summary, '重建后的有效摘要');
    expect(await sql.query('derived_source_links', where: 'valid = 0 AND owner_kind = ?', whereArgs: ['summary']), isEmpty);
    expect(await prepare(256), isNull);
  });
}
