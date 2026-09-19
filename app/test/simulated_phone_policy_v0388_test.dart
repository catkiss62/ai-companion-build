import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_phone_policy.dart';
import 'package:ai_companion_localfirst/core/phone/tarot_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('master switch blocks every producer except tarot', () {
    for (final app in SimulatedPhoneAppKind.values) {
      final allowed = SimulatedPhonePolicy.updatesAllowed(
        phoneEnabled: false,
        app: app,
      );
      expect(allowed, app == SimulatedPhoneAppKind.tarot);
    }
    for (final app in SimulatedPhoneAppKind.values) {
      expect(
        SimulatedPhonePolicy.updatesAllowed(phoneEnabled: true, app: app),
        isTrue,
      );
    }
  });

  test('local day and previous day use calendar boundaries', () {
    final now = DateTime(2026, 8, 26, 0, 3);
    expect(SimulatedPhonePolicy.localDay(now), '2026-08-26');
    expect(SimulatedPhonePolicy.previousLocalDay(now), '2026-08-25');
  });

  test('daily selection is stable and salt can separate two tarot cards', () {
    final first = SimulatedPhonePolicy.stableIndex(
      '2026-08-26',
      12,
      salt: 101,
    );
    expect(
      SimulatedPhonePolicy.stableIndex('2026-08-26', 12, salt: 101),
      first,
    );
    expect(first, inInclusiveRange(0, 11));
    expect(
      SimulatedPhonePolicy.stableIndex('2026-08-26', 12, salt: 307),
      inInclusiveRange(0, 11),
    );
  });

  test('all 22 major arcana map to bundled jpg paths and rich readings', () {
    expect(majorArcana, hasLength(22));
    expect(SimulatedPhonePolicy.tarotAssetCount, 22);
    for (var index = 0; index < majorArcana.length; index++) {
      final card = majorArcana[index];
      expect(
        SimulatedPhonePolicy.tarotAssetPath(index),
        'assets/tarot/rws_major/ar' +
            index.toString().padLeft(2, '0') +
            '.jpg',
      );
      expect(card.name, isNotEmpty);
      expect(card.theme.length, greaterThan(12));
      expect(card.symbols.length, greaterThan(20));
      expect(card.upright.length, greaterThan(20));
      expect(card.reversed.length, greaterThan(20));
      expect(card.guidance.length, greaterThan(15));
      expect(card.shadow.length, greaterThan(15));
    }
  });

  test('mood metrics are bounded and react to fatigue and stress', () {
    final calm = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.attachment: 0.72,
        DriveKey.curiosity: 0.68,
        DriveKey.fatigue: 0.18,
        DriveKey.stress: 0.22,
      },
      baselines: DesireSnapshot.defaultBaselines(),
    );
    final tired = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.attachment: 0.72,
        DriveKey.curiosity: 0.68,
        DriveKey.fatigue: 0.88,
        DriveKey.stress: 0.81,
      },
      baselines: DesireSnapshot.defaultBaselines(),
    );
    final calmMetrics = SimulatedPhonePolicy.moodMetrics(calm);
    final tiredMetrics = SimulatedPhonePolicy.moodMetrics(tired);
    expect(calmMetrics.keys, containsAll([
      'energy',
      'closeness',
      'curiosity',
      'reserve',
      'score',
    ]));
    for (final value in [...calmMetrics.values, ...tiredMetrics.values]) {
      expect(value, inInclusiveRange(0, 100));
    }
    expect(calmMetrics['energy']!, greaterThan(tiredMetrics['energy']!));
    expect(calmMetrics['reserve']!, greaterThan(tiredMetrics['reserve']!));
  });

  test('wish requires drive strength, recurrence and a concrete object', () {
    final now = DateTime(2026, 8, 26, 12);
    final desire = DesireSnapshot(
      drives: {...DesireSnapshot.defaultDrives(), DriveKey.curiosity: 0.72},
      baselines: DesireSnapshot.defaultBaselines(),
    );
    CompanionThought thought({
      int fedCount = 2,
      String topicKey = 'ai.self.autonomy',
      double strength = 0.70,
      DateTime? lastSatisfiedAt,
    }) =>
        CompanionThought(
          id: 'thought-1',
          text: 'private body must never be rendered by phone policy',
          driveKey: DriveKey.curiosity.name,
          kind: 'thread',
          strength: strength,
          bornAt: now,
          updatedAt: now,
          fedCount: fedCount,
          topicKey: topicKey,
          lastSatisfiedAt: lastSatisfiedAt,
        );

    expect(
      SimulatedPhonePolicy.wishEligible(
        thought: thought(),
        desire: desire,
      ),
      isTrue,
    );
    expect(
      SimulatedPhonePolicy.wishEligible(
        thought: thought(fedCount: 0),
        desire: desire,
      ),
      isFalse,
    );
    expect(
      SimulatedPhonePolicy.wishEligible(
        thought: thought(topicKey: ''),
        desire: desire,
      ),
      isFalse,
    );
    expect(
      SimulatedPhonePolicy.wishEligible(
        thought: thought(strength: 0.30),
        desire: desire,
      ),
      isFalse,
    );
    expect(
      SimulatedPhonePolicy.wishEligible(
        thought: thought(lastSatisfiedAt: now),
        desire: desire,
      ),
      isFalse,
    );
  });

  test('wish can update near a normal drive baseline', () {
    final now = DateTime(2026, 9, 11, 12);
    final desire = DesireSnapshot(
      drives: DesireSnapshot.defaultDrives(),
      baselines: DesireSnapshot.defaultBaselines(),
    );
    final thought = CompanionThought(
      id: 'ordinary-recurring-thought',
      text: 'private body',
      driveKey: DriveKey.curiosity.name,
      kind: 'thread',
      strength: 0.52,
      bornAt: now,
      updatedAt: now,
      fedCount: 2,
      topicKey: 'shared:whale-art',
    );

    expect(
      SimulatedPhonePolicy.wishEligible(thought: thought, desire: desire),
      isTrue,
    );
  });

  test('wish presentation never exposes the private thought body', () {
    for (final drive in DriveKey.values) {
      final text = SimulatedPhonePolicy.wishText(drive.name);
      expect(text, isNotEmpty);
      expect(text, isNot(contains('private body')));
    }
  });

  test('wish identity merges recurring thoughts about the same safe topic', () {
    final now = DateTime(2026, 9, 20, 12);
    CompanionThought thought(String id, String topicKey) => CompanionThought(
          id: id,
          text: 'private $id body',
          driveKey: DriveKey.curiosity.name,
          kind: 'thread',
          strength: 0.7,
          bornAt: now,
          updatedAt: now,
          fedCount: 2,
          topicKey: topicKey,
        );

    final first = thought('fishing-1', 'cedar_game:fishing');
    final recurring = thought('fishing-2', 'shared.activity.fishing');
    final travel = thought('travel-1', 'shared.activity.travel_cedar');

    expect(
      SimulatedPhonePolicy.wishSemanticKey(first),
      SimulatedPhonePolicy.wishSemanticKey(recurring),
    );
    expect(
      SimulatedPhonePolicy.wishSemanticKey(first),
      isNot(SimulatedPhonePolicy.wishSemanticKey(travel)),
    );
  });

  test('wish copy is topic-aware without exposing private thought text', () {
    final now = DateTime(2026, 9, 20, 12);
    final fishing = CompanionThought(
      id: 'fishing-private',
      text: 'PRIVATE FISHING REASONING',
      driveKey: DriveKey.curiosity.name,
      kind: 'thread',
      strength: 0.7,
      bornAt: now,
      updatedAt: now,
      fedCount: 2,
      source: 'cedar_game_activity',
      topicKey: 'cedar_game:fishing',
    );

    final fishingText = SimulatedPhonePolicy.wishTextForThought(fishing);
    expect(fishingText, contains('钓鱼'));
    expect(fishingText, isNot(contains('PRIVATE')));
    expect(
      fishingText,
      isNot('想认真找点没见过的新鲜东西看看'),
    );
  });

  test('unknown curiosity topic is not projected without a safe subject', () {
    final now = DateTime(2026, 9, 20, 12);
    final desire = DesireSnapshot(
      drives: {...DesireSnapshot.defaultDrives(), DriveKey.curiosity: 0.72},
      baselines: DesireSnapshot.defaultBaselines(),
    );
    final unknown = CompanionThought(
      id: 'unknown-private',
      text: 'PRIVATE UNKNOWN REASONING',
      driveKey: DriveKey.curiosity.name,
      kind: 'fixation',
      strength: 0.8,
      bornAt: now,
      updatedAt: now,
      fedCount: 3,
      topicKey: 'private.unrecognized.topic',
    );
    expect(
      SimulatedPhonePolicy.wishEligible(thought: unknown, desire: desire),
      isFalse,
    );
    expect(SimulatedPhonePolicy.wishSubjectKeyForThought(unknown), isEmpty);
  });

  test('safe self topic produces a concrete wish without private text', () {
    final now = DateTime(2026, 9, 20, 12);
    final autonomy = CompanionThought(
      id: 'self-autonomy',
      text: 'PRIVATE AUTONOMY REASONING',
      driveKey: DriveKey.curiosity.name,
      kind: 'fixation',
      strength: 0.8,
      bornAt: now,
      updatedAt: now,
      fedCount: 3,
      topicKey: 'ai.self.autonomy_growth',
    );
    final text = SimulatedPhonePolicy.wishTextForThought(autonomy);
    expect(text, contains('自主性'));
    expect(text, isNot(contains('PRIVATE')));
    expect(text, isNot(contains('那个问题')));
  });

  test('fishing detail aliases share one safe public subject', () {
    expect(
      SimulatedPhonePolicy.canonicalWishTopic(
        'cedar_game:fishing_bait_change',
      ),
      'activity:fishing',
    );
    expect(
      SimulatedPhonePolicy.canonicalWishTopic(
        'shared.activity.fishing.autumn_fish',
      ),
      'activity:fishing',
    );
    expect(
      SimulatedPhonePolicy.canonicalWishTopic(
        'shared.fishing.reed_river_map',
      ),
      'activity:fishing',
    );
    final now = DateTime(2026, 9, 20, 12);
    final sourceOnly = CompanionThought(
      id: 'source-only-fishing',
      text: 'PRIVATE',
      driveKey: DriveKey.curiosity.name,
      kind: 'fixation',
      strength: 0.8,
      bornAt: now,
      updatedAt: now,
      source: 'mcp/cedar_game:fishing:play-1234567890123456',
    );
    expect(
      SimulatedPhonePolicy.wishSubjectKeyForThought(sourceOnly),
      'activity:fishing',
    );
  });

  test('legacy wish admits when its old record lost the concrete subject', () {
    final text = SimulatedPhonePolicy.wishText(
      DriveKey.curiosity.name,
      stableKey: 'curiosity|legacy:old-id',
    );
    expect(text, contains('旧记录没有保留具体主题'));
    expect(text, isNot(contains('那个问题')));
  });

  test('notes use six daytime slots and never update in deep night', () {
    expect(SimulatedPhonePolicy.noteSlotIndex(DateTime(2026, 9, 11, 8, 59)), isNull);
    expect(SimulatedPhonePolicy.noteSlotIndex(DateTime(2026, 9, 11, 9)), 0);
    expect(SimulatedPhonePolicy.noteSlotIndex(DateTime(2026, 9, 11, 11, 29)), 0);
    expect(SimulatedPhonePolicy.noteSlotIndex(DateTime(2026, 9, 11, 11, 30)), 1);
    expect(SimulatedPhonePolicy.noteSlotIndex(DateTime(2026, 9, 11, 23, 59)), 5);
    expect(
      SimulatedPhonePolicy.noteOpportunityAllowed(
        now: DateTime(2026, 9, 11, 3),
        todayCount: 0,
        attemptedSlots: const <int>{},
        fatigue: 0,
      ),
      isFalse,
    );
    expect(
      SimulatedPhonePolicy.noteOpportunityAllowed(
        now: DateTime(2026, 9, 11, 14),
        todayCount: 2,
        attemptedSlots: const <int>{0, 1},
        fatigue: 0.4,
      ),
      isTrue,
    );
    expect(
      SimulatedPhonePolicy.noteOpportunityAllowed(
        now: DateTime(2026, 9, 11, 14),
        todayCount: 2,
        attemptedSlots: const <int>{2},
        fatigue: 0.4,
      ),
      isFalse,
    );
    expect(
      SimulatedPhonePolicy.noteOpportunityAllowed(
        now: DateTime(2026, 9, 11, 14),
        todayCount: 6,
        attemptedSlots: const <int>{},
        fatigue: 0,
      ),
      isFalse,
    );
  });

  test('fatigue can only remove a note slot opportunity', () {
    expect(
      SimulatedPhonePolicy.noteOpportunityAllowed(
        now: DateTime(2026, 9, 11, 22),
        todayCount: 0,
        attemptedSlots: const <int>{},
        fatigue: 0.64,
      ),
      isTrue,
    );
    expect(
      SimulatedPhonePolicy.noteOpportunityAllowed(
        now: DateTime(2026, 9, 11, 22),
        todayCount: 0,
        attemptedSlots: const <int>{},
        fatigue: 0.65,
      ),
      isFalse,
    );
    expect(
      SimulatedPhonePolicy.noteOpportunityAllowed(
        now: DateTime(2026, 9, 11, 14),
        todayCount: 0,
        attemptedSlots: const <int>{},
        fatigue: 0.85,
      ),
      isFalse,
    );
  });

  test('wishes keep deep-night access but require six hours between additions', () {
    final deepNight = DateTime(2026, 9, 11, 2);
    expect(
      SimulatedPhonePolicy.wishAdditionAllowed(
        now: deepNight,
        lastAddedAt: null,
      ),
      isTrue,
    );
    expect(
      SimulatedPhonePolicy.wishAdditionAllowed(
        now: deepNight,
        lastAddedAt: deepNight.subtract(const Duration(hours: 5, minutes: 59)),
      ),
      isFalse,
    );
    expect(
      SimulatedPhonePolicy.wishAdditionAllowed(
        now: deepNight,
        lastAddedAt: deepNight.subtract(const Duration(hours: 6)),
      ),
      isTrue,
    );
  });
}
