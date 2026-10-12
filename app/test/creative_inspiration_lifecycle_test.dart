import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/creative/creative_autonomy_policy.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_inspiration_engine.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CreativeStore store;
  late DateTime clock;
  const html = '<p>A little light</p>';

  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CreativeStore(db);
    clock = DateTime(2026, 10, 12, 12);
    await store.setAutonomyEnabled(true);
    await (await db.database).insert('messages', {
      'id': 'source', 'role': 'user', 'content': '今天看到金色的树叶，觉得特别好看',
      'created_at': clock.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    });
  });
  tearDown(() async => db.closeForTesting());

  Future<Map<String, dynamic>> privateWork(String ideaId, {bool shared = false}) async {
    final work = store.autonomousWork({
      'id': ideaId, 'brief': '树叶小灯', 'motive': '想留下这个颜色', 'evidence': <Object?>[],
    }, clock, model: 'deepseek-flash', effort: 'max');
    final version = CreativeContract.hash(html);
    final ready = {...work, 'status': 'ready', 'visibility': shared ? 'shared' : 'private',
      'current': version, 'versions': [version], 'completed_request': work['request_id'],
      'completed_at': clock.millisecondsSinceEpoch};
    expect(await store.write({}, ready, extra: {'${CreativeContract.sourcePrefix}$version': html}), true);
    return ready;
  }

  Map<String, dynamic> start(Map<String, Object?> input) {
    final source = (input['sources'] as List).whereType<Map>().first;
    return {'classification': [{'id': source['id'], 'kind': 'experience'}],
      'action': 'start', 'idea_id': '', 'brief': '落叶的颜色', 'motive': '想把新见到的颜色留下',
      'evidence': [{'id': source['id'], 'quote': source['text']}]};
  }

  test('private work outlives its clipped idea and can retire to release a private slot', () async {
    final old = await privateWork('old-idea');
    for (var i = 1; i < CreativeAutonomyPolicy.maxPrivateWorks; i++) {
      await privateWork('private-$i');
    }
    // This is the state after newer held ideas have displaced the old idea.
    await db.setSetting(CreativeAutonomyPolicy.stateKey, jsonEncode({
      'schema': 1, 'ideas': List.generate(CreativeAutonomyPolicy.maxIdeas, (i) => {
        'id': 'held-$i', 'brief': '新构思$i', 'motive': '暂时留着',
        'evidence': <Object?>[], 'status': 'held',
      }),
    }));
    expect(await CreativeInspirationEngine(db, reviewer: (input) async => start(input))
      .maybeThink(now: clock, manual: true), false);
    final retiring = CreativeInspirationEngine(db, reviewer: (input) async {
      expect((input['ideas'] as List).whereType<Map>().any((i) => i['id'] == 'old-idea'), false);
      expect((input['private_works'] as List).whereType<Map>().any((w) => w['idea_id'] == 'old-idea'), true);
      return {'action': 'retire', 'idea_id': 'old-idea'};
    });
    expect(await retiring.maybeThink(now: clock, manual: true), true);
    final retired = await store.get(old['id'] as String);
    expect(retired['status'], 'paused');
    expect(retired['preempt'], 'self_retired');
    expect(retired['visibility'], 'private');
    expect(retired['current'], old['current']);
    expect(await db.getSetting('${CreativeContract.sourcePrefix}${old['current']}'), html);

    await (await db.database).insert('messages', {
      'id': 'new-source', 'role': 'user', 'content': '又看到一片红色的叶子',
      'created_at': clock.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
    });
    expect(await CreativeInspirationEngine(db, reviewer: (input) async => start(input))
      .maybeThink(now: clock.add(const Duration(minutes: 2)), manual: true), true);
    final works = await store.list(includePrivate: true);
    expect(works.where((w) => w['preempt'] != 'self_retired').length, CreativeAutonomyPolicy.maxPrivateWorks);
    expect(works.where((w) => w['status'] == 'queued'), hasLength(1));
  });

  test('retirement cannot target a shared gift or a commissioned work', () async {
    final shared = await privateWork('shared-idea', shared: true);
    final commission = await store.commission(deepThinking: true, requestId: 'commission',
      messageId: 'commission-card', brief: '灯', requestQuote: '灯', latestText: '灯');
    await store.write(commission, {...commission, 'status': 'paused', 'idea_id': 'commission-idea',
      'visibility': 'private'});
    for (final ideaId in ['shared-idea', 'commission-idea', 'unknown-idea']) {
      final engine = CreativeInspirationEngine(db, reviewer: (input) async {
        expect((input['private_works'] as List).whereType<Map>().any((w) => w['idea_id'] == ideaId), false);
        return {'action': 'retire', 'idea_id': ideaId};
      });
      expect(await engine.maybeThink(now: clock, manual: true), false);
    }
    expect(await store.get(shared['id'] as String), shared);
    expect((await store.get(commission['id'] as String))['preempt'], isNot('self_retired'));
  });

  test('retirement with a clipped idea keeps epoch and selected work fences', () async {
    final work = await privateWork('old-idea');
    final epochChanged = CreativeInspirationEngine(db, reviewer: (_) async {
      await store.setAutonomyEnabled(false);
      await store.setAutonomyEnabled(true);
      return {'action': 'retire', 'idea_id': 'old-idea'};
    });
    expect(await epochChanged.maybeThink(now: clock, manual: true), false);
    expect(await store.get(work['id'] as String), work);

    final sharedDuringReview = CreativeInspirationEngine(db, reviewer: (_) async {
      await store.write(work, {...work, 'visibility': 'shared'});
      return {'action': 'retire', 'idea_id': 'old-idea'};
    });
    expect(await sharedDuringReview.maybeThink(now: clock, manual: true), false);
    final shared = await store.get(work['id'] as String);
    expect(shared['visibility'], 'shared');
    expect(shared['status'], 'ready');
    expect(shared['preempt'], isNot('self_retired'));
  });
}
