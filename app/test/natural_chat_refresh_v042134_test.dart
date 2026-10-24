import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/natural_chat_migration.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_natural_chat_v042134.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  const marker = 'worldbook_natural_chat_v042134_applied';
  const defaultId = 'default.worldbook.natural_chat';

  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
  });
  tearDown(() async => db.closeForTesting());

  Future<void> launchDefaults() async {
    final sql = await db.database;
    await migrateNaturalChatV042115(sql);
    await migrateNaturalChatV042116(sql);
    await migrateNaturalChatV042134(sql);
  }

  Future<Map<String, Object?>> row(String id) async =>
      (await (await db.database).query('reference_documents',
          where: 'id = ?', whereArgs: [id])).single;

  Future<void> seed(String id, {
    String name = '对话活人感',
    String type = 'behavior',
    String text = '旧的自定义内容',
    int created = 1,
  }) async {
    await (await db.database).insert('reference_documents', {
      'id': id, 'name': name, 'entry_type': type, 'raw_content': text,
      'kind': 'character', 'aliases': '我的别名', 'enabled': 0,
      'activation_mode': 'manual', 'priority': 77,
      'activation_probability': 42, 'scope': 'normal', 'manual_active': 1,
      'exclusive_group': '自定义组', 'builtin': 0,
      'created_at': created, 'updated_at': created,
    });
  }

  test('fresh install ends with one enabled current default', () async {
    await launchDefaults();
    await launchDefaults();
    final rows = await (await db.database).query('reference_documents');
    expect(rows.length, 1);
    expect(rows.single['id'], defaultId);
    expect(rows.single['raw_content'], worldBookNaturalChatV042134);
    expect(rows.single['enabled'], 1);
    expect(rows.single['activation_mode'], 'always');
    expect(await db.getSetting(marker), '1');
  });

  test('approved upgrade replaces an edited legacy body in place only', () async {
    await seed('legacy-import');
    await seed('other-book', name: '另一本世界书', text: '保留原样');
    final before = await row('legacy-import');
    final unrelated = await row('other-book');
    await launchDefaults();
    final after = await row('legacy-import');
    expect(after['raw_content'], worldBookNaturalChatV042134);
    for (final key in before.keys.where((k) =>
        k != 'raw_content' && k != 'updated_at')) {
      expect(after[key], before[key], reason: key);
    }
    expect(await row('other-book'), unrelated);
    expect(await (await db.database).query('reference_documents',
        where: 'id = ?', whereArgs: [defaultId]), isEmpty);
  });

  test('new revision updates a prior installed default even after an edit', () async {
    final sql = await db.database;
    await migrateNaturalChatV042115(sql);
    await sql.update('reference_documents', {'raw_content': '上版之后改过'},
        where: 'id = ?', whereArgs: [defaultId]);
    await migrateNaturalChatV042134(sql);
    expect((await row(defaultId))['raw_content'], worldBookNaturalChatV042134);
  });

  test('later edits, disabled state and deletion survive ordinary launches', () async {
    await launchDefaults();
    final sql = await db.database;
    await sql.update('reference_documents', {
      'raw_content': '本版更新后我的编辑', 'enabled': 0,
    }, where: 'id = ?', whereArgs: [defaultId]);
    await launchDefaults();
    expect((await row(defaultId))['raw_content'], '本版更新后我的编辑');
    expect((await row(defaultId))['enabled'], 0);
    await sql.delete('reference_documents', where: 'id = ?', whereArgs: [defaultId]);
    await launchDefaults();
    expect(await sql.query('reference_documents'), isEmpty);
  });

  test('a new revision reinstalls a previously deleted target once', () async {
    final sql = await db.database;
    await migrateNaturalChatV042115(sql);
    await sql.delete('reference_documents');
    await launchDefaults();
    expect((await row(defaultId))['raw_content'], worldBookNaturalChatV042134);
    expect(await sql.query('reference_documents'), hasLength(1));
  });

  test('renamed installed identity takes precedence over deliberately named copies', () async {
    await seed(defaultId, name: '我改过名字');
    await seed('extra-copy', text: '刻意保留的副本');
    await seed('knowledge-copy', type: 'knowledge', text: '同名知识条目');
    final extra = await row('extra-copy');
    final knowledge = await row('knowledge-copy');
    await launchDefaults();
    expect((await row(defaultId))['raw_content'], worldBookNaturalChatV042134);
    expect((await row(defaultId))['name'], '我改过名字');
    expect(await row('extra-copy'), extra);
    expect(await row('knowledge-copy'), knowledge);
    expect(await (await db.database).query('reference_documents'), hasLength(3));
  });

  test('legacy duplicates select one stable target without modifying copies', () async {
    await seed('earlier', created: 1);
    await seed('later', created: 2, text: '另存副本');
    final later = await row('later');
    await launchDefaults();
    expect((await row('earlier'))['raw_content'], worldBookNaturalChatV042134);
    expect(await row('later'), later);
    expect(await (await db.database).query('reference_documents'), hasLength(2));
  });

  test('failed marker commit rolls back body and can be retried', () async {
    await seed('legacy');
    final sql = await db.database;
    final before = await row('legacy');
    await sql.execute('''
      CREATE TRIGGER reject_natural_refresh BEFORE INSERT ON settings
      WHEN NEW.key = '$marker'
      BEGIN SELECT RAISE(ABORT, 'simulated commit failure'); END
    ''');
    await expectLater(migrateNaturalChatV042134(sql), throwsException);
    expect(await row('legacy'), before);
    expect(await db.getSetting(marker), isNull);
    await sql.execute('DROP TRIGGER reject_natural_refresh');
    await migrateNaturalChatV042134(sql);
    expect((await row('legacy'))['raw_content'], worldBookNaturalChatV042134);
    expect(await db.getSetting(marker), '1');
  });
}
