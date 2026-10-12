import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/memory/memory_browse_repository.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late MemoryBrowseRepository browser;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    browser = MemoryBrowseRepository(db);
  });
  tearDown(() => db.closeForTesting());

  Future<void> insert(String id, {Map<String, Object?> values = const {}}) async {
    final database = await db.database;
    await database.insert('memory_items', {
      'id': id,
      'kind': 'shared_experience',
      'content': '原文 $id',
      'created_at': 1000,
      'updated_at': 2000,
      'importance': 0.5,
      ...values,
    });
  }

  Future<List<MemoryItem>> readAll({
    String? kind,
    String status = 'active',
    String query = '',
    int limit = 37,
  }) async {
    final items = <MemoryItem>[];
    MemoryBrowseCursor? cursor;
    do {
      final page = await browser.page(
        kind: kind,
        status: status,
        query: query,
        after: cursor,
        limit: limit,
      );
      expect(page.items.length, lessThanOrEqualTo(limit));
      items.addAll(page.items);
      cursor = page.nextCursor;
      expect(items.length, lessThanOrEqualTo(1000));
    } while (cursor != null);
    return items;
  }

  test('all rows beyond 300 are reachable with equal ranking ties', () async {
    final database = await db.database;
    final batch = database.batch();
    for (var index = 638; index >= 0; index--) {
      batch.insert('memory_items', {
        'id': 'm${index.toString().padLeft(4, '0')}',
        'kind': index.isEven ? 'shared_experience' : 'user_profile',
        'content': '原文 $index',
        'created_at': 1000,
        'updated_at': 2000 + index % 3,
        'importance': (index % 2) / 2,
      });
    }
    await batch.commit(noResult: true);
    await insert('archived', values: {'status': 'archived'});
    await insert('superseded', values: {'status': 'superseded'});
    final before = await database.query('memory_items', orderBy: 'id');
    for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
      await database.execute(
        'CREATE TEMP TRIGGER page_guard_$operation '
        'BEFORE $operation ON memory_items BEGIN '
        "SELECT RAISE(ABORT, 'browsing attempted a write'); END",
      );
    }
    final expected = await database.query(
      'memory_items',
      columns: ['id'],
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'importance DESC, updated_at DESC, id ASC',
    );
    final all = await readAll();
    expect(all, hasLength(639));
    expect(all.map((item) => item.id).toSet(), hasLength(639));
    expect(all.map((item) => item.id), expected.map((row) => row['id']));
    final profiles = await readAll(kind: 'user_profile');
    expect(profiles, hasLength(319));
    expect(profiles.every((item) => item.kind == 'user_profile'), isTrue);
    expect((await readAll(status: 'archived')).single.id, 'archived');
    expect((await readAll(status: 'superseded')).single.id, 'superseded');
    expect(await database.query('memory_items', orderBy: 'id'), before);
  });

  test('paged search preserves literal wildcard escaping and all three fields', () async {
    const query = r"%_\'";
    await insert('content', values: {'content': '前$query 后'});
    await insert('tags', values: {'tags': '标签|$query'});
    await insert('subject', values: {'subject_key': 'key.$query'});
    await insert('unrelated', values: {'content': '普通文本'});
    await insert('archived', values: {'content': query, 'status': 'archived'});
    expect((await readAll(query: query, limit: 1)).map((item) => item.id), [
      'content', 'subject', 'tags',
    ]);
    expect((await browser.page(query: '没有匹配')).nextCursor, isNull);
    expect((await browser.page(query: '没有匹配')).items, isEmpty);
  });

  test('deleting cursor row or inserting ahead does not shift later pages', () async {
    for (final id in ['a', 'b', 'c', 'd']) {
      await insert(id);
    }
    final first = await browser.page(limit: 2);
    expect(first.items.map((item) => item.id), ['a', 'b']);
    expect(() => first.items.clear(), throwsUnsupportedError);
    final database = await db.database;
    await database.delete('memory_items', where: 'id = ?', whereArgs: ['b']);
    await insert('aa');
    final second = await browser.page(after: first.nextCursor, limit: 2);
    expect(second.items.map((item) => item.id), ['c', 'd']);
    expect(second.nextCursor, isNull);
  });
}
