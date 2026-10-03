import 'package:ai_companion_localfirst/core/ai/nsfw_context_router.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/generation_job.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:ai_companion_localfirst/core/mood/mood_appraisal.dart';
import 'package:ai_companion_localfirst/core/mood/mood_service.dart';
import 'package:ai_companion_localfirst/core/mood/mood_state.dart';
import 'package:ai_companion_localfirst/core/mood/mood_store.dart';
import 'package:ai_companion_localfirst/core/emotion/emotion_episode_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final at = DateTime.utc(2026, 10, 3, 12);
  MoodEvent event(
    String kind, {
    String id = 'user:u',
    String level = 'clear',
    int minutes = 0,
    String target = '',
  }) => MoodEvent(
    id: id,
    kind: kind,
    level: level,
    at: at.add(Duration(minutes: minutes)),
    targetId: target,
  );

  test('neighboring meanings and degrees do not erase shared evidence', () {
    expect(
      MoodAppraisal.resolveEvent({
        'playful': .46,
        'connection': .49,
        'none': .05,
      }),
      'connection',
    );
    expect(
      MoodAppraisal.resolveImpact({'mild': .46, 'clear': .49, 'none': .05}),
      'mild',
    );
    expect(
      MoodAppraisal.resolveImpact({
        'mild': .02,
        'clear': .07,
        'strong': .9,
        'none': .01,
      }),
      'strong',
    );
    expect(
      MoodAppraisal.resolveImpact({'mild': .35, 'clear': .1, 'none': .55}),
      'none',
    );
  });

  test('time restores baseline, without reads adding anything', () {
    final events = [event('hurt')];
    final initial = MoodPolicy.evaluate(events, at);
    expect(initial.valence, lessThan(.55));
    expect(MoodPolicy.evaluate(events, at).valence, initial.valence);
    expect(
      MoodPolicy.evaluate(events, at.add(const Duration(minutes: 45))).valence,
      greaterThan(initial.valence),
    );
    expect(
      MoodPolicy.evaluate(events, at.add(const Duration(hours: 12))).valence,
      .55,
    );
    expect(
      MoodPolicy.evaluate([], at.add(const Duration(days: 5))).valence,
      .55,
    );
  });
  test(
    'confidence never scales severity and teasing cannot create relational injury',
    () {
      for (final interaction in ['light', 'mutual', 'strong']) {
        expect(
          MoodAppraisal.event(
            answers: {
              'mood_event': 'hurt',
              'mood_impact': 'strong',
              'interaction': interaction,
            },
            userId: 'u',
            at: at,
          ),
          isNull,
        );
      }
      expect(
        MoodAppraisal.event(
          answers: {'mood_event': 'hurt', 'mood_impact': 'mild'},
          userId: 'u',
          at: at,
        ),
        isNull,
      );
      final hurt = MoodAppraisal.event(
        answers: {
          'mood_event': 'boundary',
          'mood_impact': 'strong',
          'interaction': 'serious',
        },
        userId: 'u',
        at: at,
      );
      expect(hurt!.magnitude, .22);
      expect(MoodAppraisal.event(answers: null, userId: 'u', at: at), isNull);
    },
  );
  test(
    'repair addresses one incident; clarification removes a mistaken injury',
    () {
      final hurt = event('hurt');
      final now = at.add(const Duration(minutes: 2));
      final before = MoodPolicy.evaluate([hurt], now).valence;
      final repaired = MoodPolicy.evaluate([
        hurt,
        event('repair', id: 'user:r', minutes: 1, target: hurt.id),
      ], now).valence;
      expect(repaired, greaterThan(before));
      expect(repaired, lessThan(.55));
      expect(
        MoodPolicy.evaluate([
          hurt,
          event('clarified', id: 'user:c', minutes: 1, target: hurt.id),
        ], now).valence,
        .55,
      );
      expect(
        MoodPolicy.evaluate([
          hurt,
          event('repair', id: 'user:r', minutes: 1, target: 'unrelated'),
        ], now).valence,
        before,
      );
      expect(
        MoodAppraisal.event(
          answers: {'mood_event': 'repair', 'mood_impact': 'mild'},
          userId: 'u',
          at: at,
        ),
        isNull,
      );
    },
  );
  test(
    'play leaves warmth not hurt; repeated events saturate and duplicates are inert',
    () {
      final play = event('playful', level: 'mild');
      final once = MoodPolicy.evaluate([play], at);
      expect(once.valence, greaterThan(.55));
      expect(MoodPolicy.evaluate([play, play, play], at).valence, once.valence);
      final many = MoodPolicy.evaluate(
        List.generate(96, (i) => event('playful', id: '$i', level: 'strong')),
        at,
      );
      expect(many.valence, lessThanOrEqualTo(.85));
      expect(many.activation, lessThanOrEqualTo(.78));
    },
  );
  test(
    'rest changes activation not affection; weather has no automatic sadness',
    () {
      final rested = MoodPolicy.evaluate([], at);
      final tired = MoodPolicy.evaluate(
        [],
        at,
        fatigue: .9,
        weatherAvailable: true,
      );
      expect(tired.valence, rested.valence);
      expect(tired.activation, lessThan(rested.activation));
      expect(tired.resting, isTrue);
      expect(tired.weatherAvailable, isTrue);
      expect(
        MoodPolicy.evaluate([event('hurt', minutes: 10)], at).valence,
        .55,
      );
    },
  );

  group('SQLite lifecycle and integration', () {
    late AppDatabase db;
    setUp(() async {
      db = await AppDatabase.createForTesting(databaseFactoryFfi);
    });
    tearDown(() async {
      await db.closeForTesting();
    });
    test(
      'pre-reply batch stages mood once without a second model or heat coupling',
      () async {
        var calls = 0;
        final user = ChatMessage(
          id: 'u',
          role: 'user',
          content: '合成暖心互动',
          createdAt: at,
        );
        final gateway = JevDecisionGateway(
          enabledReader: () async => true,
          keyReader: () async => 'test',
          clientFactory: () => MockClient((request) async {
            calls++;
            final questions =
                (jsonDecode(request.body) as Map)['questions'] as Map;
            expect(
              questions.keys,
              containsAll(['mode', 'interaction', 'mood_event', 'mood_impact']),
            );
            const picks = {
              'mode': 'daily',
              'interaction': 'ordinary',
              'flustered': 'no',
              'initiative': 'closed',
              'mood_event': 'connection',
              'mood_impact': 'mild',
            };
            return http.Response(
              jsonEncode({
                'answers': picks.map(
                  (k, v) => MapEntry(k, {
                    'type': 'choice',
                    'choice': v,
                    'confidence': 1.0,
                    'probabilities': {v: 1.0},
                  }),
                ),
              }),
              200,
            );
          }),
        );
        final router = NsfwContextRouter(
          db: db,
          jevGateway: gateway,
          client: DeepSeekClient(
            client: MockClient(
              (_) async => throw StateError('extra model call'),
            ),
          ),
        );
        await router.decide(
          apiKey: 'test',
          endpoint: 'https://invalid.example',
          turnId: 'u',
          latestUserText: user.content,
          recent: [user],
        );
        expect(await MoodService(db).events(), isEmpty);
        expect(
          (await MoodService(db).snapshot(now: at, previewUserId: 'u')).valence,
          greaterThan(.55),
        );
        await router.decide(
          apiKey: 'test',
          endpoint: 'https://invalid.example',
          turnId: 'u',
          latestUserText: user.content,
          recent: [user],
        );
        expect(calls, 1);
      },
    );

    test(
      'existing DeepSeek fallback carries optional mood without a second request',
      () async {
        var calls = 0;
        final client = DeepSeekClient(
          streamClientFactory: () => MockClient((request) async {
            calls++;
            final content = jsonEncode({
              'mode': 'daily',
              'interaction': 'ordinary',
              'initiative': 'closed',
              'flustered': 'no',
              'game_attitude': 'none',
              'mood_event': 'connection',
              'mood_impact': 'mild',
              'mood_certainty': 'clear',
            });
            return http.Response(
              'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {'content': content},
                  },
                ],
              })}\n\ndata: [DONE]\n\n',
              200,
              headers: {'content-type': 'text/event-stream'},
            );
          }),
        );
        final router = NsfwContextRouter(
          db: db,
          client: client,
          jevGateway: JevDecisionGateway(enabledReader: () async => false),
        );
        final user = ChatMessage(
          id: 'u',
          role: 'user',
          content: 'warm exchange',
          createdAt: at,
        );
        await router.decide(
          apiKey: 'test',
          endpoint: 'https://invalid.example',
          turnId: 'u',
          latestUserText: user.content,
          recent: [user],
        );
        expect(calls, 1);
        expect(
          (await MoodStore.pending(await db.database, 'u'))?.kind,
          'connection',
        );
      },
    );

    test(
      'reset boundary hides old raw evidence without forcing random forgetting',
      () async {
        const evidence = 'reset boundary secret evidence';
        await db.insertMessage(
          ChatMessage(id: 'u', role: 'user', content: evidence, createdAt: at),
        );
        await (await db.database).transaction(
          (txn) => MoodStore.append(txn, event('hurt'), at),
        );
        expect(await MoodService(db).prompt(now: at), contains(evidence));
        await db.setSetting(
          'conversation_context_reset_at',
          at.add(const Duration(seconds: 1)).millisecondsSinceEpoch.toString(),
        );
        expect(
          await MoodService(db).prompt(now: at.add(const Duration(seconds: 2))),
          isNot(contains(evidence)),
        );
        expect(
          await MoodService(
            db,
          ).pendingCause(at.add(const Duration(seconds: 2))),
          isNull,
        );
        expect(
          (await MoodService(
            db,
          ).snapshot(now: at.add(const Duration(seconds: 2)))).valence,
          lessThan(.55),
        );
      },
    );

    Future<GenerationJob> prepare() async {
      final pending = await db.createGenerationTurn(
        user: ChatMessage(
          id: 'u',
          role: 'user',
          content: '合成测试互动',
          createdAt: at,
        ),
        assistantMessageId: 'a',
        model: 'deepseek-flash',
        reasoningEffort: 'high',
      );
      final job = (await db.claimGenerationJob(pending.id))!;
      await MoodService(db).stage(event('connection'));
      return job;
    }

    Future<bool> commit(GenerationJob job, {bool roleplay = false}) =>
        db.completeGenerationJobIfCurrent(
          jobId: job.id,
          runToken: job.runToken,
          assistant: ChatMessage(
            id: 'a',
            role: 'assistant',
            content: '合成回应',
            createdAt: at.add(const Duration(seconds: 1)),
            worldBookContextJson: roleplay
                ? const WorldBookTurnContext(
                    roleplaySessionId: 'fiction',
                  ).encode()
                : '',
          ),
        );

    test(
      'preview is not durable; winning commit is idempotent and backup carries events',
      () async {
        final job = await prepare();
        expect((await MoodService(db).snapshot(now: at)).valence, .55);
        expect(
          (await MoodService(db).snapshot(now: at, previewUserId: 'u')).valence,
          greaterThan(.55),
        );
        expect(await MoodService(db).events(), isEmpty);
        expect(await commit(job), isTrue);
        expect(await commit(job), isTrue);
        expect(await MoodService(db).events(), hasLength(1));
        final exported = await db.exportAll();
        expect(jsonEncode(exported), contains(MoodStore.eventsKey));
      },
    );
    test('Stop blocks late commit and does not preserve preview', () async {
      final job = await prepare();
      expect(await db.cancelGenerationJobByUser(job.id), isTrue);
      expect(await commit(job), isFalse);
      expect(await MoodService(db).events(), isEmpty);
    });
    test(
      'regeneration replaces effect; failure rolls back reply and mood together',
      () async {
        final job = await prepare();
        await commit(job);
        final reopened = await db.restartLatestCompletedReply('a');
        expect(reopened, isNotNull);
        expect(await MoodService(db).events(), isEmpty);
        final next = (await db.claimGenerationJob(reopened!.id))!;
        await (await db.database).execute(
          "CREATE TRIGGER mood_test_fail BEFORE INSERT ON settings WHEN NEW.key = '${MoodStore.eventsKey}' BEGIN SELECT RAISE(ABORT, 'test'); END",
        );
        await expectLater(commit(next), throwsA(anything));
        expect(await db.messageById('a'), isNull);
        expect(await MoodService(db).events(), isEmpty);
        expect((await db.generationJobById(next.id))!.status, 'running');
      },
    );
    test(
      'fictional room and module disable do not write real relational mood',
      () async {
        final job = await prepare();
        await commit(job, roleplay: true);
        expect(await MoodService(db).events(), isEmpty);
        await db.setSetting(MoodStore.enabledKey, '0');
        await MoodService(db).external(event('discovery'));
        expect(await MoodService(db).events(), isEmpty);
      },
    );
    test(
      'legacy insult keywords no longer inject relationship harm before semantic judgement',
      () async {
        final user = ChatMessage(
          id: 'u',
          role: 'user',
          content: '闭嘴',
          createdAt: at,
        );
        final engine = EmotionEpisodeEngine(db);
        await engine.appraiseUserTurn(
          user: user,
          desire: DesireSnapshot(),
          now: at,
        );
        expect(
          (await db.activeEmotionEpisodes(
            now: at,
          )).where((e) => e.category.name == 'hurt'),
          isEmpty,
        );
        await db.setSetting(MoodStore.enabledKey, '0');
        await engine.appraiseUserTurn(
          user: user,
          desire: DesireSnapshot(),
          now: at,
        );
        expect(
          (await db.activeEmotionEpisodes(
            now: at,
          )).where((e) => e.category.name == 'hurt'),
          hasLength(1),
        );
      },
    );
    test(
      'external sources deduplicate and throttle; stale weather does not contribute',
      () async {
        final sql = await db.database;
        Future<void> add(String id, int minutes) => sql.transaction(
          (txn) => MoodStore.append(
            txn,
            MoodEvent(
              id: id,
              kind: 'progress',
              source: 'cedar_activity',
              at: at.add(Duration(minutes: minutes)),
            ),
            at.add(Duration(minutes: minutes)),
          ),
        );
        await add('game:1', 0);
        await add('game:1', 0);
        await add('game:2', 1);
        expect(await MoodService(db).events(), hasLength(1));
        await add('game:3', 31);
        expect(await MoodService(db).events(), hasLength(2));
        await db.setSettingsAtomically({
          'weather_enabled': '1',
          'weather_city': 'test',
          'weather_cached_city': 'test',
          'weather_observation': '雨',
          'weather_updated_at': at.millisecondsSinceEpoch.toString(),
        });
        expect(await MoodService(db).hasFreshWeather(at), isTrue);
        expect(
          await MoodService(
            db,
          ).hasFreshWeather(at.add(const Duration(hours: 1))),
          isFalse,
        );
        expect(
          await MoodService(
            db,
          ).hasFreshWeather(at.subtract(const Duration(minutes: 1))),
          isFalse,
        );
        await db.setSetting('weather_city', 'another');
        expect(await MoodService(db).hasFreshWeather(at), isFalse);
      },
    );
    test(
      'only unresolved recent cause is offered for repair; diagnostic omits prose',
      () async {
        final sql = await db.database;
        await sql.transaction(
          (txn) => MoodStore.append(txn, event('hurt'), at),
        );
        expect((await MoodService(db).pendingCause(at))!.id, 'user:u');
        await sql.transaction(
          (txn) => MoodStore.append(
            txn,
            event('clarified', id: 'user:r', minutes: 1, target: 'user:u'),
            at.add(const Duration(minutes: 1)),
          ),
        );
        expect(
          await MoodService(
            db,
          ).pendingCause(at.add(const Duration(minutes: 2))),
          isNull,
        );
        expect(
          jsonEncode((await MoodService(db).snapshot(now: at)).diagnostic()),
          isNot(contains('合成测试互动')),
        );
      },
    );
  });

  group('optional Jev questions preserve existing decisions', () {
    Map<String, Object?> answer(
      String chosen,
      Map<String, double> probabilities, {
      double confidence = .95,
    }) => {
      'type': 'choice',
      'choice': chosen,
      'confidence': confidence,
      'probabilities': probabilities,
    };
    Future<Map<String, String>?> classify(Map<String, Object?> extras) async {
      final gateway = JevDecisionGateway(
        enabledReader: () async => true,
        keyReader: () async => 'test',
        clientFactory: () => MockClient(
          (request) async => http.Response(
            jsonEncode({
              'answers': {
                'interaction': answer('light', {'light': .72, 'ordinary': .28}),
                ...extras,
              },
            }),
            200,
          ),
        ),
      );
      return gateway.chooseMany(
        state: {'latest_user_text': '合成'},
        usageLane: 'chat_intimacy_route',
        questions: {
          'interaction': const JevChoiceQuestion('existing heat', {
            'light': 'play',
            'ordinary': 'neutral',
          }),
          ...MoodAppraisal.questions,
        },
      );
    }

    test(
      'missing/malformed mood answers do not buy a DS retry of valid heat',
      () async {
        expect((await classify({}))!['interaction'], 'light');
        expect(
          (await classify({
            'mood_event': {'bad': true},
          }))!['interaction'],
          'light',
        );
        final bad = answer('hurt', {'hurt': .95, 'none': double.nan});
        // JSON cannot carry NaN; invalid typed probability exercises the same lane.
        bad['probabilities'] = {'hurt': .95, 'none': 'bad'};
        expect((await classify({'mood_event': bad}))!['interaction'], 'light');
      },
    );
    test(
      'ambiguous and sparse hurt cannot persist; clear complete evidence may',
      () async {
        expect(
          (await classify({
            'mood_event': answer('hurt', {'hurt': .9}),
          }))!['mood_event'],
          'none',
        );
        final uncertain = {
          for (final key in MoodAppraisal.questions['mood_event']!.options.keys)
            key: 0.0,
        };
        uncertain['hurt'] = .49;
        uncertain['playful'] = .46;
        uncertain['none'] = .05;
        expect(
          (await classify({
            'mood_event': answer('hurt', uncertain),
          }))!['mood_event'],
          'none',
        );
        final certain = {...uncertain, 'hurt': .93, 'playful': .02};
        expect(
          (await classify({
            'mood_event': answer('hurt', certain),
          }))!['mood_event'],
          'hurt',
        );
      },
    );
  });
}
