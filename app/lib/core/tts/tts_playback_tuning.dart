import 'dart:math' as math;

class TtsPlaybackTuning {
  const TtsPlaybackTuning._();

  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;
  static const double minVolume = 0.0;
  static const double maxVolume = 2.0;
  static const double minPitchSemitones = -4.0;
  static const double maxPitchSemitones = 4.0;

  static double speedFromSetting(String? value) =>
      (double.tryParse(value ?? '') ?? 1.0)
          .clamp(minSpeed, maxSpeed)
          .toDouble();

  static double volumeFromSetting(String? value) =>
      (double.tryParse(value ?? '') ?? 1.0)
          .clamp(minVolume, maxVolume)
          .toDouble();

  static double pitchSemitonesFromSetting(String? value) =>
      (double.tryParse(value ?? '') ?? 0.0)
          .clamp(minPitchSemitones, maxPitchSemitones)
          .toDouble();

  static double pitchRatioForSemitones(double semitones) =>
      math.pow(2.0, semitones / 12.0).toDouble();

  /// The saved slider is the Q-form pitch. The adult form is one semitone
  /// lower, including when the slider is at its minimum (-4 -> -5).
  static double pitchRatioForForm(
    double selectedSemitones, {
    required bool qForm,
  }) =>
      pitchRatioForSemitones(selectedSemitones - (qForm ? 0.0 : 1.0));
}
