import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import 'daily_wake_schedule.dart';

/// Settings are already portable. A per-day key also survives a same-day
/// restart or clock rollback. Foreground/background readers serialize on the
/// SQLite transaction; they never publish different draws for the same day.
abstract final class DailyWakeStore {
  static String keyFor(DateTime now) =>
      'daily_wake_schedule_v1_'
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';

  static Future<DailyWakeSchedule> read(
    DatabaseExecutor db,
    DateTime now, {
    Random? random,
  }) async {
    if (db is Database) {
      return db.transaction((txn) => read(txn, now, random: random));
    }
    final key = keyFor(now);
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    try {
      final value = jsonDecode(
        rows.isEmpty ? '' : rows.first['value'] as String,
      );
      final minute = value['minute'];
      final sampled = value['sampledAt'];
      if (minute is int && minute >= 480 && minute <= 540 && sampled is int) {
        return DailyWakeSchedule(
          wakeAt: DailyWakeSchedule.atMinute(now, minute),
          sampledAt: DateTime.fromMillisecondsSinceEpoch(
            sampled,
            isUtc: now.isUtc,
          ),
        );
      }
    } catch (_) {
      /* Missing/invalid old record: create today's record below. */
    }
    final minute = 480 + (random ?? Random()).nextInt(61);
    await db.insert('settings', {
      'key': key,
      'value': jsonEncode({
        'minute': minute,
        'sampledAt': now.millisecondsSinceEpoch,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return DailyWakeSchedule(
      wakeAt: DailyWakeSchedule.atMinute(now, minute),
      sampledAt: now,
    );
  }
}
