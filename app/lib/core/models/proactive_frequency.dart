import '../desire/daily_wake_schedule.dart';
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

  String get description =>
      '每日8–9点间自然起床，起床至14点可用$morningLimit次，14–19点累计$afternoonLimit次，'
      '19–24点累计$dayLimit次；未用次数顺延。零点至起床独立最多2次，不要求用完。'
      '至少间隔${minimumGap.inMinutes}分钟，2小时最多$twoHourLimit次；切换档位不清零。';

  int get morningLimit => switch (this) {
    ProactiveFrequencyMode.quiet => 3,
    ProactiveFrequencyMode.natural => 6,
    ProactiveFrequencyMode.frequent => 8,
  };

  int get afternoonLimit => morningLimit * 2;

  Duration get minimumGap => switch (this) {
    ProactiveFrequencyMode.quiet => const Duration(minutes: 30),
    ProactiveFrequencyMode.natural => const Duration(minutes: 15),
    ProactiveFrequencyMode.frequent => const Duration(minutes: 8),
  };

  bool allowsGap(Duration elapsed) =>
      !elapsed.isNegative && elapsed >= minimumGap;

  int get dayLimit => switch (this) {
    ProactiveFrequencyMode.quiet => 10,
    ProactiveFrequencyMode.natural => 18,
    ProactiveFrequencyMode.frequent => 24,
  };

  int get twoHourLimit => switch (this) {
    ProactiveFrequencyMode.quiet => 2,
    ProactiveFrequencyMode.natural => 3,
    ProactiveFrequencyMode.frequent => 4,
  };

  int releasedLimit(DateTime now, {DateTime? wakeAt}) => ProactiveFrequencyPolicy.isNight(now, wakeAt: wakeAt)
      ? ProactiveFrequencyPolicy.nightLimit
      : now.hour < 14
      ? morningLimit
      : now.hour < 19
      ? afternoonLimit
      : dayLimit;

  static ProactiveFrequencyMode fromSetting(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    return ProactiveFrequencyMode.values.firstWhere(
      (value) => value.key == normalized,
      orElse: () => ProactiveFrequencyMode.natural,
    );
  }
}

abstract final class ProactiveFrequencyPolicy {
  static const nightLimit = 2;
  static bool isNight(DateTime now, {DateTime? wakeAt}) =>
      now.isBefore(DailyWakeSchedule.boundary(now, wakeAt));

  // Construct wall-clock boundaries, rather than adding 24 hours across DST.
  static DateTime boundary(DateTime now, int hour) => now.isUtc
      ? DateTime.utc(now.year, now.month, now.day, hour)
      : DateTime(now.year, now.month, now.day, hour);

  static DateTime windowStart(DateTime now, {DateTime? wakeAt}) =>
      isNight(now, wakeAt: wakeAt) ? boundary(now, 0) : DailyWakeSchedule.boundary(now, wakeAt);

  static const settingKey = 'proactive_frequency_mode';
  static const defaultKey = 'natural';
  static const defaultMode = ProactiveFrequencyMode.natural;
}
