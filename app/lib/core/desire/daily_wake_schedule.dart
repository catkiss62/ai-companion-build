/// A local calendar day's shared wake boundary. This is a lightweight rhythm
/// reference, not evidence that either person actually slept or is available.
class DailyWakeSchedule {
  const DailyWakeSchedule({required this.wakeAt, required this.sampledAt});

  final DateTime wakeAt;
  final DateTime sampledAt;
  static const settlingDuration = Duration(minutes: 45);
  DateTime get clearAt => wakeAt.add(settlingDuration);

  bool beforeWake(DateTime now) => now.isBefore(wakeAt);
  double sleepiness(DateTime now) {
    if (beforeWake(now) || !now.isBefore(clearAt)) return 0;
    return (1 -
            now.difference(wakeAt).inMilliseconds /
                settlingDuration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  String promptSection(DateTime now) {
    final remaining = sleepiness(now);
    if (remaining <= 0) return '';
    final tone = remaining > .66
        ? '睡意还比较明显'
        : remaining > .33
        ? '睡意正在缓缓散去'
        : '已经逐渐清醒，只剩一点余困';
    return '【此刻身体节律】处于自然起床后的醒神时段，$tone。'
        '结合当前疲劳与话题，让语气偶尔略懒、略短即可；感兴趣时仍可以投入。'
        '这不是必须表现的动作或台词，不要求提到刚醒，不要每轮揉眼睛、打哈欠。'
        '不凭此主动发起问候，不宣称具体睡过多久、几点醒来，也不推断用户刚起床。';
  }

  Map<String, Object?> toJson(DateTime now) => {
    'wakeAt': wakeAt.toIso8601String(),
    'clearAt': clearAt.toIso8601String(),
    'sampledAt': sampledAt.toIso8601String(),
    'beforeWake': beforeWake(now),
    'settlingMinutes': settlingDuration.inMinutes,
    'sleepiness': sleepiness(now),
    'triggersMessage': false,
  };

  static DateTime atMinute(DateTime day, int minute) => day.isUtc
      ? DateTime.utc(day.year, day.month, day.day, 0, minute)
      : DateTime(day.year, day.month, day.day, 0, minute);

  // Pure policy callers without persistence use the latest possible boundary.
  // Production callers load the shared daily record and pass its wakeAt.
  static DateTime boundary(DateTime now, DateTime? wakeAt) =>
      wakeAt != null &&
          wakeAt.year == now.year &&
          wakeAt.month == now.month &&
          wakeAt.day == now.day
      ? wakeAt
      : atMinute(now, 9 * 60);
}
