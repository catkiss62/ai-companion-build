import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'mood_state.dart';

/// Storage is in settings, already covered by portable backup/restore.
/// All mutations use the caller's winning SQLite transaction.
class MoodStore {
  static const eventsKey = 'persistent_mood_events_v1';
  static const enabledKey = 'persistent_mood_enabled_v1';
  static const pendingKey = 'persistent_mood_pending_v1';

  static Future<String?> value(DatabaseExecutor db, String key) async {
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  static Future<bool> enabled(DatabaseExecutor db) async =>
      await value(db, enabledKey) != '0';
  static Future<List<MoodEvent>> load(DatabaseExecutor db) async =>
      MoodEvent.decodeList(await value(db, eventsKey));
  static Future<void> write(DatabaseExecutor db, List<MoodEvent> events) async {
    await db.insert('settings', {
      'key': eventsKey,
      'value': jsonEncode(events.map((e) => e.toJson()).toList()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<MoodEvent?> pending(DatabaseExecutor db, String userId) async {
    try {
      final event = MoodEvent.decode(
        jsonDecode(await value(db, pendingKey) ?? 'null'),
      );
      return event?.id == 'user:$userId' ? event : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> append(
    DatabaseExecutor db,
    MoodEvent event,
    DateTime now,
  ) async {
    if (!await enabled(db) || event.kind == 'none') return;
    final events = await load(db);
    if (events.any((e) => e.id == event.id)) return;
    // External sources can enrich a day without farming each frame/tool step.
    if (event.source != 'conversation' &&
        events.any(
          (e) =>
              e.source == event.source &&
              event.at.difference(e.at).abs() < const Duration(minutes: 30),
        ))
      return;
    events.removeWhere((e) => now.difference(e.at) > const Duration(days: 2));
    events.add(event);
    events.sort((a, b) => b.at.compareTo(a.at));
    await write(db, events.take(96).toList());
  }

  static Future<void> commitTurn(
    DatabaseExecutor db, {
    required String userId,
    required String replyId,
    required DateTime now,
    required bool roleplay,
  }) async {
    if (roleplay || !await enabled(db)) return;
    final event = await pending(db, userId);
    if (event == null) return;
    await append(
      db,
      MoodEvent(
        id: event.id,
        kind: event.kind,
        at: event.at,
        level: event.level,
        source: event.source,
        replyId: replyId,
        targetId: event.targetId,
      ),
      now,
    );
  }

  static Future<void> removeTurn(
    DatabaseExecutor db, {
    String userId = '',
    String replyId = '',
  }) async {
    final events = await load(db);
    final kept = events
        .where(
          (e) =>
              !(userId.isNotEmpty && e.id == 'user:$userId') &&
              !(replyId.isNotEmpty && e.replyId == replyId),
        )
        .toList();
    if (kept.length != events.length) await write(db, kept);
  }
}
