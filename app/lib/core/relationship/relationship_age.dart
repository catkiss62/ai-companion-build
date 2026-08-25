class RelationshipAge {
  const RelationshipAge({
    required this.startedAt,
    required this.now,
  });

  final DateTime startedAt;
  final DateTime now;

  int get elapsedCalendarDays => calendarDayDifference(startedAt, now);
  int get dayNumber => elapsedCalendarDays + 1;

  static int calendarDayDifference(DateTime startedAt, DateTime now) {
    final start = startedAt.toLocal();
    final current = now.toLocal();
    final startDay = DateTime.utc(start.year, start.month, start.day);
    final currentDay = DateTime.utc(current.year, current.month, current.day);
    final difference = currentDay.difference(startDay).inDays;
    return difference < 0 ? 0 : difference;
  }
}
