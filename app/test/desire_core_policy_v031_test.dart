import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/desire/desire_core_policy.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';

CompanionThought thought({
  required String id,
  required DriveKey drive,
  required double strength,
  bool fixation = false,
  String source = 'internal',
}) {
  final now = DateTime(2026, 8, 12, 0, 0);
  return CompanionThought(
    id: id,
    text: 'thought-$id',
    driveKey: drive.name,
    kind: fixation ? 'fixation' : 'flit',
    strength: strength,
    bornAt: now,
    updatedAt: now,
    source: source,
    lifecycleState: fixation ? 'fixation' : 'active',
  );
}

void main() {
  test('ordinary desire yields to rest while exceptional attachment can override', () {
    final now = DateTime(2026, 8, 12, 4, 0);
    final snapshot = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.attachment: 0.60,
        DriveKey.fatigue: 0.82,
      },
    );
    final candidates = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: snapshot.refractoryUntil,
      thoughts: const [],
      now: now,
    );

    expect(candidates.first.drive, DriveKey.fatigue);
    expect(candidates.first.action, 'rest');

    final exceptional = DesireCorePolicy.candidates(
      drives: {
        ...snapshot.drives,
        DriveKey.attachment: 0.78,
      },
      refractoryUntil: const {},
      thoughts: [
        thought(
          id: 'miss-you',
          drive: DriveKey.attachment,
          strength: 0.90,
          fixation: true,
          source: 'user_message',
        ),
      ],
      now: now,
    );

    expect(exceptional.first.drive, DriveKey.attachment);
    expect(exceptional.first.action, 'reach_out');
    expect(
      exceptional.any((candidate) => candidate.drive == DriveKey.fatigue),
      isTrue,
    );
  });

  test('circadian floor is low by day and creates real late-night sleepiness', () {
    expect(
      DesireCorePolicy.circadianFatigueFloor(DateTime(2026, 8, 12, 12)),
      closeTo(0.16, 1e-9),
    );
    expect(
      DesireCorePolicy.circadianFatigueFloor(DateTime(2026, 8, 13, 4)),
      closeTo(0.78, 1e-9),
    );
    expect(
      DesireCorePolicy.circadianFatigueFloor(DateTime(2026, 8, 13, 5, 10)),
      closeTo(0.6967, 0.0001),
    );

    final lateNight = DesireCorePolicy.advance(
      snapshot: DesireSnapshot(
        drives: {
          ...DesireSnapshot.defaultDrives(),
          DriveKey.fatigue: 0.10,
        },
        lastTickAt: DateTime(2026, 8, 13, 3, 48),
      ),
      now: DateTime(2026, 8, 13, 4),
    );
    expect(lateNight.drives[DriveKey.fatigue], closeTo(0.78, 1e-9));
  });

  test('morning passage recovers fatigue without pretending user reply is sleep', () {
    final recovered = DesireCorePolicy.advance(
      snapshot: DesireSnapshot(
        drives: {
          ...DesireSnapshot.defaultDrives(),
          DriveKey.fatigue: 0.82,
        },
        lastTickAt: DateTime(2026, 8, 13, 4),
      ),
      now: DateTime(2026, 8, 13, 9),
    );

    expect(recovered.drives[DriveKey.fatigue]!, lessThan(0.82));
    expect(recovered.drives[DriveKey.fatigue]!, greaterThanOrEqualTo(0.16));
  });

  test('only high-fatigue outbound effort adds a bounded body cost', () {
    final tired = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.attachment: 0.88,
        DriveKey.fatigue: 0.72,
      },
    );
    final outbound = DesireCorePolicy.satisfiedDrives(
      snapshot: tired,
      action: 'reach_out',
      primaryDrive: DriveKey.attachment,
      intensity: 0.55,
      outboundEffort: true,
    );
    final replyOnly = DesireCorePolicy.satisfiedDrives(
      snapshot: tired,
      action: 'reach_out',
      primaryDrive: DriveKey.attachment,
      intensity: 0.55,
    );

    expect(outbound[DriveKey.attachment]!, lessThan(0.88));
    expect(outbound[DriveKey.fatigue]!, greaterThan(0.72));
    expect(outbound[DriveKey.fatigue]!, lessThanOrEqualTo(0.805));
    expect(replyOnly[DriveKey.fatigue], closeTo(0.72, 1e-9));
    expect(DesireCorePolicy.fatigueActionPenalty(0.20), 0.0);
    expect(DesireCorePolicy.outboundFatigueCost(0.20), 0.0);
  });

  test('per-drive refractory blocks one desire without muting all others', () {
    final now = DateTime(2026, 8, 12, 20, 0);
    final snapshot = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.attachment: 0.90,
        DriveKey.curiosity: 0.76,
        DriveKey.fatigue: 0.20,
      },
      refractoryUntil: {
        DriveKey.attachment: now.add(const Duration(minutes: 30)),
      },
    );
    final candidates = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: snapshot.refractoryUntil,
      thoughts: const [],
      now: now,
    );

    expect(candidates.first.drive, isNot(DriveKey.attachment));
    expect(candidates.first.drive, DriveKey.curiosity);
    expect(candidates.first.action, 'check_in');
  });

  test('duty cannot invent an unfinished thread without grounded thought evidence', () {
    final now = DateTime(2026, 8, 12, 20, 0);
    final snapshot = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.duty: 0.98,
        DriveKey.attachment: 0.50,
        DriveKey.fatigue: 0.20,
      },
    );
    final candidates = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: const {},
      thoughts: const [],
      now: now,
    );
    expect(candidates.any((c) => c.drive == DriveKey.duty), isFalse);

    final grounded = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: const {},
      thoughts: [
        thought(
          id: 'thread',
          drive: DriveKey.duty,
          strength: 0.72,
          source: 'self_drive/thread',
        ),
      ],
      now: now,
    );
    expect(grounded.any((c) => c.drive == DriveKey.duty), isTrue);
  });

  test('fixation boosts summon score with bounded diminishing contribution', () {
    final now = DateTime(2026, 8, 12, 20, 0);
    final snapshot = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.reflection: 0.40,
        DriveKey.fatigue: 0.20,
      },
    );
    final without = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: const {},
      thoughts: const [],
      now: now,
    ).firstWhere((c) => c.drive == DriveKey.reflection);
    final withThoughts = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: const {},
      thoughts: [
        thought(
          id: 'a',
          drive: DriveKey.reflection,
          strength: 0.9,
          fixation: true,
          source: 'self_drive/memory',
        ),
        thought(
          id: 'b',
          drive: DriveKey.reflection,
          strength: 0.9,
          fixation: true,
        ),
        thought(
          id: 'c',
          drive: DriveKey.reflection,
          strength: 0.9,
          fixation: true,
        ),
        thought(
          id: 'd',
          drive: DriveKey.reflection,
          strength: 0.9,
          fixation: true,
        ),
      ],
      now: now,
    ).firstWhere((c) => c.drive == DriveKey.reflection);

    expect(withThoughts.score, greaterThan(without.score));
    expect(withThoughts.score, lessThanOrEqualTo(1.0));
    expect(withThoughts.reasonSource, 'self_drive/memory');
  });

  test('action-aware satisfy settles primary and related drives softly', () {
    final snapshot = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.attachment: 0.86,
        DriveKey.social: 0.70,
        DriveKey.curiosity: 0.62,
      },
    );
    final settled = DesireCorePolicy.satisfiedDrives(
      snapshot: snapshot,
      action: 'reach_out',
      primaryDrive: DriveKey.attachment,
      intensity: 1.0,
    );

    expect(settled[DriveKey.attachment]!, lessThan(0.86));
    expect(settled[DriveKey.social]!, lessThan(0.70));
    expect(settled[DriveKey.curiosity], closeTo(0.62, 1e-9));
    expect(
      settled[DriveKey.attachment]!,
      greaterThanOrEqualTo(snapshot.baselines[DriveKey.attachment]!),
    );
  });

  test('libido is a normal adult relationship drive without a Session gate', () {
    final now = DateTime(2026, 8, 12, 20, 0);
    final snapshot = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.libido: 0.98,
        DriveKey.fatigue: 0.20,
      },
    );
    final ordinary = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: const {},
      thoughts: const [],
      now: now,
    );
    final consumerFiltered = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: const {},
      thoughts: const [],
      now: now,
      intimacyAllowed: false,
    );

    expect(ordinary.first.drive, DriveKey.libido);
    expect(ordinary.first.action, 'tease_or_intimacy');
    expect(
      consumerFiltered.any((candidate) => candidate.drive == DriveKey.libido),
      isFalse,
    );
  });

  test('learned temperament slowly pulls back toward its original anchor', () {
    final now = DateTime(2026, 12, 10, 12, 0);
    final anchor = DesireSnapshot.defaultBaselines()[DriveKey.attachment]!;
    final snapshot = DesireSnapshot(
      baselines: {
        ...DesireSnapshot.defaultBaselines(),
        DriveKey.attachment: anchor + 0.10,
      },
      lastTickAt: now.subtract(const Duration(days: 30)),
    );
    final advanced = DesireCorePolicy.advance(snapshot: snapshot, now: now);

    expect(advanced.baselines[DriveKey.attachment]!, lessThan(anchor + 0.10));
    expect(advanced.baselines[DriveKey.attachment]!, greaterThan(anchor));
  });

  test('wildcard becomes a real pressure-release action and respects cooldown', () {
    final now = DateTime(2026, 8, 12, 20, 0);
    final snapshot = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.duty: 0.92,
        DriveKey.stress: 0.80,
        DriveKey.fatigue: 0.20,
      },
      refractoryUntil: {
        DriveKey.stress: now.add(const Duration(minutes: 30)),
      },
    );
    final ready = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      baselines: snapshot.baselines,
      refractoryUntil: snapshot.refractoryUntil,
      thoughts: const [],
      now: now,
    );
    final coolingDown = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      baselines: snapshot.baselines,
      refractoryUntil: snapshot.refractoryUntil,
      thoughts: const [],
      now: now,
      lastWildcardAt: now.subtract(const Duration(hours: 1)),
    );

    expect(ready.first.action, 'wildcard_share');
    expect(coolingDown.any((c) => c.action == 'wildcard_share'), isFalse);
  });

  test('1000 deterministic ticks stay bounded and do not self-excite', () {
    var now = DateTime(2026, 8, 12, 8, 0);
    var snapshot = DesireSnapshot(lastTickAt: now);

    for (var i = 0; i < 1000; i++) {
      now = now.add(const Duration(minutes: 12));
      final pulse = sin(i / 17.0) * 0.006;
      final advanced = DesireCorePolicy.advance(
        snapshot: snapshot,
        now: now,
        pulses: {
          DriveKey.curiosity: pulse,
          DriveKey.attachment: -pulse * 0.5,
        },
        userBusy: i % 9 == 0,
      );
      for (final value in advanced.drives.values) {
        expect(value, inInclusiveRange(0.0, 1.0));
      }
      snapshot = snapshot.copyWith(
        drives: advanced.drives,
        baselines: advanced.baselines,
        refractoryUntil: advanced.refractoryUntil,
        lastTickAt: now,
      );
    }

    expect(
      snapshot.drives.values.where((value) => value >= 0.999).length,
      lessThan(DriveKey.values.length),
    );
  });

  test('post-turn model pulses have per-drive and whole-turn budgets', () {
    final normalized = DesireCorePolicy.normalizePostTurnPulses({
      for (final drive in DriveKey.values) drive: 0.12,
    });

    expect(
      normalized[DriveKey.attachment]!,
      lessThanOrEqualTo(DesireCorePolicy.postTurnPulseCaps[DriveKey.attachment]!),
    );
    expect(
      normalized.values.fold<double>(0, (sum, value) => sum + value.abs()),
      closeTo(DesireCorePolicy.postTurnPulseBudget, 1e-9),
    );
  });

  test('rapid ordinary conversation does not mechanically pin attachment', () {
    var now = DateTime(2026, 8, 12, 20, 0);
    var snapshot = DesireSnapshot(lastTickAt: now);

    for (var i = 0; i < 80; i++) {
      now = now.add(const Duration(seconds: 20));
      final advanced = DesireCorePolicy.advance(
        snapshot: snapshot,
        now: now,
        pulses: DesireCorePolicy.ordinaryConversationPulses,
      );
      snapshot = snapshot.copyWith(
        drives: advanced.drives,
        baselines: advanced.baselines,
        refractoryUntil: advanced.refractoryUntil,
        lastTickAt: now,
      );
    }

    expect(snapshot.drives[DriveKey.attachment]!, lessThan(0.60));
    expect(snapshot.drives[DriveKey.curiosity]!, greaterThan(0.40));
    expect(snapshot.drives[DriveKey.reflection]!, greaterThan(0.38));
    expect(snapshot.drives[DriveKey.social]!, greaterThan(0.30));
  });
}
