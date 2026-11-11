import 'dart:convert';
import '../../core/database/brain_work_fence.dart';
import 'qq_archive_reader.dart';
import 'qq_reply_tasks.dart';
import 'qq_store.dart';

/// Only unsent work can be retried without a fresh platform message.
/// Retain the original message's four-minute response deadline and identity.
class QqReplyRecovery {
  QqReplyRecovery(this.store);
  final QqStore store;
  static const windowMs = 240000;
  static const key = 'automatic_retry_v1';
  static Map<String,dynamic> decode(Object? raw) {
    try { return Map<String,dynamic>.from(jsonDecode(raw as String) as Map); }
    catch (_) { return {}; }
  }
  static bool unsent(Map<String,Object?> row) {
    if (!const {'failed','interrupted','checking','generating','generated'}.contains(row['stage'])) return false;
    final raw=row['draft'];
    if(raw is String && raw.isNotEmpty) {try {if(jsonDecode(raw) is! Map)return false;}catch(_){return false;}}
    final draft=decode(raw);
    for(final name in ['delivery','inherited_delivery']) {
      final delivery=draft[name];
      if(delivery is Map && (delivery['unknown']==true || (delivery['confirmed'] as List? ?? []).isNotEmpty)) return false;
    }
    return true;
  }
  Future<bool> defer(QqBatch b,int now) => store.write(b.fence,(sql) async {
    final rows=await sql.query('qq_reply_tasks',where:'id=? AND valid=1',whereArgs:[b.id],limit:1);
    if(rows.isEmpty || !unsent(rows.single))return false;
    final row=rows.single,draft=decode(row['draft']);
    final attempts=(draft[key] is Map ? (draft[key] as Map)['attempts'] as num? : null)?.toInt() ?? 0;
    final delay=attempts==0?15000:attempts==1?30000:60000;
    if(now+delay >= (row['source_at'] as int)+windowMs)return false;
    draft[key]={'attempts':attempts,'next_at':now+delay};
    await sql.update('qq_reply_tasks',{'draft':jsonEncode(draft)},where:'id=?',whereArgs:[b.id]);
    return true;
  });

  /// Reconcile only conversations that have no live owner in this engine.
  /// A send interrupted by backup/process death remains unknown, never queued.
  Future<Set<String>> due(BrainWorkFence fence,int now,Set<String> active) => store.write(fence,(sql) async {
    final result=<String>{};
    final rows=await sql.query('qq_reply_tasks',where:"valid=1 AND source_at>? AND stage IN ('failed','interrupted','checking','generating','generated','sending','sent_archive_pending')",
      whereArgs:[now-windowMs],orderBy:'source_at DESC',limit:200);
    for(final row in rows) {
      final cid=row['conversation_id'] as String;
      if(active.contains(cid) || !QqStore.acceptsIngress(row['identity'] as String,fence))continue;
      final stage=row['stage'] as String;
      if(stage=='sending' || stage=='sent_archive_pending') {
        final state=stage=='sending'?'send_uncertain':'sent_archive_failed';
        await sql.update('qq_reply_tasks',{'stage':state,'updated_at':now},where:'id=?',whereArgs:[row['id']]);
        await sql.update('qq_deliveries',{'state':state,'updated_at':now},where:'id=?',whereArgs:[row['id']]);
        continue;
      }
      if(!unsent(row))continue;
      final draft=decode(row['draft']);
      if(stage!='failed' && draft[key] is! Map) {
        draft[key]={'attempts':0,'next_at':now};
        await sql.update('qq_reply_tasks',{'stage':'interrupted','draft':jsonEncode(draft),'updated_at':now},where:'id=?',whereArgs:[row['id']]);
      }
      if(draft[key] is Map && ((draft[key] as Map)['next_at'] as num? ?? now+1)<=now)result.add(cid);
    }
    return result;
  });

  Future<QqBatch?> claim(BrainWorkFence fence,String cid,int now,String policy) => store.write(fence,(sql) async {
    final rows=await sql.query('qq_reply_tasks',where:"conversation_id=? AND valid=1 AND stage IN ('failed','interrupted') AND source_at>?",
      whereArgs:[cid,now-windowMs],orderBy:'source_at DESC',limit:8);
    for(final row in rows) {
      if(row['policy']!=policy || !QqStore.acceptsIngress(row['identity'] as String,fence) || !unsent(row))continue;
      final draft=decode(row['draft']),retry=draft[key];
      if(retry is! Map || (retry['next_at'] as num? ?? now+1)>now)continue;
      final later=await sql.query('qq_archive',columns:['seq'],where:"conversation_id=? AND role='user' AND seq>?",whereArgs:[cid,row['through_seq']],limit:1);
      if(later.isNotEmpty)continue; // Let the new batch judge continuation/cancel.
      final stamps=(jsonDecode(row['source_stamp'] as String) as List).map((x)=>Map<String,Object?>.from(x as Map)).toList();
      if(!await QqArchiveReader(sql).matches(stamps))continue;
      final ids=(jsonDecode(row['sources'] as String) as List).cast<int>();
      if(ids.isEmpty || ids.length>80)continue;
      final original=await sql.query('qq_archive',where:"conversation_id=? AND role='user' AND seq IN (${List.filled(ids.length,'?').join(',')})",whereArgs:[cid,...ids],orderBy:'seq');
      if(original.length!=ids.length)continue;
      final conversation=(await sql.query('qq_conversations',where:'id=?',whereArgs:[cid],limit:1)).single;
      // New attempt recomputes context. Keep the paid work reservation
      // even though the prepared reply and its media are no longer available.
      final next={key:{'attempts':((retry['attempts'] as num?)?.toInt() ?? 0)+1,'next_at':0},
        if(draft[QqReplyTasks.illustrationStartedKey]==true)QqReplyTasks.illustrationStartedKey:true};
      await sql.update('qq_reply_tasks',{'stage':'checking','draft':jsonEncode(next),'updated_at':now},where:'id=?',whereArgs:[row['id']]);
      await sql.update('qq_deliveries',{'state':'checking','updated_at':now},where:'id=?',whereArgs:[row['id']]);
      return QqBatch(row['id'] as String,conversation,original,fence);
    }
    return null;
  });
}
