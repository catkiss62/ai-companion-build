enum ProactiveFrequencyMode {
  quiet,
  natural,
  frequent;

  String get key => name;

  String get zhLabel => switch (this) {
        ProactiveFrequencyMode.quiet => '安静',
        ProactiveFrequencyMode.natural => '自然',
        ProactiveFrequencyMode.frequent => '频繁',
      };

  String get description => switch (this) {
        ProactiveFrequencyMode.quiet => '过去24小时最多8次，2小时最多2次',
        ProactiveFrequencyMode.natural => '过去24小时最多16次，2小时最多3次',
        ProactiveFrequencyMode.frequent => '过去24小时最多24次，2小时最多4次',
      };

  int get dayLimit => switch (this) {
        ProactiveFrequencyMode.quiet => 8,
        ProactiveFrequencyMode.natural => 16,
        ProactiveFrequencyMode.frequent => 24,
      };

  int get twoHourLimit => switch (this) {
        ProactiveFrequencyMode.quiet => 2,
        ProactiveFrequencyMode.natural => 3,
        ProactiveFrequencyMode.frequent => 4,
      };

  static ProactiveFrequencyMode fromSetting(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    return ProactiveFrequencyMode.values.firstWhere(
      (value) => value.key == normalized,
      orElse: () => ProactiveFrequencyMode.natural,
    );
  }
}

abstract final class ProactiveFrequencyPolicy {
  static const settingKey = 'proactive_frequency_mode';
  static const defaultKey = 'natural';
  static const defaultMode = ProactiveFrequencyMode.natural;
}
