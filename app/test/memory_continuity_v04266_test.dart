import 'dart:convert';

import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_runner.dart';
import 'package:ai_companion_localfirst/core/ai/caicai_motion_planner.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/memory/conversation_recall_policy.dart';
import 'package:ai_companion_localfirst/core/memory/memory_brain.dart';
import 'package:ai_companion_localfirst/core/memory/memory_query_expander.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final at = DateTime(2026, 10, 3, 12);
  ChatMessage message(int i, String role, String text, {bool proactive = false, String worldBook = ''}) =>
      ChatMessage(id: 'm$i', role: role, content: text,
          createdAt: at.add(Duration(seconds: i)), isProactive: proactive,
          reasoningContent: 'private reasoning excluded', worldBookContextJson: worldBook);
  MemoryItem seed(String source, {String id = 'seed'}) => MemoryItem(id: id,
      kind: 'shared_experience', semanticType: 'shared_experience', content: '海边贝壳',
      importance: .7, createdAt: at, updatedAt: at, source: source);

  test('recent window preserves complete turns and current input within 64 messages', () {
    final all = [for (var i = 0; i < 96; i++) message(i, i.isEven ? 'user' : 'assistant', '内容$i'),
      message(96, 'user', '当前输入')];
    final selected = ConversationRecallPolicy.recentWindow(all);
    expect(selected.length, 63);
    expect(selected.first.id, 'm34');
    expect(selected.last.id, 'm96');
    expect(selected.first.isUser, isTrue);
  });
  test('text budget omits entire old turns and never truncates a long current input', () {
    final all = [message(0, 'assistant', '旧主动消息'), message(1, 'user', 'a' * 20000),
      message(2, 'assistant', 'b' * 17000), message(3, 'user', '新问题')];
    expect(ConversationRecallPolicy.recentWindow(all).map((m) => m.id), ['m3']);
    final long = message(4, 'user', 'c' * 40000);
    expect(ConversationRecallPolicy.recentWindow([...all, long]).single.content.length, 40000);
  });
  test('a clear recent followup borrows one title, never a new topic or ambiguous titles', () {
    final recent = [message(0, 'user', '我们说到《远山来信》'), message(1, 'assistant', '嗯'),
      message(2, 'user', '那个后来呢')];
    String resolve(String q, List<ChatMessage> ms) => ConversationRecallPolicy.contextualQuery(
      q, ms, currentMessageId: 'm2', now: at.add(const Duration(minutes: 1)));
    expect(resolve('那个后来呢', recent), contains('远山来信'));
    expect(resolve('换个话题，那台电脑怎么样', recent), '换个话题，那台电脑怎么样');
    expect(resolve('那台电脑后来怎么样了', recent), '那台电脑后来怎么样了');
    expect(resolve('后来我买了新电脑', recent), '后来我买了新电脑');
    expect(resolve('那个后来呢', [message(0, 'user', '《远山来信》和《海边书店》'), recent.last]), '那个后来呢');
    expect(ConversationRecallPolicy.contextualQuery('那个后来呢', recent, currentMessageId: 'm2',
      now: at.add(const Duration(hours: 7))), '那个后来呢');
  });
  test('roleplay context is not borrowed into real memory cues', () {
    final roleplay = const WorldBookTurnContext(roleplaySessionId: 'fiction').encode();
    final recent = [message(0, 'user', '《远山来信》', worldBook: roleplay), message(1, 'user', '那个后来呢')];
    expect(ConversationRecallPolicy.contextualQuery('那个后来呢', recent,
      currentMessageId: 'm1', now: at), '那个后来呢');
  });
  test('query rewrites preserve names, dates and negation without inventing titles', () {
    expect(MemoryQueryExpander.validate('2025年没去《远山》', [
      '2025年去过《远山》', '2026年没去《远山》', '2025年未去《海边》', '2025年没到访《远山》',
    ]), ['2025年没到访《远山》']);
    expect(MemoryQueryExpander.validate('MacBook 电源', ['笔记本充电器', 'MacBook 充电器']), ['MacBook 充电器']);
    expect(MemoryQueryExpander.validate('充电设备', ['《远山》电源', '2026 电源']), isEmpty);
  });
  test('face hints are optional and the three authored winks remain distinct', () {
    final hints = CaicaiMotionPlanner.faceMeanings;
    expect(hints.keys.toSet(), CaicaiMotionPlanner.faces.toSet());
    expect(hints['1红脸'], '明显害羞、浪漫表达或难为情时可以使用；轻微害羞不必使用。');
    expect(hints['1红脸'], isNot(contains('夸奖')));
    expect(hints['wink'], contains('轻度'));
    expect(hints['wink吐舌'], contains('中度'));
    expect(hints['比耶wink吐舌'], contains('程度更强'));
    expect(CaicaiMotionPlanner.buildPlan({'face': '无', 'emotion': 'shy', 'action': '2点单'}, {})['face'], '');
    for (final face in ['wink', 'wink吐舌', '比耶wink吐舌']) {
      expect(CaicaiMotionPlanner.buildPlan({'face': face}, {})['face'], face);
    }
  });

  group('actual SQLite recall and explicit tool', () {
    late AppDatabase db;
    const channel = MethodChannel('ai_companion/system');
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test-key'});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel, (call) async => call.method == 'runtimeProcessEpoch' ? 'test' : null);
      db = await AppDatabase.createForTesting(databaseFactoryFfi);
    });
    tearDown(() async {
      await db.closeForTesting();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });
    Future<void> rawMemory(String id, String content, {double importance = .9, String source = 'conversation',
      String semantic = 'current_fact', bool pinned = false}) async {
      await (await db.database).insert('memory_items', {
        'id': id, 'kind': semantic == 'shared_experience' ? semantic : 'user_profile',
        'content': content, 'importance': importance, 'confidence': .9,
        'source': source, 'semantic_type': semantic, 'status': 'active', 'pinned': pinned ? 1 : 0,
        'tags': '', 'subject_key': '', 'topic_key': '',
        'created_at': at.millisecondsSinceEpoch, 'updated_at': at.millisecondsSinceEpoch,
      });
    }
    test('specific old low importance memory survives more than 180 unrelated pinned facts', () async {
      for (var i = 0; i < 200; i++) { await rawMemory('unrelated$i', '园艺花盆$i', pinned: true); }
      await rawMemory('old', '海边拾到蓝色贝壳', importance: .15);
      final items = await db.relevantMemories('蓝色贝壳', now: at);
      expect(items.map((m) => m.id), ['old']);
      final stored = await db.memoryById('old');
      expect(stored!.content, '海边拾到蓝色贝壳');
      expect(stored.importance, .15);
    });
    test('SQL literal underscore is not a wildcard and relevance still gates admission', () async {
      await rawMemory('literal', 'device_key 电源');
      await rawMemory('wild', 'devicexkey 园艺');
      expect((await db.relevantMemories('device_key')).map((m) => m.id), ['literal']);
      expect(await db.relevantMemories('完全无关的棒球比赛'), isEmpty);
    });
    test('explicit recall bypasses repetition cooldown without weakening ordinary admission', () async {
      await rawMemory('shell', 'shell beach treasure');
      expect((await db.relevantMemories('shell')).length, 1);
      const cue = 'shell unknown1 unknown2 unknown3';
      expect(await db.relevantMemories(cue), isEmpty);
      expect((await db.relevantMemories(cue, retrievalMode: 'explicitRecall')).map((m) => m.id), ['shell']);
      expect(await db.relevantMemories(cue), isEmpty);
      expect(await db.relevantMemories('unrelated tomato', retrievalMode: 'explicitRecall'), isEmpty);
    });
    test('old summary beyond latest eight is searchable without overlapping recent raw turns', () async {
      await db.insertConversationSummary(fromAt: at, toAt: at.add(const Duration(seconds: 10)),
        summary: '海边一起拾取蓝色贝壳');
      for (var i = 1; i <= 12; i++) { await db.insertConversationSummary(
        fromAt: at.add(Duration(minutes: i)), toAt: at.add(Duration(minutes: i, seconds: 10)), summary: '园艺花盆$i'); }
      expect((await db.recallConversationSummaries('蓝色贝壳')).single.summary, contains('海边'));
      expect(await db.recallConversationSummaries('蓝色贝壳', before: at), isEmpty);
      expect((await db.recallConversationSummaries('园艺花盆', limit: 20)).length, 2);
    });
    test('source evidence uses actual complete pair, omits reasoning and deduplicates', () async {
      await db.insertMessage(message(0, 'user', '海边拾到蓝色贝壳'));
      await db.insertMessage(message(1, 'assistant', '留作纪念吧'));
      final seeds = [seed('conversation_turn:m0'), seed('conversation_turn:m0', id: 'other')];
      final source = await db.recallExperienceSources(seeds, before: at.add(const Duration(seconds: 2)));
      expect(source.map((m) => m.id), ['m0', 'm1']);
      expect(await db.recallExperienceSources(seeds, before: at.add(const Duration(seconds: 1))), isEmpty);
      await rawMemory('source', '海边拾到蓝色贝壳', source: 'conversation_turn:m0', semantic: 'shared_experience');
      await db.insertConversationSummary(fromAt: at, toAt: at.add(const Duration(seconds: 1)), summary: '蓝色贝壳');
      final brain = MemoryBrain(db);
      final context = await brain.buildContext('蓝色贝壳', summaryBefore: at.add(const Duration(seconds: 2)));
      expect(context.experienceSources.length, 2);
      expect(context.summaries, isEmpty);
      expect(brain.formatForPrompt(context), contains('REAL_USER_HISTORY'));
      expect(brain.formatForPrompt(context), isNot(contains('private reasoning')));
      expect((await brain.buildContext('蓝色贝壳', retrievalMode: 'proactive')).experienceSources, isEmpty);
    });
    for (final condition in ['next_user', 'proactive', 'roleplay', 'special_style', 'oversized', 'missing', 'unrelated']) {
      test('unsafe source $condition cannot become an invented shared scene', () async {
        if (condition != 'missing') {
          await db.insertMessage(message(0, 'user', condition == 'oversized' ? '贝壳${'a' * 2500}' : condition == 'unrelated' ? '午饭米线' : '贝壳',
            worldBook: condition == 'roleplay' ? const WorldBookTurnContext(roleplaySessionId: 'fiction').encode() : ''));
          await db.insertMessage(message(1, condition == 'next_user' ? 'user' : 'assistant', '回答',
            proactive: condition == 'proactive'));
        }
        expect(await db.recallExperienceSources([seed('conversation_turn:m0${condition == 'special_style' ? '|special_style:roleplay' : ''}')]), isEmpty);
      });
    }
    AgentToolPlan plan(String query) => AgentToolPlan(calls: [AgentToolCall(
      toolId: 'memory.search', arguments: {'query': query}, reasonTag: 'explicit_memory')]);
    test('local hit uses no model; two distinct misses in one turn expand only once', () async {
      var calls = 0;
      final ai = DeepSeekClient(client: MockClient((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map;
        expect(body['max_tokens'], 260);
        return http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode({'queries': ['充电器 线缆']})}}]}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      final runner = AgentToolRunner(db: db, android: AndroidBridge.instance, ai: ai);
      await rawMemory('power', '充电器 线缆');
      final hit = await runner.runPlan(plan('充电器 线缆'), eventScopeId: 'hit');
      expect(hit.single.resultCount, 1);
      expect(calls, 0);
      final expanded = await runner.runPlan(plan('电源配件'), eventScopeId: 'miss');
      expect(calls, 1);
      expect(expanded.single.promptData, contains('同义检索候选'));
      expect(expanded.single.resultCount, 1);
      await runner.runPlan(plan('无线底座'), eventScopeId: 'miss', callIndexOffset: 1);
      expect(calls, 1);
      expect((await db.listMemories()).length, 1); // Retrieval does not manufacture memories.
    });
    test('explicit memory tool does not duplicate sources already in recent raw history', () async {
      await db.insertMessage(message(0, 'user', '海边贝壳'));
      await db.insertMessage(message(1, 'assistant', '留作纪念吧'));
      await rawMemory('source', '海边贝壳', source: 'conversation_turn:m0', semantic: 'shared_experience');
      final runner = AgentToolRunner(db: db, android: AndroidBridge.instance);
      final result = await runner.runPlan(plan('海边贝壳'), eventScopeId: 'recent');
      expect(result.single.resultCount, 1);
      expect(result.single.promptData, isNot(contains('REAL_USER_HISTORY')));
    });
    test('expansion failure falls back locally and cancellation makes no request', () async {
      var calls = 0;
      final ai = DeepSeekClient(client: MockClient((request) async {
        calls++; return http.Response('invalid query', 400);
      }));
      final runner = AgentToolRunner(db: db, android: AndroidBridge.instance, ai: ai);
      final result = await runner.runPlan(plan('海边贝壳'), eventScopeId: 'failure');
      expect(result.single.status, AgentToolStatus.succeeded);
      expect(result.single.resultCount, 0);
      expect(result.single.promptData, contains('未命中不代表没有发生'));
      expect(calls, 1);
      final cancelled = GenerationCancellationToken()..cancel();
      await expectLater(runner.runPlan(plan('海边贝壳'), eventScopeId: 'cancel', cancellationToken: cancelled),
        throwsA(isA<GenerationCancelledByUserException>()));
      expect(calls, 1);
    });
  });
}
