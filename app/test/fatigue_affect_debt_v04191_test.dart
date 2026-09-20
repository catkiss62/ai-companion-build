import 'package:ai_companion_localfirst/core/desire/desire_core_policy.dart';
import 'package:ai_companion_localfirst/core/desire/fatigue_affect_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/emotion_episode.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:flutter_test/flutter_test.dart';

EmotionEpisode episode(
  EmotionEpisodeCategory category, {
  double intensity = 0.8,
}) {
  final now = DateTime(2026, 9, 21, 22);
  return EmotionEpisode(
    id: 'episode:${category.key}',
    triggerMessageId: 'message-1',
    category: category,
    causeCode: 'test',
    evidenceType: 'real_user_message',
    objectKey: 'relationship',
    desirability: category == EmotionEpisodeCategory.hurt ? -0.8 : 0.8,
    agency: 'user',
    controllability: 0.5,
    expectedness: 0.5,
    relationalMeaning: 'test',
    boundaryImpact: 0,
    certainty: 1,
    intensity: intensity,
    actionTendency: 'test',
    recoveryCondition: 'time',
    status: 'active',
    outcomeCode: '',
    createdAt: now,
    updatedAt: now,
    decayAt: now.add(const Duration(hours: 1)),
    expiresAt: now.add(const Duration(hours: 4)),
  );
}

CompanionThought attachmentThought() {
  final now = DateTime(2026, 9, 21, 22);
  return CompanionThought(
    id: 'attachment-thought',
    text: '还想再黏一会儿',
    driveKey: DriveKey.attachment.name,
    kind: 'fixation',
    strength: 0.82,
    bornAt: now,
    updatedAt: now,
    source: 'user_message',
    lifecycleState: 'fixation',
  );
}

void main() {
  final now = DateTime(2026, 9, 21, 22, 10);

  test('positive connection briefly offsets rest without erasing body fatigue', () {
    final affect = FatigueAffectPolicy.evaluate(
      episodes: [episode(EmotionEpisodeCategory.connection)],
      now: now,
    );

    expect(affect.mode, 'temporarily_activated');
    expect(affect.positiveActivation, greaterThan(0.6));
    expect(affect.restScoreAdjustment, lessThan(0));
    expect(affect.actionPenaltyAdjustment, lessThan(0));
    expect(
      DesireCorePolicy.fatigueRestScore(0.70, affect: affect),
      lessThan(DesireCorePolicy.fatigueRestScore(0.70)),
    );
  });

  test('negative emotion means tired but restless, never extra outward energy', () {
    final affect = FatigueAffectPolicy.evaluate(
      episodes: [episode(EmotionEpisodeCategory.hurt)],
      now: now,
    );

    expect(affect.mode, 'tired_but_restless');
    expect(affect.restScoreAdjustment, lessThan(0));
    expect(affect.actionPenaltyAdjustment, greaterThan(0));
    expect(
      DesireCorePolicy.fatigueActionPenalty(0.70, affect: affect),
      greaterThan(DesireCorePolicy.fatigueActionPenalty(0.70)),
    );
    expect(
      DesireCorePolicy.fatigueRestReason(affect),
      contains('身体已经累了'),
    );
  });

  test('sleep debt outweighs excitement after repeated late effort', () {
    final excited = FatigueAffectPolicy.evaluate(
      episodes: [episode(EmotionEpisodeCategory.connection)],
      now: now,
    );
    final indebted = FatigueAffectPolicy.evaluate(
      episodes: [episode(EmotionEpisodeCategory.connection)],
      now: now,
      sleepDebt: FatigueAffectPolicy.maxSleepDebt,
    );
    final drives = {
      ...DesireSnapshot.defaultDrives(),
      DriveKey.attachment: 0.58,
      DriveKey.fatigue: 0.72,
    };

    final first = DesireCorePolicy.candidates(
      drives: drives,
      refractoryUntil: const {},
      thoughts: [attachmentThought()],
      now: now,
      fatigueAffect: excited,
    );
    final afterDebt = DesireCorePolicy.candidates(
      drives: drives,
      refractoryUntil: const {},
      thoughts: [attachmentThought()],
      now: now,
      fatigueAffect: indebted,
    );

    expect(first.first.drive, DriveKey.attachment);
    expect(afterDebt.first.drive, DriveKey.fatigue);
    expect(indebted.mode, 'sleep_debt');
  });

  test('debt accrues only from tired autonomous exertion and remains bounded', () {
    expect(
      FatigueAffectPolicy.exertionDebt(bodyFatigue: 0.30),
      0,
    );
    final proactive =
        FatigueAffectPolicy.exertionDebt(bodyFatigue: 0.72);
    final cedar = FatigueAffectPolicy.exertionDebt(
      bodyFatigue: 0.72,
      weight: 0.45,
    );
    expect(proactive, inInclusiveRange(0.05, 0.055));
    expect(cedar, lessThan(proactive));
    expect(
      FatigueAffectPolicy.evaluate(
        episodes: const [],
        now: now,
        sleepDebt: 99,
      ).sleepDebt,
      FatigueAffectPolicy.maxSleepDebt,
    );
  });

  test('unrepaid debt creates daytime recovery pressure without faking fatigue', () {
    const affect = FatigueAffectSnapshot(sleepDebt: 0.14);
    final candidates = DesireCorePolicy.candidates(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.fatigue: 0.28,
        DriveKey.curiosity: 0.52,
      },
      refractoryUntil: const {},
      thoughts: const [],
      now: DateTime(2026, 9, 22, 11),
      fatigueAffect: affect,
    );

    expect(candidates.any((item) => item.drive == DriveKey.fatigue), isTrue);
    expect(affect.sleepDebt, 0.14);
  });

  test('debt repayment starts only after ninety minutes of real quiet', () {
    final updated = DateTime(2026, 9, 22, 2);
    final wakeful = updated.add(const Duration(minutes: 30));
    final tooSoon = FatigueAffectPolicy.repaySleepDebt(
      sleepDebt: 0.12,
      updatedAt: updated,
      lastWakefulAt: wakeful,
      now: wakeful.add(const Duration(minutes: 89)),
    );
    final rested = FatigueAffectPolicy.repaySleepDebt(
      sleepDebt: 0.12,
      updatedAt: updated,
      lastWakefulAt: wakeful,
      now: wakeful.add(const Duration(hours: 4, minutes: 30)),
    );

    expect(tooSoon, closeTo(0.12, 1e-9));
    expect(rested, closeTo(0.045, 1e-9));
  });

  test('Cedar uses the same debt pressure and keeps unattended night veto', () {
    final affect = FatigueAffectPolicy.evaluate(
      episodes: [episode(EmotionEpisodeCategory.connection)],
      now: DateTime(2026, 9, 22, 1),
      sleepDebt: FatigueAffectPolicy.maxSleepDebt,
      activityActivation: 0.72,
    );
    final decision = CedarContinuationGatePolicy.evaluate(
      now: DateTime(2026, 9, 22, 1),
      storedFatigue: 0.70,
      curiosity: 0.88,
      reflection: 0.70,
      strongestGameThought: 0.90,
      activelyWatched: false,
      fatigueAffect: affect,
    );

    expect(decision.allowed, isFalse);
    expect(decision.reason, 'night_sleep');
    expect(decision.restScore, greaterThan(0.70));
  });
}
