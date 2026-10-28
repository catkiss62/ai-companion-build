import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'qq_archive_reader.dart';
import 'qq_store.dart';
import 'qq_failure.dart';
import 'qq_failure_history.dart';
import '../../core/database/brain_work_fence.dart';

class QqPendingReply {
  QqPendingReply(this.row, this.stamp, this.requests, this.delivered);
  final Map<String, Object?> row;
  final List<Map<String, Object?>> stamp;
  final List<String> requests, delivered;
  String get id => row['id'] as String;
  Map<String, dynamic>? get draft {
    if (row['failure_phase'] != 'group_boundary' || delivered.isNotEmpty || row['stage'] == 'send_uncertain') return null;
    try {
      final value = jsonDecode(row['draft'] as String);
      return value is Map ? Map<String, dynamic>.from(value) : null;
    } catch (_) { return null; }
  }
  Map<String, Object?> get hint => {
    'previous_request_unfinished':row['stage']!='sent_archive_failed',
    'platform_confirmed':row['stage']=='sent_archive_failed', 'requests': requests,
    'stage': row['stage'], 'failure_phase': row['failure_phase'],
    'confirmed_delivered': delivered,
    'delivery_unknown': row['stage'] == 'send_uncertain',
    'instruction': '这是宿主提供的QQ投递事实。理解本批外层发言是否接续、追问、已解决、取消或另起话题；不要猜测上次成功，不重发已确认或结果未知的旧段落。',
  };
}

/// An unfinished response is dormant until a new received message or a new
/// trusted mention supplies a trigger. It is not a timer or an App Thought.
class QqReplyTasks {
  QqReplyTasks(this.store);
  final QqStore store;
  static const ttl = Duration(minutes: 10);
  static Future<void> begin(Transaction sql, QqBatch b, int now, String policy) async {
    await sql.delete('qq_reply_tasks', where: 'expires_at<?', whereArgs: [now]);
    final at = b.rows.last['received_at'] as int;
    await sql.insert('qq_reply_tasks', {
      'id': b.id, 'conversation_id': b.cid, 'through_seq': b.through,
      'sources': jsonEncode(b.rows.map((r) => r['seq']).toList()),
      'source_stamp': jsonEncode([for (final r in b.rows) {'table':'qq_archive','id':r['id'],'version':r['version']}]),
      'identity': QqStore.ingressIdentity(b.fence), 'policy': policy,
      'source_at': at, 'expires_at': at + ttl.inMilliseconds,
      'addressed': b.rows.any((r) => r['mentioned'] == 1) ? 1 : 0,
      'stage':'checking', 'draft':'', 'failure_phase':'', 'last_trigger_seq':b.through,
      'valid':1, 'updated_at':now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  Future<void> addressed(QqBatch b) => store.write(b.fence, (sql) async {
    await sql.update('qq_reply_tasks', {'addressed':1}, where:'id=?', whereArgs:[b.id]);
  });
  Future<void> saveDraft(QqBatch b, Map<String, Object?> draft) => store.write(b.fence, (sql) async {
    final raw = jsonEncode(draft);
    if (raw.length > 48000) throw const FormatException('qq_draft_size');
    await sql.update('qq_reply_tasks', {'draft':raw}, where:'id=? AND valid=1', whereArgs:[b.id]);
  });
  Future<void> failure(QqBatch b, String phase) => store.write(b.fence, (sql) async {
    await sql.update('qq_reply_tasks', {'failure_phase':phase}, where:'id=?', whereArgs:[b.id]);
  });
  Future<QqPendingReply?> pending(QqBatch b, int now, String policy) async {
    final sql = await store.db.database;
    final rows = await sql.query('qq_reply_tasks',
      where:"conversation_id=? AND id!=? AND valid=1 AND addressed=1 AND expires_at>? AND last_trigger_seq<=? "
        "AND stage IN ('failed','interrupted','send_uncertain','partially_sent','sent_archive_failed')",
      whereArgs:[b.cid,b.id,now,b.through], orderBy:'source_at DESC', limit:8);
    for (final row in rows) {
      if (row['policy'] != policy || !QqStore.acceptsIngress(row['identity'] as String, b.fence)) continue;
      final stamps = (jsonDecode(row['source_stamp'] as String) as List)
          .map((e) => Map<String,Object?>.from(e as Map)).toList();
      if (!await QqArchiveReader(sql).matches(stamps)) continue;
      final ids = (jsonDecode(row['sources'] as String) as List).cast<int>();
      final originals = await sql.query('qq_archive', columns:['content'],
        where:'conversation_id=? AND seq IN (${List.filled(ids.length, '?').join(',')})',whereArgs:[b.cid,...ids],orderBy:'seq');
      final sent = await sql.query('qq_archive', columns:['content'],
        where:"conversation_id=? AND role='assistant' AND id LIKE ?",whereArgs:[b.cid,'reply:${row['id']}:%'],orderBy:'seq');
      return QqPendingReply(row, stamps, originals.map((r) => QqArchiveReader.bound(r['content'] as String,2000)).toList(),
        sent.map((r) => QqArchiveReader.bound(r['content'] as String,2000)).toList());
    }
    return null;
  }
  Future<void> consume(QqBatch b, QqPendingReply pending, {required bool cancel}) => store.write(b.fence, (sql) async {
    await sql.update('qq_reply_tasks', {'last_trigger_seq':b.through, 'valid':0,
      'stage':cancel?'cancelled':'continued','draft':''},where:'id=?',whereArgs:[pending.id]);
    final history=await BrainWorkFence.value(sql,QqFailure.historyKey);
    await sql.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',[QqFailure.historyKey,
      cancel?QqFailureHistory.finish(history,pending.id,'cancelled'):QqFailureHistory.link(history,pending.id,b.id)]);
    if (!cancel) {
      final fresh = (await sql.query('qq_reply_tasks',where:'id=?',whereArgs:[b.id],limit:1)).single;
      final combined = [...(jsonDecode(fresh['source_stamp'] as String) as List), ...pending.stamp];
      await sql.update('qq_reply_tasks', {'source_stamp':jsonEncode(combined),'addressed':1},where:'id=?',whereArgs:[b.id]);
    }
  });
}
