import 'dart:convert';
import 'dart:math';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/daily_wake_schedule.dart';
import 'package:ai_companion_localfirst/core/desire/daily_wake_store.dart';
import 'package:ai_companion_localfirst/core/desire/desire_core_policy.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_dawn_gate_policy.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_delivery_budget.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_live_share_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_wake_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_session_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/proactive_frequency.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  DateTime time(int h, [int m = 0, int day = 5]) =>
      DateTime(2026, 10, day, h, m);
  setUp(
    () async => db = await AppDatabase.createForTesting(databaseFactoryFfi),
  );
  tearDown(() async => db.closeForTesting());
  Future<void> wake(int h, int m, [int day = 5]) async {
    await db.setSetting(
      DailyWakeStore.keyFor(time(0, 0, day)),
      jsonEncode({
        'minute': h * 60 + m,
        'sampledAt': time(0, 1, day).millisecondsSinceEpoch,
      }),
    );
  }

  Future<ProactiveDeliveryBudget> budget(DateTime now) async =>
      ProactiveDeliveryBudget.read(
        await db.database,
        now,
        mode: ProactiveFrequencyMode.natural,
      );
  Future<String?> send(DateTime at, {DateTime? start, String? thoughtId}) =>
      db.commitProactiveMessageIfCurrent(
        message: ChatMessage(
          id: 'm-${at.millisecondsSinceEpoch}',
          role: 'assistant',
          content: '测试内容',
          createdAt: at,
          isProactive: true,
        ),
        evaluationStartedAt: start ?? at,
        deliveryAt: at,
        proactiveTriggerReason: thoughtId == null
            ? 'curiosity:test'
            : 'game_share:immediate:test',
        enforceProactiveBudget: thoughtId == null,
        proactiveGameShare: thoughtId != null,
        cedarShareThoughtId: thoughtId,
        cedarShareGameId: thoughtId == null ? null : 'market',
      );
  Future<CedarGameSession> session({bool shared = false, DateTime? at}) async {
    final game = CedarGameSession(
      id: 'session-market',
      gameId: 'market',
      guide: '做菜',
      guideComplete: true,
      mode: shared
          ? CedarParticipationMode.coPlay
          : CedarParticipationMode.solo,
      invitationApproved: shared,
      phase: CedarActivityPhase.active,
      updatedAt: at ?? time(8, 10),
      nextActionAt: time(8, 10),
    );
    await CedarToyActivityStore(db).save(game);
    return game;
  }

  test(
    'parallel foreground/background draws agree and survive late access and restore',
    () async {
      final sql = await db.database;
      final schedules = await Future.wait(
        List.generate(
          8,
          (i) => DailyWakeStore.read(sql, time(0, 1), random: Random(i)),
        ),
      );
      final first = schedules.first;
      expect(schedules.every((v) => v.wakeAt == first.wakeAt), isTrue);
      expect(first.wakeAt.isBefore(time(8)), isFalse);
      expect(first.wakeAt.isAfter(time(9)), isFalse);
      final exported = await db.exportAll();
      await db.importAll(exported);
      final later = await DailyWakeStore.read(
        await db.database,
        time(12),
        random: Random(91),
      );
      expect(later.wakeAt, first.wakeAt);
      expect(later.sampledAt, first.sampledAt);
      final next = await DailyWakeStore.read(
        await db.database,
        time(0, 1, 6),
        random: Random(12),
      );
      expect(next.wakeAt.day, 6);
      expect(
        (await DailyWakeStore.read(await db.database, time(8))).wakeAt,
        first.wakeAt,
      );
    },
  );

  test(
    'a first launch at noon does not postpone wake or replay waking',
    () async {
      final schedule = await DailyWakeStore.read(await db.database, time(12));
      expect(schedule.wakeAt.hour, inInclusiveRange(8, 9));
      expect(schedule.sleepiness(time(12)), 0);
      expect(schedule.promptSection(time(12)), isEmpty);
    },
  );

  for (final minute in [480, 517, 540]) {
    test(
      'wake $minute releases quota and game at the same exact boundary',
      () async {
        await wake(minute ~/ 60, minute % 60);
        final at = time(minute ~/ 60, minute % 60);
        final before = at.subtract(const Duration(milliseconds: 1));
        expect((await budget(before)).night, isTrue);
        expect((await budget(at)).night, isFalse);
        expect((await budget(at)).released, 6);
        expect(
          await CedarWakePolicy.delay(await db.database, before),
          const Duration(milliseconds: 1),
        );
        expect(
          await CedarWakePolicy.delay(await db.database, at),
          Duration.zero,
        );
        final dark = ProactiveDawnGatePolicy.adjust(
          now: before,
          wakeAt: at,
          activityContext: 'screen_off',
          rawIdleBoost: .24,
        );
        final light = ProactiveDawnGatePolicy.adjust(
          now: at,
          wakeAt: at,
          activityContext: 'screen_off',
          rawIdleBoost: .24,
        );
        expect(dark.thresholdPenalty, .10);
        expect(dark.idleBoost, 0);
        expect(light.thresholdPenalty, 0);
        expect(light.idleBoost, .24);
      },
    );
  }

  test(
    'dynamic windows count actual sends, retain gaps and exclude immediate shares',
    () async {
      await wake(8, 37);
      expect(await send(time(0, 10)), isNull);
      expect(await send(time(8, 30)), isNull);
      expect((await budget(time(8, 36))).nightUsed, 2);
      expect((await budget(time(8, 37))).dayUsed, 0);
      expect(await send(time(8, 37)), 'minimum_gap');
      expect(await send(time(8, 46)), isNull);
      expect(await send(time(8, 47), thoughtId: 'cedar-event'), isNull);
      expect((await budget(time(10))).dayUsed, 1);
      expect((await budget(time(10))).nightUsed, 2);
      expect((await budget(time(14))).released, 12);
      expect((await budget(time(19))).released, 18);
    },
  );

  test(
    'final commit cancels stale night/day context and a share crossing midnight',
    () async {
      await wake(8, 37);
      expect(
        await send(time(8, 37), start: time(8, 36)),
        'proactive_window_changed',
      );
      expect(
        await send(time(0), start: time(23, 59, 4)),
        'proactive_window_changed',
      );
      expect(
        await send(time(0), start: time(23, 59, 4), thoughtId: 'cedar-event'),
        'cedar_share_before_wake',
      );
      expect((await budget(time(10))).used, 0);
    },
  );

  test(
    'old queued autonomous terminal shares wait, explicit requested reports still deliver',
    () async {
      await wake(8, 55);
      final shares = CedarLiveSharePolicy(db);
      expect(
        await shares.deliveryAllowed(
          'cedar-terminal',
          'mcp/cedar_game:market:terminal:1',
          now: time(8, 54),
        ),
        isFalse,
      );
      expect(
        await shares.deliveryAllowed(
          'cedar-terminal',
          'mcp/cedar_game:market:terminal:1',
          now: time(8, 55),
        ),
        isTrue,
      );
      expect(
        await send(time(8, 54), thoughtId: 'cedar-terminal'),
        'cedar_share_before_wake',
      );
      expect(
        await send(time(8, 54), thoughtId: 'cedar-report:requested-task'),
        isNull,
      );
      expect((await budget(time(8, 55))).nightUsed, 0);
    },
  );

  test(
    'only current timed or shared play is exempt; old invitation and pace are not',
    () async {
      await wake(8, 55);
      var game = await session(shared: true, at: time(1));
      await CedarToyActivityStore(
        db,
      ).save(game.copyWith(phase: CedarActivityPhase.completed));
      await db.setSetting(
        CedarToyActivityStore.viewingPaceSettingKey,
        'every1',
      );
      expect(
        await CedarWakePolicy.delay(await db.database, time(8, 10)),
        isNot(Duration.zero),
      );
      game = await session(shared: true);
      expect(
        await CedarWakePolicy.delay(await db.database, time(8, 10)),
        Duration.zero,
      );
      expect(
        await CedarWakePolicy.delay(
          await db.database,
          time(8, 10),
          gameId: 'other',
        ),
        isNot(Duration.zero),
      );
      game = await session();
      await db.setSetting(
        CedarPlaySessionStore.key,
        jsonEncode(
          CedarPlaySession(
            gameId: game.gameId,
            startedAt: time(8, 9),
            lastTickAt: time(8, 10),
            taskId: 'requested',
          ).toJson(),
        ),
      );
      await db.setSetting(
        CedarTimedPlayTaskStore.activeKey,
        jsonEncode({
          'id': 'requested',
          'gameId': game.gameId,
          'sessionId': game.id,
        }),
      );
      expect(
        await CedarWakePolicy.delay(await db.database, time(8, 11)),
        Duration.zero,
      );
      expect(
        await CedarWakePolicy.delay(await db.database, time(8, 20)),
        isNot(Duration.zero),
      );
    },
  );

  test(
    'late wake sleepiness passes 09:00 and fades continuously without a forced line',
    () {
      final schedule = DailyWakeSchedule(
        wakeAt: time(8, 55),
        sampledAt: time(0),
      );
      expect(schedule.sleepiness(time(8, 54)), 0);
      expect(schedule.sleepiness(time(8, 55)), 1);
      expect(schedule.sleepiness(time(9)), greaterThan(.8));
      expect(schedule.sleepiness(time(9, 39)), greaterThan(0));
      expect(schedule.sleepiness(time(9, 40)), 0);
      expect(schedule.promptSection(time(9)), contains('不要求提到刚醒'));
      expect(schedule.promptSection(time(9, 40)), isEmpty);
      double floor(DateTime at) =>
          DesireCorePolicy.circadianFatigueFloor(at, wakeAt: schedule.wakeAt);
      expect(floor(time(8, 55)), .54);
      expect(floor(time(9)), greaterThan(.48));
      expect(floor(time(9, 40)), closeTo(.16, .00001));
      var previous = floor(time(6));
      for (var m = 361; m <= 600; m++) {
        final current = floor(time(m ~/ 60, m % 60));
        expect(current, lessThanOrEqualTo(previous));
        previous = current;
      }
    },
  );

  test(
    'wake gates only pre-wake; strong interest can still beat rest after wake',
    () {
      CedarContinuationGateDecision gate(DateTime at, double interest) =>
          CedarContinuationGatePolicy.evaluate(
            now: at,
            wakeAt: time(8, 55),
            storedFatigue: .54,
            curiosity: interest,
            reflection: .1,
            strongestGameThought: interest,
            activelyWatched: false,
          );
      expect(gate(time(8, 54), .9).reason, 'night_sleep');
      expect(gate(time(8, 55), .9).allowed, isTrue);
      expect(gate(time(8, 55), .1).reason, 'rest_wins');
    },
  );
}
