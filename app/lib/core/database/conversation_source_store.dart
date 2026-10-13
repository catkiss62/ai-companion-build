import 'derived_source_store.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models/world_book_turn_context.dart';
import '../models/chat_message.dart';
import '../models/message_attachment.dart';

/// Local, read-only validation using the caller's transaction. Never performs
/// network work or opens another database connection.
typedef LocalSourceGuard = Future<bool> Function(DatabaseExecutor txn);

class ConversationSourceMaterial {
  const ConversationSourceMaterial({required this.message, required this.source});
  final ChatMessage message;
  final QualifiedConversationSource source;
}

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

  /// Background material must still be the captured ingestion version. Bare
  /// matches deliberately preserves G2 user authorization across pair changes.
  Future<bool> matchesCapturedVersion(DatabaseExecutor db) async {
    if (ingestSeq <= 0) return false;
    final live = await ConversationSourceStore.captureMessage(db, id);
    return live != null && live.role == role && live.revision == revision &&
        live.contentHash == contentHash && live.ingestSeq == ingestSeq;
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
        (raw['revision'] as int) < 0 ||
        (raw.containsKey('ingest_seq') &&
          (raw['ingest_seq'] is! int || (raw['ingest_seq'] as int) < 0))) return null;
    return ConversationSourceStamp(id: raw['id'] as String,
      role: raw['role'] as String, contentHash: raw['content_hash'] as String,
      observedAt: DateTime.fromMillisecondsSinceEpoch(raw['observed_at'] as int),
      revision: raw['revision'] as int,
      ingestSeq: raw['ingest_seq'] as int? ?? 0);
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
    if (!await stamp.matchesCapturedVersion(db)) return false;
    final live = await ConversationSourceStore.qualifyMessage(db, stamp.id);
    return live != null && live.eligibilityToken == eligibilityToken &&
        live.stamp.contentHash == stamp.contentHash &&
        live.stamp.revision == stamp.revision;
  }

  Map<String, Object?> toJson() => {'stamp': stamp.toJson(),
    'eligibility': eligibility.name, 'token': eligibilityToken, 'reason': reason,
    'user_id': userMessageId, 'assistant_id': assistantMessageId};

  static QualifiedConversationSource? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final stamp = ConversationSourceStamp.fromJson(raw['stamp']);
    final eligibility = ConversationSourceEligibility.values.where((v) => v.name == raw['eligibility']).firstOrNull;
    if (stamp == null || eligibility == null || raw['reason'] is! String ||
        raw['token'] is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(raw['token'] as String) ||
        (raw['user_id'] != null && raw['user_id'] is! String) ||
        (raw['assistant_id'] != null && raw['assistant_id'] is! String)) return null;
    return QualifiedConversationSource(stamp: stamp, eligibility: eligibility,
      eligibilityToken: raw['token'] as String, reason: raw['reason'] as String,
      userMessageId: raw['user_id'] as String?, assistantMessageId: raw['assistant_id'] as String?);
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
    'form_context_json', 'source_ingest_seq', 'source_revision'];

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

  static Object _attachmentSemantics(Map<String, Object?> a) => [
    a['id'], a['kind'], a['blob_id'] ?? '', a['mime_type'],
    a['byte_size'], a['width'], a['height'], a['source'],
    a['vision_status'], a['vision_summary'] ?? '',
  ];

  /// Compare the complete object handed to a consumer with a same-transaction
  /// source capability. A matching clipped prompt is insufficient authority.
  static String messageHash(ChatMessage message) {
    final attachments = message.attachments.toList()..sort((a,b) => a.id.compareTo(b.id));
    return _hash([1, _messageSemantics(message.toDb()),
      attachments.map((a) => _attachmentSemantics(a.toDb())).toList()]);
  }

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
    final material = attachments.map(_attachmentSemantics).toList();
    return ConversationSourceStamp(id: id, role: row['role'] as String,
      contentHash: _hash([1, _messageSemantics(row), material]),
      observedAt: DateTime.fromMillisecondsSinceEpoch((row['created_at'] as num).toInt()),
      revision: (row['source_revision'] as num?)?.toInt() ?? 0,
      ingestSeq: (row['source_ingest_seq'] as num?)?.toInt() ?? 0);
  }

  static Future<ConversationSourceMaterial?> captureMaterial(
      DatabaseExecutor txn, String id) async {
    final source = await qualifyMessage(txn, id);
    if (source == null) return null;
    final rows = await txn.query('messages', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final attachments = await txn.query('message_attachments',
      where: 'message_id = ?', whereArgs: [id], orderBy: 'id ASC');
    return ConversationSourceMaterial(message: ChatMessage.fromDb(rows.single,
      attachments: attachments.map(MessageAttachment.fromDb).toList()), source: source);
  }

  static Future<List<ConversationSourceMaterial>> recentMaterials(
      DatabaseExecutor txn, {int limit = 64, DateTime? notBefore, DateTime? notAfter}) async {
    final rows = await txn.query('messages', columns: ['id'],
      where: 'role IN (\'user\',\'assistant\')'
        '${notBefore == null ? '' : ' AND created_at >= ?'}'
        '${notAfter == null ? '' : ' AND created_at <= ?'}',
      whereArgs: [if (notBefore != null) notBefore.millisecondsSinceEpoch,
        if (notAfter != null) notAfter.millisecondsSinceEpoch],
      orderBy: 'created_at DESC, id DESC', limit: limit.clamp(1, 256).toInt());
    final result = <ConversationSourceMaterial>[];
    for (final row in rows.reversed) {
      final material = await captureMaterial(txn, row['id'] as String);
      if (material != null) result.add(material);
    }
    return result;
  }

  static bool _roleplay(Map<String, Object?> row) =>
      WorldBookTurnContext.decode(row['worldbook_context_json'] as String? ?? '').hasRoleplay;

  static Future<QualifiedConversationSource?> qualifyMessage(
      DatabaseExecutor db, String id, {bool includeSequenceInToken = true}) async {
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
        // Legacy timestamps do not encode order within a millisecond. Check
        // the whole opposite-role bucket before directional UUID adjacency.
        final ambiguous = await db.query('messages', columns: ['id'],
          where: 'created_at = ? AND is_proactive = 0 AND role = ?',
          whereArgs: [row['created_at'], next ? 'assistant' : 'user'], limit: 1);
        if (ambiguous.isNotEmpty) {
          eligibility = ConversationSourceEligibility.unresolved;
          reason = 'legacy_pair_order_unknown';
        } else {
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
      if (includeSequenceInToken) m['source_ingest_seq'] ?? 0,
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
    final consumed = await _consumedSequenceCeiling(db);
    final current = saved > maximum ? saved : maximum;
    final next = (consumed > current ? consumed : current) + 1;
    await db.insert('settings', {'key': sequenceKey, 'value': '$next'},
      conflictAlgorithm: ConflictAlgorithm.replace);
    return next;
  }

  static Future<int> _consumedSequenceCeiling(DatabaseExecutor db) async {
    final rows = await db.query('settings', columns: ['key', 'value'],
      where: 'key IN (?, ?, ?)', whereArgs: [legacySummaryCoveredKey,
        'conversation_summary_scan_state_v1', 'moe_shadow_scan_v1']);
    var maximum = 0;
    void include(Object? value) { if (value is int && value > maximum) maximum = value; }
    for (final row in rows) {
      final raw = row['value'] as String? ?? '';
      if (row['key'] == legacySummaryCoveredKey) { include(int.tryParse(raw)); continue; }
      try {
        final value = jsonDecode(raw);
        if (value is! Map) continue;
        if (row['key'] == 'conversation_summary_scan_state_v1') include(value['scan_seq']);
        if (row['key'] == 'moe_shadow_scan_v1' && value['schema'] == 1) {
          include(value['after_seq']); include(value['legacy_ceiling']);
        }
      } catch (_) { /* invalid cursors are unknown, not fabricated sequence ids */ }
    }
    return maximum;
  }

  /// Must share the caller's transaction with the message and any attachments.
  static Future<int> insertMessage(DatabaseExecutor db, Map<String, Object?> row,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort}) async {
    final old = await db.query('messages', columns: messageColumns,
      where: 'id = ?', whereArgs: [row['id']], limit: 1);
    if (old.isNotEmpty && conflictAlgorithm == ConflictAlgorithm.ignore) return 0;
    final unchanged = old.isNotEmpty && conflictAlgorithm == ConflictAlgorithm.replace &&
        _hash(_messageSemantics(old.single)) == _hash(_messageSemantics(row));
    final affected = unchanged ? <String>{} : await _affectedSources(db, row);
    if (!unchanged && old.isNotEmpty) affected.addAll(await _affectedSources(db, old.single));
    final before = await _qualificationTokens(db, affected);
    final seq = unchanged && (old.single['source_ingest_seq'] as num? ?? 0) > 0
        ? (old.single['source_ingest_seq'] as num).toInt() : await _nextSequence(db);
    final revisionRows = await db.query('settings', columns: ['value'], where: 'key = ?', whereArgs: ['message_source_revision_v1:${row['id']}']);
    final tombstone = revisionRows.isEmpty ? -1 : int.tryParse(revisionRows.single['value'] as String? ?? '') ?? -1;
    final previousRevision = old.isEmpty ? 0 : (old.single['source_revision'] as num?)?.toInt() ?? 0;
    final requestedRevision = (row['source_revision'] as num?)?.toInt() ?? 0;
    final nextRevision = old.isEmpty ? (requestedRevision > tombstone ? requestedRevision : tombstone + 1) :
        unchanged ? previousRevision : previousRevision + 1;
    if (!unchanged && old.isNotEmpty) await DerivedSourceStore.revoke(db, row['id'] as String, previousRevision, keepUserBasis: old.single['role'] != 'user');
    await db.insert('settings', {'key': 'message_source_revision_v1:${row['id']}', 'value': nextRevision.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
    final result = await db.insert('messages', {...row, 'source_ingest_seq': seq, 'source_revision': nextRevision},
      conflictAlgorithm: conflictAlgorithm);
    affected.remove(row['id']);
    final after = await _qualificationTokens(db, affected);
    await _requeue(db, affected.where((id) => before[id] != after[id]).toSet());
    return result;
  }

  /// A semantic attachment/qualification change makes an existing id visible
  /// to forward scanners again. Maintenance paths alone must not call this.
  static Future<void> sourceChanged(DatabaseExecutor db, String messageId,
      {bool qualificationChanged = false}) async {
    final rows = await db.query('messages', columns: messageColumns, where: 'id = ?',
      whereArgs: [messageId], limit: 1);
    if (rows.isEmpty) return;
    await _requeue(db, {messageId,
      if (qualificationChanged) ...await _affectedSources(db, rows.single)});
  }

  static Future<Map<String, String?>> _qualificationTokens(DatabaseExecutor db, Set<String> ids) async => {
    for (final id in ids) id: (await qualifyMessage(db, id, includeSequenceInToken: false))?.eligibilityToken,
  };

  /// Call before deletion so surviving legacy/durable peers are discoverable.
  static Future<void> sourceWillBeDeleted(DatabaseExecutor db, String id) async {
    final rows = await db.query('messages', columns: messageColumns,
      where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    await db.insert('settings', {'key': 'message_source_revision_v1:$id', 'value': ((rows.single['source_revision'] as num?)?.toInt() ?? 0).toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
    final affected = (await _affectedSources(db, rows.single))..remove(id);
    await _requeue(db, affected);
  }

  static Future<Set<String>> _affectedSources(DatabaseExecutor db, Map<String, Object?> row) async {
    final ids = <String>{};
    final jobs = await db.query('generation_jobs', columns: ['user_message_id', 'assistant_message_id'],
      where: 'user_message_id = ? OR assistant_message_id = ?', whereArgs: [row['id'], row['id']]);
    for (final job in jobs) {
      for (final key in const ['user_message_id', 'assistant_message_id']) {
        if (job[key] is String) ids.add(job[key] as String);
      }
    }
    if (row['is_proactive'] != 1) {
      final bucket = await db.query('messages', columns: ['id'],
        where: 'created_at = ? AND is_proactive = 0', whereArgs: [row['created_at']]);
      ids.addAll(bucket.map((r) => r['id'] as String));
      for (final before in const [true, false]) {
        final peer = await db.rawQuery('SELECT id FROM messages WHERE is_proactive = 0 '
          'AND role IN (\'user\',\'assistant\') AND created_at ${before ? '<' : '>'} ? '
          'ORDER BY created_at ${before ? 'DESC' : 'ASC'}, id ${before ? 'DESC' : 'ASC'} LIMIT 1',
          [row['created_at']]);
        ids.addAll(peer.map((r) => r['id'] as String));
      }
    }
    return ids;
  }

  static Future<void> _requeue(DatabaseExecutor db, Set<String> ids) async {
    for (final id in ids.toList()..sort()) {
      if ((await db.query('messages', columns: ['id'], where: 'id = ?', whereArgs: [id], limit: 1)).isEmpty) continue;
      await db.update('messages', {'source_ingest_seq': await _nextSequence(db)},
        where: 'id = ?', whereArgs: [id]);
    }
  }

  static Future<void> ensureSchema(DatabaseExecutor db) async {
    final columns = (await db.rawQuery('PRAGMA table_info(messages)'))
        .map((r) => r['name']).toSet();
    if (!columns.containsAll(['id', 'created_at']) ||
        (await db.rawQuery('PRAGMA table_info(settings)')).isEmpty) return;
    if (!columns.contains('source_revision')) await db.execute('ALTER TABLE messages ADD COLUMN source_revision INTEGER NOT NULL DEFAULT 0');
    if (!columns.contains('source_ingest_seq')) {
      await db.execute('ALTER TABLE messages ADD COLUMN source_ingest_seq INTEGER NOT NULL DEFAULT 0');
    }
    await DerivedSourceStore.ensureSchema(db);
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
    final consumed = await _consumedSequenceCeiling(db);
    if (consumed > highWater) highWater = consumed;
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
      // Only a wholly legacy deterministic backfill is an event-time prefix.
      // Existing positive seq may be backdated; never derive a new high-water
      // mark from their event timestamps when an imported baseline is missing.
      final covered = !hasSummary || maximum > 0 ? 0 : Sqflite.firstIntValue(await db.rawQuery('''
        SELECT MAX(source_ingest_seq) FROM messages
        WHERE created_at <= (SELECT MAX(to_at) FROM conversation_summaries)''')) ?? 0;
      await db.insert('settings', {'key': legacySummaryCoveredKey, 'value': '$covered'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
      if (maximum > 0 && hasSummary) await db.insert('settings', {
        'key': 'conversation_summary_legacy_baseline_unknown_v1', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
