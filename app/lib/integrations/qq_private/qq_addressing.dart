import 'dart:convert';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'qq_store.dart';
import '../../core/database/brain_work_fence.dart';

/// A group member openid is learned only by correlating an incoming self echo
/// with an actual confirmed platform send id. Names and READY ids never cross
/// namespaces. If no verified group identity exists, addressing stays semantic.
class QqAddressing {
  QqAddressing(this.store,this.api);
  final QqStore store;
  final QqApi api;
  static final _at = RegExp(r'<@!?(\w[\w-]{0,127})>');
  Future<({bool mentioned,bool selfEcho})> inspect(Map<String,dynamic> event,BrainWorkFence fence,
      {required String scope,required String group}) async {
    final cid=QqStore.conversationId(scope,'group',group);
    final id=event['id'];final author=event['author'];
    final sender=author is Map?author['member_openid']:null;
    final key='qq_self_group_openid_v1:${QqStore.hash([scope,group])}';
    if(id is String && id.isNotEmpty && sender is String && sender.isNotEmpty) {
      final own=(await (await store.db.database).query('qq_archive',columns:['id'],
        where:"conversation_id=? AND role='assistant' AND platform_id=?",whereArgs:[cid,id],limit:1)).isNotEmpty;
      if(own || api.confirmedMessage(group:true,target:group,platformId:id)) {
        await store.write(fence,(sql) async {
          await sql.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',[key,jsonEncode(sender)]);
        });
        return (mentioned:false,selfEcho:true);
      }
    }
    if(event['_trusted_event_type']=='GROUP_AT_MESSAGE_CREATE')return (mentioned:true,selfEcho:false);
    if(event['_trusted_event_type']!='GROUP_MESSAGE_CREATE')return (mentioned:false,selfEcho:false);
    String self='';try {self=jsonDecode(await store.db.getSetting(key)??'""') as String;}catch(_){}
    final content=event['content'] is String?event['content'] as String:'';
    final tokens=_at.allMatches(content).map((m)=>m.group(1)!).toSet();
    final mentions=event['mentions'];
    final matched=self.isNotEmpty && tokens.contains(self) && mentions is List && mentions.whereType<Map>().any((m)=>
      m['id']==self || m['member_openid']==self || m['user_openid']==self);
    return (mentioned:matched,selfEcho:false);
  }
}
