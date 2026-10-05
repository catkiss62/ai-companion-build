import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:ai_companion_localfirst/core/self/dream_contract.dart';
import 'package:ai_companion_localfirst/core/self/dream_engine.dart';
import 'package:ai_companion_localfirst/core/self/dream_material.dart';
import 'package:ai_companion_localfirst/core/self/dream_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final night = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 10);
  const words = '不用一直赶目标，停下来看看也很好。';
  Map<String, dynamic> change({
    String id = 'play.own_pace',
    String source = 'chat:u',
    String quote = words,
    String view = '我可能也喜欢不急着完成目标的游玩节奏。',
    String basis = 'new_experience',
    String stance = 'tentative',
  }) => {
    'action': 'upsert',
    'id': id,
    'domain': 'play',
    'stance': stance,
    'understanding': view,
    'choice': '允许自己在有兴趣的地方多停留一会儿。',
    'uncertainty': '也可能只是今天更想轻松一点。',
    'reason': '新的交流使我重新考虑原来急着完成目标的习惯。',
    'basis': basis,
    'evidence': [
      {'id': source, 'quote': quote, 'role': 'support'},
    ],
  };
  Map<String, dynamic> payload([Map<String, dynamic>? c]) => {
    'changes': [c ?? change()],
  };
  DreamSource source({
    String kind = 'user_text',
    bool fresh = true,
    int? at,
  }) => DreamSource(
    id: 'chat:u',
    kind: kind,
    text: words,
    at: at ?? night.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
    fresh: fresh,
  );

  group('reflective meaning and evidence', () {
    test(
      'a single significant experience can form a tentative interpretation',
      () {
        final next = DreamContract.apply(
          payload: payload(),
          state: {},
          sources: [source()],
          now: night,
        )!;
        final i = DreamContract.records(next['insights']).single;
        expect(i['stance'], 'tentative');
        expect(i.containsKey('confidence'), isFalse);
        expect(i.containsKey('evidence_count'), isFalse);
        expect(i['evidence'], contains(containsPair('at', source().at)));
      },
    );
    for (final kind in [
      'missing_id',
      'false_quote',
      'no_support',
      'empty_evidence',
      'duplicate_id',
      'malformed',
      'old_as_new',
    ]) {
      test('$kind cannot become a reflective conclusion', () {
        final c = change();
        if (kind == 'missing_id')
          c['evidence'] = [
            {'id': 'memory:invented', 'quote': words, 'role': 'support'},
          ];
        if (kind == 'false_quote')
          c['evidence'] = [
            {'id': 'chat:u', 'quote': '并没有说过的话', 'role': 'support'},
          ];
        if (kind == 'no_support')
          c['evidence'] = [
            {'id': 'chat:u', 'quote': words, 'role': 'counter'},
          ];
        if (kind == 'empty_evidence') c['evidence'] = [];
        final p = kind == 'malformed' ? <String, dynamic>{} : payload(c);
        if (kind == 'duplicate_id') (p['changes'] as List).add(change());
        expect(
          DreamContract.apply(
            payload: p,
            state: {},
            sources: [source(fresh: kind != 'old_as_new')],
            now: night,
          ),
          isNull,
        );
      });
    }
    test(
      'new experience revises old interpretation rather than voting against six months',
      () {
        final oldAt = night.subtract(const Duration(days: 180));
        final old = DreamContract.apply(
          payload: payload(change(view: '我以为完成所有目标才是游玩的乐趣。')),
          state: {},
          sources: [source(at: oldAt.millisecondsSinceEpoch)],
          now: oldAt,
        )!;
        final next = DreamContract.apply(
          payload: payload(),
          state: old,
          sources: [source()],
          now: night,
        )!;
        expect(DreamContract.records(next['insights']).length, 1);
        final history = DreamContract.records(next['history']).single;
        expect(history['understanding'], contains('完成所有目标'));
        expect(
          DreamContract.records(history['evidence']).single['at'],
          oldAt.millisecondsSinceEpoch,
        );
        expect(
          DreamContract.records(next['insights']).single['understanding'],
          change()['understanding'],
        );
      },
    );
    test(
      'reinterpreting old sources stays tentative and preserves the original date',
      () {
        final original = source(
          fresh: false,
          at: night.subtract(const Duration(days: 190)).millisecondsSinceEpoch,
        );
        final next = DreamContract.apply(
          payload: payload(
            change(basis: 'reinterpretation', stance: 'considered'),
          ),
          state: {},
          sources: [original],
          now: night,
        )!;
        final i = DreamContract.records(next['insights']).single;
        expect(i['stance'], 'tentative');
        expect(DreamContract.records(i['evidence']).single['at'], original.at);
      },
    );
    test('assistant self-report cannot establish a considered disposition', () {
      final next = DreamContract.apply(
        payload: payload(change(stance: 'considered')),
        state: {},
        sources: [source(kind: 'assistant_text')],
        now: night,
      )!;
      expect(
        DreamContract.records(next['insights']).single['stance'],
        'tentative',
      );
    });
    test(
      'repeating the same conclusion does not refresh it or increase certainty',
      () {
        final old = DreamContract.apply(
          payload: payload(),
          state: {},
          sources: [source()],
          now: night,
        )!;
        final next = DreamContract.apply(
          payload: payload(change(stance: 'considered')),
          state: old,
          sources: [source()],
          now: night.add(const Duration(days: 1)),
        )!;
        expect(next['insights'], old['insights']);
        expect(next['history'], isEmpty);
      },
    );
    test('aspirations are allowed without claiming an established habit', () {
      final next = DreamContract.apply(
        payload: payload(change(stance: 'aspiration')),
        state: {},
        sources: [source()],
        now: night,
      )!;
      expect(
        DreamContract.records(next['insights']).single['stance'],
        'aspiration',
      );
    });
    test('retirement archives reasons and removes the old active view', () {
      final old = DreamContract.apply(
        payload: payload(),
        state: {},
        sources: [source()],
        now: night,
      )!;
      final retired = {...change(), 'action': 'retire'};
      final next = DreamContract.apply(
        payload: payload(retired),
        state: old,
        sources: [source()],
        now: night.add(const Duration(days: 1)),
      )!;
      expect(next['insights'], isEmpty);
      expect(
        DreamContract.records(next['history']).single['revision_reason'],
        retired['reason'],
      );
    });
    test('current interpretations are bounded without age-based eviction', () {
      var state = <String, dynamic>{};
      for (var i = 0; i < 10; i++) {
        state = DreamContract.apply(
          payload: payload(change(id: 'view.$i')),
          state: state,
          sources: [source()],
          now: night,
        )!;
      }
      expect(
        DreamContract.apply(
          payload: payload(change(id: 'overflow')),
          state: state,
          sources: [source()],
          now: night,
        ),
        isNull,
      );
      expect(DreamContract.records(state['insights']).first['id'], 'view.0');
    });
  });

  group('durable midnight integration', () {
    late AppDatabase db;
    setUp(() async {
      db = await AppDatabase.createForTesting(databaseFactoryFfi);
    });
    tearDown(() async {
      await db.closeForTesting();
    });
    Future<void> seed({
      String id = 'u',
      String text = words,
      DateTime? at,
      String role = 'user',
      String worldBook = '',
      bool proactive = false,
    }) => db.insertMessage(
      ChatMessage(
        id: id,
        role: role,
        content: text,
        createdAt: at ?? night.subtract(const Duration(hours: 2)),
        worldBookContextJson: worldBook,
        isProactive: proactive,
      ),
    );
    DreamEngine engine({DreamReviewer? reviewer}) =>
        DreamEngine(db, reviewer: reviewer ?? (_) async => payload());

    test(
      'midnight runs once; a missed night catches up in the daytime',
      () async {
        await seed();
        var calls = 0;
        final e = engine(
          reviewer: (_) async {
            calls++;
            return payload();
          },
        );
        expect(
          await e.maybeDream(now: night.add(const Duration(hours: 10))),
          isTrue,
        );
        expect(
          await e.maybeDream(
            now: night.add(const Duration(hours: 18)),
            manual: true,
          ),
          isFalse,
        );
        expect(calls, 1);
        expect(
          (await DreamStore(db).load())['last_success_day'],
          DreamContract.day(night),
        );
        expect(
          await db.getSetting('last_proactive_at'),
          isNot('${night.millisecondsSinceEpoch}'),
        );
      },
    );
    test(
      'quiet days make no model call; week review replaces the ordinary pass',
      () async {
        await seed();
        final weeklyFlags = <Object?>[];
        final e = engine(
          reviewer: (m) async {
            weeklyFlags.add(m['weekly']);
            return weeklyFlags.length == 1 ? payload() : {'changes': []};
          },
        );
        expect(await e.maybeDream(now: night), isTrue);
        expect(
          await e.maybeDream(now: night.add(const Duration(days: 1))),
          isTrue,
        );
        expect(weeklyFlags, [true]);
        expect(
          await e.maybeDream(now: night.add(const Duration(days: 7))),
          isTrue,
        );
        expect(weeklyFlags, [true, true]);
        expect(
          await e.maybeDream(now: night.add(const Duration(days: 7, hours: 1))),
          isFalse,
        );
      },
    );
    test(
      'a completed no-change dream consumes the day without inventing personality',
      () async {
        await seed();
        expect(
          await engine(
            reviewer: (_) async => {'changes': []},
          ).maybeDream(now: night),
          isTrue,
        );
        expect((await DreamStore(db).load())['insights'], isEmpty);
        expect(
          await engine().maybeDream(now: night.add(const Duration(hours: 1))),
          isFalse,
        );
      },
    );
    for (final invalid in [false, true]) {
      test(
        'failed/invalid payload keeps the cursor and retries after backoff: $invalid',
        () async {
          await seed();
          var calls = 0;
          final e = engine(
            reviewer: (_) async {
              calls++;
              if (calls == 1)
                return invalid ? payload(change(source: 'invented')) : null;
              return payload();
            },
          );
          expect(await e.maybeDream(now: night), isFalse);
          expect(await db.getSetting(DreamStore.stateKey), isNull);
          expect(
            await e.maybeDream(now: night.add(const Duration(minutes: 10))),
            isFalse,
          );
          expect(calls, 1);
          expect(
            await e.maybeDream(now: night.add(const Duration(minutes: 31))),
            isTrue,
          );
          expect(calls, 2);
        },
      );
    }
    test(
      'an offline night backs off but still allows daytime catch-up',
      () async {
        await seed();
        var calls = 0;
        final e = engine(
          reviewer: (_) async {
            calls++;
            throw StateError('offline');
          },
        );
        for (final minutes in [0, 10, 31, 60, 92, 120]) {
          await e.maybeDream(now: night.add(Duration(minutes: minutes)));
        }
        expect(calls, 3);
        expect(await db.getSetting(DreamStore.stateKey), isNull);
        expect(
          await engine().maybeDream(now: night.add(const Duration(hours: 8))),
          isTrue,
        );
      },
    );
    test(
      'manual retry can recover after connectivity returns without a second daily success',
      () async {
        await seed();
        expect(
          await engine(reviewer: (_) async => null).maybeDream(now: night),
          isFalse,
        );
        expect(
          await engine().maybeDream(
            now: night.add(const Duration(minutes: 1)),
            manual: true,
          ),
          isTrue,
        );
        expect(
          await engine().maybeDream(
            now: night.add(const Duration(minutes: 2)),
            manual: true,
          ),
          isFalse,
        );
      },
    );
    test('busy chat defers without spending the daily opportunity', () async {
      await seed();
      await db.tryAcquireLocalLease('chat_turn_lease');
      expect(await engine().maybeDream(now: night, manual: true), isFalse);
      await db.releaseLocalLease('chat_turn_lease');
      expect(await engine().maybeDream(now: night), isTrue);
    });
    test(
      'five-minute idle grace prevents an immediate post-reply dream',
      () async {
        await seed(at: night.subtract(const Duration(minutes: 2)));
        expect(await engine().maybeDream(now: night), isFalse);
        expect(
          await engine().maybeDream(now: night.add(const Duration(minutes: 4))),
          isTrue,
        );
      },
    );
    for (final event in [
      'new_message',
      'generation',
      'epoch',
      'disable',
      'reset',
      'transfer',
      'source_edit',
      'lease_loss',
    ]) {
      test(
        '$event preempts a late result with no ghost interpretation',
        () async {
          await seed();
          final entered = Completer<void>();
          final finish = Completer<Map<String, dynamic>?>();
          final work = engine(
            reviewer: (_) {
              entered.complete();
              return finish.future;
            },
          ).maybeDream(now: night);
          await entered.future;
          switch (event) {
            case 'new_message':
              await seed(id: 'new', text: '新消息来了', at: night);
              break;
            case 'generation':
              await db.setSetting('state_generation', '8');
              break;
            case 'epoch':
              await db.setSetting('runtime_state_epoch_v1', 'new');
              break;
            case 'disable':
              await db.setSetting(DreamStore.enabledKey, '0');
              break;
            case 'reset':
              await db.setSetting(
                'conversation_context_reset_at',
                '${night.millisecondsSinceEpoch}',
              );
              break;
            case 'transfer':
              await db.setSetting('transfer_lock', '1');
              break;
            case 'source_edit':
              await (await db.database).update(
                'messages',
                {'content': '原消息已经改写'},
                where: 'id = ?',
                whereArgs: ['u'],
              );
              break;
            case 'lease_loss':
              await db.setSetting(DreamStore.leaseKey, 'other|9999999999999');
              break;
          }
          finish.complete(payload());
          expect(await work, isFalse);
          expect(await db.getSetting(DreamStore.stateKey), isNull);
        },
      );
    }
    test('parallel heartbeats cannot call the reviewer twice', () async {
      await seed();
      final entered = Completer<void>();
      final finish = Completer<Map<String, dynamic>?>();
      var calls = 0;
      final e = engine(
        reviewer: (_) {
          calls++;
          entered.complete();
          return finish.future;
        },
      );
      final first = e.maybeDream(now: night);
      await entered.future;
      expect(await engine().maybeDream(now: night), isFalse);
      finish.complete(payload());
      expect(await first, isTrue);
      expect(calls, 1);
    });
    test(
      'SQLite failure rolls back state, schedule and successful diagnostic together',
      () async {
        await seed();
        await (await db.database).execute(
          "CREATE TRIGGER dream_fail BEFORE INSERT ON settings WHEN NEW.key = '${DreamStore.stateKey}' BEGIN SELECT RAISE(ABORT, 'test'); END",
        );
        expect(await engine().maybeDream(now: night), isFalse);
        expect(await db.getSetting(DreamStore.stateKey), isNull);
        expect(
          await db.getSetting('last_self_reflection_at'),
          isNot('${night.millisecondsSinceEpoch}'),
        );
        await (await db.database).execute('DROP TRIGGER dream_fail');
        expect(
          await engine().maybeDream(
            now: night.add(const Duration(minutes: 31)),
          ),
          isTrue,
        );
      },
    );
    test(
      'roleplay assistant and its unmarked user are excluded even at a batch edge',
      () async {
        await seed();
        await seed(
          id: 'rp-u',
          text: '我是幻想世界的一条龙',
          at: night.subtract(const Duration(minutes: 30)),
        );
        await seed(
          id: 'rp-a',
          text: '我们飞去了月亮',
          role: 'assistant',
          at: night.subtract(const Duration(minutes: 29)),
          worldBook: const WorldBookTurnContext(
            roleplaySessionId: 'fiction',
          ).encode(),
        );
        final material = await DreamMaterial.collect(
          db,
          {},
          night,
          weekly: true,
        );
        expect(material.sources.map((s) => s.id), contains('chat:u'));
        expect(material.sources.map((s) => s.id), isNot(contains('chat:rp-u')));
        expect(material.sources.map((s) => s.id), isNot(contains('chat:rp-a')));
        expect(
          (await DreamStore.originals(await db.database, ['chat:rp-u'])),
          isEmpty,
        );
      },
    );
    test(
      'a proactive roleplay line does not erase the real prior user message',
      () async {
        await seed();
        await seed(
          id: 'rp-a',
          role: 'assistant',
          proactive: true,
          text: '虚构台词',
          at: night.subtract(const Duration(minutes: 29)),
          worldBook: const WorldBookTurnContext(
            roleplaySessionId: 'fiction',
          ).encode(),
        );
        final material = await DreamMaterial.collect(
          db,
          {},
          night,
          weekly: true,
        );
        expect(material.sources.map((s) => s.id), contains('chat:u'));
      },
    );
    test(
      'long backlog uses the processed cursor instead of skipping unseen rows',
      () async {
        final start = night.subtract(const Duration(hours: 3));
        await db.setSetting(
          DreamStore.stateKey,
          jsonEncode({
            'schema': 1,
            'insights': [],
            'cursor': {
              'chat_at': start.millisecondsSinceEpoch - 1,
              'chat_id': '',
            },
          }),
        );
        for (var i = 0; i < 250; i++) {
          await seed(
            id: 'm$i',
            text: '真实消息第$i条',
            at: start.add(Duration(seconds: i)),
          );
        }
        final seen = <String>[];
        final e = engine(
          reviewer: (m) async {
            seen.addAll(
              (m['sources'] as List)
                  .cast<Map>()
                  .where((s) => s['fresh'] == true)
                  .map((s) => s['id'] as String),
            );
            return {'changes': []};
          },
        );
        expect(await e.maybeDream(now: night), isTrue);
        expect(seen.length, 240);
        expect(
          await e.maybeDream(now: night.add(const Duration(days: 1))),
          isTrue,
        );
        expect(seen.length, 250);
        expect(seen.toSet().length, 250);
      },
    );
    test('deleted or regenerated originals stop influencing prompts', () async {
      await seed();
      expect(await engine().maybeDream(now: night), isTrue);
      expect(
        await DreamStore(db).prompt(),
        contains(change()['understanding']),
      );
      await (await db.database).delete(
        'messages',
        where: 'id = ?',
        whereArgs: ['u'],
      );
      expect(await DreamStore(db).prompt(), isEmpty);
      expect((await DreamStore(db).load())['insights'], isNotEmpty);
    });
    test(
      'fresh-topic and roleplay isolation preserve ordinary and game choice use',
      () async {
        await seed();
        await engine().maybeDream(now: night);
        final store = DreamStore(db);
        expect(await store.prompt(), contains(change()['choice']));
        expect(
          await store.prompt(game: true),
          contains(change()['understanding']),
        );
        expect(await store.prompt(freshSourceOnly: true), isEmpty);
        expect(await store.prompt(roleplay: true), isEmpty);
        expect(await store.prompt(), isNot(contains(words)));
        await db.setSetting(DreamStore.enabledKey, '0');
        expect(await store.prompt(), isEmpty);
      },
    );
    test(
      'metadata does not leak dream text; backup includes cursor and revisions',
      () async {
        await seed();
        await engine().maybeDream(now: night);
        final diagnostic = jsonEncode(await DreamStore(db).diagnostics());
        expect(diagnostic, isNot(contains(words)));
        expect(diagnostic, isNot(contains(change()['understanding'])));
        final exported = await db.exportAll();
        final settings = ((exported['tables'] as Map)['settings'] as List)
            .cast<Map>();
        final saved = settings.singleWhere(
          (s) => s['key'] == DreamStore.stateKey,
        )['value'];
        expect(saved, await db.getSetting(DreamStore.stateKey));
        final restoredRoot = await Directory.systemTemp.createTemp(
          'dream-restore-',
        );
        final restored = await AppDatabase.createForTesting(
          databaseFactoryFfi,
          path: '${restoredRoot.path}/restored.db',
        );
        try {
          await restored.importAll(exported);
          expect(await restored.getSetting(DreamStore.stateKey), saved);
          expect(
            await DreamStore(restored).prompt(),
            contains(change()['understanding']),
          );
          expect(
            await DreamEngine(
              restored,
              reviewer: (_) async => throw StateError('must not run twice'),
            ).maybeDream(now: night),
            isFalse,
          );
        } finally {
          await restored.closeForTesting();
          await restoredRoot.delete(recursive: true);
        }
      },
    );
    test('malformed saved state is not silently replaced', () async {
      await seed();
      await db.setSetting(DreamStore.stateKey, '{broken');
      var calls = 0;
      expect(
        await engine(
          reviewer: (_) async {
            calls++;
            return payload();
          },
        ).maybeDream(now: night),
        isFalse,
      );
      expect(calls, 0);
      expect(await db.getSetting(DreamStore.stateKey), '{broken');
    });
  });
}
