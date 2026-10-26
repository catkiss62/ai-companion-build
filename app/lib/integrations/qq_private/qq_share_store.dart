import '../../core/database/app_database.dart';
import '../../core/database/brain_work_fence.dart';
import '../../core/database/qq_share_contract.dart';
import 'qq_archive_reader.dart';
import 'qq_options.dart';
import 'qq_private_config.dart';
import 'qq_store.dart';

/// One persisted ownership decision arbitrates App versus owner QQ. Unknown
/// sends never reappear on another entrance. This store never changes drives.
class QqShareStore {
  QqShareStore(this.db);
  final AppDatabase db;
  static String policyKey(String ns)=>'qq_options_policy_v2:$ns';
  Future<bool> prefersQq(DateTime now,QqPrivateConfig c) async {
    final sql=await db.database;final scope=QqStore.hash([c.appId,c.namespace,c.owner]);
    final qq=await sql.rawQuery("SELECT MAX(a.received_at) AS at FROM qq_archive a JOIN qq_conversations c ON c.id=a.conversation_id WHERE c.scope=? AND c.kind='private' AND a.role='user' AND a.owner=1",[scope]);
    final app=await sql.rawQuery("SELECT MAX(created_at) AS at FROM messages WHERE role='user'");
    final q=qq.single['at'] as int? ?? 0;final a=app.single['at'] as int? ?? 0;
    return q>a && q>now.subtract(const Duration(minutes:30)).millisecondsSinceEpoch;
  }
  Future<List<Map<String,Object?>>> candidates(DateTime now,{String destination='app'}) async {
    if(await db.getSetting('qq_master_enabled_v2')!='1') return [];
    try {return await _candidates(now,destination:destination);} catch(_) {return [];}
  }
  Future<List<Map<String,Object?>>> _candidates(DateTime now,{String destination='app'}) async {
    final c=await QqPrivateConfig.read();if(c.owner.isEmpty) return [];
    final o=await QqOptions.read(namespace:c.namespace);
    if(!o.ownerShare || await db.getSetting('qq_master_enabled_v2')!='1' ||
      await db.getSetting(policyKey(c.namespace))!=QqStore.hash(o.toJson()) || (await prefersQq(now,c))!=(destination=='qq')) return [];
    final sql=await db.database;
    final cooldown=await sql.rawQuery("SELECT 1 FROM qq_shares WHERE state IN ('sent','sending','send_uncertain','claimed','failed','permission_error') AND updated_at>? LIMIT 1",[now.subtract(const Duration(hours:6)).millisecondsSinceEpoch]);
    if(cooldown.isNotEmpty) return [];
    final rows=await sql.rawQuery('SELECT s.*,n.content AS memory,n.source_stamp,n.sources,n.valid,c.target '
      'FROM qq_shares s JOIN qq_notes n ON n.id=s.note_id JOIN qq_conversations c ON c.id=n.conversation_id '
      "JOIN qq_archive a ON a.seq=n.through_seq WHERE c.scope=? AND c.kind='group' AND s.state='pending' AND n.valid=1 AND a.observed_at>? ORDER BY s.updated_at DESC LIMIT 12",
      [QqStore.hash([c.appId,c.namespace,c.owner]),now.subtract(const Duration(hours:24)).millisecondsSinceEpoch]);
    final admitted=<Map<String,Object?>>[];final reader=QqArchiveReader(sql);
    for(final row in rows) {if(o.groups.contains(row['target']) && await reader.noteCurrent({...row,'content':row['memory']})) admitted.add(row);}
    return admitted.take(2).toList();
  }
  Future<QqShareOffer?> claim(String id,String destination,DateTime now,{BrainWorkFence? fence}) async {
    if(!const {'app','qq'}.contains(destination)) return null;
    final candidate=(await candidates(now,destination:destination)).where((r)=>r['id']==id).firstOrNull;
    if(candidate==null) return null;
    final c=await QqPrivateConfig.read();final o=await QqOptions.read(namespace:c.namespace);
    final captured=fence??await QqStore(db).capture();
    final offer=QqShareOffer(id:id,noteId:candidate['note_id'] as String,noteToken:QqArchiveReader.noteToken({...candidate,'content':candidate['memory']}),
      content:candidate['content'] as String,sourceMemory:candidate['memory'] as String,destination:destination,policyKey:policyKey(c.namespace),policyToken:QqStore.hash(o.toJson()),fence:captured);
    return (await db.database).transaction((txn) async {
      if(!await captured.matches(txn) || await BrainWorkFence.value(txn,offer.policyKey)!=offer.policyToken ||
          await BrainWorkFence.value(txn,'qq_master_enabled_v2')!='1' || !await offer.evidence.matches(txn)) return null;
      final other=await txn.rawQuery("SELECT 1 FROM qq_shares WHERE state IN ('sent','sending','send_uncertain','claimed','failed','permission_error') AND updated_at>? LIMIT 1",[now.subtract(const Duration(hours:6)).millisecondsSinceEpoch]);
      if(other.isNotEmpty) return null;
      final count=await txn.update('qq_shares',{'state':'claimed','destination':destination,'updated_at':now.millisecondsSinceEpoch},where:'id=? AND state=?',whereArgs:[id,'pending']);
      return count==1?offer:null;
    });
  }
}
