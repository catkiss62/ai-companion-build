import 'dart:async';
import 'dart:convert';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/wishes/companion_wish.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_engine.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final at = DateTime(2026, 10, 4, 10);
  CompanionWish wish({
    String route = 'game',
    String kind = 'game_result',
    String state = 'active',
    bool hold = false,
  }) => CompanionWish(
    id: 'w',
    goal: '今天想钓到一条新图鉴',
    reason: '最近发现了不同的鱼',
    route: route,
    criterion: '本次收获中出现此前未收录的鱼',
    completionKind: kind,
    gameId: 'fishing',
    createdAt: at,
    updatedAt: at,
    state: state,
    manualHold: hold,
  );
  WishEvidence event({
    String kind = 'game_result',
    String game = 'fishing',
    DateTime? time,
    String text = '新图鉴：月光鱼',
  }) => WishEvidence(
    id: 'e',
    kind: kind,
    gameId: game,
    text: text,
    at: time ?? at.add(const Duration(hours: 1)),
  );
  Map<String, dynamic> update({
    String state = 'completed',
    bool observed = true,
    bool expressed = false,
    String quote = '新图鉴：月光鱼',
  }) => {
    'updates': [
      {
        'id': 'w',
        'state': state,
        'evidence_id': 'e',
        'quote': quote,
        'confidence': .94,
        'same_target': true,
        'observed': observed,
        'expressed': expressed,
        'progress': '新增月光鱼',
      },
    ],
  };
  List<CompanionWish> apply(
    CompanionWish w,
    WishEvidence e,
    Map<String, dynamic> p,
  ) => WishPolicy.apply(
    wishes: [w],
    payload: p,
    evidence: [e],
    catalogIds: {'fishing'},
    now: at.add(const Duration(hours: 2)),
    canGenerate: false,
  );
  test('actual new collection outcome completes matching goal', () {
    final done = apply(wish(), event(), update()).single;
    expect(done.state, 'completed');
    expect(done.evidenceIds, ['e']);
    expect(done.criterion, wish().criterion);
  });
  for (final bad in [
    event(kind: 'game_context'),
    event(game: 'chess'),
    event(kind: 'web_read'),
    event(kind: 'assistant_text'),
    event(time: at.subtract(const Duration(minutes: 1))),
  ]) {
    test(
      'rejects non-result or wrong scope ${bad.kind}/${bad.gameId}/${bad.at}',
      () {
        expect(apply(wish(), bad, update()).single.state, 'active');
      },
    );
  }
  test('uncertain result, invented quote and a promise do not complete', () {
    expect(
      apply(wish(), event(), update(observed: false)).single.state,
      'active',
    );
    expect(
      apply(wish(), event(), update(quote: '不存在的内容')).single.state,
      'active',
    );
    expect(
      apply(
        wish(route: 'user', kind: 'user_photo'),
        event(kind: 'user_text'),
        update(),
      ).single.state,
      'active',
    );
    expect(
      apply(
        wish(route: 'user', kind: 'user_text'),
        event(kind: 'user_text', text: '我明天会拍给你'),
        update(observed: false, quote: '我明天会拍给你'),
      ).single.state,
      'active',
    );
  });
  test(
    'photo can satisfy a photo criterion, web or assistant cannot substitute',
    () {
      final w = CompanionWish(
        id: 'w',
        goal: '想看看你身边的花',
        reason: '觉得花很美',
        route: 'user',
        criterion: '收到你发来的可识别花朵照片',
        completionKind: 'user_photo',
        createdAt: at,
        updatedAt: at,
      );
      final p = update(quote: '视觉识别：花朵');
      expect(
        apply(w, event(kind: 'user_photo', text: '视觉识别：花朵'), p).single.state,
        'completed',
      );
      expect(
        apply(w, event(kind: 'web_read', text: '视觉识别：花朵'), p).single.state,
        'active',
      );
    },
  );
  test(
    'saying a wish only marks expression and does not refresh its interest',
    () {
      final result = apply(
        wish(),
        event(kind: 'assistant_text'),
        update(expressed: true),
      ).single;
      expect(result.state, 'active');
      expect(result.expressedAt, isNotNull);
      expect(result.lastEvidenceAt, isNull);
    },
  );
  test(
    'user refusal pauses, manual hold and aspiration cannot be completed',
    () {
      expect(
        apply(
          wish(),
          event(kind: 'user_text'),
          update(state: 'paused'),
        ).single.manualHold,
        isTrue,
      );
      expect(apply(wish(hold: true), event(), update()).single.state, 'active');
      expect(
        apply(wish(route: 'aspiration'), event(), update()).single.state,
        'active',
      );
    },
  );
  test(
    'natural decay pauses without destroying wish or pretending completion',
    () {
      final old = WishPolicy.age(wish(), at.add(const Duration(days: 31)));
      expect(old.state, 'paused');
      expect(old.goal, wish().goal);
      expect(
        wish().priority(at.add(const Duration(days: 14))),
        closeTo(.3, .001),
      );
    },
  );
  test(
    'solo game proposals stay out of the interaction wishlist',
    () {
      Map<String, dynamic> draft(String goal, String game) => {
        'new_wish': {
          'goal': goal,
          'reason': '这次游戏让我有点期待',
          'route': 'game',
          'game_id': game,
          'criterion': '新图鉴出现一条新鱼',
          'completion_kind': 'game_result',
          'source_ids': ['e'],
        },
      };
      List<CompanionWish> run(String goal, String game) => WishPolicy.apply(
        wishes: [wish()],
        payload: draft(goal, game),
        evidence: [event()],
        catalogIds: {'fishing'},
        now: at,
        canGenerate: true,
      );
      expect(run(wish().goal, 'fishing').length, 1);
      expect(run('想种出第一朵蓝色花', 'invented').length, 1);
      expect(run('想发现池塘最深处有什么', 'fishing').length, 1);
    },
  );

  test('photo clarification needs matching quotes, dates, and observed result', () {
    final w = wish(route: 'user', kind: 'user_photo');
    final text = event(kind:'user_text', text:'那张图就是完整成品');
    final photo = WishEvidence(id:'p', kind:'user_photo', text:'视觉识别：完整的模型',
      at:at.subtract(const Duration(days: 2)));
    String check({WishEvidence? support, WishEvidence? main, Map overrides = const {}, bool hold = false}) {
      final result = WishPolicy.apply(wishes:[hold ? wish(route:'user',kind:'user_photo',hold:true) : w],
        evidence:[main ?? text, if (support != null) support], catalogIds:{}, canGenerate:false,
        now:at.add(const Duration(days: 1)), payload:{'updates':[{
          'id':'w','evidence_id':'e','state':'completed','quote':'那张图就是完整成品',
          'observed':true,'same_target':true,'confidence':.98,'confirms_photo_meets_criterion':true,
          'supporting_photo':{'evidence_id':'p','quote':'完整的模型'}, ...overrides,
        }]});
      return result.single.state;
    }
    expect(check(support:photo), 'completed');
    expect(check(), 'active');
    expect(check(support:photo,hold:true), 'active');
    expect(check(support:photo,overrides:{'observed':false}), 'active');
    expect(check(support:photo,overrides:{'same_target':false}), 'active');
    expect(check(support:photo,overrides:{'confirms_photo_meets_criterion':false}), 'active');
    expect(check(support:photo,overrides:{'supporting_photo':{'evidence_id':'p','quote':'别的物体'}}), 'active');
    expect(check(support:WishEvidence(id:'p',kind:'web_read',text:photo.text,at:photo.at)), 'active');
    expect(check(support:WishEvidence(id:'p',kind:'user_photo',text:photo.text,
      at:text.at.add(const Duration(minutes:1)))), 'active');
    expect(check(support:photo,main:event(kind:'user_text',text:text.text,time:at)), 'active');
  });

  group('durable SQLite lifecycle', () {
    late AppDatabase db;
    setUp(() async {
      db = await AppDatabase.createForTesting(databaseFactoryFfi);
    });
    tearDown(() async {
      await db.closeForTesting();
    });
    Future<void> seed() async {
      await WishStore(db).initialize();
      final raw = await db.getSetting(WishStore.stateKey) ?? '';
      final fence = (await db.captureBrainWorkFence())!;
      expect(
        await WishStore(db).save([wish()], expected: raw, fence: fence),
        isTrue,
      );
    }

    test(
      'migration preserves legacy record in paused history and is idempotent',
      () async {
        await db.setSetting(
          WishStore.activeKey,
          jsonEncode([
            {
              'id': 'old',
              'body': '想做几件值得记住的事',
              'created_at': at.millisecondsSinceEpoch,
            },
          ]),
        );
        await WishStore(db).initialize();
        await WishStore(db).initialize();
        final items = await WishStore(db).load();
        expect(items.single.legacy, isTrue);
        expect(items.single.state, 'paused');
        expect(
          jsonDecode((await db.getSetting(WishStore.activeKey))!) as List,
          isEmpty,
        );
        expect(
          jsonDecode((await db.getSetting(WishStore.archivedKey))!) as List,
          hasLength(1),
        );
      },
    );
    test(
      'contact claim survives restart/import and does not complete',
      () async {
        await seed();
        expect(await WishStore(db).claimContact('w', at), isTrue);
        final backup = await db.exportAll();
        await db.importAll(backup);
        expect(
          await WishStore(
            db,
          ).claimContact('w', at.add(const Duration(hours: 1))),
          isFalse,
        );
        expect((await WishStore(db).load()).single.state, 'active');
      },
    );
    test(
      'pause and generation restore fence reject late model writes',
      () async {
        await seed();
        final raw = await db.getSetting(WishStore.stateKey) ?? '';
        await db.tryAcquireLocalLease(WishEngine.leaseKey);
        final fence = (await db.captureBrainWorkFence(
          leaseKey: WishEngine.leaseKey,
        ))!;
        await WishStore(db).setUserState('w', 'paused', now: at);
        expect(
          await WishStore(db).save([wish()], expected: raw, fence: fence),
          isFalse,
        );
        final backup = await db.exportAll();
        await db.importAll(
          backup,
          runtimeSettingOverrides: {WishEngine.leaseKey: '0'},
        );
        expect(
          await WishStore(db).save(
            [wish()],
            expected: await db.getSetting(WishStore.stateKey) ?? '',
            fence: fence,
          ),
          isFalse,
        );
      },
    );
    test('manual pause fences an already generated proactive reply', () async {
      await seed();
      final fence = (await db.captureBrainWorkFence(
        settingKeys: [WishStore.stateKey, WishStore.enabledKey],
      ))!;
      await WishStore(db).setUserState('w', 'paused', now: at);
      final reason = await db.commitProactiveMessageIfCurrent(
        message: ChatMessage(
          id: 'late-wish',
          role: 'assistant',
          content: '想去钓新鱼',
          createdAt: at,
        ),
        evaluationStartedAt: at,
        workFence: fence,
      );
      expect(reason, 'work_fence');
      expect(await db.messageById('late-wish'), isNull);
    });
    test('completion moves all projections in the same transaction', () async {
      await seed();
      final raw = await db.getSetting(WishStore.stateKey) ?? '';
      final done = apply(wish(), event(), update());
      await WishStore(
        db,
      ).save(done, expected: raw, fence: (await db.captureBrainWorkFence())!);
      expect((await WishStore(db).load()).single.state, 'completed');
      expect(jsonDecode((await db.getSetting(WishStore.activeKey))!), isEmpty);
      expect(
        jsonDecode((await db.getSetting(WishStore.completedKey))!),
        hasLength(1),
      );
      expect(await WishStore(db).prompt(), '');
    });
    test(
      'unavailable reviewer retains wishes and persists attempt cooldown',
      () async {
        await seed();
        await db.insertMessage(
          ChatMessage(id: 'u', role: 'user', content: '新消息', createdAt: at),
        );
        var calls = 0;
        final engine = WishEngine(
          db,
          reviewer: (_) async {
            calls++;
            throw StateError('offline');
          },
        );
        await engine.maybeRefresh(now: at);
        await engine.maybeRefresh(now: at.add(const Duration(minutes: 10)));
        expect(calls, 1);
        expect((await WishStore(db).load()).single.goal, wish().goal);
      },
    );
    test(
      'a model attempt is bounded and unchanged evidence is not repeatedly reviewed',
      () async {
        await db.insertMessage(
          ChatMessage(
            id: 'u',
            role: 'user',
            content: '今天见到一种很漂亮的植物',
            createdAt: at,
          ),
        );
        var calls = 0;
        final engine = WishEngine(
          db,
          reviewer: (m) async {
            calls++;
            return {'updates': []};
          },
        );
        expect(await engine.maybeRefresh(now: at), isTrue);
        await engine.maybeRefresh(now: at.add(const Duration(hours: 1)));
        await engine.maybeRefresh(now: at.add(const Duration(hours: 3)));
        expect(calls, 1);
      },
    );
    test('unchanged material gets one proposal opportunity after a review-only cooldown', () async {
      await seed();
      await db.insertMessage(ChatMessage(id: 'u-test', role: 'user',
        content: '我们周末可以一起认一认阳台上的花', createdAt: at));
      await db.setSetting(WishEngine.generationKey, '${at.millisecondsSinceEpoch}');
      final gates = <bool>[];
      final engine = WishEngine(db, reviewer: (material) async {
        gates.add(material['can_generate'] == true);
        return {'updates':[{'id':'w','state':'unchanged','reason_code':'no_new_evidence','evidence_ids':[]}]};
      });
      await engine.maybeRefresh(now: at);
      await engine.maybeRefresh(now: at.add(const Duration(hours: 3)));
      await engine.maybeRefresh(now: at.add(const Duration(hours: 13)));
      await engine.maybeRefresh(now: at.add(const Duration(hours: 16)));
      expect(gates, [false, true]);
    });

    test(
      'foreground chat fences a pending review and preserves current state',
      () async {
        await seed();
        await db.insertMessage(
          ChatMessage(id: 'u', role: 'user', content: '今天在钓鱼', createdAt: at),
        );
        final started = Completer<void>(),
            response = Completer<Map<String, dynamic>?>();
        final pending = WishEngine(
          db,
          reviewer: (m) {
            started.complete();
            return response.future;
          },
        ).maybeRefresh(now: at);
        await started.future;
        await db.tryAcquireLocalLease('chat_turn_lease');
        response.complete({'updates': []});
        expect(await pending, isFalse);
        expect((await WishStore(db).load()).single.goal, wish().goal);
        await db.releaseLocalLease('chat_turn_lease');
      },
    );
    test('self disposition commits history and removes active game motivation', () async {
      await seed();
      final now = at.add(const Duration(hours: 1));
      const statement = '我现在已经不想继续追这个目标了';
      await db.insertMessage(ChatMessage(id: 'self-choice', role: 'assistant',
        content: statement, createdAt: at.add(const Duration(minutes: 10))));
      final engine = WishEngine(db, reviewer: (_) async => {
        'updates': [{
          'id': 'w', 'state': 'abandoned', 'self_decision': true,
          'speech_act': 'considered_decision', 'reason': '已经不再执着原先的目标',
          'evidence_id': 'chat:self-choice', 'quote': statement,
          'same_target': true, 'confidence': .95,
        }],
      });
      expect(await engine.maybeRefresh(now: now), true);
      expect((await WishStore(db).load()).single.state, 'abandoned');
      expect(jsonDecode((await db.getSetting(WishStore.activeKey))!), isEmpty);
      expect(jsonDecode((await db.getSetting(WishStore.archivedKey))!), hasLength(1));
      expect(await WishStore(db).prompt(gameOnly: true, now: now), '');
      expect(await WishStore(db).prompt(includeCompleted: true, now: now), contains('abandoned'));
      final snapshot = await db.exportAll();
      await db.importAll(snapshot);
      expect((await WishStore(db).load()).single.state, 'abandoned');
      expect(await WishStore(db).prompt(gameOnly: true, now: now), '');
    });
    test('disabled phone makes no call and exposes no wish prompt', () async {
      await seed();
      await db.setSetting(WishStore.enabledKey, '0');
      expect(
        await WishEngine(
          db,
          reviewer: (_) async => throw StateError('unexpected model call'),
        ).maybeRefresh(now: at),
        isFalse,
      );
      expect(await WishStore(db).prompt(), '');
    });
    test('upgrade rechecks archived chat evidence once across retries and restarts', () async {
      final store = WishStore(db);
      await store.initialize();
      final item = CompanionWish(id: 'w', goal: '想看完整灯塔模型',
        reason: '看看拼起来的样子', route: 'user', completionKind: 'user_photo',
        criterion: '用户展示完整的灯塔模型', createdAt: at, updatedAt: at);
      expect(await store.save([item], expected: (await db.getSetting(WishStore.stateKey))!,
        fence: (await db.captureBrainWorkFence())!), isTrue);
      final photoAt = at.subtract(const Duration(days: 3));
      await db.insertMessageWithAttachments(ChatMessage(id: 'old', role: 'user',
        content: '灯塔拼好了', createdAt: photoAt), [
        MessageAttachment(id: 'image', messageId: 'old', kind: 'image', originalPath: '',
          thumbnailPath: '', byteSize: 0, width: 1, height: 1, mimeType: 'image/png',
          source: 'gallery', visionStatus: 'completed', visionSummary: '桌上摆着灯塔模型',
          createdAt: photoAt),
      ]);
      await db.setSetting('companion_wish_review_v9_completed','1');
      const clarification = '之前那张灯塔模型照片就是完整成品';
      await db.insertMessage(ChatMessage(id: 'clarify', role: 'user', content: clarification,
        createdAt: at.add(const Duration(hours: 1))));
      for (var i = 0; i < 258; i++) {
        await db.insertMessage(ChatMessage(id: 'later-$i', role: 'user', content: '无关闲聊',
          createdAt: at.add(Duration(days: 16, seconds: i))));
      }
      final now = at.add(const Duration(days: 17));
      await db.setSetting(WishEngine.attemptKey, '${now.millisecondsSinceEpoch}');
      var calls = 0;
      final engine = WishEngine(db, reviewer: (material) async {
        calls++;
        expect(material['can_generate'], false);
        final ids = (material['sources'] as List).map((e) => e['id']).toSet();
        expect(ids, containsAll(['photo:old:image', 'chat:clarify']));
        final group=(material['wishes'] as List).single['candidate_evidence'] as List;
        expect(group.singleWhere((v)=>v['id']=='photo:old:image')['vision'],'桌上摆着灯塔模型');
        expect(group.singleWhere((v)=>v['id']=='chat:clarify')['text'],clarification);
        if (calls == 1) return null;
        return {'updates': [{
          'id':'w', 'state':'completed','evidence_id':'chat:clarify','quote':clarification,
          'same_target':true,'observed':true,'confidence':.96,
          'confirms_photo_meets_criterion':true,
          'supporting_photo':{'evidence_id':'photo:old:image','quote':'桌上摆着灯塔模型'},
        }]};
      });
      await db.tryAcquireLocalLease('chat_turn_lease', holdFor: const Duration(minutes: 2));
      expect(await engine.maybeRefresh(now: now, upgradeOnly: true), false);
      expect(calls, 0);
      await db.releaseLocalLease('chat_turn_lease');
      expect(await engine.maybeRefresh(now: now, upgradeOnly: true), false);
      expect(await db.getSetting(WishEngine.upgradeKey), isNot('1'));
      expect(await engine.maybeRefresh(now: now, upgradeOnly: true), false);
      expect(calls, 1);
      expect(await engine.maybeRefresh(now: now.add(WishEngine.upgradeRetry), upgradeOnly: true), true);
      expect((await store.load()).single.state, 'completed');
      expect((await store.load()).single.evidenceIds, containsAll(['photo:old:image','chat:clarify']));
      expect(await db.getSetting(WishEngine.upgradeKey), '1');
      expect(await WishEngine(db, reviewer: (_) => throw StateError('already done'))
        .maybeRefresh(now: now, upgradeOnly:true), true);
      expect(calls, 2);
    });

    test('long caption keeps verified visual evidence separate',() async {
      final w=wish(route:'user',kind:'user_photo');
      final photoAt=at.subtract(const Duration(days:3));
      await db.insertMessageWithAttachments(ChatMessage(id:'old-img',role:'user',
        content:'仅在附言里出现的描述'+('甲'*1150),createdAt:photoAt),[
        MessageAttachment(id:'p',messageId:'old-img',kind:'image',originalPath:'',
          thumbnailPath:'',byteSize:0,width:1,height:1,mimeType:'image/png',source:'gallery',
          visionStatus:'completed',visionSummary:'视觉里独有的模型轮廓',createdAt:photoAt)]);
      final after=at.add(const Duration(hours:2));
      await db.insertMessage(ChatMessage(id:'explain',role:'user',content:'那张照片就是成品',createdAt:after));
      final material=await WishEngine(db).collect(after,wishes:[w]);
      final p=material.singleWhere((v)=>v.kind=='user_photo');
      expect(p.caption!.length,350);
      expect(p.vision,'视觉里独有的模型轮廓');
      String verify(String quote) => WishPolicy.apply(wishes:[w],evidence:material,catalogIds:{},
        now:after,canGenerate:false,payload:{'updates':[{
          'id':'w','evidence_id':'chat:explain','state':'completed','quote':'那张照片就是成品',
          'observed':true,'same_target':true,'confidence':.97,'confirms_photo_meets_criterion':true,
          'supporting_photo':{'evidence_id':p.id,'quote':quote}}]}).single.state;
      expect(verify('视觉里独有的模型轮廓'),'completed');
      expect(verify('仅在附言里出现的描述'),'active');
    });
    test('wrong wish ID leaves upgrade pending with its own reason',() async {
      await seed();
      await db.insertMessage(ChatMessage(id:'u-new',role:'user',content:'已看到结果',
          createdAt:at.add(const Duration(hours:1))));
      final engine=WishEngine(db,reviewer:(_)async=>{'updates':[{'id':'unknown_id',
        'state':'completed','evidence_id':'chat:u-new','quote':'已看到结果'}]});
      expect(await engine.maybeRefresh(now:at.add(const Duration(hours:2)),upgradeOnly:true),false);
      expect(await db.getSetting(WishEngine.upgradeKey),isNot('1'));
      final diag=jsonDecode((await db.getSetting(WishEngine.diagnosticKey))!);
      expect(diag['reason'],'unknown_wish_id');
    });

    test('upgrade distinguishes missing row from a reviewed unmet criterion',() async {
      await seed();
      final now = at.add(const Duration(hours:2));
      await db.insertMessage(ChatMessage(id:'seen',role:'user',content:'还在等新的结果',createdAt:now));
      await db.setSetting('companion_wish_review_v9_completed','1');
      var calls=0;
      final engine=WishEngine(db,reviewer:(_) async {
        calls++;
        return {'updates': [if(calls>1) {
          'id':'w','state':'unchanged','reason_code':'criterion_unmet','evidence_ids':['chat:seen']
        }]};
      });
      expect(await engine.maybeRefresh(now:now,upgradeOnly:true),false);
      final first=jsonDecode((await db.getSetting(WishEngine.diagnosticKey))!);
      expect(first['reason'],'missing_wish_review');
      expect(await engine.maybeRefresh(now:now.add(WishEngine.upgradeRetry),upgradeOnly:true),false);
      expect(calls,1);
      expect(await engine.maybeRefresh(now:now.add(WishEngine.reviewGap),upgradeOnly:true),true);
      final last=jsonDecode((await db.getSetting(WishEngine.diagnosticKey))!);
      final decision=last['decisions'].single;
      expect(decision['requested'],'unchanged');
      expect(decision['reason'],'criterion_unmet');
      expect(decision['reviewed_sources'].single,matches(RegExp(r'^[0-9a-f]{12}$')));
      expect(last['candidate_sources'],contains(decision['wish_hash']));
      expect((await WishStore(db).load()).single.active,true);
      expect(await engine.maybeRefresh(now:now.add(const Duration(days:1)),upgradeOnly:true),true);
      expect(calls,2);
    });

    test('empty upgrade completes without model work', () async {
      var calls = 0;
      final engine = WishEngine(db, reviewer: (_) async {calls++; return null;});
      expect(await engine.maybeRefresh(now: at, upgradeOnly:true), true);
      expect(calls, 0);
      expect(await db.getSetting(WishEngine.upgradeKey), '1');
    });
    test('sticker observations never enter user photo evidence', () async {
      await db.insertMessageWithAttachments(
        ChatMessage(id: 'u', role: 'user', content: '', createdAt: at),
        [
          MessageAttachment(
            id: 'sticker',
            messageId: 'u',
            kind: 'image',
            originalPath: '',
            thumbnailPath: '',
            byteSize: 0,
            width: 1,
            height: 1,
            mimeType: 'image/png',
            source: 'user_sticker:test',
            visionStatus: 'completed',
            visionSummary: '花朵',
            createdAt: at,
          ),
        ],
      );
      expect(
        (await WishEngine(db).collect(at)).where((e) => e.kind == 'user_photo'),
        isEmpty,
      );
    });
  });
}
