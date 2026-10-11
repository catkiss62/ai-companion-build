import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/creative/creative_worker.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/creative/creative_play.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/diagnostics/daily_spend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi);
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test-only'}); });
  tearDown(() async { await db.closeForTesting(); });
  test('normal chat cannot advertise or parse a creation call', () {
    const text = '给我做一个猜拳小游戏';
    final call = DeepSeekToolCall(id: 'c', name: 'creative_work_commission', arguments: jsonEncode({'brief': text, 'request_quote': text}));
    for (final deep in [false, true]) {
      final tools = jsonEncode(AgentToolPlanner.nativeToolDefinitionsFor(text, deepThinking: deep));
      expect(tools.contains('creative_work_commission'), deep);
      final plan = AgentToolPlanner.fromNativeToolCalls([call], latestUserText: text, deepThinking: deep);
      expect(plan.calls.isNotEmpty, deep);
    }
  });
  test('corrupt archive metadata is rejected before restore', () {
    final tables = <String, dynamic>{'settings': <Map<String, Object?>>[
      {'key': '${CreativeContract.metaPrefix}id', 'value': jsonEncode({'schema': 1, 'id': 'wrong', 'status': 'ready', 'updated': 1})},
    ]};
    expect(() => CreativeContract.normalizeImport(tables), throwsFormatException);
  });
  test('ordinary chat may stop a work without gaining commission capability', () {
    final tools = jsonEncode(AgentToolPlanner.nativeToolDefinitionsFor('先暂停作品制作'));
    expect(tools, contains('creative_work_stop'));
    expect(tools, isNot(contains('creative_work_commission')));
    expect(AgentToolPlanner.nativeToolDefinitionsFor('这个作品很好看'), isEmpty);
  });
  test('commission is idempotent, gated at request time, paused on import', () async {
    final store = CreativeStore(db);
    Future<Map<String, dynamic>> make(bool deep) => store.commission(deepThinking: deep,
      requestId: 'request', messageId: 'message', brief: '做猜拳', requestQuote: '做猜拳', latestText: '做猜拳');
    await expectLater(make(false), throwsFormatException);
    final first = await make(true);
    expect(await make(true), first);
    await db.setSetting('deep_thinking_enabled', '0');
    expect((await store.get(first['id'] as String))['status'], 'queued');
    final backup = await db.exportAll();
    await db.importAll(Map<String, dynamic>.from(backup));
    expect((await store.get(first['id'] as String))['status'], 'paused');
    await expectLater(store.resume(first['id'] as String, deepThinking: false), throwsFormatException);
  });
  test('committed choice is hidden, first reveal wins, and backup retains it', () async {
    final store = CreativeStore(db);
    final work = await store.commission(deepThinking: true, requestId: 'r', messageId: 'm',
      brief: '做猜拳', requestQuote: '做猜拳', latestText: '做猜拳');
    final id = work['id'] as String;
    const html = '<button>猜拳</button>';
    final hash = CreativeContract.hash(html);
    await store.write(work, {...work, 'current': hash, 'status': 'ready', 'versions': [hash]},
      extra: {'${CreativeContract.sourcePrefix}$hash': html});
    var choices = 0;
    final play = CreativePlay(db, id, clientFactory: (abort) => DeepSeekClient(abortWhen: abort,
      jsonClientFactory: () => MockClient((request) async {
        choices++;
        expect(request.body, isNot(contains('playerChoice')));
        return http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode({'choice': '石头'})}}]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      })));
    await play.open();
    final decision = jsonEncode({'kind': 'choose', 'data': {'turn': 't1', 'options': ['石头', '剪刀', '布']}});
    expect(await play.event(hash, decision), {'committed': true});
    expect(await play.event(hash, decision), {'committed': true});
    expect(choices, 1);
    expect((await play.open())['public'], isEmpty);
    expect(await CreativePlay.chatContext(db), isNot(contains('石头')));
    Future<Object?> reveal(String choice) => play.event(hash, jsonEncode({'kind': 'reveal',
      'data': {'turn': 't1', 'playerChoice': choice}}));
    expect(await reveal('剪刀'), {'choice': '石头', 'playerChoice': '剪刀'});
    expect(await reveal('布'), {'choice': '石头', 'playerChoice': '剪刀'});
    final backup = await db.exportAll();
    await db.importAll(Map<String, dynamic>.from(backup));
    expect(((await play.read())['turns'] as Map)['t1']['choice'], '石头');
    expect(await db.getSetting('${CreativeContract.sourcePrefix}$hash'), html);
    await db.setSetting('runtime_state_epoch_v1', 'restored');
    await expectLater(play.event(hash, jsonEncode({'kind': 'save', 'data': {'stale': true}})), throwsA(isA<Exception>()));
    expect((await play.read())['public'], isEmpty);
    await play.open();
    await store.delete(id);
    expect((await store.commission(deepThinking: true, requestId: 'r', messageId: 'm',
      brief: '做猜拳', requestQuote: '做猜拳', latestText: '做猜拳'))['status'], 'deleted');
    await expectLater(reveal('布'), throwsA(isA<Exception>()));
  });
  test('unknown prices and missing usage remain unknown; attempts deduplicate', () async {
    final at = DateTime(2026, 10, 11, 12);
    final data = <String, Object?>{'id': 'one', 'at': DateTime.now().millisecondsSinceEpoch,
      'model': 'deepseek-flash', 'endpoint': 'https://api.deepseek.com/chat/completions', 'lane': 'creative_build'};
    expect(DailySpend.estimate(data), isNull);
    await DailySpend.record(db, data);
    expect((await DailySpend.today(db)).label, '今日：—');
    final used = {...data, 'usage': {'prompt_cache_hit_tokens': 1000000, 'prompt_cache_miss_tokens': 1000000, 'completion_tokens': 1000000}};
    expect(DailySpend.estimate({...used, 'at': at.millisecondsSinceEpoch}), closeTo(5.02, 0.000001));
    // Use current-day records for retention, while testing the price on Sunday.
    final current = {...used, 'at': DateTime.now().millisecondsSinceEpoch};
    await DailySpend.record(db, current); await DailySpend.record(db, current);
    final amount = DailySpend.estimate(current)!;
    expect((await DailySpend.today(db)).label, '今日：-￥${amount.toStringAsFixed(2)}');
    expect(DailySpend.estimate({...used, 'model': 'future-unknown'}), isNull);
  });
}
