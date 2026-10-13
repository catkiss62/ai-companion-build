import 'derived_source_store.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'brain_work_fence.dart';
import 'conversation_source_store.dart';

/// Host-created input capability. Models never set its source manifest/cursor.
class ConversationSummaryWork {
  const ConversationSummaryWork._({required this.workFence, required this.stateToken,
    required this.materials, required this.batchHash});
  final BrainWorkFence workFence;
  final String stateToken, batchHash;
  final List<ConversationSourceMaterial> materials;
}

class ConversationSummaryStore {
  static const table = 'conversation_summary_sources';
  static const stateKey = 'conversation_summary_scan_state_v1';
  static const _uuid = Uuid();

  static Future<void> ensureSchema(DatabaseExecutor db) async {
    final columns = (await db.rawQuery('PRAGMA table_info(conversation_summaries)'))
        .map((r) => r['name']).toSet();
    if (columns.isEmpty) return;
    for (final name in const ['source_batch_hash', 'source_manifest_json']) {
      if (!columns.contains(name)) await db.execute(
        "ALTER TABLE conversation_summaries ADD COLUMN $name TEXT NOT NULL DEFAULT ''");
    }
    // The legacy uniqueness was an explicit index, never an inline constraint.
    // Preserve every historical row while allowing late batches in same range.
    await db.execute('DROP INDEX IF EXISTS idx_summary_range_unique');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_summary_range ON conversation_summaries(from_at,to_at)');
    await db.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_summary_source_batch ON conversation_summaries(source_batch_hash) WHERE source_batch_hash <> ''");
    await db.execute('''CREATE TABLE IF NOT EXISTS $table (
      message_id TEXT PRIMARY KEY, ingest_seq INTEGER NOT NULL,
      source_json TEXT NOT NULL, state TEXT NOT NULL, reason TEXT NOT NULL DEFAULT '',
      covered_batch_hash TEXT NOT NULL DEFAULT '')''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_summary_sources_state ON $table(state,ingest_seq)');
  }

  static Map<String, dynamic> _state(String raw) {
    try { final value = jsonDecode(raw); if (value is Map) return Map<String, dynamic>.from(value); } catch (_) { /* legacy unknown */ }
    return {};
  }

  static int _nonnegative(Object? value) => value is int && value >= 0 ? value : 0;

  static Future<void> _classify(DatabaseExecutor txn, ConversationSourceMaterial material) async {
    final source = material.source;
    final stamp = source.stamp;
    final old = await txn.query(table, where: 'message_id = ?', whereArgs: [stamp.id], limit: 1);
    final encoded = jsonEncode(source.toJson());
    if (old.isNotEmpty && old.single['ingest_seq'] == stamp.ingestSeq &&
        old.single['source_json'] == encoded && old.single['state'] == 'covered') return;
    final String state, reason;
    if (stamp.ingestSeq <= 0 || source.eligibility == ConversationSourceEligibility.unresolved) {
      state = 'deferred'; reason = source.reason;
    } else if (!source.isOrdinary) {
      state = 'excluded'; reason = source.reason;
    } else if (material.message.createdAt.isAfter(DateTime.now())) {
      state = 'deferred'; reason = 'future_event_time';
    } else if (material.message.promptContent.trim().isEmpty) {
      state = 'excluded'; reason = 'empty_material';
    } else { state = 'pending'; reason = ''; }
    await txn.insert(table, {'message_id': stamp.id, 'ingest_seq': stamp.ingestSeq,
      'source_json': encoded, 'state': state, 'reason': reason, 'covered_batch_hash': ''},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Must run in the caller's transaction with its original fence.
  static Future<ConversationSummaryWork?> prepare(DatabaseExecutor txn, {
    required BrainWorkFence workFence, int scanLimit = 256, int batchLimit = 36,
    int minimumMessages = 14,
  }) async {
    if (!await workFence.matches(txn)) return null;
    final raw = await BrainWorkFence.value(txn, stateKey);
    final state = _state(raw);
    final legacy = int.tryParse(await BrainWorkFence.value(txn,
      ConversationSourceStore.legacySummaryCoveredKey)) ?? 0;
    final maximum = Sqflite.firstIntValue(await txn.rawQuery('SELECT MAX(source_ingest_seq) FROM messages')) ?? 0;
    var scanSeq = state.containsKey('scan_seq') ? _nonnegative(state['scan_seq']) : legacy;
    // A corrupt imported future cursor must not hide all real sources.
    if (scanSeq > maximum && maximum > 0) scanSeq = 0;
    final limit = scanLimit.clamp(1, 256).toInt();
    await txn.rawDelete('DELETE FROM $table WHERE message_id IN (SELECT s.message_id FROM $table s '
      'LEFT JOIN messages m ON m.id=s.message_id WHERE m.id IS NULL LIMIT ?)', [limit]);
    final scan = await ConversationSourceStore.scanAfter(txn, afterSeq: scanSeq, limit: limit);
    for (final source in scan.sources) {
      final material = await ConversationSourceStore.captureMaterial(txn, source.stamp.id);
      if (material != null) await _classify(txn, material);
    }
    scanSeq = scan.lastScannedSeq;
    // Independent bounded rotation: one unresolved legacy bucket never blocks
    // later ordinary material. One row per live message, not one per attempt.
    var reviewCursor = state['review_cursor'] is String ? state['review_cursor'] as String : '';
    var review = await txn.query(table, columns: ['message_id'],
      where: "state IN ('deferred','excluded') AND message_id > ?", whereArgs: [reviewCursor],
      orderBy: 'message_id ASC', limit: limit);
    if (review.isEmpty && reviewCursor.isNotEmpty) {
      reviewCursor = '';
      review = await txn.query(table, columns: ['message_id'],
        where: "state IN ('deferred','excluded')", orderBy: 'message_id ASC', limit: limit);
    }
    for (final row in review) {
      final id = row['message_id'] as String;
      final material = await ConversationSourceStore.captureMaterial(txn, id);
      if (material != null) await _classify(txn, material);
      reviewCursor = id;
    }
    final pending = await txn.query(table, columns: ['message_id'], where: "state = 'pending'",
      orderBy: 'ingest_seq ASC', limit: limit < batchLimit.clamp(1, 36)
          ? batchLimit.clamp(1, 36).toInt() : limit);
    final materials = <ConversationSourceMaterial>[];
    final batchSize = batchLimit.clamp(1, 36).toInt();
    for (final row in pending) {
      final material = await ConversationSourceStore.captureMaterial(txn, row['message_id'] as String);
      if (material == null) continue;
      await _classify(txn, material);
      if (material.source.isOrdinary && material.source.stamp.ingestSeq > 0 &&
          !material.message.createdAt.isAfter(DateTime.now()) && material.message.promptContent.trim().isNotEmpty) {
        materials.add(material);
        if (materials.length == batchSize) break;
      }
    }
    final token = jsonEncode({'scan_seq': scanSeq, 'review_cursor': reviewCursor, 'version': _uuid.v4()});
    await txn.insert('settings', {'key': stateKey, 'value': token}, conflictAlgorithm: ConflictAlgorithm.replace);
    if (materials.length < minimumMessages.clamp(1, 36)) return null;
    materials.sort((a,b) {
      final order = a.message.createdAt.compareTo(b.message.createdAt);
      return order != 0 ? order : a.source.stamp.ingestSeq.compareTo(b.source.stamp.ingestSeq);
    });
    final manifest = materials.map((m) => m.source.toJson()).toList();
    final hash = sha256.convert(utf8.encode(jsonEncode(manifest))).toString();
    return ConversationSummaryWork._(workFence: workFence, stateToken: token,
      materials: List.unmodifiable(materials), batchHash: hash);
  }

  static Future<bool> commit(DatabaseExecutor txn, {required ConversationSummaryWork work,
    required String summary, List<String> keyPoints = const []}) async {
    if (summary.trim().isEmpty || !await work.workFence.matches(txn) ||
        await BrainWorkFence.value(txn, stateKey) != work.stateToken) return false;
    for (final material in work.materials) {
      if (!material.source.isOrdinary || !await material.source.matches(txn)) return false;
      final rows = await txn.query(table, columns: ['state', 'source_json'],
        where: 'message_id = ?', whereArgs: [material.message.id], limit: 1);
      if (rows.isEmpty || rows.single['state'] != 'pending' ||
          rows.single['source_json'] != jsonEncode(material.source.toJson())) return false;
    }
    final existing = await txn.query('conversation_summaries', columns: ['id'],
      where: 'source_batch_hash = ?', whereArgs: [work.batchHash], limit: 1);
    final summaryId = existing.isEmpty ? _uuid.v4() : existing.single['id'] as String;
    if (existing.isEmpty) await txn.insert('conversation_summaries', {
      'id': summaryId, 'from_at': work.materials.first.message.createdAt.millisecondsSinceEpoch,
      'to_at': work.materials.last.message.createdAt.millisecondsSinceEpoch,
      'summary': summary.trim(), 'key_points': keyPoints.take(12).join('|'),
      'created_at': DateTime.now().millisecondsSinceEpoch, 'source_batch_hash': work.batchHash,
      'source_manifest_json': jsonEncode(work.materials.map((m) => m.source.toJson()).toList()),
    });
    for (final material in work.materials) {
      await DerivedSourceStore.link(txn, kind: 'summary', ownerId: summaryId,
        sourceId: material.source.stamp.id, revision: material.source.stamp.revision,
        hash: material.source.stamp.contentHash, role: material.message.isUser ? 'user_basis' : 'assistant_basis');
      await txn.update(table, {'state': 'covered', 'covered_batch_hash': work.batchHash},
        where: 'message_id = ?', whereArgs: [material.message.id]);
    }
    final state = _state(work.stateToken)..['version'] = _uuid.v4();
    await txn.insert('settings', {'key': stateKey, 'value': jsonEncode(state)}, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }
}
