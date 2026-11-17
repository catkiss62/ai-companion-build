import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_correction.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const channel = MethodChannel('ai_companion/system');
  late AppDatabase db;
  late CedarToyActivityStore store;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel,
            (call) async => call.method == 'runtimeProcessEpoch' ? 'rules201' : null);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CedarToyActivityStore(db);
    await store.saveCatalog('arcade·街机厅，单人·fixture | chess·棋馆，单人·fixture');
    for (final id in ['chess', 'arcade']) {
      final session = await store.recordGuide(gameId: id, guide: '完整规则：查询 status。');
      await store.save(session.copyWith(mode: CedarParticipationMode.solo,
          phase: CedarActivityPhase.active));
    }
  });
  tearDown(() async {
    await db.closeForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('plain rule corrections are recognized, ambiguity is not promoted', () {
    for (final text in ['游戏币不等于兑换额度', '筹码≠积分', '你记错规则了，行动点只能用于移动']) {
      expect(CedarGameCorrection.accepts(text), isTrue, reason: text);
    }
    for (final text in ['今天游戏挺好玩的', '游戏币不等于兑换额度吗',
      '游戏币不等于兑换额度？', '如果游戏币不等于额度，就麻烦了',
      '他说游戏币不等于兑换额度', '撤回游戏规则纠正',
      '游戏币不等于额度${List.filled(501, "啊").join()}']) {
      expect(CedarGameCorrection.accepts(text), isFalse, reason: text);
    }
  });
  test('correction survives short advice, guide refresh and serialized reload', () async {
    final time = DateTime(2026, 11, 17);
    await store.rememberUserAdvice('游戏币不等于兑换额度', sourceId: 'user-message', sourceAt: time);
    for (var i = 0; i < 5; i++) {
      await store.rememberUserAdvice('建议先看看第$i个选项');
    }
    await store.recordGuide(gameId: 'arcade', guide: '更新后的完整规则。');
    final session = (await CedarToyActivityStore(db).loadSession('arcade'))!;
    expect(session.adviceNotes.length, lessThanOrEqualTo(3));
    final restored = CedarGameSession.fromJson(jsonDecode(jsonEncode(session.toJson())));
    expect(restored.ruleCorrections.single.text, '游戏币不等于兑换额度');
    expect(restored.ruleCorrections.single.sourceId, 'user-message');
    expect(restored.ruleCorrections.single.at, time.millisecondsSinceEpoch);
  });
  test('explicit target never modifies active or unknown games', () async {
    await store.rememberUserAdvice('棋馆规则记错了，行动点不能用于兑换',
        gameId: 'chess', allowSessionAdvice: false);
    await store.rememberUserAdvice('游戏币不等于额度', gameId: 'missing');
    await store.rememberUserAdvice('两款游戏的规则都记错了', allowSessionAdvice: false);
    await store.rememberUserAdvice('换个游戏，两款游戏的规则都记错了',
        allowSessionAdvice: false);
    expect((await store.loadSession('chess'))!.ruleCorrections, hasLength(1));
    expect((await store.loadSession('arcade'))!.ruleCorrections, isEmpty);
    expect((await store.loadState()).activeGameId, 'arcade');
  });
  test('duplicate is refreshed, later correction remains ordered and bounded', () async {
    await store.rememberUserAdvice('游戏币不等于额度', sourceId: 'old');
    await store.rememberUserAdvice('游戏币不等于额度', sourceId: 'new');
    expect((await store.loadSession('arcade'))!.ruleCorrections.single.sourceId, 'new');
    for (var i = 0; i < 8; i++) {
      await store.rememberUserAdvice('更正规则：第$i项积分不能兑换');
    }
    final notes = (await store.loadSession('arcade'))!.ruleCorrections;
    expect(notes, hasLength(6));
    expect(notes.first.text, contains('第2项'));
    expect(notes.last.text, contains('第7项'));
  });
  test('named retraction clears only that game and leaves play advice', () async {
    await store.rememberUserAdvice('游戏币不等于额度');
    await store.rememberUserAdvice('建议先看看规则');
    await store.rememberUserAdvice('行动点不能兑换', gameId: 'chess');
    await store.rememberUserAdvice('请撤回街机厅的规则纠正', gameId: 'arcade');
    final session = (await store.loadSession('arcade'))!;
    expect(session.ruleCorrections, isEmpty);
    expect(session.adviceNotes, contains('建议先看看规则'));
    expect((await store.loadSession('chess'))!.ruleCorrections, hasLength(1));
    expect(CedarGameCorrection.retracts('撤回规则纠正'), isTrue);
    expect(CedarGameCorrection.retracts('不要撤回规则纠正'), isFalse);
  });
  test('corrections are opt-in context and retain provenance/status boundaries', () async {
    await store.rememberUserAdvice('游戏币不等于兑换额度');
    final session = (await store.loadSession('arcade'))!;
    expect(store.promptContext(session), isNot(contains('游戏币不等于兑换额度')));
    final prompt = store.promptContext(session, includeRuleCorrections: true);
    expect(prompt, contains('游戏币不等于兑换额度'));
    expect(prompt, contains('最新工具结果'));
    expect(prompt, contains('只证明用户这样纠正过'));
  });
  test('old saves and malformed records remain readable', () {
    final old = CedarGameSession(id: 'old', gameId: 'old', guide: '',
        guideComplete: false, mode: CedarParticipationMode.solo,
        phase: CedarActivityPhase.completed, updatedAt: DateTime(2026));
    final json = old.toJson()..remove('rule_corrections');
    expect(CedarGameSession.fromJson(json).ruleCorrections, isEmpty);
    expect(CedarGameCorrection.decode([null, {'text': 'x'}, {'text': 12}]), isEmpty);
  });
  test('restored epoch rejects late correction commit', () async {
    final stale = CedarToyActivityStore(db, beforeStateCommit: () async {
      await db.setSetting('runtime_state_epoch_v1', 'restored201');
    });
    await stale.rememberUserAdvice('游戏币不等于额度');
    expect((await store.loadSession('arcade'))!.ruleCorrections, isEmpty);
  });
}
