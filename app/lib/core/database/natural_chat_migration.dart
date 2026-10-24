import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../reference/world_book_natural_chat_v042115.dart';
import '../reference/world_book_natural_chat_v042116.dart';
import '../reference/world_book_natural_chat_v042134.dart';

/// Update only the exact draft approved for revision. Preserve user edits,
/// activation, identity and other world books. Install the approved default once
/// when the old draft has been removed or on a fresh installation.
Future<void> migrateNaturalChatV042115(Database db) async {
  await db.transaction((txn) async {
    const marker = 'worldbook_natural_chat_v042115_applied';
    final done = await txn.query('settings', where: 'key = ?', whereArgs: [marker]);
    if (done.isNotEmpty && done.first['value'] == '1') return;
    final rows = await txn.query('reference_documents', columns: ['id', 'raw_content'],
      where: 'name = ? AND entry_type = ?', whereArgs: ['对话活人感', 'behavior']);
    if (rows.isEmpty) {
      final now=DateTime.now().millisecondsSinceEpoch;
      await txn.insert('reference_documents', {
        'id':'default.worldbook.natural_chat', 'name':'对话活人感',
        'kind':'character', 'aliases':'活人感', 'raw_content':worldBookNaturalChatV042115,
        'enabled':1,'created_at':now,'updated_at':now,'entry_type':'behavior',
        'activation_mode':'always','priority':900,'activation_probability':100,
        'scope':'all','manual_active':0,'exclusive_group':'','builtin':0,
      },conflictAlgorithm:ConflictAlgorithm.ignore);
    }
    for (final row in rows) {
      final raw = row['raw_content'] as String? ?? '';
      if (sha256.convert(utf8.encode(raw)).toString() != approvedNaturalChatDraftHash) continue;
      await txn.update('reference_documents', {
        'raw_content': worldBookNaturalChatV042115,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, where: 'id = ? AND raw_content = ?', whereArgs: [row['id'], raw]);
    }
    await txn.insert('settings', {'key': marker, 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace);
  });
}

const approvedNaturalChatDraftHash = 'cb0f3ecfb5441ec235cde057439ca6571e6ef42d5bfc3a39e791ffe479daa0fb';

/// Each explicitly approved revision replaces the target body once, including
/// an edited previous body. Later user edits, deletion and controls survive
/// ordinary launches. Keep the historical V115 migration contract unchanged.
/// For a future approved revision, change both its content and marker.
Future<void> migrateNaturalChatV042116(Database db) async {
  await db.transaction((txn) async {
    const marker = 'worldbook_natural_chat_v042116_applied';
    const defaultId = 'default.worldbook.natural_chat';
    final done = await txn.query('settings', where: 'key = ?', whereArgs: [marker]);
    if (done.isNotEmpty && done.first['value'] == '1') return;

    // Prefer the installed default even if renamed. Otherwise adopt one legacy
    // named entry in place; do not duplicate it or overwrite deliberate copies.
    final rows = await txn.query(
      'reference_documents',
      columns: ['id'],
      where: 'id = ? OR (name = ? AND entry_type = ?)',
      whereArgs: [defaultId, '对话活人感', 'behavior'],
      orderBy: "CASE WHEN id = '$defaultId' THEN 0 ELSE 1 END, created_at, id",
      limit: 1,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    if (rows.isEmpty) {
      await txn.insert('reference_documents', {
        'id': defaultId,
        'name': '对话活人感',
        'kind': 'character',
        'aliases': '活人感',
        'raw_content': worldBookNaturalChatV042116,
        'enabled': 1,
        'created_at': now,
        'updated_at': now,
        'entry_type': 'behavior',
        'activation_mode': 'always',
        'priority': 900,
        'activation_probability': 100,
        'scope': 'all',
        'manual_active': 0,
        'exclusive_group': '',
        'builtin': 0,
      });
    } else {
      await txn.update('reference_documents', {
        'raw_content': worldBookNaturalChatV042116,
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [rows.single['id']]);
    }
    await txn.insert('settings', {'key': marker, 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace);
  });
}

// One approved default refresh; preserve subsequent user changes.
Future<void> migrateNaturalChatV042134(Database db) async {
  await db.transaction((txn) async {
    const marker = 'worldbook_natural_chat_v042134_applied';
    const defaultId = 'default.worldbook.natural_chat';
    final done = await txn.query('settings', where: 'key = ?', whereArgs: [marker]);
    if (done.isNotEmpty && done.first['value'] == '1') return;

    // Prefer the installed default even if renamed. Otherwise adopt one legacy
    // named entry in place; do not duplicate it or overwrite deliberate copies.
    final rows = await txn.query(
      'reference_documents',
      columns: ['id'],
      where: 'id = ? OR (name = ? AND entry_type = ?)',
      whereArgs: [defaultId, '对话活人感', 'behavior'],
      orderBy: "CASE WHEN id = '$defaultId' THEN 0 ELSE 1 END, created_at, id",
      limit: 1,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    if (rows.isEmpty) {
      await txn.insert('reference_documents', {
        'id': defaultId,
        'name': '对话活人感',
        'kind': 'character',
        'aliases': '活人感',
        'raw_content': worldBookNaturalChatV042134,
        'enabled': 1,
        'created_at': now,
        'updated_at': now,
        'entry_type': 'behavior',
        'activation_mode': 'always',
        'priority': 900,
        'activation_probability': 100,
        'scope': 'all',
        'manual_active': 0,
        'exclusive_group': '',
        'builtin': 0,
      });
    } else {
      await txn.update('reference_documents', {
        'raw_content': worldBookNaturalChatV042134,
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [rows.single['id']]);
    }
    await txn.insert('settings', {'key': marker, 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace);
  });
}
