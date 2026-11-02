import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/memory_extractor.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_note_generator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/background_cost_policy.dart';
import 'package:ai_companion_localfirst/core/ai/prompt_cache_layout.dart';
import 'package:ai_companion_localfirst/core/creative/creative_autonomy_policy.dart';
import 'package:ai_companion_localfirst/core/creative/creative_inspiration_engine.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/creative/creative_worker.dart';
import 'package:ai_companion_localfirst/core/creative/creative_workspace.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/diagnostics/daily_spend.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  final peak = DateTime.parse('2026-11-02T16:00:00+08:00');
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'synthetic-test-key'});
  });
  tearDown(() async => db.closeForTesting());

  test('Beijing windows have exact boundaries in every device timezone', () {
    for (final pair in <String, String?>{
      '2026-11-02T08:59:59+08:00': null,
      '2026-11-02T09:00:00+08:00': '2026-11-02T12:00:00+08:00',
      '2026-11-02T11:59:59+08:00': '2026-11-02T12:00:00+08:00',
      '2026-11-02T12:00:00+08:00': null,
      '2026-11-02T13:59:59+08:00': null,
      '2026-11-02T14:00:00+08:00': '2026-11-02T18:00:00+08:00',
      '2026-11-02T18:00:00+08:00': null,
      '2026-11-07T10:00:00+08:00': null,
      '2026-11-08T16:00:00+08:00': null,
    }.entries) {
      expect(BackgroundCostPolicy.peakEnd(DateTime.parse(pair.key)),
          pair.value == null ? null : DateTime.parse(pair.value!), reason: pair.key);
    }
    expect(BackgroundCostPolicy.peakEnd(peak),
        BackgroundCostPolicy.peakEnd(peak.toLocal()));
    expect(BackgroundCostPolicy.peakEnd(peak), DateTime.utc(2026, 11, 2, 10));
  });

  test('only configured official paid models defer; other providers remain immediate', () async {
    expect(await BackgroundCostPolicy.deferredUntil(db, peak), isNotNull);
    expect(await BackgroundCostPolicy.deferredUntil(db, peak,
        endpoint: 'https://compatible.invalid/v1/chat/completions'), isNull);
    expect(await BackgroundCostPolicy.deferredUntil(db, peak,
        model: 'unknown-price-model'), isNull);
    await db.setSetting(BackgroundCostPolicy.enabledKey, '0');
    expect(await BackgroundCostPolicy.deferredUntil(db, peak), isNull);
  });

  test('deferred private thinking and wish review consume neither lease nor attempt', () async {
    var calls = 0;
    await db.setSetting(CreativeAutonomyPolicy.enabledKey, '1');
    expect(await CreativeInspirationEngine(db, reviewer: (_) async {
      calls++; return null;
    }).maybeThink(now: peak), false);
    expect(await WishEngine(db, reviewer: (_) async {
      calls++; return null;
    }).maybeRefresh(now: peak), false);
    expect(calls, 0);
    expect(await db.getSetting(CreativeAutonomyPolicy.attemptKey), anyOf(null, ''));
    expect(await db.getSetting(WishEngine.attemptKey), anyOf(null, ''));
    expect(await db.isLocalLeaseHeld(CreativeAutonomyPolicy.lease), false);
    expect(await db.isLocalLeaseHeld(WishEngine.leaseKey), false);
  });

  test('autonomous work remains queued at peak and resumes off peak; commissions run now', () async {
    await db.setSetting(CreativeAutonomyPolicy.enabledKey, '1');
    final store = CreativeStore(db);
    final work = store.autonomousWork({'id': 'synthetic-idea', 'brief': '一盏灯',
      'motive': '想试试光影', 'evidence': <Object?>[]}, peak,
      model: 'deepseek-flash', effort: 'high');
    final key = CreativeStore.key(work['id'] as String);
    await db.setSetting(key, jsonEncode(work));
    var calls = 0;
    var clock = peak;
    final worker = CreativeWorker(db, now: () => clock, clientFactory: (_) {
      calls++; throw StateError('synthetic network interruption');
    });
    await worker.runOnce();
    expect(calls, 0);
    expect(await db.getSetting(key), jsonEncode(work));
    expect(await db.isLocalLeaseHeld(CreativeWorker.lease), false);
    clock = DateTime.parse('2026-11-02T18:01:00+08:00');
    await worker.runOnce();
    expect(calls, 1);
    expect((await store.get(work['id'] as String))['attempts'], 1);
    clock = peak;
    await store.commission(deepThinking: true, requestId: 'explicit-now',
      messageId: 'synthetic-message', brief: '做猜拳', requestQuote: '做猜拳', latestText: '做猜拳');
    await worker.runOnce();
    expect(calls, 2);
  });

  test('stable guides precede clocks and evidence without losing fresh facts or array order', () {
    final guides = [{'text': '不变的完整规则', 'id': 'game'}];
    final a = PromptCacheLayout.material({'now': 'A', 'sources': [3, 1],
      'known_game_guides': guides, 'catalog': [{'title': '游戏', 'id': 'game'}]},
      ['catalog', 'known_game_guides']);
    final b = PromptCacheLayout.material({'now': 'B', 'sources': [4, 2],
      'known_game_guides': [{'id': 'game', 'text': '不变的完整规则'}],
      'catalog': [{'id': 'game', 'title': '游戏'}]}, ['catalog', 'known_game_guides']);
    expect(a.substring(0, a.indexOf('"now"')), b.substring(0, b.indexOf('"now"')));
    expect(jsonDecode(b)['sources'], [4, 2]);
    expect(jsonDecode(a)['now'], 'A');
    expect(a.indexOf('不变的完整规则'), lessThan(a.indexOf('"now"')));
  });

  test('Cedar changing outcomes cannot invalidate the complete guide prefix', () {
    CedarGameSession session(String result) => CedarGameSession(id: 'synthetic',
      gameId: 'travel', guide: '完整指南：读状态后选择走路。', guideComplete: true,
      mode: CedarParticipationMode.solo, phase: CedarActivityPhase.active,
      updatedAt: peak, lastOutcome: result);
    final store = CedarToyActivityStore(db);
    final a = store.promptContext(session('旧回执'), playProtocol: '精确动作schema');
    final b = store.promptContext(session('新回执'), playProtocol: '精确动作schema');
    const marker = '【CEDAR_ACTIVITY_SESSION · REAL LOCAL STATE】';
    expect(a.substring(0, a.indexOf(marker)), b.substring(0, b.indexOf(marker)));
    expect(b, contains('新回执'));
    expect(b, contains('只授权 game=travel'));
    expect(b, contains('精确动作schema'));
  });

  test('creative brief stays a prefix while plans, files and durable tools remain current', () {
    final state = CreativeWorkspace.create('work', 'request');
    final work = <String, dynamic>{'origin': 'commission', 'brief': '固定完整委托'};
    final before = CreativeWorkspace.messages(state, work);
    state['plan'] = {'next': '检查按钮'};
    state['files'] = {'index.html': '<button>新内容</button>'};
    state['history'] = [{'role': 'assistant', 'content': '', 'tool_calls': []},
      {'role': 'tool', 'tool_call_id': 'receipt', 'content': '真实结果'}];
    final after = CreativeWorkspace.messages(state, work);
    expect(after.take(2).toList(), before.take(2).toList());
    expect(after[2]['content'], contains('检查按钮'));
    expect(after.last, state['history'].last);
  });

  test('whole-day token accounting is idempotent and unknown usage stays unknown', () async {
    final at = DateTime.now();
    final request = <String, Object?>{'id': 'synthetic-request', 'at': at.millisecondsSinceEpoch,
      'endpoint': 'https://api.deepseek.com/chat/completions', 'model': 'deepseek-flash',
      'lane': 'companion_wish'};
    await DailySpend.record(db, request);
    expect((await DailySpend.today(db, now: at)).label, '今日：—');
    final completed = {...request, 'usage': {'prompt_cache_hit_tokens': 800,
      'prompt_cache_miss_tokens': 200, 'completion_tokens': 100}};
    await DailySpend.record(db, completed);
    await DailySpend.record(db, completed);
    await DailySpend.record(db, request); // A delayed incomplete event cannot erase usage.
    final row = jsonDecode((await db.getSetting(
      '${DailySpend.prefix}${DailySpend.day(at)}:synthetic-request'))!);
    expect(row['known'], true);
    expect(row['tokens']['prompt_cache_hit_tokens'], 800);
    final summary = await DailySpend.today(db, now: at);
    expect(summary.detail, contains('80.0%（1 次完整用量'));
    expect(summary.label, isNot('今日：—'));
  });
  test('recovery resumes a deferred summary even with no new post-turn job', () async {
    await db.setSetting(BackgroundCostPolicy.enabledKey, '0');
    await db.setSetting('conversation_summary_offpeak_pending', '1');
    var calls = 0;
    final client = DeepSeekClient(client: MockClient((_) async {
      calls++; throw StateError('empty backlog must not invoke a model');
    }));
    final extractor = MemoryExtractor(db: db, client: client, desireEngine: DesireEngine(db));
    await extractor.drainPending(retryIfBusy: false);
    for (var i = 0; i < 100 && await db.getSetting('conversation_summary_offpeak_pending') == '1'; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(await db.getSetting('conversation_summary_offpeak_pending'), '');
    expect(calls, 0);
    client.close();
  });

  test('phone instructions remain a common prefix while every reading receives fresh material', () async {
    final requests = <List<dynamic>>[];
    final generator = DeepSeekSimulatedNoteGenerator(modelLoader: () async => DeepSeekModelProfile.flash,
      clientFactory: () => DeepSeekClient(client: MockClient((request) async {
        requests.add((jsonDecode(request.body) as Map)['messages'] as List);
        return http.Response(jsonEncode({'choices': [{'message': {'content':
          jsonEncode({'title': '灯下', 'body': '我想起今天窗边的那一点亮光，心里还有点暖'})}}]}), 200);
      })));
    for (final fact in ['旧资料', '全新资料']) {
      await generator.generate(material: SimulatedNoteMaterial(localDay: '2026-11-02', items: [fact]),
        recentBodies: [fact]);
    }
    expect(requests, hasLength(2));
    expect(requests[0].take(2).toList(), requests[1].take(2).toList());
    expect(requests[1].last['content'], contains('全新资料'));
    expect(requests[1].last['content'], isNot(contains('旧资料')));
  });
}
