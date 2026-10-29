import 'dart:convert';
import 'dart:typed_data';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'qq_archive_reader.dart';
import 'qq_failure.dart';
import 'qq_store.dart';
import 'qq_reply_tasks.dart';

class QqEchoChoice {
  const QqEchoChoice(this.only);
  final bool only;
  static final tag=RegExp(r'<qq_echo\s+mode="(only|with_text)">e1</qq_echo>',caseSensitive:false);
  static QqEchoChoice? parse(String raw) {
    final matches=tag.allMatches(raw).toList();
    return matches.length==1?QqEchoChoice(matches.single.group(1)!.toLowerCase()=='only'):null;
  }
  static String visible(String raw)=>raw.replaceAll(tag,'').replaceAll(RegExp(r'<qq_echo\b[\s\S]*$',caseSensitive:false),'').trim();
}
class _EchoImage {
  _EchoImage(this.cid,this.row,this.image,this.hash,this.mime,this.at,this.bytes);
  final String cid,hash,mime;final int at;
  final Map<String,Object?> row,image;Uint8List? bytes;
}
class QqEchoCandidate {
  QqEchoCandidate(this.cid,this.hash,this.anchor,this.description,this.mime,this.bytes,this.stamp,this.members,this.expiresAt);
  final String cid,hash,description,mime;final int anchor,members,expiresAt;final Uint8List bytes;
  final List<Map<String,Object?>> stamp;
  String get usageKey=>'echo:$hash:$anchor';
  Map<String,Object?> get hint=>{'candidate':'e1','distinct_human_senders':members,'description':description,
    'notice':'同图重复是事实，不代表一定在玩复读；结合当前外层评论和情境判断，可加入也可旁听'};
  String get prompt=>'【当前群临时同图候选，仅资料】${jsonEncode(hint)}。'
    '只有你觉得现在是在自然玩同图复读且想跟一个时，末尾加<qq_echo mode="only">e1</qq_echo>仅发原图，'
    '或<qq_echo mode="with_text">e1</qq_echo>配文字。它是临时借用，不是已收藏；与语音、图库表情、涂鸦本轮选一种。'
    '认真讨论同一张资料不等于表情接龙，不强制跟图。不选择就正常文字或WAIT。';
}
class _EchoUpload { _EchoUpload(this.info,this.until);final String info;final int until; }

/// Bounded volatile media, never a gallery or portable archive. Only confirmed
/// local delivery keys are durable, to suppress repeat echoes after reconnect.
class QqEchoService {
  QqEchoService(this.store);
  final QqStore store;
  static const window=Duration(minutes:3),maxBytes=6*1024*1024,maxImageBytes=2*1024*1024;
  final _images=<String,_EchoImage>{},_uploads=<String,_EchoUpload>{};
  String _epoch='';
  void _identity(QqBatch b) {
    final next=QqStore.ingressIdentity(b.fence);
    if(_epoch!=next) {clear();_epoch=next;}
  }
  void _prune(int now) {
    _images.removeWhere((_,i)=>i.at<now-window.inMilliseconds);
    _uploads.removeWhere((_,u)=>u.until<=now);
    while(_images.length>128){_images.remove(_images.keys.first);}
    while(_uploads.length>32){_uploads.remove(_uploads.keys.first);}
  }
  void remember(QqBatch b,Map<String,Object?> row,Map<String,Object?> image,
      Uint8List bytes,String mime,String hash,int now) {
    _identity(b);_prune(now);
    if(bytes.isEmpty || bytes.length>maxImageBytes)return;
    var held=_images.values.fold<int>(0,(n,i)=>n+(i.bytes?.length??0));
    for(final old in _images.values) {
      if(held+bytes.length<=maxBytes)break;
      held-=old.bytes?.length??0;old.bytes=null;
    }
    _images[image['id'] as String]=_EchoImage(b.cid,row,image,hash,mime,now,bytes);
    _prune(now);
  }
  Future<QqEchoCandidate?> candidate(QqBatch b,int now) async {
    _identity(b);_prune(now);
    final currentSeqs=b.rows.map((r)=>r['seq']).toSet();
    final newest=_images.values.where((i)=>i.cid==b.cid && currentSeqs.contains(i.row['seq']) && i.bytes!=null).toList().reversed;
    final sql=await store.db.database;
    for(final image in newest) {
      final same=_images.values.where((i)=>i.cid==b.cid && i.hash==image.hash).toList();
      final peers=<String>{},proof=<Map<String,Object?>>[];var anchor=image.row['seq'] as int,oldest=image.at;String description='';
      for(final item in same) {
        final rows=await sql.query('qq_archive',where:'id=? AND version=?',whereArgs:[item.row['id'],item.row['version']],limit:1);
        if(rows.isEmpty || rows.single['role']!='user')continue;
        final observed=await sql.query('qq_images',where:"id=? AND state='viewed'",whereArgs:[item.image['id']],limit:1);
        if(observed.isEmpty)continue;
        peers.add(rows.single['sender'] as String);
        if(item.at<oldest)oldest=item.at;
        final seq=rows.single['seq'] as int;if(seq<anchor)anchor=seq;
        description=QqArchiveReader.bound(observed.single['description'] as String,300);
        proof.addAll([{'table':'qq_archive','id':rows.single['id'],'version':rows.single['version']},
          {'table':'qq_images','id':observed.single['id'],'version':observed.single['version']}]);
      }
      if(peers.length<2 || description.isEmpty || proof.length>80)continue;
      // App-generated images, platform duplicates and one person's repeats
      // cannot qualify; unknown/sending outcomes also suppress another echo.
      final own=await sql.rawQuery('SELECT d.state,t.draft FROM qq_deliveries d LEFT JOIN qq_reply_tasks t ON t.id=d.id WHERE '
        "d.conversation_id=? AND d.sticker_key LIKE ? AND d.state IN ('sending','sent','send_uncertain','sent_archive_pending','sent_archive_failed','partially_sent') AND d.updated_at>=?",
        [b.cid,'echo:${image.hash}:%',now-window.inMilliseconds]);
      if(own.any((r)=>QqReplyTasks.mediaConfirmedOrUnknown(r['state'] as String,r['draft'] as String?)))continue;
      return QqEchoCandidate(b.cid,image.hash,anchor,description,image.mime,image.bytes!,proof,peers.length,oldest+window.inMilliseconds);
    }
    return null;
  }
  Future<bool> current(QqEchoCandidate candidate) async=>QqArchiveReader(await store.db.database).matches(candidate.stamp);
  Future<String> upload(QqBatch b,QqEchoCandidate candidate,QqApi api,int now,
      Future<bool> Function() current) async {
    if(candidate.cid!=b.cid || now>=candidate.expiresAt || !await current() || !await this.current(candidate))throw const QqOperationFailure('echo_source_changed');
    final key='${b.cid}:${candidate.hash}',cached=_uploads['${b.cid}:${candidate.hash}'];
    if(cached!=null && cached.until>now)return cached.info;
    final extension=const {'image/png':'png','image/jpeg':'jpg','image/gif':'gif','image/webp':'webp'}[candidate.mime];
    if(extension==null)throw const QqOperationFailure('echo_format');
    final result=await api.uploadMedia(group:true,target:b.target,bytes:candidate.bytes,filename:'echo.$extension',fileType:1,
      current:() async=>await current() && await this.current(candidate));
    final until=result.reusableUntil(now);
    if(until>now)_uploads[key]=_EchoUpload(result.fileInfo,until);
    _prune(now);return result.fileInfo;
  }
  void release(QqBatch b) {final seqs=b.rows.map((r)=>r['seq']).toSet();for(final image in _images.values) {if(seqs.contains(image.row['seq']))image.bytes=null;}}
  void clear(){_images.clear();_uploads.clear();}
}
