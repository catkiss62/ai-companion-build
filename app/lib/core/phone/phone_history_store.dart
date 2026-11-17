import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Full history lives in individually bounded settings rows so existing database
/// backups carry it without a second archive file or a new restore protocol.
/// The old JSON lists remain recent projections for existing producers/readers.
class PhoneHistoryStore {
  static const prefix = 'simulated_phone_history_v1:';
  static const migrationKey = 'simulated_phone_history_migrated_v1';
  static const legacy = {
    'diary': 'simulated_phone_diary_json',
    'note': 'simulated_phone_notes_json',
  };

  static String ownerKey(String kind, String id) =>
      'simulated_phone_history_owner_v1:$kind:${base64Url.encode(utf8.encode(id))}';

  static Map<String, String> values(Map<String, Object?> entry) {
    final kind = entry['kind'];
    final id = entry['id'];
    if (!legacy.containsKey(kind) || id is! String || id.isEmpty) {
      throw const FormatException('Invalid phone history identity');
    }
    final at = (entry['created_at'] as num?)?.toInt() ?? 0;
    var day = entry['local_day'] as String? ?? '';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      final date = DateTime.fromMillisecondsSinceEpoch(at).toLocal();
      day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    final key = '$prefix$kind:$day:${at.toString().padLeft(16, '0')}:${base64Url.encode(utf8.encode(id))}';
    return {key: jsonEncode({...entry, 'local_day': day}), ownerKey(kind as String, id): key};
  }

  /// Transactional, repeat-safe migration. Malformed legacy data aborts without
  /// marking completion; never silently erase a list that failed decoding.
  static Future<void> migrate(Database db) => db.transaction((txn) async {
    final done = await txn.query('settings', columns: ['value'],
        where: 'key = ?', whereArgs: [migrationKey]);
    if (done.isNotEmpty && done.single['value'] == '1') return;
    for (final source in legacy.entries) {
      final rows = await txn.query('settings', columns: ['value'],
          where: 'key = ?', whereArgs: [source.value]);
      final raw = rows.isEmpty ? '' : rows.single['value'] as String? ?? '';
      if (raw.isEmpty) continue;
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Invalid phone history list');
      for (final item in decoded) {
        if (item is! Map) throw const FormatException('Invalid phone history entry');
        final entry = Map<String, Object?>.from(item);
        // Legacy entries must keep their original source kind and identity.
        if (entry['kind'] == null || entry['kind'] == '') entry['kind'] = source.key;
        if (entry['kind'] != source.key) throw const FormatException('Phone history kind mismatch');
        for (final row in values(entry).entries) {
          await txn.insert('settings', {'key': row.key, 'value': row.value},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    }
    await txn.insert('settings', {'key': migrationKey, 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace);
  });

  static Future<bool> contains(DatabaseExecutor db, String kind, String id) async =>
      (await db.query('settings', columns: ['key'], where: 'key = ?',
          whereArgs: [ownerKey(kind, id)], limit: 1)).isNotEmpty;

  static Future<List<Map<String, Object?>>> page(DatabaseExecutor db, {
    required String day, int offset = 0, int limit = 50,
  }) async {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      throw const FormatException('Invalid phone history date');
    }
    final diary = '${prefix}diary:$day:';
    final note = '${prefix}note:$day:';
    final rows = await db.query('settings', columns: ['value'],
        where: '(key >= ? AND key < ?) OR (key >= ? AND key < ?)',
        whereArgs: [diary, '$diary~', note, '$note~'],
        orderBy: 'key ASC', limit: limit.clamp(1, 100), offset: offset < 0 ? 0 : offset);
    return rows.map((row) => Map<String, Object?>.from(jsonDecode(row['value'] as String) as Map)).toList();
  }
}
