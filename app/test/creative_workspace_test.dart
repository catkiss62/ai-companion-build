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
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
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
    final play = CreativePlay(db, id);
    final state = await play.open();
    await db.setSetting(play.stateKey, jsonEncode({...state, 'turns': {'t1': {
      'choice': '石头', 'options': ['石头', '剪刀', '布'], 'at': 1}}}));
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
    await store.delete(id);
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
