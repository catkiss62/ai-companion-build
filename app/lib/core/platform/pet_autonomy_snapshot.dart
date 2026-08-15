import '../models/desire_state.dart';
import '../models/thought.dart';

/// Read-only projection of the existing inner-life state for the native pet.
///
/// This object never mutates Desire or Thought and never decides whether the
/// companion should contact the user. It only turns already-durable state into
/// a small, privacy-safe visual cue consumed by the Android animation layer.
class PetAutonomySnapshot {
  const PetAutonomySnapshot({
    required this.enabled,
    required this.dominantDrive,
    required this.driveLevel,
    required this.mood,
    required this.thoughtActive,
    required this.thoughtStrength,
    required this.lateNight,
  });

  final bool enabled;
  final String dominantDrive;
  final double driveLevel;
  final String mood;
  final bool thoughtActive;
  final double thoughtStrength;
  final bool lateNight;

  factory PetAutonomySnapshot.project({
    required DesireSnapshot desire,
    required List<CompanionThought> thoughts,
    required bool brainWorkAllowed,
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now();
    final dominant = desire.drives.entries.reduce(
      (left, right) => left.value >= right.value ? left : right,
    );
    final activeThoughts = thoughts
        .where((thought) => thought.canDriveIntentAt(instant))
        .toList(growable: false)
      ..sort((a, b) => b.strength.compareTo(a.strength));
    final thought = activeThoughts.isEmpty ? null : activeThoughts.first;
    DriveKey? thoughtDrive;
    for (final drive in DriveKey.values) {
      if (drive.name == thought?.driveKey) {
        thoughtDrive = drive;
        break;
      }
    }
    final useThought = thought != null &&
        thoughtDrive != null &&
        thought.strength >= 0.50 &&
        thought.strength >= dominant.value - 0.08;
    final selectedDrive = useThought ? thoughtDrive! : dominant.key;
    final selectedLevel = useThought
        ? thought.strength.clamp(0.0, 1.0).toDouble()
        : dominant.value.clamp(0.0, 1.0).toDouble();
    final fatigue = desire.drives[DriveKey.fatigue] ?? 0;
    final stress = desire.drives[DriveKey.stress] ?? 0;
    final attachment = desire.drives[DriveKey.attachment] ?? 0;
    final social = desire.drives[DriveKey.social] ?? 0;
    final curiosity = desire.drives[DriveKey.curiosity] ?? 0;
    final reflection = desire.drives[DriveKey.reflection] ?? 0;
    final lateNight = instant.hour < 6;
    final mood = fatigue >= 0.48 || lateNight
        ? 'sleepy'
        : stress >= 0.56
            ? 'tense'
            : attachment >= 0.60 || social >= 0.60
                ? 'warm'
                : curiosity >= 0.56
                    ? 'curious'
                    : reflection >= 0.54 || (thought?.strength ?? 0) >= 0.55
                        ? 'reflective'
                        : 'calm';
    return PetAutonomySnapshot(
      enabled: brainWorkAllowed,
      dominantDrive: selectedDrive.name,
      driveLevel: selectedLevel,
      mood: mood,
      thoughtActive: thought != null,
      thoughtStrength: (thought?.strength ?? 0).clamp(0.0, 1.0).toDouble(),
      lateNight: lateNight,
    );
  }

  Map<String, Object> toChannelMap() => <String, Object>{
        'enabled': enabled,
        'dominant_drive': dominantDrive,
        'drive_level': driveLevel,
        'mood': mood,
        'thought_active': thoughtActive,
        'thought_strength': thoughtStrength,
        'late_night': lateNight,
      };
}
