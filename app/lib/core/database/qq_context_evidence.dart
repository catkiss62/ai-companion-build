import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../integrations/qq_private/qq_archive_reader.dart';
import 'brain_work_fence.dart';

/// Small source contract passed from retrieval to the winning App commit.
/// QQ-derived expression is distinguishable from new App growth evidence.
class QqContextEvidence {
  const QqContextEvidence(this.stamps,this.fence,{this.additionalFences=const []});
  final List<Map<String,Object?>> stamps;
  final BrainWorkFence fence;
  final List<BrainWorkFence> additionalFences;
  static Future<QqContextEvidence> capture(DatabaseExecutor sql,List<Map<String,Object?>> stamps) async {
    final identity={for(final key in ['state_lineage_id','state_generation','runtime_state_epoch_v1',
      'conversation_context_reset_at','conversation_context_reset_count'])key:await BrainWorkFence.value(sql,key)};
    return QqContextEvidence(List.unmodifiable(stamps),BrainWorkFence(identity:identity));
  }
  static QqContextEvidence? merge(Iterable<QqContextEvidence?> values) {
    final sources=values.whereType<QqContextEvidence>().toList();if(sources.isEmpty) return null;
    final unique=<String,Map<String,Object?>>{};
    for(final source in sources) {for(final stamp in source.stamps) {unique[jsonEncode(stamp)]=stamp;}}
    return QqContextEvidence(unique.values.toList(),sources.first.fence,
      additionalFences:[for(final source in sources)...[source.fence,...source.additionalFences]]);
  }
  static Future<({String text,QqContextEvidence? evidence})> read(DatabaseExecutor sql,String query) async {
    final identity={for(final key in ['state_lineage_id','state_generation','runtime_state_epoch_v1',
      'conversation_context_reset_at','conversation_context_reset_count'])key:await BrainWorkFence.value(sql,key)};
    final stamps=<Map<String,Object?>>[];
    final text=await QqArchiveReader(sql).privateContext(query,stamp:stamps,
      resetAt:int.tryParse(identity['conversation_context_reset_at']??'')??0);
    return (text:text,evidence:stamps.isEmpty?null:QqContextEvidence(stamps,BrainWorkFence(identity:identity)));
  }
  Future<bool> matches(DatabaseExecutor sql) async {
    if(stamps.length>1200 || !await fence.matches(sql)) return false;
    for(final captured in additionalFences) {if(!await captured.matches(sql)) return false;}
    for(var at=0;at<stamps.length;at+=200) {
      if(!await QqArchiveReader(sql).matches(stamps.skip(at).take(200).toList())) return false;
    }
    return true;
  }
  Future<void> consume(DatabaseExecutor sql,String messageId,int revision,int at) async {
    await sql.insert('qq_receipts',{'id':'$messageId@$revision','message_id':messageId,'message_revision':revision,
      'source_stamp':jsonEncode(stamps),'created_at':at},conflictAlgorithm:ConflictAlgorithm.ignore);
  }
  static Future<bool> usedBy(DatabaseExecutor sql,String messageId,int revision) async {
    // Small legacy/source-store test databases need not own the QQ extension.
    if((await sql.rawQuery("SELECT 1 FROM sqlite_master WHERE type='table' AND name='qq_receipts' LIMIT 1")).isEmpty) return false;
    return (await sql.query('qq_receipts',columns:['id'],where:'message_id=? AND message_revision=?',whereArgs:[messageId,revision],limit:1)).isNotEmpty;
  }
}
