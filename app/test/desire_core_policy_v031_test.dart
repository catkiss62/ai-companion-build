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
  final now = DateTime(2026, 8, 12, 12, 0);
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
  test('fatigue is a rest gate, not an outbound contact reason', () {
    final snapshot = DesireSnapshot(
      drives: {
        ...DesireSnapshot.defaultDrives(),
        DriveKey.attachment: 0.95,
        DriveKey.fatigue: 0.82,
      },
    );
    final candidates = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: snapshot.refractoryUntil,
      thoughts: const [],
      now: DateTime(2026, 8, 12, 20, 0),
    );

    expect(candidates.single.drive, DriveKey.fatigue);
    expect(candidates.single.action, 'rest');
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
}
