import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/wishes/companion_wish.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_engine.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_store.dart';

const _guide = '花园里每盆花只能浇水一次。浇水以后自动成长，不能连续三天重复浇水。';
Map<String, dynamic> _decision(String id, {String state = 'abandoned'}) => {'updates': [{
  'id': 'w', 'state': state, 'evidence_id': id, 'quote': '每盆花只能浇水一次',
  'confidence': .95, 'same_target': true, 'self_decision': true,
  'speech_act': 'mechanism_review', 'mechanic_incompatible': true,
  'permanent_constraint': true, 'temporary_block': false,
  'reason': '原条件要求三天重复浇水，而实际机制每盆只能浇一次，决定放下这个目标',
}]};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late DateTime now;
  late CompanionWish wish;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    now = DateTime.now();
    wish = CompanionWish(id: 'w', goal: '连续三天给同一盆花浇水', reason: '照料花朵',
      route: 'game', gameId: 'garden_cats', criterion: '三个不同日期给同一盆花浇水',
      createdAt: now.subtract(const Duration(days: 1)), updatedAt: now.subtract(const Duration(days: 1)));
    final store = WishStore(db);
    await store.initialize();
    expect(await store.save([wish], expected: await db.getSetting(WishStore.stateKey) ?? '',
      fence: (await db.captureBrainWorkFence())!), true);
    await CedarToyActivityStore(db).recordGuide(gameId: 'garden_cats', guide: _guide);
  });
  tearDown(() => db.closeForTesting());

  test('existing complete guide can retire impossible wish without fabricated chat', () async {
    expect(await db.recentMessages(), isEmpty);
    expect(await WishEngine(db, reviewer: (material) async {
      final guides = material['known_game_guides'] as List;
      final guide = guides.whereType<Map>().single;
      expect(guide['guide'], _guide);
      return _decision(guide['evidence_id'] as String);
    }).maybeRefresh(now: now), true);
    final result = (await WishStore(db).load()).single;
    expect(result.state, 'abandoned');
    expect(result.criterion, wish.criterion);
    expect(result.createdAt.millisecondsSinceEpoch, wish.createdAt.millisecondsSinceEpoch);
    expect(result.evidenceQuote, '每盆花只能浇水一次');
    expect(result.lastIntentionSource, startsWith('mechanism_review:guide:garden_cats:'));
    expect(result.lastEvidenceAt, wish.lastEvidenceAt);
    expect((await db.recentMessages()), isEmpty);
    await db.importAll(await db.exportAll());
    expect((await WishStore(db).load()).single.criterion, wish.criterion);
    expect((await WishStore(db).load()).single.state, 'abandoned');
  });

  for (final change in ['guide', 'restore']) {
    test('late decision cannot survive $change while reviewer is running', () async {
      final entered = Completer<Map<String, dynamic>>();
      final release = Completer<Map<String, dynamic>?>();
      final future = WishEngine(db, reviewer: (material) {
        entered.complete(_decision(((material['known_game_guides'] as List).single as Map)['evidence_id'] as String));
        return release.future;
      }).maybeRefresh(now: now);
      final proposal = await entered.future.timeout(const Duration(seconds: 10));
      if (change == 'guide') {
        await CedarToyActivityStore(db).recordGuide(gameId: 'garden_cats', guide: '每盆花每天都能浇水。');
      } else {
        await db.importAll(await db.exportAll());
      }
      release.complete(proposal);
      expect(await future.timeout(const Duration(seconds: 10)), false);
      expect((await WishStore(db).load()).single.state, 'active');
    });
  }

  test('quote guards, temporary blocks, user holds and completion boundaries remain', () {
    final evidence = WishEvidence(id: 'guide', kind: 'game_guide', text: _guide,
      gameId: 'garden_cats', at: DateTime.fromMillisecondsSinceEpoch(0), timeKnown: false);
    CompanionWish apply(CompanionWish current, Map<String, dynamic> payload) => WishPolicy.apply(
      wishes: [current], payload: payload, evidence: [evidence], catalogIds: {'garden_cats'},
      now: now, canGenerate: false).single;
    for (final patch in [{'quote': '并不存在的引用'}, {'temporary_block': true},
      {'permanent_constraint': false}, {'state': 'completed'}, {'state': 'satisfied'},
      {'confidence': .5}, {'self_decision': false}]) {
      final payload = _decision('guide');
      (payload['updates'] as List).single.addAll(patch);
      expect(apply(wish, payload).state, 'active', reason: '$patch');
    }
    expect(apply(wish.copyWith(manualHold: true), _decision('guide')).state, 'active');
    expect(apply(wish, _decision('guide', state: 'paused')).state, 'paused');
  });
}
