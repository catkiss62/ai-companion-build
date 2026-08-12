class ChatTimestampFormatter {
  const ChatTimestampFormatter._();

  static String time(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static bool shouldShowDateSeparator(
    DateTime current,
    DateTime? previous,
  ) {
    if (previous == null) return true;
    final a = current.toLocal();
    final b = previous.toLocal();
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  static String dateSeparator(DateTime value, {DateTime? now}) {
    final local = value.toLocal();
    final today = (now ?? DateTime.now()).toLocal();
    final yesterday = today.subtract(const Duration(days: 1));

    if (_sameDay(local, today)) {
      return '今天 · ${_weekday(local.weekday)}';
    }
    if (_sameDay(local, yesterday)) {
      return '昨天 · ${_weekday(local.weekday)}';
    }
    if (local.year == today.year) {
      return '${local.month}月${local.day}日 · ${_weekday(local.weekday)}';
    }
    return '${local.year}年${local.month}月${local.day}日 · ${_weekday(local.weekday)}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _weekday(int weekday) => const {
        DateTime.monday: '周一',
        DateTime.tuesday: '周二',
        DateTime.wednesday: '周三',
        DateTime.thursday: '周四',
        DateTime.friday: '周五',
        DateTime.saturday: '周六',
        DateTime.sunday: '周日',
      }[weekday] ?? '';
}
