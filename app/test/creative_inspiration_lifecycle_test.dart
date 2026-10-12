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

  test('resuming a commission during inspiration keeps the user task ahead of new private work', () async {
    final commission = await store.commission(deepThinking: true, requestId: 'paused-commission',
      messageId: 'commission-card', brief: '做一盏灯', requestQuote: '做一盏灯', latestText: '做一盏灯');
    await store.stop(commission['id'] as String);
    final engine = CreativeInspirationEngine(db, reviewer: (input) async {
      await store.resume(commission['id'] as String);
      return start(input);
    });
    expect(await engine.maybeThink(now: clock, manual: true), false);
    final works = await store.list(includePrivate: true);
    expect(works, hasLength(1));
    expect(works.single['id'], commission['id']);
    expect(works.single['status'], 'queued');
    expect(CreativeContract.decode(await db.getSetting(CreativeAutonomyPolicy.stateKey)), isEmpty);
  });

  test('private-work capacity is checked again when an inspiration result commits', () async {
    for (var i = 0; i < CreativeAutonomyPolicy.maxPrivateWorks - 1; i++) {
      await privateWork('existing-$i');
    }
    final engine = CreativeInspirationEngine(db, reviewer: (input) async {
      await privateWork('last-slot');
      return start(input);
    });
    expect(await engine.maybeThink(now: clock, manual: true), false);
    final works = await store.list(includePrivate: true);
    expect(works, hasLength(CreativeAutonomyPolicy.maxPrivateWorks));
    expect(works.every((work) => work['status'] == 'ready'), true);
    expect(CreativeContract.decode(await db.getSetting(CreativeAutonomyPolicy.stateKey)), isEmpty);
  });

  for (final reversed in [false, true]) {
    test('conflicting request classification remains blocked in ${reversed ? 'reverse' : 'forward'} order', () async {
      String sourceId = '';
      final engine = CreativeInspirationEngine(db, reviewer: (input) async {
        final result = start(input);
        sourceId = ((input['sources'] as List).first as Map)['id'] as String;
        final classifications = [
          {'id': sourceId, 'kind': 'unapproved_request'},
          {'id': sourceId, 'kind': 'experience'},
        ];
        return {...result, 'classification': reversed ? classifications.reversed.toList() : classifications};
      });
      expect(await engine.maybeThink(now: clock, manual: true), false);
      expect(await store.list(includePrivate: true), isEmpty);
      final state = CreativeContract.decode(await db.getSetting(CreativeAutonomyPolicy.stateKey));
      expect(state['blocked_sources'], hasLength(1));
      expect(state['ideas'], isEmpty);
      final next = CreativeInspirationEngine(db, reviewer: (_) async {
        fail('the rejected source must not be reclassified on the next review');
      });
      expect(await next.maybeThink(now: clock.add(const Duration(hours: 7)), manual: true), false);
    });
  }

  test('equal classification duplicates are compatible but conflicting non-request rows cannot start work', () async {
    final uncertain = CreativeInspirationEngine(db, reviewer: (input) async {
      final result = start(input);
      final source = ((input['sources'] as List).first as Map)['id'];
      return {...result, 'classification': [
        {'id': source, 'kind': 'other'}, {'id': source, 'kind': 'experience'},
      ]};
    });
    expect(await uncertain.maybeThink(now: clock, manual: true), false);
    expect(await store.list(includePrivate: true), isEmpty);
    final repeated = CreativeInspirationEngine(db, reviewer: (input) async {
      final result = start(input);
      final row = (result['classification'] as List).single;
      return {...result, 'classification': [row, row]};
    });
    expect(await repeated.maybeThink(now: clock, manual: true), true);
    expect(await store.list(includePrivate: true), hasLength(1));
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
