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
    'one novel supported candidate, semantic duplicate and invented game rejected',
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
      expect(run('想发现池塘最深处有什么', 'fishing').length, 2);
    },
  );

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
