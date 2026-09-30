import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

/// SQLite can store a value larger than Android's CursorWindow can return.
/// Every result row is bounded; the snapshot still contains the complete value.
class SqliteSettingsReader {
  static const chunkBytes = 64 * 1024;
  static const _projection =
      'SELECT key, length(CAST(value AS BLOB)) AS value_bytes, '
      'substr(CAST(value AS BLOB), 1, ?) AS value_chunk FROM settings';

  static Future<String?> read(DatabaseExecutor executor, String key) async {
    final rows = await executor.rawQuery(
      '$_projection WHERE key = ? LIMIT 1',
      <Object?>[chunkBytes, key],
    );
    if (rows.isEmpty) return null;
    // Keep ordinary reads at one query. Re-read a large value inside a stable
    // transaction so another Flutter engine cannot mix generations of chunks.
    if (executor is Database &&
        (rows.single['value_bytes'] as num).toInt() > chunkBytes) {
      return executor.transaction((txn) => read(txn, key));
    }
    return _value(executor, rows.single);
  }

  static Future<List<Map<String, Object?>>> readAll(
    DatabaseExecutor executor,
  ) async {
    if (executor is Database) {
      return executor.transaction((txn) => readAll(txn));
    }
    final rows = await executor.rawQuery('$_projection ORDER BY key', <Object?>[
      chunkBytes,
    ]);
    final result = <Map<String, Object?>>[];
    for (final row in rows) {
      result.add(<String, Object?>{
        'key': row['key'] as String,
        'value': await _value(executor, row),
      });
    }
    return result;
  }

  static Future<String> _value(
    DatabaseExecutor executor,
    Map<String, Object?> row,
  ) async {
    final key = row['key'] as String;
    final length = (row['value_bytes'] as num).toInt();
    // Some SQLite builds return NULL for substr() of a zero-length BLOB.
    if (length == 0) return '';
    final first = row['value_chunk'];
    if (length < 0 ||
        first is! List<int> ||
        first.length != min(length, chunkBytes)) {
      throw StateError('设置读取长度不一致，已停止读取以免丢失内容。');
    }
    if (length <= chunkBytes) return utf8.decode(first);
    final bytes = BytesBuilder(copy: false)..add(first);
    for (var offset = first.length; offset < length;) {
      final count = min(chunkBytes, length - offset);
      final parts = await executor.rawQuery(
        'SELECT substr(CAST(value AS BLOB), ?, ?) AS value_chunk '
        'FROM settings WHERE key = ?',
        <Object?>[offset + 1, count, key],
      );
      final part = parts.length == 1 ? parts.single['value_chunk'] : null;
      if (part is! List<int> || part.length != count) {
        throw StateError('设置分段读取不完整，已停止读取以免丢失内容。');
      }
      bytes.add(part);
      offset += part.length;
    }
    // Decode once after joining bytes: a boundary can split Chinese or emoji,
    // and byte slicing also preserves embedded NULs unlike length(TEXT).
    return utf8.decode(bytes.takeBytes());
  }
}
