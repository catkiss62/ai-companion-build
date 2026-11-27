import 'dart:convert';

import '../database/app_database.dart';

class MonthlyRestDays {
  MonthlyRestDays(DateTime date, Iterable<int>? selected)
    : month = DateTime(date.toLocal().year, date.toLocal().month),
      days = selected == null
          ? null
          : List.unmodifiable(selected.toSet().toList()..sort());

  final DateTime month;

  /// Null means the user has not confirmed the month's roster.
  final List<int>? days;
  int get length => DateTime(month.year, month.month + 1, 0).day;
  String get monthLabel => '${month.year}年${month.month}月';
  String get key => 'user_rest_days_v1_${month.year}_${month.month}';

  String get prompt {
    final rest = days;
    final schedule = rest == null
        ? '用户尚未确认本月排班；工作日和休息日都未知，星期几不能确定用户是否休息。'
        : rest.isEmpty
        ? '用户已确认本月没有排定的休息日。'
        : '用户已确认本月排班，休息日为 ${rest.join("、")} 日，其余日期按工作日理解。';
    return '【用户手动登记的月度排班】$monthLabel：$schedule 仅适用于这个月。当前聊天里用户说的临时调班或请假优先。仅在相关时参考。';
  }

  static const _enabledKey = 'user_rest_days_enabled_v1';
  static Future<bool> enabled(AppDatabase db) async =>
      await db.getSetting(_enabledKey) != '0';

  static Future<void> setEnabled(AppDatabase db, bool value) =>
      db.setSetting(_enabledKey, value ? '1' : '0');

  static Future<MonthlyRestDays?> forPrompt(
    AppDatabase db,
    DateTime date,
  ) async {
    if (!await enabled(db)) return null;
    return read(db, date);
  }

  static Future<MonthlyRestDays> read(AppDatabase db, DateTime date) async {
    final unknown = MonthlyRestDays(date, null);
    final raw = await db.getSetting(unknown.key);
    if (raw == null || raw.isEmpty) return unknown;
    try {
      final list = jsonDecode(raw);
      if (list is List &&
          list.every((v) => v is int && v >= 1 && v <= unknown.length)) {
        return MonthlyRestDays(date, list.cast<int>());
      }
    } on FormatException {
      /* Unreadable data cannot establish a work schedule. */
    }
    return unknown;
  }

  Future<void> save(AppDatabase db) {
    if (days?.any((d) => d < 1 || d > length) == true) {
      throw ArgumentError('日期超出本月范围');
    }
    return db.setSetting(key, days == null ? '' : jsonEncode(days));
  }
}
