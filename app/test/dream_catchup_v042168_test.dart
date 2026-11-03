import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/self/dream_engine.dart';
import 'package:ai_companion_localfirst/core/self/dream_contract.dart';
import 'package:ai_companion_localfirst/core/self/dream_store.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_motion_planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final now = DateTime.now().add(const Duration(days: 1));
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.setSetting(DreamStore.stateKey, jsonEncode({
      'schema': 1, 'insights': [], 'history': [],
      'cursor': {'chat_seq': 0, 'chat_at': 0, 'chat_id': '', 'web_at': 0, 'web_id': ''},
    }));
  });
  tearDown(() async => db.closeForTesting());
  Future<void> seed(int count) async {
    for (var i = 0; i < count; i++) {
      await db.insertMessage(ChatMessage(id: 'source-$i', role: 'user',
        content: '这是正常相处的真实发言第$i条，玩笑和游戏讨论不等于角色扮演。',
        createdAt: now.subtract(const Duration(days: 2)).add(Duration(seconds: i))));
    }
  }
  Map<String, dynamic> proposal(Map<String, Object?> input) {
    final sources = (input['sources'] as List).cast<Map>();
    final source = sources.firstWhere((s) => s['kind'] == 'user_text');
    return {'changes': [{
      'action': 'upsert', 'id': 'play.own_pace', 'domain': 'play', 'stance': 'tentative',
      'understanding': '我可能喜欢在共同游玩时保留自己观察和选择的节奏。',
      'choice': '先看看自己真正感兴趣的地方。', 'uncertainty': '不同游戏里可能不一样。',
      'reason': '从交流中重新考虑自己的选择和相处方式。',
      'basis': input['phase'] == 'catchup_integrate' ? 'reinterpretation' : 'new_experience',
      'evidence': [{'id': source['id'], 'quote': source['text'], 'role': 'support'}],
    }]};
  }

  test('1974 old rows are covered once in the same day; candidates stay private until integration', () async {
    await seed(1974);
    final seen = <String>[];
    var integrated = false;
    final engine = DreamEngine(db, reviewer: (m) async {
      if (m['phase'] == 'catchup_read') {
        expect((await DreamStore(db).load())['insights'], isEmpty);
        expect(await DreamStore(db).prompt(), isEmpty);
        seen.addAll((m['sources'] as List).cast<Map>()
            .where((s) => s['fresh'] == true).map((s) => s['id'] as String));
      } else if (m['phase'] == 'catchup_integrate') { integrated = true; }
      return proposal(m);
    });
    expect(await engine.maybeDream(now: now, manual: true), isTrue);
    for (var step = 0; step < 25 && (await DreamStore(db).load())['catchup'] != null; step++) {
      expect(await engine.maybeDream(now: now, manual: true), isTrue);
    }
    expect(seen.length, 1974);
    expect(seen.toSet().length, 1974);
    expect(integrated, isTrue);
    expect((await DreamStore(db).load())['catchup'], isNull);
    expect(await DreamStore(db).prompt(), contains('保留自己观察和选择'));
    expect((await DreamStore(db).load())['last_catchup'], contains('before_insights'));
  });

  test('new arrivals are ordinary material while old source ranges remain private', () async {
    await seed(300);
    final seen = <Map<String, Object?>>[];
    final engine = DreamEngine(db, reviewer: (m) async {seen.add(m); return {'changes': []};});
    await engine.maybeDream(now: now, manual: true);
    await db.insertMessage(ChatMessage(id: 'new-arrival', role: 'user',
      content: '这是专项开始以后刚发生的新交流。', createdAt: now.subtract(const Duration(minutes: 10))));
    expect(await engine.maybeDream(now: now, manual: true), isTrue);
    expect(seen.single['phase'], 'ordinary');
    final sources = (seen.single['sources'] as List).cast<Map>();
    expect(sources.where((s) => s['fresh'] == true).map((s) => s['id']), ['chat:new-arrival']);
    expect(sources.any((s) => (s['id'] as String).startsWith('chat:source-')), isFalse);
    expect((await DreamStore(db).load())['catchup'], isNotNull);
    expect(await engine.maybeDream(now: now, manual: true), isTrue);
    expect(seen.last['phase'], 'catchup_read');
  });

  test('no-change historical reading completes without a paid integration or forced personality', () async {
    await seed(300);
    var reads = 0;
    final engine = DreamEngine(db, reviewer: (m) async {
      expect(m['phase'], 'catchup_read'); reads++; return {'changes': []};
    });
    await engine.maybeDream(now: now, manual: true);
    for (var i = 0; i < 8 && (await DreamStore(db).load())['catchup'] != null; i++) {
      expect(await engine.maybeDream(now: now, manual: true), isTrue);
    }
    expect(reads, greaterThan(0));
    expect((await DreamStore(db).load())['catchup'], isNull);
    expect((await DreamStore(db).load())['insights'], isEmpty);
  });

  test('real snapshot roundtrip resumes source coverage and never exposes a private draft', () async {
    await seed(400);
    final engine = DreamEngine(db, reviewer: (m) async => proposal(m));
    await engine.maybeDream(now: now, manual: true);
    await engine.maybeDream(now: now, manual: true);
    final before = await DreamStore(db).load();
    expect(before['catchup'], isNotNull);
    final exported = await db.exportAll();
    final directory = await Directory.systemTemp.createTemp('dream-catchup-restore-');
    final restored = await AppDatabase.createForTesting(databaseFactoryFfi, path: '${directory.path}/restored.db');
    try {
      await restored.importAll(exported);
      final state = await DreamStore(restored).load();
      expect(state['catchup'], before['catchup']);
      expect(await DreamStore(restored).prompt(), isEmpty);
      var calls = 0;
      expect(await DreamEngine(restored, reviewer: (m) async {
        calls++; expect(m['phase'], 'catchup_read'); return {'changes': []};
      }).maybeDream(now: now, manual: true), isTrue);
      expect(calls, 1);
    } finally { await restored.closeForTesting(); await directory.delete(recursive: true); }
  });

  test('output truncation shrinks historical input and does not advance the journal', () async {
    await seed(300);
    final engine = DreamEngine(db, reviewer: (_) async => throw const IncompleteJsonCompletionException('length'));
    await engine.maybeDream(now: now, manual: true);
    final before = (await DreamStore(db).load())['catchup'];
    expect(await engine.maybeDream(now: now, manual: true), isFalse);
    expect(await db.getSetting(DreamEngine.catchupBatchKey), '120');
    expect((await DreamStore(db).load())['catchup'], before);
    expect(jsonDecode((await db.getSetting(DreamEngine.requestBudgetKey))!)['requests'], 1);
  });

  test('repeated invalid evidence pauses identical paid requests, even when manual', () async {
    await seed(1);
    var calls = 0;
    final engine = DreamEngine(db, reviewer: (_) async {calls++; return {'bad': []};});
    for (var i = 0; i < 8; i++) {expect(await engine.maybeDream(now: now, manual: true), isFalse);}
    expect(calls, 3);
    expect((await DreamStore(db).load())['cursor']['chat_seq'], 0);
    expect(jsonDecode((await db.getSetting(DreamStore.diagnosticKey))!)['status'], 'repeated_failure_paused');
  });

  test('daily request ceiling includes failures and cannot be bypassed by a manual run', () async {
    await seed(1);
    await db.setSetting(DreamEngine.requestBudgetKey, jsonEncode({'day': DreamContract.day(now), 'requests': 24}));
    var calls = 0;
    expect(await DreamEngine(db, reviewer: (_) async {calls++; return {'changes': []};})
      .maybeDream(now: now, manual: true), isFalse);
    expect(calls, 0);
    expect((await DreamStore(db).load())['cursor']['chat_seq'], 0);
  });

  test('speech rejects fixed-mouth special eyes while the opening plan keeps them', () {
    const answers = {'face_use': 'yes', 'face': '嫌弃眼',
      'speech0_face_use': 'yes', 'speech0_face': '嫌弃眼'};
    expect(DeepseekMotionPlanner.preset(answers, '')['face'], '嫌弃眼');
    expect(DeepseekMotionPlanner.preset(answers, 'speech0_')['face'], '');
  });
}
