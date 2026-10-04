import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/emotion/emotion_contract.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/generation_job.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:ai_companion_localfirst/core/reflection/deep_reflection_contract.dart';
import 'package:ai_companion_localfirst/core/reflection/deep_reflection_engine.dart';
import 'package:ai_companion_localfirst/core/reflection/deep_reflection_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final at = DateTime.now();
  const userText = '我觉得可以保留不确定，不用马上下结论';
  const replyText = '可以先保留不确定，这样我能区分选择与解释。';
  Map<String, dynamic> topic({String phase = 'offered'}) => {
    'id': 'dr:test',
    'revision': 0,
    'reset': '',
    'phase': phase,
    'question': '暂时解释不了的选择，怎样才算理解了它？',
    'prior_view': '以为每个选择都需要立刻得到解释',
    'tension': '我们讨论的选择并没有唯一解释',
    'why_user': '想知道你怎样面对暂时不清楚的选择',
    'view': '以为每个选择都需要立刻得到解释',
    'remaining': '是否一定要马上解释',
    'progress': '',
    'created_at': at.millisecondsSinceEpoch,
    'updated_at': at.millisecondsSinceEpoch,
  };
  Map<String, dynamic> update({
    String action = 'settle',
    bool related = true,
    bool resume = false,
    String userQuote = '可以保留不确定',
  }) => {
    'id': 'dr:test',
    'action': action,
    'related': related,
    'resume': resume,
    'view': '可以让选择先于完整解释',
    'remaining': action == 'discuss' ? '解释会怎样影响下一次选择' : '',
    'progress': '理解到保留不确定也是一个暂时立场',
    'user_quote': userQuote,
    'reply_quote': '可以先保留不确定',
  };
  String sidecar(Map<String, dynamic> u) =>
      '<reflection_state>${jsonEncode(u)}</reflection_state>';

  test('every streamed prefix hides complete and interrupted metadata', () {
    final marker = sidecar(update());
    for (var n = 0; n <= marker.length; n++) {
      expect(
        EmotionEnvelope.streamingVisible('正文${marker.substring(0, n)}'),
        '正文',
        reason: 'prefix $n',
      );
    }
    expect(
      EmotionEnvelope.parse('<emotion>平静</emotion>正文$marker').visibleText,
      '正文',
    );
    expect(
      EmotionEnvelope.parse('正文${marker.toUpperCase()}').visibleText,
      '正文',
    );
  });
  test(
    'malformed duplicate and oversized sidecars are hidden but not applied',
    () {
      final good = sidecar(update());
      for (final raw in [
        '$good$good',
        '<reflection_state>{broken}</reflection_state>',
        '<reflection_state>${' ' * 2401}</reflection_state>',
        '<reflection_state extra="x">{}</reflection_state>',
      ]) {
        expect(DeepReflectionUpdate.parse(raw), isNull);
        expect(DeepReflectionUpdate.visible('正文$raw'), '正文');
      }
      expect(DeepReflectionUpdate.parse(good), isNotNull);
    },
  );
  test('partial closing and spaced tags never escape', () {
    expect(DeepReflectionUpdate.visible('正文< reflection_state>私有内容'), '正文');
    expect(DeepReflectionUpdate.visible('正文</reflec'), '正文');
    expect(DeepReflectionUpdate.visible('正文<reflection_state />'), '正文');
    expect(DeepReflectionUpdate.visible('数学 < 3'), '数学 < 3');
  });

  group('durable discussion', () {
    late AppDatabase db;
    setUp(() async {
      db = await AppDatabase.createForTesting(databaseFactoryFfi);
    });
    tearDown(() async {
      await db.closeForTesting();
    });
    Future<String> seed({String phase = 'offered'}) async {
      final raw = jsonEncode({'topic': topic(phase: phase), 'history': []});
      await db.setSetting(DeepReflectionStore.stateKey, raw);
      return raw;
    }

    Future<GenerationJob> turn({String content = userText}) async {
      final pending = await db.createGenerationTurn(
        user: ChatMessage(
          id: 'u',
          role: 'user',
          content: content,
          createdAt: at,
        ),
        assistantMessageId: 'a',
        model: 'deepseek-flash',
        reasoningEffort: 'high',
      );
      return (await db.claimGenerationJob(pending.id))!;
    }

    Future<bool> commit(
      GenerationJob job,
      DeepReflectionContext? context, {
      Map<String, dynamic>? data,
      bool roleplay = false,
      String? token,
    }) => db.completeGenerationJobIfCurrent(
      jobId: job.id,
      runToken: token ?? job.runToken,
      assistant: ChatMessage(
        id: 'a',
        role: 'assistant',
        content: replyText,
        createdAt: at.add(const Duration(seconds: 1)),
        worldBookContextJson: roleplay
            ? const WorldBookTurnContext(roleplaySessionId: 'fiction').encode()
            : '',
      ),
      deepReflection: context,
      reflectionUpdate: data == null
          ? null
          : DeepReflectionUpdate.parse(sidecar(data)),
    );
    Future<Map<String, dynamic>> current() async =>
        DeepReflectionStore.decode(
              await db.getSetting(DeepReflectionStore.stateKey) ?? '',
            )['topic']
            as Map<String, dynamic>;

    test('one answer may settle; message and state commit once', () async {
      await seed();
      final c = await DeepReflectionStore(db).context(now: at);
      final j = await turn();
      expect(await commit(j, c, data: update()), isTrue);
      expect((await current())['phase'], 'settled');
      expect((await current())['revision'], 1);
      expect(await db.messageById('a'), isNotNull);
      await commit(j, c, data: update());
      expect((await current())['revision'], 1);
    });
    test(
      'short acknowledgement can continue with an actual remaining question',
      () async {
        await seed();
        final c = await DeepReflectionStore(db).context(now: at);
        final j = await turn(content: '嗯');
        await commit(
          j,
          c,
          data: update(action: 'discuss', userQuote: '嗯'),
        );
        expect((await current())['phase'], 'discussing');
        expect((await current())['remaining'], isNotEmpty);
      },
    );
    test('unrelated turn pauses without replacing the existing view', () async {
      await seed();
      final c = await DeepReflectionStore(db).context(now: at);
      final j = await turn(content: '今天吃什么');
      await commit(j, c, data: update(action: 'pause', related: false));
      expect((await current())['phase'], 'paused');
      expect((await current())['view'], topic()['view']);
      expect(
        await DeepReflectionStore(
          db,
        ).context(now: at.add(const Duration(days: 5)), invite: true),
        isNull,
      );
    });
    test('paused question requires an explicit resume decision', () async {
      final raw = await seed(phase: 'paused');
      final c = await DeepReflectionStore(db).context(now: at);
      final j = await turn();
      await commit(j, c, data: update(action: 'discuss'));
      expect(await db.getSetting(DeepReflectionStore.stateKey), raw);
    });
    test('user returning to a paused issue can continue', () async {
      await seed(phase: 'paused');
      final c = await DeepReflectionStore(db).context(now: at);
      final j = await turn();
      await commit(j, c, data: update(action: 'discuss', resume: true));
      expect((await current())['phase'], 'discussing');
    });
    for (final kind in [
      'missing',
      'invented_quote',
      'missing_question',
      'wrong_id',
      'roleplay',
    ]) {
      test(
        '$kind metadata does not fabricate progress or block the reply',
        () async {
          final raw = await seed();
          final c = await DeepReflectionStore(db).context(now: at);
          final j = await turn();
          final data = update(
            action: kind == 'missing_question' ? 'discuss' : 'settle',
          );
          if (kind == 'invented_quote') data['user_quote'] = '用户根本没说过';
          if (kind == 'missing_question') data['remaining'] = '';
          if (kind == 'wrong_id') data['id'] = 'another';
          expect(
            await commit(
              j,
              c,
              data: kind == 'missing' ? null : data,
              roleplay: kind == 'roleplay',
            ),
            isTrue,
          );
          expect(await db.getSetting(DeepReflectionStore.stateKey), raw);
        },
      );
    }
    test(
      'stale generation token never writes either reply or progress',
      () async {
        final raw = await seed();
        final c = await DeepReflectionStore(db).context(now: at);
        final j = await turn();
        expect(await commit(j, c, data: update(), token: 'expired'), isFalse);
        expect(await db.messageById('a'), isNull);
        expect(await db.getSetting(DeepReflectionStore.stateKey), raw);
      },
    );
    test('Stop invalidates the writer with no ghost conclusion', () async {
      final raw = await seed();
      final c = await DeepReflectionStore(db).context(now: at);
      final j = await turn();
      expect(await db.cancelGenerationJobByUser(j.id), isTrue);
      expect(await commit(j, c, data: update()), isFalse);
      expect(await db.getSetting(DeepReflectionStore.stateKey), raw);
    });
    test('regeneration undoes the matching discussion settlement', () async {
      final raw = await seed();
      final c = await DeepReflectionStore(db).context(now: at);
      final j = await turn();
      await commit(j, c, data: update());
      expect(await db.restartLatestCompletedReply('a'), isNotNull);
      expect(await db.getSetting(DeepReflectionStore.stateKey), raw);
      expect(await db.messageById('a'), isNull);
    });
    test(
      'SQLite failure rolls back reply, job and reflection together',
      () async {
        final raw = await seed();
        final c = await DeepReflectionStore(db).context(now: at);
        final j = await turn();
        await (await db.database).execute(
          "CREATE TRIGGER reflection_fail BEFORE INSERT ON settings WHEN NEW.key = '${DeepReflectionStore.stateKey}' BEGIN SELECT RAISE(ABORT, 'test'); END",
        );
        await expectLater(commit(j, c, data: update()), throwsA(anything));
        expect(await db.messageById('a'), isNull);
        expect((await db.generationJobById(j.id))!.status, 'running');
        expect(await db.getSetting(DeepReflectionStore.stateKey), raw);
      },
    );
    for (final key in [
      DeepReflectionStore.enabledKey,
      DeepReflectionStore.resetKey,
    ]) {
      test('$key change prevents stale settlement', () async {
        final raw = await seed();
        final c = await DeepReflectionStore(db).context(now: at);
        final j = await turn();
        await db.setSetting(
          key,
          key == DeepReflectionStore.enabledKey ? '0' : '42',
        );
        await commit(j, c, data: update());
        expect(await db.getSetting(DeepReflectionStore.stateKey), raw);
        expect(await DeepReflectionStore(db).context(now: at), isNull);
      });
    }
    test('uninvited preparation never hijacks a normal user turn', () async {
      await seed(phase: 'ready');
      expect(await DeepReflectionStore(db).context(now: at), isNull);
      expect(
        await DeepReflectionStore(db).context(now: at, invite: true),
        isNotNull,
      );
    });
    test(
      'invitation is committed with actual delivered message and is rate limited',
      () async {
        await seed(phase: 'ready');
        final c = await DeepReflectionStore(db).claimInvitation('dr:test', at);
        expect(c, isNotNull);
        expect((await current())['phase'], 'ready');
        expect(
          await DeepReflectionStore(db).claimInvitation('dr:test', at),
          isNull,
        );
        final blocked = await db.commitProactiveMessageIfCurrent(
          message: ChatMessage(
            id: 'p',
            role: 'assistant',
            content: '有个具体的问题想听听你的看法。',
            createdAt: at,
          ),
          evaluationStartedAt: at,
          reflectionInvitation: c,
        );
        expect(blocked, isNull);
        expect((await current())['phase'], 'offered');
        expect((await current())['last_reply_id'], 'p');
      },
    );
    test(
      'new user message preempts invitation without marking it discussed',
      () async {
        final raw = await seed(phase: 'ready');
        final c = await DeepReflectionStore(db).claimInvitation('dr:test', at);
        await db.insertMessage(
          ChatMessage(
            id: 'new',
            role: 'user',
            content: '我先说',
            createdAt: at.add(const Duration(seconds: 1)),
          ),
        );
        expect(
          await db.commitProactiveMessageIfCurrent(
            message: ChatMessage(
              id: 'p',
              role: 'assistant',
              content: '问题',
              createdAt: at,
            ),
            evaluationStartedAt: at,
            reflectionInvitation: c,
          ),
          'new_user',
        );
        expect(await db.getSetting(DeepReflectionStore.stateKey), raw);
        expect(await db.messageById('p'), isNull);
      },
    );
    test(
      'quiet week means dormant context, never automatic invitation',
      () async {
        await seed();
        final c = await DeepReflectionStore(
          db,
        ).context(now: at.add(const Duration(days: 8)));
        expect(c!.topic['phase'], 'paused');
        expect(
          await DeepReflectionStore(
            db,
          ).context(now: at.add(const Duration(days: 8)), invite: true),
          isNull,
        );
      },
    );
    test(
      'preparation is optional, bounded, and does not retry every heartbeat',
      () async {
        await db.insertMessage(
          ChatMessage(
            id: 'source',
            role: 'user',
            content: userText,
            createdAt: at,
          ),
        );
        var calls = 0;
        final engine = DeepReflectionEngine(
          db,
          reviewer: (_) async {
            calls++;
            return {'topic': null};
          },
        );
        expect(await engine.maybePrepare(now: at), isFalse);
        expect(
          await engine.maybePrepare(now: at.add(const Duration(hours: 1))),
          isFalse,
        );
        expect(
          await engine.maybePrepare(now: at.add(const Duration(hours: 13))),
          isFalse,
        );
        expect(calls, 1);
        expect(await db.getSetting(DeepReflectionStore.stateKey), isNull);
      },
    );
    test(
      'active discussion and disabled module never invoke preparation',
      () async {
        await seed();
        var calls = 0;
        final engine = DeepReflectionEngine(
          db,
          reviewer: (_) async {
            calls++;
            return null;
          },
        );
        await engine.maybePrepare(now: at);
        await db.setSetting(DeepReflectionStore.enabledKey, '0');
        await engine.maybePrepare(now: at.add(const Duration(days: 10)));
        expect(calls, 0);
      },
    );
    test('late preparation cannot write after reset', () async {
      await db.insertMessage(
        ChatMessage(
          id: 'source',
          role: 'user',
          content: userText,
          createdAt: at,
        ),
      );
      final entered = Completer<void>();
      final release = Completer<Map<String, dynamic>?>();
      final work = DeepReflectionEngine(
        db,
        reviewer: (_) {
          entered.complete();
          return release.future;
        },
      ).maybePrepare(now: at);
      await entered.future;
      await db.setSetting(DeepReflectionStore.resetKey, 'changed');
      release.complete({
        'topic': {
          'question': '解释不了的选择怎样才算理解？',
          'prior_view': '原本以为需要解释',
          'tension': '允许不确定改变了理解',
          'why_user': '想听用户的不同视角',
          'source_id': 'chat:source',
          'source_quote': '可以保留不确定',
          'suitable': true,
        },
      });
      expect(await work, isFalse);
      expect(await db.getSetting(DeepReflectionStore.stateKey), isNull);
    });
    test(
      'generation requires verifiable new inspiration instead of stock questions',
      () {
        final source = [
          {
            'id': 'chat:source',
            'text': userText,
            'at': at.millisecondsSinceEpoch,
          },
        ];
        final payload = {
          'topic': {
            'question': '解释不了的选择怎样才算理解？',
            'prior_view': '原本以为需要解释',
            'tension': '允许不确定改变了理解',
            'why_user': '想听用户的不同视角',
            'source_id': 'chat:source',
            'source_quote': '可以保留不确定',
            'suitable': true,
          },
        };
        expect(
          DeepReflectionEngine.qualify(payload, source, {}, at, ''),
          isNotNull,
        );
        expect(DeepReflectionEngine.qualify(payload, [], {}, at, ''), isNull);
        expect(
          DeepReflectionEngine.qualify(payload, source, topic(), at, ''),
          isNull,
        );
      },
    );
    test(
      'regeneration retracts archived conclusion without erasing newer preparation',
      () async {
        await seed();
        final c = await DeepReflectionStore(db).context(now: at);
        final j = await turn();
        await commit(j, c, data: update());
        final settled = await current();
        final newer = {...topic(phase: 'ready'), 'id': 'dr:new'};
        await db.setSetting(
          DeepReflectionStore.stateKey,
          jsonEncode({
            'topic': newer,
            'history': [settled],
          }),
        );
        expect(await db.restartLatestCompletedReply('a'), isNotNull);
        final state = DeepReflectionStore.decode(
          await db.getSetting(DeepReflectionStore.stateKey) ?? '',
        );
        expect((state['topic'] as Map)['id'], 'dr:new');
        expect((state['history'] as List).single['phase'], 'paused');
        expect((state['history'] as List).single['view'], topic()['view']);
      },
    );
    test('malformed optional state does not block context building', () async {
      await db.setSetting(DeepReflectionStore.stateKey, '{broken');
      expect(await DeepReflectionStore(db).context(now: at), isNull);
      await db.setSetting(
        DeepReflectionStore.stateKey,
        jsonEncode({
          'topic': {...topic(), 'updated_at': 'broken'},
        }),
      );
      expect(await DeepReflectionStore(db).context(now: at), isNull);
    });
    test('diagnostics contain no question or view', () async {
      await seed();
      final c = await DeepReflectionStore(db).context(now: at);
      final j = await turn();
      await commit(j, c, data: update());
      final raw = await db.getSetting(DeepReflectionStore.diagnosticKey);
      expect(raw, contains('committed_mutations'));
      expect(raw, isNot(contains(userText)));
      expect(raw, isNot(contains(topic()['question'])));
      expect(raw, isNot(contains('可以让选择先于完整解释')));
    });
  });
}
