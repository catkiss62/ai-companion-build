import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/database/brain_work_fence.dart';
import '../../core/database/automatic_memory_permit.dart';
import '../../core/qq/qq_message_material.dart';
import 'qq_archive_reader.dart';
import 'qq_work_queue.dart';
import 'qq_failure.dart';

class QqBatch {
  QqBatch(this.id,this.conversation,this.rows,this.fence);
  final String id;
  final Map<String,Object?> conversation;
  final List<Map<String,Object?>> rows;
  final BrainWorkFence fence;
  String get cid=>conversation['id'] as String;
  String get target=>conversation['target'] as String;
  bool get group=>conversation['kind']=='group';
  int get through=>rows.last['seq'] as int;
}

/// The host owns all writes. Protocol code never receives this database handle.
/// No main-message rows, memory-extractor, Desire or learning calls occur here.
class QqStore {
  QqStore(this.db);
  final AppDatabase db;
  Future<void> recordFailure(BrainWorkFence fence,String phase,Object error,{int attempt=1,int elapsedMs=0}) async {
    try {
      await write(fence,(txn) async {
        final raw=await BrainWorkFence.value(txn,QqFailure.historyKey);
        List entries=[];try {final decoded=jsonDecode(raw);if(decoded is List)entries=decoded.take(11).toList();}catch(_){}
        final entry={'at':DateTime.now().millisecondsSinceEpoch,'phase':phase,'code':QqFailure.code(error),
          'attempt':attempt,'elapsed_ms':elapsedMs};
        await txn.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',[QqFailure.historyKey,jsonEncode([entry,...entries])]);
      });
    } catch(_) { /* A diagnostic must not replace the original failure. */ }
  }
  static String hash(Object? o)=>sha256.convert(utf8.encode(jsonEncode(o))).toString();
  static String conversationId(String scope,String kind,String target)=>hash([scope,kind,target]);
  static const identityKeys=['state_lineage_id','state_generation','runtime_state_epoch_v1',
    'conversation_context_reset_at','conversation_context_reset_count','qq_context_policy_version_v1'];
  /// Ingress ownership is stable across ordinary note edits. Output work still
  /// captures the conversation epoch and is invalidated by derived-data edits.
  static String ingressIdentity(BrainWorkFence fence)=>jsonEncode({for(final key in identityKeys)key:fence.identity[key]??''});
  static bool acceptsIngress(String raw,BrainWorkFence fence) {
    try {final value=jsonDecode(raw);return value is Map && identityKeys.every((key)=>(value[key]??'')==(fence.identity[key]??''));}
    catch(_){return false;}
  }
  Future<BrainWorkFence> capture({String? conversationId}) async =>(await db.database).transaction((txn) async=>BrainWorkFence(identity:{
    for(final key in [...identityKeys,if(conversationId!=null)'qq_archive_epoch_v1:$conversationId'])key:await BrainWorkFence.value(txn,key)}));
  Future<bool> current(BrainWorkFence fence) async=>fence.matches(await db.database);
  Future<T> write<T>(BrainWorkFence fence,Future<T> Function(Transaction) body) async=>
    (await db.database).transaction((txn) async {if(!await fence.matches(txn)) throw const BrainWorkInvalidated(); return body(txn);});
  Future<void> discover(BrainWorkFence fence,String scope,String kind,String target) =>write(fence,(txn) async {
    await txn.insert('qq_conversations',{'id':conversationId(scope,kind,target),'scope':scope,'kind':kind,'target':target},conflictAlgorithm:ConflictAlgorithm.ignore);
  });
  Future<int?> append({required BrainWorkFence fence,required String scope,required String kind,
    required String target,required String platformId,required String sender,required String text,
    required int observedAt,required int receivedAt,bool owner=false,bool mentioned=false,String replyTo='',int images=0,
    String role='user',String policy='',String contextMeta=''})=>write(fence,(txn) async {
      QqMessageMaterial.decode(contextMeta);
      final cid=conversationId(scope,kind,target); final id=hash([scope,kind,target,platformId]);
      final existing=await txn.query('qq_archive',columns:['seq','mentioned'],where:'id = ?',whereArgs:[id],limit:1);
      if(existing.isNotEmpty) {
        if(mentioned && existing.single['mentioned']==0) {
          final changed=await txn.rawUpdate('UPDATE qq_archive SET mentioned=1 WHERE id=? AND seq>(SELECT checked_seq FROM qq_conversations WHERE id=?)',[id,cid]);
          if(changed>0) return existing.single['seq'] as int;
        }
        return null;
      }
      if(role=='user') {
        await txn.delete('qq_ingress',where:'expires_at<?',whereArgs:[receivedAt]);
        if((await txn.query('qq_ingress',columns:['id'],where:'id=?',whereArgs:[id],limit:1)).isNotEmpty)return null;
        await txn.insert('qq_ingress',{'id':id,'expires_at':receivedAt+const Duration(days:1).inMilliseconds});
      }
      if((Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM qq_archive'))??0)>=250000) throw StateError('archive_full');
      await txn.insert('qq_conversations',{'id':cid,'scope':scope,'kind':kind,'target':target},conflictAlgorithm:ConflictAlgorithm.ignore);
      await txn.rawInsert('INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)',['qq_style_cursor_v1:$cid','0']);
      final seq=await txn.insert('qq_archive',{'id':id,'conversation_id':cid,'platform_id':platformId,'sender':sender,
        'owner':owner?1:0,'role':role,'content':QqArchiveReader.bound(text,16000),'context_meta':contextMeta,'observed_at':observedAt,'received_at':receivedAt,
        'mentioned':mentioned?1:0,'reply_to':replyTo,'accepted_identity':ingressIdentity(fence),'accepted_policy':policy});
      for(var i=0;i<images.clamp(0,8);i++) { await txn.insert('qq_images',{'id':'$id:$i','archive_seq':seq,'ordinal':i}); }
      return seq;
    });
  Future<List<Map<String,Object?>>> pending(String cid) async=>(await db.database).rawQuery(
    'SELECT a.* FROM qq_archive a JOIN qq_conversations c ON c.id=a.conversation_id '
    "WHERE c.id=? AND a.seq>c.checked_seq AND a.role='user' ORDER BY a.seq LIMIT 40",[cid]);
  Future<List<Map<String,Object?>>> conversations(String scope) async=>(await db.database).query('qq_conversations',where:'scope = ?',whereArgs:[scope],orderBy:'rowid DESC',limit:200);
  Future<List<Map<String,Object?>>> images(int seq) async=>(await db.database).query('qq_images',where:'archive_seq = ?',whereArgs:[seq],orderBy:'ordinal');
  Future<QqBatch?> claim(BrainWorkFence fence,String cid,int through,int now,{String policy='',String authorityKey='',String authority=''})=>write(fence,(txn) async {
    if(authorityKey.isNotEmpty) {final stored=await BrainWorkFence.value(txn,authorityKey);if(stored.isNotEmpty && stored!=authority)return null;}
    final c=(await txn.query('qq_conversations',where:'id = ?',whereArgs:[cid],limit:1)).single;
    final checked=c['checked_seq'] as int;
    if(through<=checked) return null;
    final rows=await txn.query('qq_archive',where:"conversation_id=? AND seq>? AND seq<=? AND role='user'",whereArgs:[cid,checked,through],orderBy:'seq');
    final admitted=rows.where((r)=>acceptsIngress(r['accepted_identity'] as String,fence) && r['accepted_policy']==policy).toList();
    if(admitted.isEmpty) { await txn.update('qq_conversations',{'checked_seq':through},where:'id=?',whereArgs:[cid]); return null; }
    final id=hash([cid,through]);
    await txn.update('qq_conversations',{'checked_seq':through},where:'id = ?',whereArgs:[cid]);
    await txn.insert('qq_deliveries',{'id':id,'conversation_id':cid,'through_seq':through,'state':'checking','updated_at':now});
    return QqBatch(id,c,admitted,fence);
  });
  Future<void> mark(QqBatch b,String state,{String? text,String? sticker})=>write(b.fence,(txn) async {
    await txn.update('qq_deliveries',{'state':state,'updated_at':DateTime.now().millisecondsSinceEpoch,
      if(text!=null)'content':text,if(sticker!=null)'sticker_key':sticker},where:'id = ?',whereArgs:[b.id]);
  });
  Future<void> sentPart(QqBatch b,int part,String text,String sticker,int now,{String sketchSvg='',String voiceLanguage=''})=>write(b.fence,(txn) async {
    if(!await QqArchiveReader(txn).matches([for(final r in b.rows){'table':'qq_archive','id':r['id'],'version':r['version']}])) throw const BrainWorkInvalidated();
    await txn.insert('qq_archive',{'id':'reply:${b.id}:$part','conversation_id':b.cid,'platform_id':'',
      'sender':'assistant','role':'assistant','content':text,'observed_at':now,'received_at':now},conflictAlgorithm:ConflictAlgorithm.ignore);
    if(sticker.isNotEmpty) {
      final row=(await txn.query('qq_archive',columns:['seq'],where:'id = ?',whereArgs:['reply:${b.id}:$part'],limit:1)).single;
      await txn.insert('qq_images',{'id':'reply:${b.id}:$part:image','archive_seq':row['seq'],'ordinal':0,'state':'viewed',
        'description':sticker,'fingerprint':''},conflictAlgorithm:ConflictAlgorithm.ignore);
    }
    if(sketchSvg.isNotEmpty) {
      final row=(await txn.query('qq_archive',columns:['seq'],where:'id=?',whereArgs:['reply:${b.id}:$part'],limit:1)).single;
      await txn.insert('qq_sketches',{'id':'sketch:${b.id}:$part','archive_seq':row['seq'],'svg':sketchSvg,'description':sticker,'created_at':now},conflictAlgorithm:ConflictAlgorithm.ignore);
    }
    if(voiceLanguage.isNotEmpty) {
      if(!const {'zh','ja','en'}.contains(voiceLanguage) || text.trim().isEmpty || sticker.isNotEmpty || sketchSvg.isNotEmpty)throw const FormatException('voice_archive');
      final row=(await txn.query('qq_archive',columns:['seq'],where:'id=?',whereArgs:['reply:${b.id}:$part'],limit:1)).single;
      await txn.insert('qq_voices',{'id':'voice:${b.id}:$part','archive_seq':row['seq'],'language':voiceLanguage,'created_at':now},conflictAlgorithm:ConflictAlgorithm.ignore);
    }
    await txn.update('qq_conversations',{'last_reply_at':now},where:'id = ?',whereArgs:[b.cid]);
  });
  Future<void> observation(BrainWorkFence fence,String id,String state,String text,String fingerprint)=>write(fence,(txn) async {
    await txn.rawUpdate('UPDATE qq_images SET state=?,description=?,fingerprint=?,version=version+1 WHERE id=?',[state,QqArchiveReader.bound(text,2200),fingerprint,id]);
  });
  Future<String?> cachedImage(String cid,String fingerprint) async {
    final rows=await (await db.database).rawQuery('SELECT i.description FROM qq_images i JOIN qq_archive a ON a.seq=i.archive_seq '
      "WHERE a.conversation_id=? AND i.fingerprint=? AND i.state='viewed' ORDER BY a.seq DESC LIMIT 1",[cid,fingerprint]);
    return rows.isEmpty?null:rows.single['description'] as String;
  }
  Future<int> groupRepliesSince(int since) async=>Sqflite.firstIntValue(await (await db.database).rawQuery(
    "SELECT COUNT(*) FROM qq_deliveries d JOIN qq_conversations c ON c.id=d.conversation_id WHERE c.kind='group' AND d.state IN ('sent','sending','send_uncertain') AND d.updated_at>?",[since]))??0;
  Future<void> recover(BrainWorkFence fence)=>write(fence,(txn) async {
    await txn.execute("UPDATE qq_deliveries SET state=CASE WHEN state='sending' THEN 'send_uncertain' ELSE 'interrupted' END WHERE state IN ('checking','generating','generated','sending')");
    await txn.execute("UPDATE qq_shares SET state=CASE WHEN state='sending' THEN 'send_uncertain' ELSE 'interrupted' END WHERE state IN ('claimed','sending')");
    final now=DateTime.now().millisecondsSinceEpoch;
    await txn.rawUpdate("UPDATE qq_work_items SET state=CASE WHEN attempts>=3 THEN 'failed' ELSE 'pending' END,run_token='',next_at=MAX(next_at,?+120000),updated_at=? WHERE state='running'",[now,now]);
  });
  Future<void> forget(BrainWorkFence fence,String cid)=>write(fence,(txn) async {
    await txn.rawDelete('DELETE FROM qq_shares WHERE note_id IN (SELECT id FROM qq_notes WHERE conversation_id=?)',[cid]);
    await txn.delete('qq_notes',where:'conversation_id=?',whereArgs:[cid]);
    await txn.delete('qq_deliveries',where:'conversation_id=?',whereArgs:[cid]);
    await txn.rawDelete('DELETE FROM qq_images WHERE archive_seq IN (SELECT seq FROM qq_archive WHERE conversation_id=?)',[cid]);
    await txn.delete('qq_work_items',where:'conversation_id=?',whereArgs:[cid]);
    await txn.delete('qq_styles',where:'conversation_id=?',whereArgs:[cid]);
    await txn.rawDelete('DELETE FROM qq_sketches WHERE archive_seq IN (SELECT seq FROM qq_archive WHERE conversation_id=?)',[cid]);
    await txn.rawDelete('DELETE FROM qq_voices WHERE archive_seq IN (SELECT seq FROM qq_archive WHERE conversation_id=?)',[cid]);
    await txn.delete('qq_archive',where:'conversation_id=?',whereArgs:[cid]);
    await txn.rawUpdate('UPDATE qq_conversations SET checked_seq=0,summary_seq=0,summary_checked_seq=0,version=version+1 WHERE id=?',[cid]);
    final epoch='qq_archive_epoch_v1:$cid';
    await txn.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',[epoch,'${(int.tryParse(await BrainWorkFence.value(txn,epoch))??0)+1}']);
  });
  Future<({List<Map<String,Object?>> rows,AutomaticMemoryPermit permit,String input,List<Map<String,Object?>> stamp,String repairId,int repairRevision,int conversationVersion,String workId,String runToken})?> claimSummary(BrainWorkFence fence,String cid,{required bool idle,int? at})=>write(fence,(txn) async {
    final now=at??DateTime.now().millisecondsSinceEpoch;
    final active=await AutomaticMemoryPermit.capture(txn,'auto_memory');
    if(!active.enabled) return null;
    final c=(await txn.query('qq_conversations',where:'id=?',whereArgs:[cid],limit:1)).single;
    var job=await QqWorkQueue.due(txn,cid,'summary',now);
    Map<String,Object?>? repair;
    List<Map<String,Object?>> rows;
    AutomaticMemoryPermit permit=active;
    if(job!=null) {
      final meta=jsonDecode(job['permit'] as String) as Map;
      final saved=AutomaticMemoryPermit.decode(meta['memory']);
      if(saved==null || !await saved.matches(txn) || !acceptsIngress(job['identity'] as String,fence)) {
        await QqWorkQueue.cancel(txn,job['id'] as String,now);return null;
      }
      permit=saved;
      final repairId=meta['repairId'] as String? ?? '';
      if(repairId.isNotEmpty) {
        repair=(await txn.query('qq_notes',where:'id=? AND conversation_id=? AND valid=0 AND revision=?',whereArgs:[repairId,cid,meta['repairRevision']],limit:1)).firstOrNull;
        if(repair==null) {await QqWorkQueue.cancel(txn,job['id'] as String,now);return null;}
      }
      final ids=(jsonDecode(job['sources'] as String) as List).cast<int>();
      rows=await txn.query('qq_archive',where:'conversation_id=? AND seq IN (${List.filled(ids.length,'?').join(',')})',whereArgs:[cid,...ids],orderBy:'seq');
      if(rows.length!=ids.length) {await QqWorkQueue.cancel(txn,job['id'] as String,now);return null;}
    } else {
      repair=(await txn.query('qq_notes',where:'conversation_id=? AND valid=0',whereArgs:[cid],orderBy:'created_at,id',limit:1)).firstOrNull;
      final ids=repair==null?<int>[]:(jsonDecode(repair['sources'] as String) as List).cast<int>();
      rows=await txn.query('qq_archive',where:repair==null?'conversation_id=? AND seq>?':'conversation_id=? AND seq IN (${List.filled(ids.length,'?').join(',')})',whereArgs:repair==null?[cid,c['summary_checked_seq']]:[cid,...ids],orderBy:'seq',limit:20);
      if(rows.isEmpty || repair==null && !idle && rows.length<20) return null;
      final first=DateTime.fromMillisecondsSinceEpoch(rows.first['observed_at'] as int);
      rows=rows.takeWhile((r) {final d=DateTime.fromMillisecondsSinceEpoch(r['observed_at'] as int);return d.year==first.year && d.month==first.month;}).toList();
    }
    // Include whole messages. A partial display page is not proof that its
    // hidden tail was summarized; one unusually long source remains intact.
    final stamp=<Map<String,Object?>>[],included=<Map<String,Object?>>[],blocks=<String>[];
    var length=0;
    for(final row in rows) {
      final proof=<Map<String,Object?>>[];
      final block=await QqArchiveReader(txn).render(row,stamp:proof);
      if(job==null && included.isNotEmpty && length+block.length>27500) break;
      included.add(row);blocks.add(block);stamp.addAll(proof);length+=block.length;
    }
    if(included.isEmpty)return null;
    final repairId=repair?['id'] as String? ?? '',revision=repair?['revision'] as int? ?? 0;
    final id=job?['id'] as String? ?? await QqWorkQueue.register(txn,kind:'summary',cid:cid,sources:[for(final r in included)r['seq'] as int],identity:ingressIdentity(fence),permit:{'memory':permit.toJson(),'repairId':repairId,'repairRevision':revision},repair:'$repairId:$revision',now:now);
    final token=await QqWorkQueue.begin(txn,id,now);if(token==null)return null;
    if(job==null && repair==null)await txn.update('qq_conversations',{'summary_checked_seq':included.last['seq']},where:'id=?',whereArgs:[cid]);
    return (rows:included,permit:permit,input:blocks.join('\n'),stamp:stamp,repairId:repairId,repairRevision:revision,conversationVersion:c['version'] as int,workId:id,runToken:token);
  });
  Future<bool> saveNote(BrainWorkFence fence,String cid,List<Map<String,Object?>> rows,List<Map<String,Object?>> stamp,
    AutomaticMemoryPermit permit,String content,String share,int now,{String repairId='',int repairRevision=0,int? conversationVersion,String workId='',String runToken=''})=>write(fence,(txn) async {
    if(workId.isNotEmpty && !await QqWorkQueue.current(txn,workId,runToken))return false;
    if(!await permit.matches(txn) || !await QqArchiveReader(txn).matches(stamp)) return false;
    final c=(await txn.query('qq_conversations',where:'id=?',whereArgs:[cid],limit:1)).firstOrNull;
    if(c==null || conversationVersion!=null && c['version']!=conversationVersion) return false;
    final through=rows.last['seq'] as int; final id=hash(['note',cid,through]);
    if(repairId.isNotEmpty) {
      final repairs=await txn.query('qq_notes',where:'id=? AND conversation_id=? AND valid=0 AND revision=?',
        whereArgs:[repairId,cid,repairRevision],limit:1);
      if(repairs.isEmpty) return false;
      final covered=rows.map((r)=>r['seq']).toSet();
      final left=(jsonDecode(repairs.single['sources'] as String) as List).cast<int>().where((id)=>!covered.contains(id)).toList();
      if(left.isEmpty) {await txn.delete('qq_notes',where:'id=?',whereArgs:[repairId]);}
      else {
        final range=(await txn.rawQuery('SELECT MIN(observed_at) AS first,MAX(observed_at) AS last FROM qq_archive WHERE conversation_id=? AND seq IN (${List.filled(left.length,'?').join(',')})',[cid,...left])).single;
        await txn.update('qq_notes',{'sources':jsonEncode(left),'range_start':range['first'],'range_end':range['last'],
          'through_seq':left.reduce((a,b)=>a>b?a:b),'revision':repairRevision+1},where:'id=?',whereArgs:[repairId]);
      }
    }
    if(content.trim().isNotEmpty) {
      final times=rows.map((r)=>r['observed_at'] as int).toList()..sort();
      await txn.insert('qq_notes',{'id':id,'conversation_id':cid,'content':QqArchiveReader.bound(content,6000),
        'sources':jsonEncode(rows.map((r)=>r['seq']).toList()),'source_stamp':jsonEncode(stamp),'through_seq':through,'created_at':now,
        'range_start':times.first,'range_end':times.last,'revision':repairId==id?repairRevision+1:1},conflictAlgorithm:ConflictAlgorithm.ignore);
      if(repairId.isEmpty && share.trim().isNotEmpty) await txn.insert('qq_shares',{'id':id,'note_id':id,'state':'pending',
        'content':QqArchiveReader.bound(share,1400),'updated_at':now},conflictAlgorithm:ConflictAlgorithm.ignore);
    }
    if(repairId.isEmpty) await txn.rawUpdate('UPDATE qq_conversations SET summary_seq=MAX(summary_seq,?) WHERE id=?',[through,cid]);
    if(workId.isNotEmpty)await QqWorkQueue.complete(txn,workId,runToken,now);
    return true;
  });
}
