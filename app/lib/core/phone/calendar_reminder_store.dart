import 'dart:convert';

import '../database/app_database.dart';
import '../platform/android_bridge.dart';

class CalendarReminder {
  const CalendarReminder({
    required this.id,
    required this.title,
    required this.year,
    required this.month,
    required this.day,
    required this.yearly,
    this.hour,
    this.minute,
  });

  final String id;
  final String title;
  final int year;
  final int month;
  final int day;
  final bool yearly;
  final int? hour;
  final int? minute;

  bool get timed => hour != null && minute != null;
  String get dateLabel => '$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  bool occursOn(DateTime local) => month == local.month &&
      day == local.day && (yearly || year == local.year);

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'year': year,
        'month': month,
        'day': day,
        'yearly': yearly,
        if (timed) 'hour': hour,
        if (timed) 'minute': minute,
      };

  factory CalendarReminder.fromJson(Map<String, Object?> json) =>
      CalendarReminder(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        year: (json['year'] as num?)?.toInt() ?? 0,
        month: (json['month'] as num?)?.toInt() ?? 0,
        day: (json['day'] as num?)?.toInt() ?? 0,
        yearly: json['yearly'] == true,
        hour: (json['hour'] as num?)?.toInt(),
        minute: (json['minute'] as num?)?.toInt(),
      );
}

/// The SQLite setting is the backed-up source of truth. Android keeps an
/// independently restorable scheduling mirror for process death and reboot.
class CalendarReminderStore {
  CalendarReminderStore(this.db, {AndroidBridge? android})
      : android = android ?? AndroidBridge.instance;

  static const settingKey = 'calendar_reminders_v1';
  final AppDatabase db;
  final AndroidBridge android;

  Future<List<CalendarReminder>> load() async {
    try {
      final decoded = jsonDecode(await db.getSetting(settingKey) ?? '[]');
      if (decoded is! List) return const [];
      return decoded.whereType<Map>().map((item) => CalendarReminder.fromJson(
            Map<String, Object?>.from(item),
          )).where((item) => item.id.isNotEmpty && item.title.isNotEmpty &&
              item.month >= 1 && item.month <= 12 && item.day >= 1 &&
              item.day <= 31).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<bool> save(List<CalendarReminder> entries) async {
    await db.setSetting(settingKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
    return sync(entries);
  }

  Future<bool> sync([List<CalendarReminder>? entries]) async =>
      android.syncCalendarReminders(
        (entries ?? await load()).map((entry) => entry.toJson()).toList(),
      );

  Future<List<CalendarReminder>> today([DateTime? now]) async {
    final local = (now ?? DateTime.now()).toLocal();
    return (await load()).where((entry) => entry.occursOn(local)).toList();
  }
}
