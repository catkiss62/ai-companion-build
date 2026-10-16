import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../reference/world_book_spoken_dialogue_v042108.dart';

const spokenDialogueDefaultMarkerV042108 =
    'worldbook_spoken_dialogue_default_v042108_applied';

/// Replace only known untouched defaults. An imported user row can own the
/// module, so neither a built-in ID nor its existence implies permission to
/// overwrite custom content or activation controls.
Future<void> migrateSpokenDialogueDefaultV042108(Database db) async {
  await db.transaction((txn) async {
    final marker = await txn.query('settings', columns: ['value'],
      where: 'key = ?', whereArgs: [spokenDialogueDefaultMarkerV042108]);
    if (marker.isNotEmpty && marker.first['value'] == '1') return;
    const untouchedHashes = {
      // Original English, reviewed Chinese, then v0.41.57 exact default.
      '0af88f096e3b50d4d1c10574982400c18d17465d02a1202259a42fcc9a4d8697',
      '399dbcade44c15ce4af3f215df27ed193de04991644371dbbd79f2caabed8f11',
      '13189a1fcb24f10eb071f455356ffd902d3eafa1abb8466a28580b768bf9a393',
    };
    final rows = await txn.query('reference_documents',
      columns: ['id', 'raw_content'],
      where: 'entry_type = ? AND name = ?',
      whereArgs: ['behavior', '角色表达自然化']);
    for (final row in rows) {
      final raw = row['raw_content'] as String? ?? '';
      if (!untouchedHashes.contains(sha256.convert(utf8.encode(raw)).toString())) {
        continue;
      }
      await txn.update('reference_documents', {
        'raw_content': worldBookSpokenDialogueV042108,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, where: 'id = ? AND raw_content = ?', whereArgs: [row['id'], raw]);
    }
    await txn.insert('settings', {
      'key': spokenDialogueDefaultMarkerV042108, 'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
}
