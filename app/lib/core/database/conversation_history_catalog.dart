import 'package:sqflite/sqflite.dart';

/// Rebuildable local directory, not a second transcript or learned memory.
/// Canonical text and semantic source stamps remain in messages/source stores.
abstract final class ConversationHistoryCatalog {
  static const table = 'conversation_history_catalog';
  static const versionKey = 'conversation_history_catalog_version';
  static const readyKey = 'conversation_history_catalog_ready_v1';
  static const previewLength = 96;
  static const columns = ['message_id', 'created_at', 'role', 'source_revision',
    'source_ingest_seq', 'preview'];

  static Future<void> ensureSchema(DatabaseExecutor db) async {
    if ((await db.rawQuery('PRAGMA table_info(messages)')).isEmpty) return;
    final existed = (await db.rawQuery('PRAGMA table_info(conversation_history_catalog)')).isNotEmpty;
    await db.execute('''CREATE TABLE IF NOT EXISTS conversation_history_catalog (
      message_id TEXT PRIMARY KEY REFERENCES messages(id) ON DELETE CASCADE,
      created_at INTEGER NOT NULL, role TEXT NOT NULL,
      source_revision INTEGER NOT NULL, source_ingest_seq INTEGER NOT NULL,
      preview TEXT NOT NULL)''');
    if (!existed) {
      await db.delete('settings',where:'key = ?',whereArgs:[readyKey]);
    }
    await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_catalog_time '
      'ON conversation_history_catalog(created_at, message_id)');
    // All writers, including restore, direct SQL and source revisions, share
    // these triggers. Opening the database never scans the whole transcript.
    for (final operation in ['INSERT', 'UPDATE']) {
      final suffix = operation.toLowerCase();
      await db.execute('''CREATE TRIGGER IF NOT EXISTS chat_catalog_$suffix
        AFTER $operation ON messages BEGIN
          DELETE FROM conversation_history_catalog WHERE message_id = NEW.id;
          INSERT INTO conversation_history_catalog
            (message_id,created_at,role,source_revision,source_ingest_seq,preview)
          SELECT NEW.id,NEW.created_at,NEW.role,NEW.source_revision,
            NEW.source_ingest_seq,substr(NEW.content,1,96)
          WHERE NEW.role IN ('user','assistant');
        END''');
    }
    await db.execute('''CREATE TRIGGER IF NOT EXISTS chat_catalog_delete
      AFTER DELETE ON messages BEGIN
        DELETE FROM conversation_history_catalog WHERE message_id = OLD.id;
      END''');
  }

  static Future<void> ensureReady(DatabaseExecutor db) async {
    final rows = await db.query('settings', columns: ['value'],
      where: 'key = ?', whereArgs: [readyKey], limit: 1);
    if (rows.isNotEmpty && rows.single['value'] == '1') return;
    await rebuild(db);
  }

  /// Runs inside the caller's transaction. One local metadata pass on first
  /// use/export or restore; no model calls, startup scan or copied full text.
  static Future<void> rebuild(DatabaseExecutor db) async {
    await db.delete(table);
    await db.execute('''INSERT INTO conversation_history_catalog
      (message_id,created_at,role,source_revision,source_ingest_seq,preview)
      SELECT id,created_at,role,source_revision,source_ingest_seq,substr(content,1,96)
      FROM messages WHERE role IN ('user','assistant')''');
    await db.insert('settings', {'key': readyKey, 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static String preview(String text) =>
      String.fromCharCodes(text.runes.take(previewLength));

  /// New exports promise this directory; old backups may omit it and rebuild.
  /// Reject a broken declared directory before modifying any local state.
  static void validateArchive(Map<String, dynamic> backup,
      Map<String, dynamic> tables) {
    final declared = backup[versionKey];
    if (declared == null) return;
    if (declared != 1 || tables[table] is! List || tables['messages'] is! List) {
      throw const FormatException('聊天目录版本无效或缺少完整目录');
    }
    final messages = <String, Map>{};
    for (final raw in tables['messages'] as List) {
      if (raw is Map && const {'user', 'assistant'}.contains(raw['role'])) {
        messages[raw['id'] as String] = raw;
      }
    }
    final seen = <String>{};
    for (final raw in tables[table] as List) {
      if (raw is! Map || raw['message_id'] is! String ||
          !seen.add(raw['message_id'] as String)) {
        throw const FormatException('聊天目录条目无效或重复');
      }
      final source = messages[raw['message_id']];
      if (source == null || raw.keys.any((key) => !columns.contains(key)) ||
          raw['created_at'] != source['created_at'] ||
          raw['role'] != source['role'] ||
          raw['source_revision'] != (source['source_revision'] ?? 0) ||
          raw['source_ingest_seq'] != (source['source_ingest_seq'] ?? 0) ||
          raw['preview'] != preview(source['content'] as String? ?? '')) {
        throw const FormatException('聊天目录与原文不一致');
      }
    }
    if (seen.length != messages.length) {
      throw const FormatException('聊天目录未覆盖完整原文');
    }
  }
}
