import 'package:ai_companion_localfirst/core/database/spoken_dialogue_default_migration.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_content_v04156_user.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_presets.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_spoken_dialogue_v042108.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('''CREATE TABLE reference_documents (
      id TEXT PRIMARY KEY, name TEXT, entry_type TEXT, raw_content TEXT,
      enabled INTEGER, activation_mode TEXT, priority INTEGER,
      activation_probability INTEGER, scope TEXT, manual_active INTEGER,
      builtin INTEGER, created_at INTEGER, updated_at INTEGER)''');
  });
  tearDown(() => db.close());

  Future<void> insert(String id, String content, {String name = '角色表达自然化',
      String type = 'behavior'}) => db.insert('reference_documents', {
    'id': id, 'name': name, 'entry_type': type, 'raw_content': content,
    'enabled': 0, 'activation_mode': 'manual', 'priority': 432,
    'activation_probability': 37, 'scope': 'chat', 'manual_active': 0,
    'builtin': 0, 'created_at': 10, 'updated_at': 20,
  }).then((_) {});
  Future<Map<String, Object?>> row(String id) async =>
      (await db.query('reference_documents', where: 'id = ?', whereArgs: [id])).single;

  test('fresh-install preset uses the approved spoken body and existing identity', () {
    final preset = worldBookSystemPresets.singleWhere(
      (p) => p.id == 'builtin.worldbook.natural_dialogue');
    expect(preset.name, '角色表达自然化');
    expect(preset.content, worldBookSpokenDialogueV042108);
    expect(preset.content, startsWith('# 对白的口语表达'));
    expect(preset.priority, 1000);
    expect(preset.activationMode, 'always');
    expect(preset.scope, 'all');
  });

  test('untouched old default migrates in place without changing user controls', () async {
    await insert('imported-user-row', worldBookNaturalDialogueV04157);
    final before = await row('imported-user-row');
    await migrateSpokenDialogueDefaultV042108(db);
    final after = await row('imported-user-row');
    expect(after['raw_content'], worldBookSpokenDialogueV042108);
    expect(after['updated_at'], greaterThan(20));
    for (final key in before.keys.where((k) => k != 'raw_content' && k != 'updated_at')) {
      expect(after[key], before[key], reason: key);
    }
    expect(await db.query('reference_documents'), hasLength(1));
  });

  test('custom, already applied, renamed and unrelated bodies remain byte-exact', () async {
    await insert('builtin.worldbook.natural_dialogue', '$worldBookNaturalDialogueV04157\n我的编辑');
    await insert('already-applied', '$worldBookSpokenDialogueV042108\n');
    await insert('renamed', worldBookNaturalDialogueV04157, name: '自己的规则');
    await insert('other-type', worldBookNaturalDialogueV04157, type: 'roleplay');
    final before = await db.query('reference_documents', orderBy: 'id');
    await migrateSpokenDialogueDefaultV042108(db);
    expect(await db.query('reference_documents', orderBy: 'id'), before);
  });

  test('migration marker preserves later user edits and never recreates a row', () async {
    await insert('old-default', worldBookNaturalDialogueV04157);
    await migrateSpokenDialogueDefaultV042108(db);
    // Even choosing the old wording later is a user edit after migration.
    await db.update('reference_documents', {'raw_content': worldBookNaturalDialogueV04157,
      'updated_at': 123}, where: 'id = ?', whereArgs: ['old-default']);
    await migrateSpokenDialogueDefaultV042108(db);
    expect((await row('old-default'))['raw_content'], worldBookNaturalDialogueV04157);
    expect((await row('old-default'))['updated_at'], 123);
    await db.delete('reference_documents');
    await migrateSpokenDialogueDefaultV042108(db);
    expect(await db.query('reference_documents'), isEmpty);
  });
}
