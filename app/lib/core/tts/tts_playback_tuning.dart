class TtsPlaybackTuning {
  const TtsPlaybackTuning._();

  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;
  static const double minVolume = 0.0;
  static const double maxVolume = 2.0;

  static double speedFromSetting(String? value) =>
      (double.tryParse(value ?? '') ?? 1.0)
          .clamp(minSpeed, maxSpeed)
          .toDouble();

  static double volumeFromSetting(String? value) =>
      (double.tryParse(value ?? '') ?? 1.0)
          .clamp(minVolume, maxVolume)
          .toDouble();
}
