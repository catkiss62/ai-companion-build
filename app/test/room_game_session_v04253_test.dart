import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_form_snapshot.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_session_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/memory/remembered_user_facts.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';
import 'package:ai_companion_localfirst/core/tts/tts_service.dart';
import 'package:ai_companion_localfirst/core/tts/tts_provider.dart';

class _PitchProvider extends Fake implements TtsProvider {
  double? pitch;
  @override
  Future<void> setPitch(double value) async {
    pitch = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final noon = DateTime(2026, 9, 30, 13);

  test(
    '30 minute grant counts play but excludes pause and process suspension',
    () {
      var period = CedarPlaySession(
        gameId: 'fishing',
        startedAt: noon,
        lastTickAt: noon,
      );
      for (var i = 1; i <= 10; i++) {
        period = period.tick(noon.add(Duration(minutes: i)));
      }
      period = period.tick(noon.add(const Duration(minutes: 10)), pause: true);
      period = period.tick(noon.add(const Duration(minutes: 40)));
      expect(period.usedMs, const Duration(minutes: 10).inMilliseconds);
      for (var i = 41; i <= 60; i++) {
        period = period.tick(noon.add(Duration(minutes: i)));
      }
      expect(period.usedMs, CedarPlaySession.budgetMs);
      expect(
        period.validAt(noon.add(const Duration(hours: 1)), 'fishing'),
        isFalse,
      );
      final suspended = CedarPlaySession(
        gameId: 'fishing',
        startedAt: noon,
        lastTickAt: noon,
      ).tick(noon.add(const Duration(minutes: 20)));
      expect(suspended.usedMs, 0);
    },
  );
  test('cross night, changed game and stale grants expire', () {
    final night = DateTime(2026, 9, 30, 23, 59);
    final period = CedarPlaySession(
      gameId: 'fishing',
      startedAt: night,
      lastTickAt: night,
    );
    expect(
      period.validAt(night.add(const Duration(minutes: 2)), 'fishing'),
      isFalse,
    );
    expect(period.validAt(night, 'travel'), isFalse);
    expect(
      period.validAt(night.add(const Duration(hours: 3)), 'fishing'),
      isFalse,
    );
  });
  test('sustained grant bypasses short competition but preserves night and fatigue', () {
    final awake = CedarContinuationGatePolicy.evaluate(
      now: noon,
      storedFatigue: .2,
      curiosity: .1,
      reflection: .1,
      strongestGameThought: 0,
      activelyWatched: false,
      sustained: true,
      recentActionCount: 50,
    );
    expect(awake.allowed, isTrue);
    final sleepy = CedarContinuationGatePolicy.evaluate(
      now: noon,
      storedFatigue: .9,
      curiosity: .1,
      reflection: .1,
      strongestGameThought: 0,
      activelyWatched: false,
      sustained: true,
    );
    expect(sleepy.allowed, isFalse);
    final night = CedarContinuationGatePolicy.evaluate(
      now: DateTime(2026, 9, 30, 2),
      storedFatigue: .1,
      curiosity: 1,
      reflection: 1,
      strongestGameThought: 1,
      activelyWatched: false,
      sustained: true,
    );
    expect(night.reason, 'night_sleep');
  });
  test('encouragement is game scoped, decays, and expires', () {
    final attitude = CedarGameAttitude(
      gameId: 'fishing',
      turn: 'u1',
      at: noon,
      encouraged: true,
    );
    expect(attitude.bonusAt(noon, 'fishing'), closeTo(.1, .0001));
    expect(
      attitude.bonusAt(noon.add(const Duration(hours: 3)), 'fishing'),
      closeTo(.05, .0001),
    );
    expect(attitude.bonusAt(noon.add(const Duration(hours: 12)), 'fishing'), 0);
    expect(attitude.bonusAt(noon, 'travel'), 0);
  });
  test(
    'entry snapshot TTS is fixed while ordinary TTS follows shared form',
    () async {
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting);
      await db.setSetting(
        PlayfulFormState.settingKey,
        jsonEncode({'qForm': true, 'heat': 99}),
      );
      final snapshot = ImmersiveFormSnapshot.capture(
        await PlayfulFormStore(db).load(),
      );
      final roomVoice = _PitchProvider();
      final normalVoice = _PitchProvider();
      final roomTts = TtsService(
        db: db,
        provider: roomVoice,
        qFormOverride: () async => snapshot.qForm,
      );
      final ordinaryTts = TtsService(db: db, provider: normalVoice);
      await roomTts.applyPitchForCurrentForm(0);
      final capturedPitch = roomVoice.pitch;
      await db.setSetting(
        PlayfulFormState.settingKey,
        jsonEncode({'qForm': false, 'heat': 0}),
      );
      await roomTts.applyPitchForCurrentForm(0);
      await ordinaryTts.applyPitchForCurrentForm(0);
      expect(roomVoice.pitch, capturedPitch);
      expect(roomVoice.pitch, greaterThan(normalVoice.pitch!));
      expect(snapshot.qForm, isTrue);
      expect(snapshot.prompt, isNot(contains('99')));
      expect((await PlayfulFormStore(db).load()).qForm, isFalse);
    },
  );
  test(
    'attitude commits once and refresh replaces rather than stacks',
    () async {
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting);
      final store = CedarGameAttitudeStore(db);
      await db.setSetting('nsfw_route_turn_id', 'u1');
      await db.setSetting('cedar_game_attitude_route_signal', 'encourage');
      await db.setSetting('cedar_game_attitude_route_game', 'fishing');
      await store.commit(turnId: 'stopped-turn', now: noon);
      expect(await store.load(), isNull);
      await store.commit(turnId: 'u1', now: noon);
      await store.commit(turnId: 'u1', now: noon.add(const Duration(hours: 1)));
      expect((await store.load())!.at, noon);
      await db.setSetting('nsfw_route_turn_id', 'u2');
      await store.commit(turnId: 'u2', now: noon.add(const Duration(hours: 1)));
      expect(
        (await store.load())!.bonusAt(
          noon.add(const Duration(hours: 1)),
          'fishing',
        ),
        closeTo(.1, .0001),
      );
      await CedarPlaySessionStore(db).save(
        CedarPlaySession(gameId: 'fishing', startedAt: noon, lastTickAt: noon),
      );
      await db.setSetting('nsfw_route_turn_id', 'u3');
      await db.setSetting('cedar_game_attitude_route_signal', 'pause');
      await store.commit(turnId: 'u3', now: noon.add(const Duration(hours: 1)));
      expect(await CedarPlaySessionStore(db).load(), isNull);
    },
  );
  test(
    'remembered facts persist without memory rows or importance events',
    () async {
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting);
      final store = RememberedUserFactsStore(db);
      await store.save(
        const RememberedUserFacts([
          RememberedUserFact(subject: '午饭', content: '通常下午1点'),
        ]),
      );
      final facts = await store.load();
      expect(facts.items.single.content, '通常下午1点');
      expect(await db.listMemories(), isEmpty);
      expect(facts.prompt, contains('当天例外'));
      await store.save(const RememberedUserFacts([]));
      expect((await store.load()).prompt, isEmpty);
    },
  );
}
