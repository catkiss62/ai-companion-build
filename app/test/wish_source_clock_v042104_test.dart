import 'dart:convert';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/wishes/companion_wish.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_engine.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_game_evidence.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  DateTime at(int hour) => DateTime(2026, 10, 13, hour);
  CompanionWish wish() => CompanionWish(id: 'w', goal: '想看懂白房间的纸角折痕',
    reason: '想知道里面的联系', route: 'game', gameId: 'white_room',
    criterion: '实际看到纸角折痕的对应关系', completionKind: 'game_result',
    createdAt: at(9), updatedAt: at(9), lastIntentionAt: at(9),
    lastIntentionSource: 'wish_creation');
  Map<String, dynamic> update(String id, String state, String quote,
      {bool self = false}) => {'updates': [{
    'id': 'w', 'state': state, 'evidence_id': id, 'quote': quote,
    'same_target': true, 'confidence': .95, 'observed': true,
    'self_decision': self, 'speech_act': 'considered_decision',
    'reason': '我已经想清楚自己的选择', 'progress': '看见了一点新的关系',
  }]};
  CompanionWish apply(CompanionWish current, WishEvidence source, String state,
      {bool self = false}) => WishPolicy.apply(wishes: [current],
    evidence: [source], payload: update(source.id, state, source.text, self: self),
    catalogIds: {'white_room'}, now: at(14), canGenerate: false).single;
  WishEvidence evidence(String id, int hour, {String kind = 'game_result'}) =>
    WishEvidence(id: id, kind: kind, gameId: 'white_room',
      text: kind == 'user_text' ? '这个白房间的愿望先不要做了' : '看见纸角折痕的新关系', at: at(hour));

  test('objective progress changes evidence and processing clocks only, with evidence max', () {
    final recent = apply(wish(), evidence('recent', 12), 'active');
    final old = apply(recent, evidence('late-old', 10), 'active');
    expect(old.lastIntentionAt, at(9));
    expect(old.lastIntentionSource, 'wish_creation');
    expect(old.intentionNotBeforeAt, isNull);
    expect(old.lastEvidenceAt, at(12));
    expect(old.updatedAt, at(14));
  });
  for (final state in ['paused', 'abandoned']) {
    test('older user $state cannot overwrite a newer accepted intention', () {
      final current = wish().copyWith(lastIntentionAt: at(12),
        lastIntentionSource: 'chat:new-choice');
      final rejected = apply(current, evidence('old-refusal', 11, kind: 'user_text'), state);
      expect(rejected.state, 'active');
      expect(rejected.manualHold, isFalse);
      expect(rejected.lastIntentionAt, at(12));
      final accepted = apply(current, evidence('new-refusal', 13, kind: 'user_text'), state);
      expect(accepted.state, state);
      expect(accepted.manualHold, isTrue);
      expect(accepted.lastIntentionAt, at(13));
      expect(accepted.lastIntentionSource, 'new-refusal');
    });
  }
  test('legacy missing intention remains unknown and does not inherit processing time', () {
    final raw = wish().toJson()..remove('last_intention_at')
      ..remove('last_intention_source')..remove('intention_not_before_at');
    raw['updated_at'] = at(14).millisecondsSinceEpoch;
    raw['last_evidence_at'] = at(10).millisecondsSinceEpoch;
    final restored = CompanionWish.fromJson(raw);
    expect(restored.lastIntentionAt, isNull);
    expect(restored.lastIntentionSource, isEmpty);
    expect(restored.legacy, isFalse);
    expect(restored.acceptsIntentionAt(at(11)), isTrue);
    expect(restored.acceptsIntentionAt(at(10)), isFalse);
    expect(CompanionWish.fromJson(restored.toJson()).lastIntentionAt, isNull);
  });

  group('real wish lifecycle', () {
    late AppDatabase db;
    setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
    tearDown(() async { await db.closeForTesting(); });
    Future<void> seed(CompanionWish value) async {
      await WishStore(db).initialize();
      expect(await WishStore(db).save([value],
        expected: await db.getSetting(WishStore.stateKey) ?? '',
        fence: (await db.captureBrainWorkFence())!), isTrue);
    }
    for(final scenario in ['input','output','aged','manual']){
      test('game receipt completion and upgrade eligibility: $scenario',()async{
        final w=wish();
        final persisted=WishGameEvidence.append(raw:'',wishes:[w],gameId:'white_room',eventId:'one',
          action:'submit',input:scenario=='input'?'纸角折痕指向钟楼':'按下按钮',
          output:scenario=='input'?'猜测错误，请再试一次':'纸角折痕指向钟楼',at:at(10));
        await seed(scenario=='manual'?w.copyWith(state:'paused',manualHold:true):w);
        await db.setSetting(WishGameEvidence.key,persisted);
        var calls=0; var found=false;
        final app=WishEngine(db,reviewer:(m)async{
          calls++;found=(m['sources'] as List).any((s)=>s['id']=='game:white_room:one');
          if(found) return update('game:white_room:one','completed','纸角折痕指向钟楼');
          return {'updates':[]};
        });
        await app.maybeRefresh(now:scenario=='aged'?at(14).add(const Duration(days:32)):at(14),upgradeOnly:true);
        final state=(await WishStore(db).load()).single.state,marked=await db.getSetting(WishEngine.upgradeKey);
        final kept=WishGameEvidence.decode((await db.getSetting(WishGameEvidence.key))!).length;
        expect(state, scenario == 'input' ? 'active' : scenario == 'manual' ? 'paused' : 'completed');
        expect(marked,'1');
        expect(calls,scenario=='manual'?0:1);
        expect(found, scenario != 'manual');
        expect(kept,1);
      });
    }
    test('legacy game receipt survives rotation for its naturally paused owner', () {
      final paused=wish().copyWith(state:'paused',autoPausedAt:at(12));
      final old=jsonEncode([{'id':'game:white_room:old','wish_id':'w','game_id':'white_room',
        'at':at(10).millisecondsSinceEpoch,
        'text':'action=guess\nsubmitted_input=错误猜测\nreturned_outcome=真正的回包'}]);
      final retained=WishGameEvidence.append(raw:old,wishes:[paused],gameId:'other',
        eventId:'later',action:'step',input:'',output:'',at:at(13));
      final item=WishGameEvidence.collect(retained,[paused],at(14),includePaused:true).single;
      expect(item.quotesOutcome('错误猜测'),false);
      expect(item.quotesOutcome('真正的回包'),true);
      expect(WishGameEvidence.collect(retained,[paused],at(14)),isEmpty);
    });
    test('review 12 progress cannot hide decision 11 from review 14 beyond latest sixteen', () async {
      await seed(wish());
      const quote = '白房间的愿望我想通了，不再追求纸角折痕的答案了';
      await db.insertMessage(ChatMessage(id: 'decision', role: 'assistant',
        content: quote, createdAt: at(11), isProactive: true));
      await db.setSetting(WishGameEvidence.key, WishGameEvidence.append(raw: '',
        wishes: [wish()], gameId: 'white_room', eventId: 'progress',
        action: 'look', input: '{}', output: '看见纸角折痕', at: at(10)));
      var calls = 0;
      final engine = WishEngine(db, reviewer: (material) async {
        calls++;
        final sources = (material['sources'] as List).cast<Map>();
        if (calls == 1) return update('game:white_room:progress', 'active', '看见纸角折痕');
        expect(sources.where((s) => s['id'] == 'chat:decision'), hasLength(1));
        return update('chat:decision', 'abandoned', quote, self: true);
      });
      expect(await engine.maybeRefresh(now: at(12)), isTrue);
      final progress = (await WishStore(db).load()).single;
      expect(progress.lastIntentionAt, at(9));
      expect(progress.lastEvidenceAt, at(10));
      expect(progress.updatedAt, at(12));
      for (var i = 1; i <= 20; i++) {
        await db.insertMessage(ChatMessage(id: 'unrelated-$i', role: 'assistant',
          content: '另外一件完全无关的事情$i', isProactive: true,
          createdAt: at(11).add(Duration(minutes: i))));
      }
      expect((await db.recentMessages(limit: 16)).map((m) => m.id), isNot(contains('decision')));
      expect(await engine.maybeRefresh(now: at(14)), isTrue);
      final retired = (await WishStore(db).load()).single;
      expect(calls, 2);
      expect(retired.state, 'abandoned');
      expect(retired.lastIntentionAt, at(11));
      expect(retired.lastEvidenceAt, at(11));
      expect(retired.updatedAt, at(14));
      expect(jsonDecode((await db.getSetting(WishStore.completedKey))!), isEmpty);
      expect(jsonDecode((await db.getSetting(WishStore.activeKey))!), isEmpty);
    });
    test('UI rollback preserves a separate floor, later UI remains authoritative, and clocks survive import', () async {
      await seed(wish().copyWith(lastIntentionAt: at(12), lastIntentionSource: 'chat:new-choice'));
      final store = WishStore(db);
      expect(await store.setUserState('w', 'active', now: at(10)), isTrue);
      final current = (await store.load()).single;
      expect(current.lastIntentionAt, at(10));
      expect(current.lastIntentionSource, 'local_user');
      expect(current.intentionNotBeforeAt, at(12));
      expect(apply(current, evidence('old', 11, kind: 'user_text'), 'paused').state, 'active');
      expect(await store.setUserState('w', 'paused', now: at(9)), isTrue);
      expect(await store.setUserState('w', 'active', now: at(10)), isTrue);
      await store.claimContact('w', at(13));
      await store.noteAction('w', at(13));
      await store.noteExpressed('w', at(13));
      final snapshot = await db.exportAll();
      await db.importAll(snapshot);
      final restored = (await store.load()).single;
      expect(restored.lastIntentionAt, at(10));
      expect(restored.intentionNotBeforeAt, at(12));
      expect(restored.lastEvidenceAt, isNull);
      expect(restored.acceptsIntentionAt(at(12)), isFalse);
      expect(restored.acceptsIntentionAt(at(13)), isTrue);
    });
    test('legacy unknown intention freezes its old bound before later objective progress', () async {
      final old = wish().toJson()..remove('last_intention_at')
        ..remove('last_intention_source')..remove('intention_not_before_at');
      old['last_evidence_at'] = at(10).millisecondsSinceEpoch;
      await seed(CompanionWish.fromJson(old));
      const decision = '白房间的愿望我想通了，不再追求纸角折痕的答案了';
      await db.insertMessage(ChatMessage(id: 'legacy-decision', role: 'assistant',
        content: decision, createdAt: at(11), isProactive: true));
      final progressAt = at(11).add(const Duration(minutes: 30));
      await db.setSetting(WishGameEvidence.key, WishGameEvidence.append(raw: '',
        wishes: await WishStore(db).load(), gameId: 'white_room', eventId: 'new-progress',
        action: 'look', input: '{}', output: '看见纸角折痕', at: progressAt));
      var calls = 0;
      final engine = WishEngine(db, reviewer: (_) async => ++calls == 1
        ? update('game:white_room:new-progress', 'active', '看见纸角折痕')
        : update('chat:legacy-decision', 'abandoned', decision, self: true));
      expect(await engine.maybeRefresh(now: at(12)), isTrue);
      final progressed = (await WishStore(db).load()).single;
      expect(progressed.lastIntentionAt, isNull);
      expect(progressed.intentionNotBeforeAt, at(10));
      expect(progressed.lastEvidenceAt, progressAt);
      expect(await engine.maybeRefresh(now: at(14)), isTrue);
      final retired = (await WishStore(db).load()).single;
      expect(retired.state, 'abandoned');
      expect(retired.lastIntentionAt, at(11));
      expect(retired.lastEvidenceAt, progressAt);
    });
  });
}
