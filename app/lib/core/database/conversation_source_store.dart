import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models/world_book_turn_context.dart';

/// A local capability for one complete message, independent of whether the
/// surrounding turn is eligible for background factual learning.
class ConversationSourceStamp {
  const ConversationSourceStamp({
    required this.id,
    required this.role,
    required this.contentHash,
    required this.observedAt,
    this.revision = 0,
    this.ingestSeq = 0,
  });

  final String id, role, contentHash;
  final DateTime observedAt;
  final int revision, ingestSeq;

  Future<bool> matches(DatabaseExecutor db) async {
    final live = await ConversationSourceStore.captureMessage(db, id);
    return live != null && live.role == role && live.revision == revision &&
        live.contentHash == contentHash;
  }

  Map<String, Object?> toJson() => {
    'contract': 1, 'id': id, 'role': role, 'revision': revision,
    'content_hash': contentHash,
    'observed_at': observedAt.millisecondsSinceEpoch, 'ingest_seq': ingestSeq,
  };

  static ConversationSourceStamp? fromJson(Object? raw) {
    if (raw is! Map || raw['contract'] != 1 || raw['id'] is! String ||
        (raw['id'] as String).isEmpty ||
        !const {'user', 'assistant'}.contains(raw['role']) ||
        raw['content_hash'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(raw['content_hash'] as String) ||
        raw['observed_at'] is! int || raw['revision'] is! int ||
        (raw['revision'] as int) < 0) return null;
    return ConversationSourceStamp(id: raw['id'] as String,
      role: raw['role'] as String, contentHash: raw['content_hash'] as String,
      observedAt: DateTime.fromMillisecondsSinceEpoch(raw['observed_at'] as int),
      revision: raw['revision'] as int,
      ingestSeq: (raw['ingest_seq'] as num?)?.toInt() ?? 0);
  }
}

enum ConversationSourceEligibility { ordinary, roleplay, unresolved }

class QualifiedConversationSource {
  const QualifiedConversationSource({required this.stamp,
    required this.eligibility, required this.eligibilityToken,
    required this.reason, this.userMessageId, this.assistantMessageId});

  final ConversationSourceStamp stamp;
  final ConversationSourceEligibility eligibility;
  final String eligibilityToken, reason;
  final String? userMessageId, assistantMessageId;
  bool get isOrdinary => eligibility == ConversationSourceEligibility.ordinary;

  Future<bool> matches(DatabaseExecutor db) async {
    final live = await ConversationSourceStore.qualifyMessage(db, stamp.id);
    return live != null && live.eligibilityToken == eligibilityToken &&
        live.stamp.contentHash == stamp.contentHash &&
        live.stamp.revision == stamp.revision;
  }
}

class QualifiedConversationBatch {
  const QualifiedConversationBatch({required this.sources,
    required this.lastScannedSeq});
  final List<QualifiedConversationSource> sources;
  final int lastScannedSeq;
}

/// Call capture/qualify and their final matches with the caller's transaction
/// when an atomic snapshot or write decision is required. No model-supplied
/// hash, inferred form, or clipped text is used as authority here.
class ConversationSourceStore {
  static const sequenceKey = 'message_source_seq_v1';
  static const legacySummaryCoveredKey = 'conversation_summary_legacy_covered_seq_v1';
  // Durable reply revisions are added by G5; until then legacy/current stamps
  // carry revision 0 and still verify the complete local semantic hash.
  static const messageColumns = ['id', 'role', 'content', 'created_at',
    'is_proactive', 'expects_reply', 'worldbook_context_json',
    'form_context_json', 'source_ingest_seq'];

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  static Object? _json(Object? value) {
    if (value is! String || value.isEmpty) return '';
    try { return _canonical(jsonDecode(value)); } catch (_) { return value; }
  }

  static String _hash(Object? value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();

  static Object _messageSemantics(Map<String, Object?> row) => [
    row['id'], row['role'], row['content'] ?? '', row['created_at'],
    row['is_proactive'] ?? 0, row['expects_reply'] ?? 1,
    _json(row['worldbook_context_json']), _json(row['form_context_json']),
  ];

  static Future<ConversationSourceStamp?> captureMessage(
      DatabaseExecutor db, String id) async {
    final rows = await db.query('messages', columns: messageColumns, where: 'id = ?',
      whereArgs: [id], limit: 1);
    if (rows.isEmpty || !const {'user', 'assistant'}.contains(rows.first['role'])) return null;
    final row = rows.single;
    final attachments = await db.query('message_attachments',
      where: 'message_id = ?', whereArgs: [id], orderBy: 'id ASC');
    // Paths, retry counters and analysis timestamps are not semantic identity.
    // Legacy blobs without a stored content id remain unknown, never guessed.
    final material = [for (final a in attachments) [
      a['id'], a['kind'], a['blob_id'] ?? '', a['mime_type'],
      a['byte_size'], a['width'], a['height'], a['source'],
      a['vision_status'], a['vision_summary'] ?? '',
    ]];
    return ConversationSourceStamp(id: id, role: row['role'] as String,
      contentHash: _hash([1, _messageSemantics(row), material]),
      observedAt: DateTime.fromMillisecondsSinceEpoch((row['created_at'] as num).toInt()),
      revision: (row['source_revision'] as num?)?.toInt() ?? 0,
      ingestSeq: (row['source_ingest_seq'] as num?)?.toInt() ?? 0);
  }

  static bool _roleplay(Map<String, Object?> row) =>
      WorldBookTurnContext.decode(row['worldbook_context_json'] as String? ?? '').hasRoleplay;

  static Future<QualifiedConversationSource?> qualifyMessage(
      DatabaseExecutor db, String id) async {
    final stamp = await captureMessage(db, id);
    if (stamp == null) return null;
    final current = await db.query('messages', columns: messageColumns, where: 'id = ?',
      whereArgs: [id], limit: 1);
    if (current.isEmpty) return null;
    final row = current.single;
    Map<String, Object?>? user, assistant;
    Map<String, Object?>? job;
    var reason = 'legacy_unmarked';
    var eligibility = ConversationSourceEligibility.ordinary;
    if (row['role'] == 'user') { user = row; } else { assistant = row; }
    if (_roleplay(row)) {
      eligibility = ConversationSourceEligibility.roleplay;
      reason = 'own_roleplay';
    } else if (row['is_proactive'] == 1) {
      reason = 'standalone_proactive';
    } else {
      final jobs = await db.query('generation_jobs',
        columns: ['id', 'status', 'user_message_id', 'assistant_message_id'],
        where: stamp.role == 'user' ? 'user_message_id = ?' : 'assistant_message_id = ?',
        whereArgs: [id], limit: 1);
      if (jobs.isNotEmpty) {
        job = jobs.single;
        final peerId = stamp.role == 'user' ? job['assistant_message_id'] : job['user_message_id'];
        final peers = await db.query('messages', columns: messageColumns,
          where: 'id = ?', whereArgs: [peerId], limit: 1);
        final peer = peers.isEmpty ? null : peers.single;
        if (stamp.role == 'user') { assistant = peer; } else { user = peer; }
        if (peer != null && _roleplay(peer)) {
          eligibility = ConversationSourceEligibility.roleplay;
          reason = 'paired_roleplay';
        } else if (job['status'] != 'completed' || user?['role'] != 'user' ||
            assistant?['role'] != 'assistant' || assistant?['is_proactive'] == 1) {
          eligibility = ConversationSourceEligibility.unresolved;
          reason = 'incomplete_durable_turn';
        } else { reason = 'durable_pair'; }
      } else {
        final next = stamp.role == 'user';
        final peers = await db.rawQuery('''SELECT ${messageColumns.join(',')} FROM messages
          WHERE is_proactive = 0 AND role IN ('user','assistant')
          AND (created_at ${next ? '>' : '<'} ? OR
            (created_at = ? AND id ${next ? '>' : '<'} ?))
          ORDER BY created_at ${next ? 'ASC' : 'DESC'}, id ${next ? 'ASC' : 'DESC'} LIMIT 1''',
          [row['created_at'], row['created_at'], id]);
        if (peers.isNotEmpty && peers.single['role'] == (next ? 'assistant' : 'user')) {
          final peer = peers.single;
          if (peer['created_at'] == row['created_at']) {
            eligibility = ConversationSourceEligibility.unresolved;
            reason = 'legacy_pair_order_unknown';
          } else {
            if (next) { assistant = peer; } else { user = peer; }
            if (_roleplay(peer)) {
              eligibility = ConversationSourceEligibility.roleplay;
              reason = 'legacy_paired_roleplay';
            } else { reason = 'legacy_pair'; }
          }
        }
      }
    }
    if (eligibility == ConversationSourceEligibility.ordinary && stamp.role == 'user') {
      final pending = await db.query('message_attachments', columns: ['id'],
        where: "message_id = ? AND vision_status IN ('pending','analyzing')",
        whereArgs: [id], limit: 1);
      if (pending.isNotEmpty) {
        eligibility = ConversationSourceEligibility.unresolved;
        reason = 'vision_pending';
      }
    }
    Object? provenance(Map<String, Object?>? m) => m == null ? null : [
      m['id'], m['role'], m['is_proactive'], _json(m['worldbook_context_json']),
      m['source_revision'] ?? 0,
    ];
    return QualifiedConversationSource(stamp: stamp, eligibility: eligibility,
      reason: reason, userMessageId: user?['id'] as String?,
      assistantMessageId: assistant?['id'] as String?,
      eligibilityToken: _hash([1, eligibility.name, reason,
        job?['id'], job?['status'], provenance(user), provenance(assistant)]));
  }

  static Future<QualifiedConversationBatch> scanAfter(DatabaseExecutor db,
      {required int afterSeq, int limit = 64}) async {
    final rows = await db.query('messages', columns: ['id', 'source_ingest_seq'],
      where: 'source_ingest_seq > ?', whereArgs: [afterSeq],
      orderBy: 'source_ingest_seq ASC', limit: limit.clamp(1, 256).toInt());
    final sources = <QualifiedConversationSource>[];
    for (final row in rows) {
      final source = await qualifyMessage(db, row['id'] as String);
      if (source != null) sources.add(source);
    }
    return QualifiedConversationBatch(sources: sources,
      lastScannedSeq: rows.isEmpty ? afterSeq : (rows.last['source_ingest_seq'] as num).toInt());
  }

  static Future<int> _nextSequence(DatabaseExecutor db) async {
    final raw = await db.query('settings', columns: ['value'],
      where: 'key = ?', whereArgs: [sequenceKey], limit: 1);
    final saved = raw.isEmpty ? 0 : int.tryParse(raw.single['value'] as String? ?? '') ?? 0;
    final maximum = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT MAX(source_ingest_seq) FROM messages WHERE source_ingest_seq > 0')) ?? 0;
    final next = (saved > maximum ? saved : maximum) + 1;
    await db.insert('settings', {'key': sequenceKey, 'value': '$next'},
      conflictAlgorithm: ConflictAlgorithm.replace);
    return next;
  }

  /// Must share the caller's transaction with the message and any attachments.
  static Future<int> insertMessage(DatabaseExecutor db, Map<String, Object?> row,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    final old = await db.query('messages', columns: messageColumns,
      where: 'id = ?', whereArgs: [row['id']], limit: 1);
    if (old.isNotEmpty && conflictAlgorithm == ConflictAlgorithm.ignore) return 0;
    final unchanged = old.isNotEmpty && conflictAlgorithm == ConflictAlgorithm.replace &&
        _hash(_messageSemantics(old.single)) == _hash(_messageSemantics(row));
    final seq = unchanged && (old.single['source_ingest_seq'] as num? ?? 0) > 0
        ? (old.single['source_ingest_seq'] as num).toInt() : await _nextSequence(db);
    return db.insert('messages', {...row, 'source_ingest_seq': seq},
      conflictAlgorithm: conflictAlgorithm);
  }

  /// A semantic attachment/qualification change makes an existing id visible
  /// to forward scanners again. Maintenance paths alone must not call this.
  static Future<void> sourceChanged(DatabaseExecutor db, String messageId) async {
    if ((await db.query('messages', columns: ['id'], where: 'id = ?',
      whereArgs: [messageId], limit: 1)).isEmpty) return;
    final next = await _nextSequence(db);
    await db.update('messages', {'source_ingest_seq': next},
      where: 'id = ?', whereArgs: [messageId]);
  }

  static Future<void> ensureSchema(DatabaseExecutor db) async {
    final columns = (await db.rawQuery('PRAGMA table_info(messages)'))
        .map((r) => r['name']).toSet();
    if (!columns.containsAll(['id', 'created_at']) ||
        (await db.rawQuery('PRAGMA table_info(settings)')).isEmpty) return;
    if (!columns.contains('source_ingest_seq')) {
      await db.execute('ALTER TABLE messages ADD COLUMN source_ingest_seq INTEGER NOT NULL DEFAULT 0');
    }
    await initializeSequences(db);
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_message_source_seq '
      'ON messages(source_ingest_seq) WHERE source_ingest_seq > 0');
  }

  /// One-time legacy backfill, or validation after an atomic snapshot import.
  /// Existing positive sequences and the saved high-water mark are retained.
  static Future<void> initializeSequences(DatabaseExecutor db) async {
    final missing = await db.query('messages', columns: ['id'],
      where: 'source_ingest_seq <= 0', orderBy: 'created_at ASC, id ASC');
    final maximum = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT MAX(source_ingest_seq) FROM messages WHERE source_ingest_seq > 0')) ?? 0;
    final old = await db.query('settings', columns: ['value'],
      where: 'key = ?', whereArgs: [sequenceKey], limit: 1);
    final saved = old.isEmpty ? 0 : int.tryParse(old.single['value'] as String? ?? '') ?? 0;
    var highWater = saved > maximum ? saved : maximum;
    final backfill = db.batch();
    for (final row in missing) {
      backfill.update('messages', {'source_ingest_seq': ++highWater},
        where: 'id = ?', whereArgs: [row['id']]);
    }
    await backfill.commit(noResult: true);
    await db.insert('settings', {'key': sequenceKey,
      'value': '$highWater'}, conflictAlgorithm: ConflictAlgorithm.replace);
    if ((await db.query('settings', columns: ['key'], where: 'key = ?',
      whereArgs: [legacySummaryCoveredKey], limit: 1)).isEmpty) {
      final hasSummary = (await db.rawQuery('PRAGMA table_info(conversation_summaries)')).isNotEmpty;
      final covered = !hasSummary ? 0 : Sqflite.firstIntValue(await db.rawQuery('''
        SELECT MAX(source_ingest_seq) FROM messages
        WHERE created_at <= (SELECT MAX(to_at) FROM conversation_summaries)''')) ?? 0;
      await db.insert('settings', {'key': legacySummaryCoveredKey, 'value': '$covered'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
