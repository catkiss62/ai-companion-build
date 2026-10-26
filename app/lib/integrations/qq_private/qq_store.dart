import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/database/brain_work_fence.dart';
import '../../core/database/automatic_memory_permit.dart';
import 'qq_archive_reader.dart';

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
  static String hash(Object? o)=>sha256.convert(utf8.encode(jsonEncode(o))).toString();
  static String conversationId(String scope,String kind,String target)=>hash([scope,kind,target]);
  static const identityKeys=['state_lineage_id','state_generation','runtime_state_epoch_v1',
    'conversation_context_reset_at','conversation_context_reset_count','qq_context_policy_version_v1'];
  Future<BrainWorkFence> capture() async =>(await db.database).transaction((txn) async=>BrainWorkFence(identity:{
    for(final key in identityKeys)key:await BrainWorkFence.value(txn,key)}));
  Future<bool> current(BrainWorkFence fence) async=>fence.matches(await db.database);
  Future<T> write<T>(BrainWorkFence fence,Future<T> Function(Transaction) body) async=>
    (await db.database).transaction((txn) async {if(!await fence.matches(txn)) throw const BrainWorkInvalidated(); return body(txn);});
  Future<void> discover(BrainWorkFence fence,String scope,String kind,String target) =>write(fence,(txn) async {
    await txn.insert('qq_conversations',{'id':conversationId(scope,kind,target),'scope':scope,'kind':kind,'target':target},conflictAlgorithm:ConflictAlgorithm.ignore);
  });
  Future<int?> append({required BrainWorkFence fence,required String scope,required String kind,
    required String target,required String platformId,required String sender,required String text,
    required int observedAt,required int receivedAt,bool owner=false,bool mentioned=false,String replyTo='',int images=0,
    String role='user',String policy=''})=>write(fence,(txn) async {
      final cid=conversationId(scope,kind,target); final id=hash([scope,kind,target,platformId]);
      final existing=await txn.query('qq_archive',columns:['seq','mentioned'],where:'id = ?',whereArgs:[id],limit:1);
      if(existing.isNotEmpty) {
        if(mentioned && existing.single['mentioned']==0) {
          final changed=await txn.rawUpdate('UPDATE qq_archive SET mentioned=1 WHERE id=? AND seq>(SELECT checked_seq FROM qq_conversations WHERE id=?)',[id,cid]);
          if(changed>0) return existing.single['seq'] as int;
        }
        return null;
      }
      if((Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM qq_archive'))??0)>=250000) throw StateError('archive_full');
      await txn.insert('qq_conversations',{'id':cid,'scope':scope,'kind':kind,'target':target},conflictAlgorithm:ConflictAlgorithm.ignore);
      final seq=await txn.insert('qq_archive',{'id':id,'conversation_id':cid,'platform_id':platformId,'sender':sender,
        'owner':owner?1:0,'role':role,'content':QqArchiveReader.bound(text,16000),'observed_at':observedAt,'received_at':receivedAt,
        'mentioned':mentioned?1:0,'reply_to':replyTo,'accepted_identity':jsonEncode(fence.identity),'accepted_policy':policy});
      for(var i=0;i<images.clamp(0,8);i++) { await txn.insert('qq_images',{'id':'$id:$i','archive_seq':seq,'ordinal':i}); }
      return seq;
    });
  Future<List<Map<String,Object?>>> pending(String cid) async=>(await db.database).rawQuery(
    'SELECT a.* FROM qq_archive a JOIN qq_conversations c ON c.id=a.conversation_id '
    "WHERE c.id=? AND a.seq>c.checked_seq AND a.role='user' ORDER BY a.seq LIMIT 40",[cid]);
  Future<List<Map<String,Object?>>> conversations(String scope) async=>(await db.database).query('qq_conversations',where:'scope = ?',whereArgs:[scope],orderBy:'rowid DESC',limit:200);
  Future<List<Map<String,Object?>>> images(int seq) async=>(await db.database).query('qq_images',where:'archive_seq = ?',whereArgs:[seq],orderBy:'ordinal');
  Future<QqBatch?> claim(BrainWorkFence fence,String cid,int through,int now,{String policy=''})=>write(fence,(txn) async {
    final c=(await txn.query('qq_conversations',where:'id = ?',whereArgs:[cid],limit:1)).single;
    final checked=c['checked_seq'] as int;
    if(through<=checked) return null;
    final rows=await txn.query('qq_archive',where:"conversation_id=? AND seq>? AND seq<=? AND role='user'",whereArgs:[cid,checked,through],orderBy:'seq');
    final admitted=rows.where((r)=>r['accepted_identity']==jsonEncode(fence.identity) && r['accepted_policy']==policy).toList();
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
  Future<void> sentPart(QqBatch b,int part,String text,String sticker,int now)=>write(b.fence,(txn) async {
    if(!await QqArchiveReader(txn).matches([for(final r in b.rows){'table':'qq_archive','id':r['id'],'version':r['version']}])) throw const BrainWorkInvalidated();
    await txn.insert('qq_archive',{'id':'reply:${b.id}:$part','conversation_id':b.cid,'platform_id':'',
      'sender':'assistant','role':'assistant','content':text,'observed_at':now,'received_at':now},conflictAlgorithm:ConflictAlgorithm.ignore);
    if(sticker.isNotEmpty) {
      final row=(await txn.query('qq_archive',columns:['seq'],where:'id = ?',whereArgs:['reply:${b.id}:$part'],limit:1)).single;
      await txn.insert('qq_images',{'id':'reply:${b.id}:$part:image','archive_seq':row['seq'],'ordinal':0,'state':'viewed',
        'description':sticker,'fingerprint':''},conflictAlgorithm:ConflictAlgorithm.ignore);
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
  });
  Future<void> forget(BrainWorkFence fence,String cid)=>write(fence,(txn) async {
    await txn.rawDelete('DELETE FROM qq_shares WHERE note_id IN (SELECT id FROM qq_notes WHERE conversation_id=?)',[cid]);
    await txn.delete('qq_notes',where:'conversation_id=?',whereArgs:[cid]);
    await txn.delete('qq_deliveries',where:'conversation_id=?',whereArgs:[cid]);
    await txn.rawDelete('DELETE FROM qq_images WHERE archive_seq IN (SELECT seq FROM qq_archive WHERE conversation_id=?)',[cid]);
    await txn.delete('qq_archive',where:'conversation_id=?',whereArgs:[cid]);
    await txn.rawUpdate('UPDATE qq_conversations SET checked_seq=0,summary_seq=0,summary_checked_seq=0,version=version+1 WHERE id=?',[cid]);
  });
  Future<({List<Map<String,Object?>> rows,AutomaticMemoryPermit permit,String input,List<Map<String,Object?>> stamp})?> claimSummary(BrainWorkFence fence,String cid,{required bool idle})=>write(fence,(txn) async {
    final permit=await AutomaticMemoryPermit.capture(txn,'auto_memory');
    if(!permit.enabled) return null;
    final c=(await txn.query('qq_conversations',where:'id=?',whereArgs:[cid],limit:1)).single;
    final rows=await txn.query('qq_archive',where:'conversation_id=? AND seq>?',whereArgs:[cid,c['summary_checked_seq']],orderBy:'seq',limit:20);
    if(rows.isEmpty || !idle && rows.length<20) return null;
    final stamp=<Map<String,Object?>>[];
    final page=await QqArchiveReader(txn).projectRows(rows,maxChars:27500,stamp:stamp,newestFirst:false);
    if(page.count==0) return null;
    final included=rows.take(page.count).toList();
    await txn.update('qq_conversations',{'summary_checked_seq':included.last['seq']},where:'id=?',whereArgs:[cid]);
    return (rows:included,permit:permit,input:page.text,stamp:stamp);
  });
  Future<bool> saveNote(BrainWorkFence fence,String cid,List<Map<String,Object?>> rows,List<Map<String,Object?>> stamp,
    AutomaticMemoryPermit permit,String content,String share,int now)=>write(fence,(txn) async {
    if(!await permit.matches(txn) || !await QqArchiveReader(txn).matches(stamp)) return false;
    final through=rows.last['seq'] as int; final id=hash(['note',cid,through]);
    if(content.trim().isNotEmpty) {
      await txn.insert('qq_notes',{'id':id,'conversation_id':cid,'content':QqArchiveReader.bound(content,6000),
        'sources':jsonEncode(rows.map((r)=>r['seq']).toList()),'source_stamp':jsonEncode(stamp),'through_seq':through,'created_at':now},conflictAlgorithm:ConflictAlgorithm.ignore);
      if(share.trim().isNotEmpty) await txn.insert('qq_shares',{'id':id,'note_id':id,'state':'pending','content':QqArchiveReader.bound(share,1400),'updated_at':now},conflictAlgorithm:ConflictAlgorithm.ignore);
    }
    await txn.update('qq_conversations',{'summary_seq':through},where:'id=?',whereArgs:[cid]);
    return true;
  });
}
