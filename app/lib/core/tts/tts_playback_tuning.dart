import 'dart:math' as math;

enum TtsTonePreset {
  original('original', '高音版（原声）'),
  low('low', '低音版'),
  custom('custom', '自定义变调');

  const TtsTonePreset(this.key, this.label);

  final String key;
  final String label;

  static TtsTonePreset fromSetting(String? value) => values.firstWhere(
        (preset) => preset.key == value,
        orElse: () => original,
      );
}

class TtsPlaybackTuning {
  const TtsPlaybackTuning._();

  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;
  static const double minVolume = 0.0;
  static const double maxVolume = 2.0;
  static const double minPitchSemitones = -4.0;
  static const double maxPitchSemitones = 4.0;
  static const double lowPitchSemitones = -2.0;

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

  static double effectivePitchSemitones(
    TtsTonePreset preset,
    double customSemitones,
  ) =>
      switch (preset) {
        TtsTonePreset.original => 0.0,
        TtsTonePreset.low => lowPitchSemitones,
        TtsTonePreset.custom => customSemitones.clamp(
            minPitchSemitones,
            maxPitchSemitones,
          ).toDouble(),
      };

  static double pitchRatioForSemitones(double semitones) =>
      math.pow(2.0, semitones / 12.0).toDouble();
}
