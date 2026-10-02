/// The time has elapsed; that alone cannot prove the real-world task expired
/// or was completed. This policy describes timing, never guesses task outcome.
class ReminderTimeliness {
  const ReminderTimeliness(this.scheduledAt, this.now);
  final DateTime scheduledAt;
  final DateTime now;
  Duration get delay => now.difference(scheduledAt);
  bool get delayed => delay > const Duration(minutes: 30);
  bool get pastDay => scheduledAt.toLocal().year != now.toLocal().year ||
      scheduledAt.toLocal().month != now.toLocal().month ||
      scheduledAt.toLocal().day != now.toLocal().day;
  bool get future => delay.isNegative;

  String get prompt => '原定时间=${scheduledAt.toLocal()}；当前时间=${now.toLocal()}。'
      '${pastDay ? '这是往日未送达的提醒，只能回顾原定事项，不能当作今天刚到点，也不要催促立即执行。' : delayed ? '提醒已延迟${delay.inMinutes}分钟，不可说刚刚到点；如提起，只温和确认现在是否仍有需要。' : '按真实计划时间自然提醒，不夸大紧迫程度。'}'
      '不知道事项是否仍有效或已经完成，不替用户判断；时间敏感的事项可能已过时，不能机械催办。'
      '不要责怪用户没回应，不重复催促，不捏造延迟原因。';

  static String label(DateTime scheduledAt, DateTime now) {
    if (scheduledAt.isAfter(now)) return '待提醒';
    return '原定时间已过 · 完成情况未知';
  }
}
