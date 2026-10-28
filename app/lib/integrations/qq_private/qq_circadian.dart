import 'dart:convert';
import '../../core/database/app_database.dart';
import '../../core/desire/daily_wake_schedule.dart';
import '../../core/desire/daily_wake_store.dart';

/// QQ only projects an existing App day. It never calls DailyWakeStore.read,
/// which can sample and persist a missing schedule.
class QqCircadianProjection {
  const QqCircadianProjection(this.phase, {required this.known});
  final String phase;
  final bool known;
  bool get resting => phase == 'resting';
  String get small => '$phase${known ? '' : ' (当天记录缺失，保守只读回退)'}';
  String get prompt => switch (phase) {
    'waking' => '【共享时间状态】处于App当天起床后的醒神时段。语气可以略懒、略短，但准确理解问题；不必提刚醒，不编造睡眠经历。',
    'sleepy' => '【共享时间状态】晚间渐困，可以更松、更短；不用每句打哈欠，也不因此取消直接对话。',
    'very_sleepy' => '【共享时间状态】深夜困意更明显，可以低能耗说话，认真问题仍说清；不要求报告状态。',
    'resting' => '【共享时间状态】共同休息时段。群聊仅归档；本人私聊沿用原有可回应策略，不改变App数值。',
    _ => '',
  };
  static QqCircadianProjection derive(DateTime now, {int? wakeMinute}) {
    final known = wakeMinute != null && wakeMinute >= 480 && wakeMinute <= 540;
    final wake = DailyWakeSchedule.atMinute(now, known ? wakeMinute! : 540);
    if (now.isBefore(wake)) return QqCircadianProjection('resting', known: known);
    if (known && now.isBefore(wake.add(DailyWakeSchedule.settlingDuration))) {
      return const QqCircadianProjection('waking', known: true);
    }
    return QqCircadianProjection(now.hour >= 23 ? 'very_sleepy' : now.hour >= 22 ? 'sleepy' : 'daytime', known: known);
  }
  static Future<QqCircadianProjection> read(AppDatabase db, DateTime now) async {
    int? minute;
    try {
      final value = jsonDecode(await db.getSetting(DailyWakeStore.keyFor(now)) ?? '{}');
      if (value is Map && value['minute'] is int) minute = value['minute'] as int;
    } catch (_) { /* No writes on missing or malformed records. */ }
    return derive(now, wakeMinute: minute);
  }
}
