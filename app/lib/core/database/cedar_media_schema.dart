import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Persistent owners for optional Outcome pictures. Rows contain blob ids,
/// never image bytes or remote URLs. The activity is the source of truth.
abstract final class CedarMediaSchema {
  static const table = 'cedar_event_media';
  static const stateKey = 'cedar_toy_activity_state_v2';
  static const columns = {'id','game_id','session_id','event_id','blob_id','ordinal','mime_type','created_at'};
  static Future<void> create(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS cedar_event_media(
      id TEXT PRIMARY KEY,game_id TEXT NOT NULL,session_id TEXT NOT NULL,event_id TEXT NOT NULL,
      blob_id TEXT NOT NULL,ordinal INTEGER NOT NULL,mime_type TEXT NOT NULL,created_at INTEGER NOT NULL)''');
    await db.execute('CREATE INDEX IF NOT EXISTS cedar_media_blob ON cedar_event_media(blob_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS cedar_media_event ON cedar_event_media(session_id,event_id,ordinal)');
  }
  static Map<String,String> events(String raw) {
    final result = <String,String>{};
    try {
      final state = jsonDecode(raw);
      if (state is Map && state['sessions'] is List) {
        for (final s in (state['sessions'] as List).whereType<Map>()) {
          if (s['id'] is! String || s['game_id'] is! String || s['events'] is! List) continue;
          for (final e in (s['events'] as List).whereType<Map>()) {
            if (e['id'] is String) result['${s['id']}:${e['id']}'] = s['game_id'] as String;
          }
        }
      }
    } catch (_) {}
    return result;
  }
  static Future<void> prune(DatabaseExecutor db,String state) async {
    final live = events(state);
    for (final row in await db.query(table,columns:['id','session_id','event_id','game_id'])) {
      if (live['${row['session_id']}:${row['event_id']}'] != row['game_id']) {
        await db.delete(table,where:'id=?',whereArgs:[row['id']]);
      }
    }
  }
  static void validate(Map tables,{required int version}) {
    if (version < 67) { tables[table] = <Object?>[]; return; }
    final rows = tables[table];
    if (rows is! List || rows.length > 16000) throw const FormatException('游戏媒体归属表缺失或过大');
    final settings = tables['settings'];String state = '';
    if (settings is List) for (final row in settings.whereType<Map>()) {
      if (row['key'] == stateKey && row['value'] is String) state = row['value'] as String;
    }
    final live = events(state);
    final blobs = {for(final b in (tables['media_blobs'] as List? ?? []).whereType<Map>()) b['id']:b};
    final ids = <String>{};
    for (final row in rows) {
      if (row is! Map || row.length != columns.length || !row.keys.toSet().containsAll(columns) ||
          row['id'] is! String || !ids.add(row['id'] as String) ||
          live['${row['session_id']}:${row['event_id']}'] != row['game_id'] ||
          !blobs.containsKey(row['blob_id']) || row['ordinal'] is! int ||
          (row['ordinal'] as int) < 0 || (row['ordinal'] as int) >= 4 ||
          row['mime_type'] is! String || !(row['mime_type'] as String).startsWith('image/') ||
          row['created_at'] is! int || row.values.any((v) => v is! String && v is! int) ||
          row.values.whereType<String>().any((v) => v.length > 2000)) {
        throw const FormatException('游戏图片缺少有效活动或共享媒体来源');
      }
    }
  }
}
