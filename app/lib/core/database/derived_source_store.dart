import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Links derived records to the exact expression used to produce them.
/// User facts and external effects remain independent of a rewritten reply.
abstract final class DerivedSourceStore {
  static Future<void> ensureSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS derived_source_links (
      owner_kind TEXT NOT NULL, owner_id TEXT NOT NULL, source_id TEXT NOT NULL,
      source_revision INTEGER NOT NULL, dependency_role TEXT NOT NULL,
      source_hash TEXT NOT NULL DEFAULT '', valid INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY(owner_kind,owner_id,source_id,source_revision,dependency_role))''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_derived_source ON derived_source_links(source_id,source_revision,valid)');
  }

  static Future<void> link(DatabaseExecutor txn, {required String kind,
    required String ownerId, required String sourceId, required int revision,
    required String role, String hash = ''}) async {
    await txn.insert('derived_source_links', {'owner_kind': kind, 'owner_id': ownerId,
      'source_id': sourceId, 'source_revision': revision, 'dependency_role': role,
      'source_hash': hash}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<Set<String>> revoke(DatabaseExecutor txn, String sourceId, int revision, {bool keepUserBasis = true}) async {
    final tables = (await txn.rawQuery("SELECT name FROM sqlite_master WHERE type='table'")).map((r) => r['name']).toSet();
    if (!tables.contains('derived_source_links')) return const <String>{};
    final links = await txn.query('derived_source_links',
      where: 'source_id = ? AND source_revision = ? AND valid = 1', whereArgs: [sourceId, revision]);
    final memories = <String>{}, candidates = <String>{};
    for (final link in links) {
      if (keepUserBasis && link['dependency_role'] == 'user_basis' || link['dependency_role'] == 'external_outcome') continue;
      final kind = link['owner_kind'], id = link['owner_id'];
      if (kind == 'memory_evidence') {
        final rows = await txn.query('memory_evidence', columns: ['memory_id'], where: 'id = ?', whereArgs: [id]);
        memories.addAll(rows.map((r) => r['memory_id'] as String));
        await txn.update('memory_evidence', {'source_valid': 0}, where: 'id = ?', whereArgs: [id]);
      } else if (kind == 'summary') {
        await txn.update('conversation_summaries', {'source_valid': 0}, where: 'id = ?', whereArgs: [id]);
      } else if (kind == 'personality_evidence') {
        final rows = await txn.query('personality_learning_evidence', columns: ['candidate_id'], where: 'id = ?', whereArgs: [id]);
        candidates.addAll(rows.map((r) => r['candidate_id'] as String));
        await txn.update('personality_learning_evidence', {'source_valid': 0}, where: 'id = ?', whereArgs: [id]);
      }
    }
    await txn.update('derived_source_links', {'valid': 0},
      where: keepUserBasis ? 'source_id = ? AND source_revision = ? AND dependency_role NOT IN (?, ?)' : 'source_id = ? AND source_revision = ? AND dependency_role != ?',
      whereArgs: [sourceId, revision, if (keepUserBasis) 'user_basis', 'external_outcome']);
    // Legacy evidence has no invented historical hash. Target only the turn
    // actually being withdrawn; preserve independently grounded user material.
    final legacy = !tables.containsAll(['memory_evidence', 'memory_items']) ? const <Map<String, Object?>>[] : await txn.rawQuery('SELECT e.id,e.memory_id,e.source_context_json,m.kind,m.source_user_message_id '
      'FROM memory_evidence e JOIN memory_items m ON m.id=e.memory_id '
      'WHERE e.source LIKE ? AND e.source_valid = 1', ['conversation_turn:$sourceId%']);
    for (final row in legacy) {
      Map data = const {};
      try { final raw = jsonDecode(row['source_context_json'] as String? ?? ''); if (raw is Map) data = raw; } catch (_) {}
      if (data['dependency'] == 'user_basis' ||
          (const {'user_profile','preference'}.contains(row['kind']) && (row['source_user_message_id'] as String? ?? '').isNotEmpty)) continue;
      await txn.update('memory_evidence', {'source_valid': 0}, where: 'id = ?', whereArgs: [row['id']]);
      memories.add(row['memory_id'] as String);
    }
    for (final id in memories) {
      final valid = Sqflite.firstIntValue(await txn.rawQuery(
        'SELECT COUNT(*) FROM memory_evidence WHERE memory_id = ? AND source_valid = 1', [id])) ?? 0;
      if (valid == 0) await txn.update('memory_items', {'source_valid': 0}, where: 'id = ?', whereArgs: [id]);
    }
    // Legacy summaries are range-only: withdraw affected material without
    // manufacturing a precise source manifest retroactively.
    final source = await txn.query('messages', columns: ['created_at'], where: 'id = ?', whereArgs: [sourceId]);
    if (source.isNotEmpty && tables.contains('conversation_summaries')) await txn.rawUpdate('UPDATE conversation_summaries SET source_valid = 0 '
      "WHERE source_manifest_json = '' AND from_at <= ? AND to_at >= ?", [source.single['created_at'], source.single['created_at']]);
    return candidates;
  }
}
