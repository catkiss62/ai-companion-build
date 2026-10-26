import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/database/automatic_memory_permit.dart';
import '../../core/database/brain_work_fence.dart';

/// Durable, bounded background work inside QQ. It never queues participation
/// decisions or outbound retries. Empty successful extraction is completion.
abstract final class QqWorkQueue {
  static String id(String kind,String cid,List<int> sources,String repair)=>sha256.convert(utf8.encode(jsonEncode([kind,cid,sources,repair]))).toString();
  static Future<Map<String,Object?>?> due(DatabaseExecutor sql,String cid,String kind,int now) async =>
    (await sql.query('qq_work_items',where:"conversation_id=? AND kind=? AND state='pending' AND next_at<=?",whereArgs:[cid,kind,now],orderBy:'created_at,id',limit:1)).firstOrNull;
  static Future<String> register(DatabaseExecutor sql,{required String kind,required String cid,required List<int> sources,
    required String identity,required Map<String,Object?> permit,String repair='',required int now}) async {
    final key=id(kind,cid,sources,repair);
    await sql.insert('qq_work_items',{'id':key,'conversation_id':cid,'kind':kind,'sources':jsonEncode(sources),
      'identity':identity,'permit':jsonEncode(permit),'state':'pending','created_at':now,'updated_at':now},conflictAlgorithm:ConflictAlgorithm.ignore);
    return key;
  }
  static Future<String?> begin(DatabaseExecutor sql,String id,int now) async {
    final token=sha256.convert(utf8.encode('$id:$now:${DateTime.now().microsecondsSinceEpoch}')).toString();
    final changed=await sql.rawUpdate("UPDATE qq_work_items SET state='running',attempts=attempts+1,run_token=?,updated_at=? WHERE id=? AND state='pending' AND attempts<3 AND next_at<=?",[token,now,id,now]);
    return changed==1?token:null;
  }
  static Future<bool> current(DatabaseExecutor sql,String id,String token) async=>
    (await sql.query('qq_work_items',columns:['id'],where:"id=? AND state='running' AND run_token=?",whereArgs:[id,token],limit:1)).isNotEmpty;
  static Future<void> complete(DatabaseExecutor sql,String id,String token,int now) async {
    await sql.update('qq_work_items',{'state':'complete','run_token':'','updated_at':now},where:"id=? AND state='running' AND run_token=?",whereArgs:[id,token]);
  }
  static Future<void> fail(AppDatabase db,String id,String token,int now) async {
    final sql=await db.database;
    await sql.rawUpdate("UPDATE qq_work_items SET state=CASE WHEN attempts>=3 THEN 'failed' ELSE 'pending' END,next_at=?+CASE WHEN attempts<2 THEN 120000 ELSE 600000 END,run_token='',updated_at=? WHERE id=? AND state='running' AND run_token=?",[now,now,id,token]);
  }
  static Future<void> cancel(DatabaseExecutor sql,String id,int now) async {
    await sql.update('qq_work_items',{'state':'cancelled','run_token':'','updated_at':now},where:'id=?',whereArgs:[id]);
  }
  static Future<void> removeSources(DatabaseExecutor sql,String cid,Set<int> deleted) async {
    for(final row in await sql.query('qq_work_items',where:'conversation_id=?',whereArgs:[cid])) {
      final sources=(jsonDecode(row['sources'] as String) as List).cast<int>();
      if(!sources.any(deleted.contains))continue;
      await sql.delete('qq_work_items',where:'id=?',whereArgs:[row['id']]);
      final keep=sources.where((id)=>!deleted.contains(id)).toList();
      final meta=jsonDecode(row['permit'] as String) as Map;
      // Repairs are re-created from the surviving note revision. Completed work
      // stays consumed; removing data never grants permission to relearn it.
      if(keep.isNotEmpty && ['pending','running','failed'].contains(row['state']) && (meta['repairId']??'')=='') {
        await sql.insert('qq_work_items',{...row,'id':id(row['kind'] as String,cid,keep,''),'sources':jsonEncode(keep),
          'state':row['state']=='running'?(row['attempts'] as int>=3?'failed':'pending'):row['state'],'run_token':''},conflictAlgorithm:ConflictAlgorithm.ignore);
      }
    }
    for(final row in await sql.query('qq_styles',where:'conversation_id=?',whereArgs:[cid])) {
      if((jsonDecode(row['sources'] as String) as List).any(deleted.contains))await sql.delete('qq_styles',where:'id=?',whereArgs:[row['id']]);
    }
  }
  static Future<int?> nextDue(AppDatabase db,String cid) async {
    final rows=await (await db.database).rawQuery("SELECT MIN(next_at) AS at FROM qq_work_items WHERE conversation_id=? AND state='pending'",[cid]);
    return rows.single['at'] as int?;
  }
  static Future<int> retrySummary(AppDatabase db,String cid) async {
    final sql=await db.database;
    return sql.transaction((txn) async {
      final permit=await AutomaticMemoryPermit.capture(txn,'auto_memory');if(!permit.enabled)throw StateError('auto_memory_off');
      var count=0;
      for(final row in await txn.query('qq_work_items',where:"conversation_id=? AND kind='summary' AND state='failed'",whereArgs:[cid])) {
        final identity=(jsonDecode(row['identity'] as String) as Map).cast<String,String>();
        if(!await BrainWorkFence(identity:identity).matches(txn))continue;
        final meta=(jsonDecode(row['permit'] as String) as Map).cast<String,Object?>();meta['memory']=permit.toJson();
        count+=await txn.update('qq_work_items',{'state':'pending','attempts':0,'next_at':0,'run_token':'','permit':jsonEncode(meta)},where:'id=?',whereArgs:[row['id']]);
      }
      return count;
    });
  }
}
