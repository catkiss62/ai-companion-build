import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/creative/creative_autonomy_policy.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_delivery.dart';
import 'package:ai_companion_localfirst/core/creative/creative_inspiration_engine.dart';
import 'package:ai_companion_localfirst/core/creative/creative_play.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/creative/creative_worker.dart';
import 'package:ai_companion_localfirst/core/creative/creative_workspace.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/features/creative/creative_pages.dart';
import 'creative_agent_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CreativeStore store;
  late DateTime clock;
  const secret = '金色树叶的小灯';
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CreativeStore(db); clock = DateTime(2026, 10, 12, 12);
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test-key-only'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CreativeWorker.preview, (_) async => {'ok': true, 'errors': [], 'page_text': '亮了', 'elements': []});
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CreativeWorker.preview, null);
    await db.closeForTesting();
  });
  Future<void> source([String text = '今天看到金色的树叶，觉得特别好看']) async {
    await (await db.database).insert('messages', {'id': 'source', 'role': 'user',
      'content': text, 'created_at': clock.subtract(const Duration(hours: 1)).millisecondsSinceEpoch});
  }
  Map<String, dynamic> decision(Map<String, Object?> input, {String action = 'start', String kind = 'experience'}) {
    final s = (input['sources'] as List).whereType<Map>().first;
    return {'classification': [{'id': s['id'], 'kind': kind}], 'action': action, 'idea_id': '',
      'brief': secret, 'motive': '我想把最近注意到的颜色做成可以点亮的灯',
      'evidence': [{'id': s['id'], 'quote': s['text']}]};
  }
  Future<Map<String, dynamic>> privateWork({bool ready = false, String ideaId = 'idea'}) async {
    await store.setAutonomyEnabled(true);
    final idea = {'id': ideaId, 'brief': secret, 'motive': '想留下这个颜色',
      'evidence': <Object?>[], 'status': 'building'};
    var work = store.autonomousWork(idea, clock, model: 'deepseek-flash', effort: 'max');
    final version = CreativeContract.hash(fixture.repaired);
    if (ready) work = {...work, 'title': secret, 'intro': '点亮树叶', 'status': 'ready',
      'current': version, 'versions': [version], 'completed_request': work['request_id'],
      'completed_at': clock.millisecondsSinceEpoch};
    expect(await store.write({}, work, extra: {
      if (ready) '${CreativeContract.sourcePrefix}$version': fixture.repaired}), true);
    return work;
  }
  CreativeWorker worker(List<Map<String, dynamic>> calls, {void Function()? requested}) =>
      CreativeWorker(db, now: () => clock, clientFactory: (abort) => DeepSeekClient(abortWhen: abort,
        streamClientFactory: () => MockClient((r) async {
          requested?.call(); return fixture.response(fixture.sse(calls));
        })));
  ChatMessage shareMessage(String id) => ChatMessage(id: id, role: 'assistant', content: '给你做了一盏灯',
    createdAt: clock, isProactive: true);
  Future<Map<String, dynamic>> backup() async =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(await db.exportAll())) as Map);

  test('default off; ordinary thinking switch does not grant autonomy', () async {
    await source(); await db.setSetting('deep_thinking_enabled', '1');
    var calls = 0;
    final engine = CreativeInspirationEngine(db, reviewer: (m) async { calls++; return decision(m); });
    expect(await engine.maybeThink(now: clock, manual: true), false);
    expect(calls, 0);
    await store.setAutonomyEnabled(true); await db.setSetting('deep_thinking_enabled', '0');
    expect(await engine.maybeThink(now: clock, manual: true), true);
    expect(calls, 1); expect(await store.list(), isEmpty);
    final work = (await store.list(includePrivate: true)).single;
    expect(work['origin'], 'autonomous'); expect(work['original_request'], '');
    expect(work['brief'], secret);
    expect(await store.chatContext(), isNot(contains(secret)));
  });

  test('unapproved request cannot become an autonomous commission', () async {
    await source('请帮我做一盏树叶灯'); await store.setAutonomyEnabled(true);
    final engine = CreativeInspirationEngine(db, reviewer: (m) async => decision(m, kind: 'unapproved_request'));
    expect(await engine.maybeThink(now: clock, manual: true), false);
    expect(await store.list(includePrivate: true), isEmpty);
    final state = CreativeContract.decode(await db.getSetting(CreativeAutonomyPolicy.stateKey));
    expect(state['blocked_sources'], isNotEmpty);
    expect(await engine.maybeThink(now: clock.add(const Duration(days: 1)), manual: true), false);
    expect(await store.list(includePrivate: true), isEmpty);
  });

  test('held idea is private, survives JSON backup and requires explicit resume', () async {
    await source(); await store.setAutonomyEnabled(true);
    var calls = 0;
    final engine = CreativeInspirationEngine(db, reviewer: (m) async { calls++; return decision(m, action: 'hold'); });
    expect(await engine.maybeThink(now: clock, manual: true), true);
    final raw = await db.getSetting(CreativeAutonomyPolicy.stateKey);
    expect(raw, contains(secret)); expect(await store.list(), isEmpty);
    await db.importAll(await backup());
    final restored = CreativeContract.decode(await db.getSetting(CreativeAutonomyPolicy.stateKey));
    expect((restored['ideas'] as List).single['brief'], secret);
    expect(restored['suspended'], true);
    expect(await engine.maybeThink(now: clock, manual: true), false); expect(calls, 1);
    await store.resumeAutonomous();
    expect(CreativeContract.decode(await db.getSetting(CreativeAutonomyPolicy.stateKey))['suspended'], false);
  });

  test('a new user turn or toggle roundtrip invalidates in-flight inspiration', () async {
    await source(); await store.setAutonomyEnabled(true);
    final engine = CreativeInspirationEngine(db, reviewer: (m) async {
      await store.setAutonomyEnabled(false); await store.setAutonomyEnabled(true);
      return decision(m);
    });
    expect(await engine.maybeThink(now: clock, manual: true), false);
    expect(await store.list(includePrivate: true), isEmpty);
  });

  test('private finish checks source and never queues ordinary completion', () async {
    final work = await privateWork(); final id = work['id'] as String;
    await worker([fixture.plan(), fixture.write(fixture.repaired), fixture.previewCall(), fixture.call('work_finish', {})]).runOnce();
    final ready = await store.get(id);
    expect(ready['status'], 'ready'); expect(ready['visibility'], 'private');
    expect(ready['completed_request'], ready['request_id']);
    expect(await db.getSetting(CreativeDelivery.key(id)), isNull);
    expect(await store.list(), isEmpty); expect(await store.forMessage(''), isEmpty);
    expect(await store.chatContext(), isNot(contains(secret)));
    expect(() => CreativePlay(db, id).open(), throwsFormatException);
  });

  test('private worker yields to chat without consuming calls, then resumes saved files', () async {
    final work = await privateWork(); var calls = 0;
    final runtime = worker([fixture.plan(), fixture.write(fixture.repaired)], requested: () => calls++);
    await db.tryAcquireLocalLease('chat_turn_lease');
    await runtime.runOnce(); expect(calls, 0);
    await db.releaseLocalLease('chat_turn_lease');
    await runtime.runOnce(); expect(calls, 1);
    final checkpoint = await db.getSetting(CreativeWorkspace.key(work['id'] as String));
    await store.setAutonomyEnabled(false); await runtime.runOnce(); expect(calls, 1);
    expect(await db.getSetting(CreativeWorkspace.key(work['id'] as String)), checkpoint);
  });

  test('chat starting during preview keeps the last checkpoint and prevents private finish', () async {
    final w = await privateWork(); final id = w['id'] as String;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      CreativeWorker.preview, (_) async {
        await db.tryAcquireLocalLease('chat_turn_lease');
        return {'ok': true, 'errors': [], 'page_text': '亮了', 'elements': []};
      });
    await worker([fixture.plan(), fixture.write(fixture.repaired), fixture.previewCall(), fixture.call('work_finish', {})]).runOnce();
    final paused = await store.get(id);
    final agent = CreativeContract.decode(await db.getSetting(CreativeWorkspace.key(id)));
    expect(paused['status'], isNot('ready'));
    expect(CreativeWorkspace.files(agent), isNotEmpty);
    expect(agent['verification'], isEmpty);
    expect(await store.list(), isEmpty);
  });

  test('active private files and tool cursor survive full export/import paused', () async {
    final work = await privateWork(); final id = work['id'] as String;
    await worker([fixture.plan(), fixture.write(fixture.repaired)]).runOnce();
    final prior = CreativeContract.decode(await db.getSetting(CreativeWorkspace.key(id)));
    await db.importAll(await backup());
    final restored = await store.get(id);
    final agent = CreativeContract.decode(await db.getSetting(CreativeWorkspace.key(id)));
    expect(restored['status'], 'paused'); expect(restored['preempt'], 'import');
    expect(restored['visibility'], 'private'); expect(agent['files'], prior['files']);
    expect(agent['pending'], prior['pending']); expect(agent['next_tool'], prior['next_tool']);
    expect(agent['verification'], isEmpty); expect(await store.list(), isEmpty);
    await store.resumeAutonomous(); expect((await store.get(id))['status'], 'queued');
  });

  test('completed private backup remains private and cannot auto-share after import', () async {
    final w = await privateWork(ready: true); final id = w['id'] as String;
    await db.importAll(await backup());
    expect((await store.get(id))['visibility'], 'private');
    expect(await store.claimShare(id, clock), isNull);
    expect(await db.getSetting('${CreativeContract.sourcePrefix}${w['current']}'), fixture.repaired);
    await store.resumeAutonomous(); expect(await store.claimShare(id, clock), isNotNull);
    expect(await store.list(), isEmpty);
  });

  test('retired private work stays retired after import and continue', () async {
    final w = await privateWork(ready: true); final id = w['id'] as String;
    await store.write(w, {...w, 'status': 'paused', 'preempt': 'self_retired'});
    await db.importAll(await backup());
    await store.resumeAutonomous();
    expect((await store.get(id))['status'], 'paused');
    expect((await store.get(id))['preempt'], 'self_retired');
    expect(await store.shareCandidates(clock), isEmpty);
    expect(await db.getSetting('${CreativeContract.sourcePrefix}${w['current']}'), fixture.repaired);
  });

  test('share visibility, message, receipt and ordinary quota commit together', () async {
    final w = await privateWork(ready: true); final id = w['id'] as String;
    final share = await store.claimShare(id, clock); expect(share, isNotNull);
    expect(await store.list(), isEmpty);
    expect(await db.commitProactiveMessageIfCurrent(message: shareMessage('gift'), evaluationStartedAt: clock,
      creativeShare: share, proactiveTriggerReason: 'creative_share:$id',
      enforceProactiveBudget: true, deliveryAt: clock), isNull);
    expect((await store.get(id))['visibility'], 'shared');
    expect((await store.forMessage('gift')).single['card_kind'], 'delivered');
    expect(await store.shareCandidates(clock.add(const Duration(days: 1))), isEmpty);
    expect(await db.messageById('gift'), isNotNull);
    expect((await (await db.database).query('proactive_history', where: "decision='sent'")).length, 1);
    await db.importAll(await backup());
    expect((await store.list()).single['visibility'], 'shared');
    expect((await store.forMessage('gift')).single['delivered_version'], w['current']);
    expect(await store.shareCandidates(clock.add(const Duration(days: 1))), isEmpty);
  });

  test('toggle or stale selected version cannot publish a private work', () async {
    final w = await privateWork(ready: true); final id = w['id'] as String;
    final share = await store.claimShare(id, clock);
    await store.setAutonomyEnabled(false); await store.setAutonomyEnabled(true);
    expect(await db.commitProactiveMessageIfCurrent(message: shareMessage('stale'), evaluationStartedAt: clock,
      creativeShare: share), 'creative_share_changed');
    expect(await db.messageById('stale'), isNull); expect(await store.list(), isEmpty);
    expect(await store.forMessage('stale'), isEmpty);
  });

  test('chat preemption cannot publish a gift without its message', () async {
    final w = await privateWork(ready: true);
    final share = await store.claimShare(w['id'] as String, clock);
    await db.tryAcquireLocalLease('chat_turn_lease');
    expect(await db.commitProactiveMessageIfCurrent(message: shareMessage('busy'), evaluationStartedAt: clock,
      creativeShare: share), 'chat_turn');
    expect(await store.list(), isEmpty); expect(await db.messageById('busy'), isNull);
  });

  test('missing private source rejects import without replacing data', () async {
    final w = await privateWork(ready: true); final id = w['id'] as String;
    final broken = await backup();
    final tables = broken['tables'] as Map;
    (tables['settings'] as List).removeWhere((r) => r['key'] == '${CreativeContract.sourcePrefix}${w['current']}');
    await expectLater(db.importAll(broken), throwsFormatException);
    expect((await store.get(id))['current'], w['current']);
    expect(await db.getSetting('${CreativeContract.sourcePrefix}${w['current']}'), fixture.repaired);
  });

  test('corrupt private visibility or inspiration state rejects before replacing live data', () async {
    final w = await privateWork(ready: true); final id = w['id'] as String;
    final broken = await backup();
    final rows = (broken['tables'] as Map)['settings'] as List;
    final row = rows.whereType<Map>().singleWhere((r) => r['key'] == CreativeStore.key(id));
    row['value'] = jsonEncode({...w, 'visibility': 'unknown'});
    await expectLater(db.importAll(broken), throwsFormatException);
    expect(await store.get(id), w);
    final other = await backup();
    ((other['tables'] as Map)['settings'] as List).add({
      'key': CreativeAutonomyPolicy.stateKey,
      'value': jsonEncode({'schema': 1, 'ideas': [], 'blocked_sources': 'damaged'})});
    await expectLater(db.importAll(other), throwsFormatException);
    expect(await store.get(id), w); expect(await store.list(), isEmpty);
  });

  test('ordinary message budget rejection leaves private work and receipts untouched', () async {
    final w = await privateWork(ready: true);
    final share = await store.claimShare(w['id'] as String, clock);
    await (await db.database).insert('proactive_history', {
      'id': 'recent-send', 'trigger_reason': 'ordinary', 'decision': 'sent',
      'message_id': 'previous', 'created_at': clock.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch});
    expect(await db.commitProactiveMessageIfCurrent(message: shareMessage('over-budget'), evaluationStartedAt: clock,
      creativeShare: share, proactiveTriggerReason: 'creative_share:${w['id']}',
      enforceProactiveBudget: true, deliveryAt: clock), 'minimum_gap');
    expect(await db.messageById('over-budget'), isNull);
    expect(await store.forMessage('over-budget'), isEmpty); expect(await store.list(), isEmpty);
    expect((await store.get(w['id'] as String))['visibility'], 'private');
  });

  test('old archives keep public works visible and autonomy default off', () async {
    final w = await store.commission(deepThinking: true, requestId: 'old', messageId: 'old-card',
      brief: '旧作品', requestQuote: '旧作品', latestText: '旧作品');
    final legacy = {...w}..remove('origin')..remove('visibility');
    await store.write(w, legacy); await db.importAll(await backup());
    expect((await store.list()).single['id'], w['id']);
    expect(await db.getSetting(CreativeAutonomyPolicy.enabledKey), isNot('1'));
  });

  test('completed card receipt is per commission, not current work status', () async {
    final w = await store.commission(deepThinking: true, requestId: 'first', messageId: 'card1',
      brief: '灯', requestQuote: '灯', latestText: '灯');
    await worker([fixture.plan(), fixture.write(fixture.repaired), fixture.previewCall(), fixture.call('work_finish', {})]).runOnce();
    expect((await store.forMessage('card1')).single['record_completed'], true);
    await store.commission(deepThinking: true, requestId: 'second', messageId: 'card2', workId: w['id'] as String,
      brief: '修改灯', requestQuote: '修改灯', latestText: '修改灯');
    expect((await store.forMessage('card1')).single['record_completed'], true);
    expect((await store.forMessage('card2')).single['record_completed'], false);
    await db.importAll(await backup());
    expect((await store.forMessage('card1')).single['record_completed'], true);
    expect((await store.forMessage('card2')).single['record_completed'], false);
  });

  testWidgets('completed creation badge is visible while card remains collapsed', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CreativeWorkCard(
      work: const {'id': 'w', 'title': '作品', 'card_kind': 'progress', 'record_completed': true},
    ))));
    expect(find.text('已完成'), findsOneWidget); expect(find.textContaining('制作记录'), findsNothing);
  });
}
