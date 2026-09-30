import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/sqlite_settings_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A desktop SQLite result has no Android limit. Impose it on returned rows,
/// while still executing every production SQL query against real SQLite.
class _WindowBoundExecutor implements DatabaseExecutor {
  _WindowBoundExecutor(this.delegate);
  final DatabaseExecutor delegate;
  var queries = 0;
  var largestRowBytes = 0;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    queries++;
    final rows = await delegate.rawQuery(sql, arguments);
    for (final row in rows) {
      var bytes = 0;
      for (final value in row.values) {
        bytes += value is String
            ? utf8.encode(value).length
            : value is List<int>
            ? value.length
            : 8;
      }
      if (bytes > largestRowBytes) largestRowBytes = bytes;
      if (bytes > 128 * 1024) {
        throw StateError('Row too big to fit into CursorWindow');
      }
    }
    return rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
  });
  tearDown(() async {
    await db.closeForTesting();
  });

  final large = List.filled(350000, '汉🙂\u0000尾').join() + '🧭结束';

  test('small, empty and absent values keep one bounded query', () async {
    await db.setSetting("key' ?", '中文🙂');
    await db.setSetting('empty', '');
    final limited = _WindowBoundExecutor(await db.database);
    expect(await SqliteSettingsReader.read(limited, "key' ?"), '中文🙂');
    expect(await SqliteSettingsReader.read(limited, 'empty'), '');
    expect(await SqliteSettingsReader.read(limited, 'absent'), isNull);
    expect(limited.queries, 3);
  });

  test(
    'large settings survive a CursorWindow bound without truncation',
    () async {
      expect(utf8.encode(large).length, greaterThan(3 * 1024 * 1024));
      await db.setSetting('large', large);
      await db.setSetting('small', '保留');
      await (await db.database).transaction((txn) async {
        final legacy = _WindowBoundExecutor(txn);
        await expectLater(
          legacy.rawQuery('SELECT * FROM settings'),
          throwsStateError,
        );
        final limited = _WindowBoundExecutor(txn);
        final rows = await SqliteSettingsReader.readAll(limited);
        final values = {for (final row in rows) row['key']: row['value']};
        expect(values['large'], large);
        expect(values['small'], '保留');
        expect(limited.largestRowBytes, lessThan(128 * 1024));
        expect(limited.queries, greaterThan(40));
      });
      expect(await db.getSetting('large'), large);
    },
  );

  test('export JSON and restore keep complete multi MiB settings', () async {
    await db.setSetting('test_large', large);
    await db.setSetting(
      'remembered_user_facts_v1',
      '{"items":[{"fact":"中午一点吃饭"}]}',
    );
    final exported = await db.exportAll();
    final tables = exported['tables'] as Map;
    final rows = tables['settings'] as List;
    expect(
      rows.every(
        (row) => (row as Map).keys.toSet().difference({'key', 'value'}).isEmpty,
      ),
      isTrue,
    );
    final directory = await Directory.systemTemp.createTemp(
      'settings-restore-',
    );
    final restored = await AppDatabase.createForTesting(
      databaseFactoryFfi,
      path: '${directory.path}/restored.db',
    );
    try {
      await restored.importAll(
        jsonDecode(jsonEncode(exported)) as Map<String, dynamic>,
      );
      expect(await restored.getSetting('test_large'), large);
      expect(
        await restored.getSetting('remembered_user_facts_v1'),
        await db.getSetting('remembered_user_facts_v1'),
      );
    } finally {
      await restored.closeForTesting();
      await directory.delete(recursive: true);
    }
  });

  test('short chunk is an error, never a successful partial value', () async {
    await db.setSetting('large', large);
    final executor = _ShortChunkExecutor(await db.database);
    await expectLater(
      SqliteSettingsReader.read(executor, 'large'),
      throwsStateError,
    );
  });
}

class _ShortChunkExecutor extends _WindowBoundExecutor {
  _ShortChunkExecutor(super.delegate);
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final rows = await super.rawQuery(sql, arguments);
    if (sql.startsWith('SELECT substr(')) {
      return [
        {
          'value_chunk': <int>[0],
        },
      ];
    }
    return rows;
  }
}
