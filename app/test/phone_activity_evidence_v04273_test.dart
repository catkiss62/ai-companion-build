import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:ai_companion_localfirst/core/presence/phone_activity_evidence.dart';
import 'package:ai_companion_localfirst/core/presence/presence_intelligence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime(2026, 10, 5, 1);
  DateTime at(int minutes) => start.add(Duration(minutes: minutes));
  UsageEventInfo event(
    int minute,
    String package, [
    String type = 'foreground',
  ]) => UsageEventInfo(
    packageName: package,
    timestamp: at(minute),
    eventType: type,
  );
  Map<String, Object?> signal(
    int minute,
    String source, [
    String type = 'event',
  ]) => {
    'occurred_at': at(minute).millisecondsSinceEpoch,
    'source': source,
    'event_type': type,
  };
  PhoneActivityEvidence collect({
    int? from = 0,
    int to = 10,
    bool interactive = true,
    bool wasInteractive = true,
    List<UsageEventInfo> usage = const [],
    List<Map<String, Object?>> states = const [],
    List<Map<String, Object?>> signals = const [],
  }) => PhoneActivityEvidence.collect(
    now: at(to),
    previousAt: from == null ? null : at(from),
    wasInteractive: wasInteractive,
    interactive: interactive,
    usage: usage,
    deviceEvents: states,
    signals: signals,
  );

  test('cold start, upgrade and long unobserved gaps establish a baseline', () {
    for (final evidence in [
      collect(from: null),
      collect(to: 31),
      collect(wasInteractive: false),
    ]) {
      expect(evidence.reset, true);
      expect(evidence.activeMinutes, 0);
    }
  });
  test(
    'unlock does not turn old usage and queued notifications into new activity',
    () {
      final evidence = collect(
        usage: [event(-60, 'a')],
        states: [signal(9, 'system', 'user_present')],
        signals: List.generate(15, (_) => signal(5, 'notification')),
      );
      expect(evidence.reset, true);
      expect(evidence.activeMinutes, 0);
      expect(evidence.accessibilityEvents, 0);
    },
  );
  test(
    'known screen-off boundary invalidates continuity even when capture sees on',
    () {
      expect(collect(states: [signal(5, 'system', 'screen_off')]).reset, true);
      expect(collect(interactive: false).reset, true);
      expect(collect(to: 0).reset, true);
      expect(collect(to: -1).reset, true);
    },
  );
  test(
    'continuous foreground duration is charged once across adjacent captures',
    () {
      final usage = [event(-5, 'a')];
      final first = collect(to: 10, usage: usage);
      final second = collect(from: 10, to: 20, usage: usage);
      expect(first.activeMinutes, 10);
      expect(second.activeMinutes, 10);
      expect(first.activeMinutes + second.activeMinutes, 20);
    },
  );
  test(
    'rolling old switches and accessibility events do not get counted again',
    () {
      final usage = [
        event(-5, 'a'),
        event(3, 'a', 'background'),
        event(3, 'b'),
      ];
      final signals = [
        signal(4, 'accessibility'),
        signal(11, 'accessibility'),
        signal(12, 'notification'),
      ];
      final first = collect(to: 10, usage: usage, signals: signals);
      final second = collect(from: 10, to: 15, usage: usage, signals: signals);
      expect(first.switches, 1);
      expect(second.switches, 0);
      expect(first.accessibilityEvents, 1);
      expect(second.accessibilityEvents, 1);
    },
  );
  test(
    'duplicate foreground signals do not manufacture switches or overlapping time',
    () {
      final result = collect(
        usage: [event(-2, 'a'), event(2, 'a'), event(2, 'a'), event(5, 'b')],
      );
      expect(result.activeMinutes, 10);
      expect(result.switches, 1);
    },
  );
  test('background gaps and future events are excluded', () {
    final result = collect(
      usage: [
        event(-2, 'a'),
        event(3, 'a', 'background'),
        event(7, 'b'),
        event(12, 'c'),
      ],
    );
    expect(result.activeMinutes, 6);
    expect(result.switches, 1);
  });
  test(
    'mere on state, passive notifications or missing activity do not imply active minutes',
    () {
      final result = collect(signals: [signal(3, 'notification')]);
      expect(result.activeMinutes, 0);
      expect(result.accessibilityEvents, 0);
      expect(result.reset, false);
    },
  );
  PresenceMomentumResult advance(
    PhoneActivityEvidence evidence, {
    double score = .8,
  }) => PresenceMomentumPolicy.advance(
    previousScore: score,
    elapsed: const Duration(minutes: 10),
    input: PresenceMomentumInput(
      screenInteractive: true,
      evidence: evidence,
      busyScore: 0,
      dominantActivityMinutes: 90,
      appSwitchesLast30Minutes: 99,
      newNotificationCount: 99,
      newAccessibilityCount: 99,
      hasCurrentActivity: true,
      userIdleMinutes: 180,
    ),
  );
  test(
    'baseline and empty intervals cannot feed a thought even with high retained score',
    () {
      for (final evidence in [collect(from: null), collect()]) {
        final result = advance(evidence);
        expect(result.impulse, 0);
        expect(result.shouldFeedThought, false);
        expect(result.score, lessThan(.8));
      }
    },
  );
  test(
    'fresh activity can still create a thought without a blanket unlock cooldown',
    () {
      final result = advance(collect(usage: [event(0, 'a')]));
      expect(result.impulse, closeTo(.09, .00001));
      expect(result.shouldFeedThought, true);
    },
  );
  test(
    'activity pressure scales by elapsed evidence rather than number of captures',
    () {
      final whole = advance(collect(usage: [event(0, 'a')]), score: 0);
      final first = advance(collect(to: 5, usage: [event(0, 'a')]), score: 0);
      final second = advance(
        collect(from: 5, to: 10, usage: [event(0, 'a')]),
        score: 0,
      );
      expect(whole.impulse, closeTo(first.impulse + second.impulse, .00001));
    },
  );

  group('persisted evidence and thought scope', () {
    late AppDatabase db;
    late DesireEngine desire;
    late PresenceIntelligenceEngine presence;
    setUp(() async {
      sqfliteFfiInit();
      db = await AppDatabase.createForTesting(databaseFactoryFfi);
      desire = DesireEngine(db);
      presence = PresenceIntelligenceEngine(db: db, desire: desire);
    });
    tearDown(() async => db.closeForTesting());
    test(
      'reset retires phone thoughts but preserves an independent topic and current score decay',
      () async {
        await desire.feedThought(
          text: '手机活动',
          drive: DriveKey.curiosity,
          source: 'presence/phone_activity',
          topicKey: 'presence:phone_activity',
          now: at(-30),
        );
        await desire.feedThought(
          text: '之前的游戏',
          drive: DriveKey.curiosity,
          source: 'internal',
          topicKey: 'game:shared',
          now: at(-30),
        );
        await db.setSetting('presence_momentum_score', '.8');
        await db.setSetting(
          'presence_momentum_updated_at',
          at(0).millisecondsSinceEpoch.toString(),
        );
        await presence.integrate(
          screenInteractive: true,
          evidence: collect(from: null),
          busyScore: 0,
          dominantActivityMinutes: 60,
          appSwitchesLast30Minutes: 10,
          newNotificationCount: 20,
          newAccessibilityCount: 20,
          hasCurrentActivity: true,
          now: at(10),
        );
        final phone = await db.thoughtBySource('presence/phone_activity');
        final other = await db.thoughtBySource('internal');
        expect(phone!.lifecycleState, 'dormant');
        expect(phone.residualStrength, 0);
        expect(other!.lifecycleState, 'active');
        expect(
          await db.getSetting('presence_evidence_at_v317'),
          at(10).millisecondsSinceEpoch.toString(),
        );
        expect(
          await presence.currentMomentum(now: at(10)),
          closeTo(.8 * .881591, .0001),
        );
        expect(await db.getSetting('presence_last_thought_at'), isNull);
      },
    );
  });
}
