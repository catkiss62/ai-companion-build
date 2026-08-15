import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:ai_companion_localfirst/core/platform/pet_autonomy_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final daytime = DateTime(2026, 8, 16, 14);

  test('projects a strong active Thought without exposing its text', () {
    final thought = CompanionThought(
      id: 'thought-1',
      text: 'private body must not cross the native channel',
      driveKey: DriveKey.reflection.name,
      kind: 'fixation',
      strength: 0.72,
      bornAt: daytime,
      updatedAt: daytime,
    );
    final snapshot = PetAutonomySnapshot.project(
      desire: DesireSnapshot(),
      thoughts: [thought],
      brainWorkAllowed: true,
      now: daytime,
    );

    expect(snapshot.dominantDrive, DriveKey.reflection.name);
    expect(snapshot.thoughtActive, isTrue);
    expect(snapshot.mood, 'reflective');
    expect(snapshot.toChannelMap().values, isNot(contains(thought.text)));
  });

  test('fatigue and local late night project to sleepy visual mood', () {
    final drives = DesireSnapshot.defaultDrives()
      ..[DriveKey.fatigue] = 0.70;
    final fatigue = PetAutonomySnapshot.project(
      desire: DesireSnapshot(drives: drives),
      thoughts: const [],
      brainWorkAllowed: true,
      now: daytime,
    );
    final lateNight = PetAutonomySnapshot.project(
      desire: DesireSnapshot(),
      thoughts: const [],
      brainWorkAllowed: true,
      now: DateTime(2026, 8, 17, 2),
    );

    expect(fatigue.mood, 'sleepy');
    expect(lateNight.mood, 'sleepy');
    expect(lateNight.lateNight, isTrue);
  });

  test('standby brain disables autonomous consumption', () {
    final snapshot = PetAutonomySnapshot.project(
      desire: DesireSnapshot(),
      thoughts: const [],
      brainWorkAllowed: false,
      now: daytime,
    );
    expect(snapshot.enabled, isFalse);
  });
}
