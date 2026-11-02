import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/background_cost_policy.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/memory_extractor.dart';
import 'package:ai_companion_localfirst/core/creative/creative_autonomy_policy.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/creative/creative_worker.dart';
import 'package:ai_companion_localfirst/core/creative/creative_workspace.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_summary_store.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'creative_agent_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CreativeStore store;
  final peak = DateTime.parse('2026-11-03T16:00:00+08:00');
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CreativeStore(db);
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'synthetic-test-key'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CreativeWorker.preview, (call) async => fixture.nativePreviewResult(call.arguments));
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CreativeWorker.preview, null);
    await db.closeForTesting();
  });

  Future<Map<String, dynamic>> savedBatch(List<Map<String, dynamic>> calls) async {
    await store.setAutonomyEnabled(true);
    final work = {...store.autonomousWork({'id': 'saved-idea', 'brief': '点亮一盏灯',
      'motive': '我想试试光影', 'evidence': <Object?>[]}, peak,
      model: 'deepseek-flash', effort: 'high'), 'status': 'building', 'attempts': 1};
    final agent = CreativeWorkspace.create(work['id'] as String, work['request_id'] as String);
    agent['pending'] = calls;
    agent['history'] = [{'role': 'assistant', 'content': '', 'reasoning_content': '已完成规划',
      'tool_calls': calls.map((c) => {'id': c['id'], 'type': 'function',
        'function': {'name': c['name'], 'arguments': c['arguments']}}).toList()}];
    expect(await store.write({}, work, extra: {
      CreativeWorkspace.key(work['id'] as String): jsonEncode(agent)}), true);
    return work;
  }

  test('peak resumes paid local batch through preview and private finish with no model request', () async {
    final work = await savedBatch([fixture.plan(), fixture.write(fixture.repaired),
      fixture.previewCall(), fixture.call('work_finish', {})]);
    var requests = 0;
    await CreativeWorker(db, now: () => peak, clientFactory: (_) {
      requests++; throw StateError('saved result must not be requested again');
    }).runOnce();
    final after = await store.get(work['id'] as String);
    expect(requests, 0); expect(after['status'], 'ready'); expect(after['attempts'], 1);
    expect(after['visibility'], 'private'); expect(await store.list(), isEmpty);
    final agent = CreativeContract.decode(await db.getSetting(CreativeWorkspace.key(work['id'] as String)));
    expect(agent['pending'], isEmpty);
    expect(CreativeWorkspace.files(agent)['index.html'], fixture.repaired);
  });

  test('local continuation is free but the next model turn still waits until off peak', () async {
    final work = await savedBatch([fixture.write('A')]);
    var requests = 0; var clock = peak;
    final worker = CreativeWorker(db, now: () => clock, clientFactory: (_) {
      requests++; throw StateError('synthetic model boundary');
    });
    await worker.runOnce();
    final id = work['id'] as String;
    expect(CreativeWorkspace.files(CreativeContract.decode(await db.getSetting(CreativeWorkspace.key(id))))['index.html'], 'A');
    await worker.runOnce();
    expect(requests, 0); expect((await store.get(id))['attempts'], 1);
    clock = DateTime.parse('2026-11-03T18:01:00+08:00');
    await worker.runOnce();
    expect(requests, 1); expect((await store.get(id))['attempts'], 2);
  });

  test('peak resumes at the saved tool cursor without appending an earlier chunk twice', () async {
    final calls = [fixture.write('A'), fixture.write('B', before: CreativeContract.hash('A'), mode: 'append')];
    calls[0]['id'] = 'first'; calls[1]['id'] = 'second';
    final work = await savedBatch(calls);
    final id = work['id'] as String, key = CreativeWorkspace.key(id);
    final agent = CreativeContract.decode(await db.getSetting(key));
    CreativeWorkspace.edit(agent, {'path': 'index.html', 'mode': 'replace', 'content': 'A', 'expected_hash': ''});
    agent['next_tool'] = 1;
    (agent['history'] as List).add({'role': 'tool', 'tool_call_id': 'first', 'content': '{"ok":true}'});
    await db.setSetting(key, jsonEncode(agent));
    await CreativeWorker(db, now: () => peak, clientFactory: (_) {
      fail('saved model result must not be regenerated');
    }).runOnce();
    final after = CreativeContract.decode(await db.getSetting(key));
    expect(CreativeWorkspace.files(after)['index.html'], 'AB');
    expect(after['pending'], isEmpty); expect((await store.get(id))['attempts'], 1);
  });

  for (final stop in ['paused', 'deleted', 'disabled', 'imported']) {
    test('saved batch cannot bypass $stop ownership while peak scheduling is bypassed', () async {
      final work = await savedBatch([fixture.write('must-not-run')]);
      final id = work['id'] as String;
      if (stop == 'paused') await store.stop(id);
      if (stop == 'deleted') await store.delete(id);
      if (stop == 'disabled') await store.setAutonomyEnabled(false);
      if (stop == 'imported') {
        await db.importAll(Map<String, dynamic>.from(jsonDecode(jsonEncode(await db.exportAll())) as Map));
      }
      final before = await db.getSetting(CreativeWorkspace.key(id));
      await CreativeWorker(db, now: () => peak, clientFactory: (_) {
        fail('blocked work must not request a model');
      }).runOnce();
      expect(await db.getSetting(CreativeWorkspace.key(id)), before);
      expect((await store.get(id))['status'], isNot('ready'));
    });
  }

  test('a previous request pending batch cannot bypass the new request price gate', () async {
    final work = await savedBatch([fixture.write('old-result')]);
    final id = work['id'] as String;
    expect(await store.write(work, {...work, 'request_id': 'new-request'}), true);
    final before = await db.getSetting(CreativeWorkspace.key(id));
    await CreativeWorker(db, now: () => peak, clientFactory: (_) {
      fail('new request waits for off peak');
    }).runOnce();
    expect(await db.getSetting(CreativeWorkspace.key(id)), before);
    expect((await store.get(id))['attempts'], 1);
  });

  Future<void> sources(int excluded, int ordinary) async {
    for (var i = 0; i < excluded + ordinary; i++) {
      await db.insertMessage(ChatMessage(id: 'source-$i', role: 'user',
        content: '合成材料 $i', createdAt: DateTime(2026, 1, 1).add(Duration(seconds: i)),
        worldBookContextJson: i < excluded
          ? const WorldBookTurnContext(roleplaySessionId: 'synthetic-fiction').encode() : ''));
    }
  }

  test('empty bounded scan keeps recovery and later sources summarize without a new chat', () async {
    await db.setSetting(BackgroundCostPolicy.enabledKey, '0');
    await sources(300, 14);
    await db.setSetting(ConversationSummaryStore.offpeakPendingKey, '1');
    var requests = 0;
    final client = DeepSeekClient(client: MockClient((request) async {
      requests++;
      final messages = (jsonDecode(request.body) as Map)['messages'] as List;
      expect(messages.last['content'], contains('合成材料 313'));
      expect(messages.last['content'], isNot(contains('合成材料 0\n')));
      return http.Response(jsonEncode({'choices': [{'message': {'content':
        jsonEncode({'summary': '十四条合格材料的摘要', 'key_points': <String>[]})}}]}),
        200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final extractor = MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db));
    try {
      await extractor.consolidateIfNeeded(apiKey: 'synthetic-test-key', endpoint: 'https://api.deepseek.com/chat/completions');
      expect(requests, 0); expect(await db.getSetting(ConversationSummaryStore.offpeakPendingKey), '1');
      expect(jsonDecode((await db.getSetting(ConversationSummaryStore.stateKey))!)['scan_seq'], 256);
      await extractor.drainPending(retryIfBusy: false);
      final sql = await db.database;
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while ((await sql.query('conversation_summaries')).isEmpty ||
          await db.isLocalLeaseHeld('conversation_summary_lease_until')) {
        if (DateTime.now().isAfter(deadline)) fail('deferred scan did not resume');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(requests, 1);
      expect(await sql.query(ConversationSummaryStore.table, where: "state='covered'"), hasLength(14));
      await extractor.consolidateIfNeeded(apiKey: 'synthetic-test-key', endpoint: 'https://api.deepseek.com/chat/completions');
      expect(await db.getSetting(ConversationSummaryStore.offpeakPendingKey), '');
      expect(requests, 1);
    } finally { client.close(); }
  });

  test('stable tail below fourteen stays raw and never triggers paid empty polling', () async {
    await db.setSetting(BackgroundCostPolicy.enabledKey, '0');
    await sources(0, 13);
    var requests = 0;
    final client = DeepSeekClient(client: MockClient((_) async {
      requests++; throw StateError('too few sources');
    }));
    try {
      final extractor = MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db));
      for (var i = 0; i < 3; i++) {
        await db.setSetting(ConversationSummaryStore.offpeakPendingKey, '1');
        await extractor.consolidateIfNeeded(apiKey: 'synthetic-test-key', endpoint: 'https://api.deepseek.com/chat/completions');
        expect(await db.getSetting(ConversationSummaryStore.offpeakPendingKey), '');
      }
      expect(requests, 0);
      expect(await (await db.database).query(ConversationSummaryStore.table, where: "state='pending'"), hasLength(13));
    } finally { client.close(); }
  });

  test('old summary owner cannot clear or retain markers after settings invalidation', () async {
    await db.setSetting(ConversationSummaryStore.offpeakPendingKey, '1');
    final fence = (await db.captureBrainWorkFence(settingKeys: ['conversation_context_reset_count']))!;
    await db.setSetting('conversation_context_reset_count', '42');
    final applied = await (await db.database).transaction((txn) =>
      ConversationSummaryStore.settleEmptyScan(txn, workFence: fence));
    expect(applied, false);
    expect(await db.getSetting(ConversationSummaryStore.offpeakPendingKey), '1');
  });

  test('a source arriving after an empty prepare is observed by the marker transaction', () async {
    await sources(0, 13);
    final fence = (await db.captureBrainWorkFence(settingKeys: ['conversation_context_reset_count']))!;
    expect(await db.prepareConversationSummary(workFence: fence), isNull);
    await db.insertMessage(ChatMessage(id: 'late-fourteenth', role: 'user',
      content: '新到的第十四条', createdAt: DateTime(2026, 1, 2)));
    final applied = await (await db.database).transaction((txn) =>
      ConversationSummaryStore.settleEmptyScan(txn, workFence: fence));
    expect(applied, true);
    expect(await db.getSetting(ConversationSummaryStore.offpeakPendingKey), '1');
    expect((await db.prepareConversationSummary(workFence: fence))!.materials, hasLength(14));
  });
}
