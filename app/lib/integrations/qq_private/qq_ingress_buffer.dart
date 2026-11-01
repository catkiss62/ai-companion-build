import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'qq_store.dart';
import '../../core/database/brain_work_fence.dart';

/// Device-local inbox outside the portable snapshot. Media URLs never enter
/// archives. Only same-identity events held during ordinary backup can replay.
class QqIngressBuffer {
  QqIngressBuffer([this.file]);
  final File? file;
  final _rows=<String,Map<String,dynamic>>{};
  Future<void> _tail=Future.value();
  bool _loaded=false;
  Future<T> _locked<T>(Future<T> Function() body) {
    final result=Completer<T>();
    _tail=_tail.then((_) async {
      try {result.complete(await body());}catch(e,s){result.completeError(e,s);}
    });
    return result.future;
  }
  Future<void> _load() async {
    if(_loaded)return;
    final f=file;
    if(f!=null && await f.exists()) {
      final data=jsonDecode(await f.readAsString());
      if(data is! Map)throw const FormatException('qq_inbox_format');
      for(final e in data.entries) {if(e.value is Map)_rows[e.key as String]=Map<String,dynamic>.from(e.value as Map);}
    }
    _loaded=true;
  }
  Future<void> _save() async {
    final f=file;if(f==null)return;
    await f.parent.create(recursive:true);
    final temporary=File('${f.path}.writing');
    await temporary.writeAsString(jsonEncode(_rows),flush:true);
    await temporary.rename(f.path);
  }
  Future<void> hold(Map<String,dynamic> event,bool group,BrainWorkFence fence,String policy,int now) => _locked(() async {
    await _load();
    _rows.removeWhere((_,r)=>now-(r['at'] as int)>240000);
    final id=QqStore.hash([group,event['id'],event['_trusted_event_type']]);
    final row={'event':event,'group':group,'identity':QqStore.ingressIdentity(fence),'policy':policy,'at':now};
    final next={..._rows,id:row};
    if(next.length>256 || utf8.encode(jsonEncode(next)).length>2*1024*1024)throw StateError('qq_inbox_full');
    _rows[id]=row;await _save();
  });
  Future<void> drain(BrainWorkFence fence,String policy,int now,Future<bool> Function(Map<String,dynamic>,bool,int) accept) async {
    final rows=await _locked(() async {await _load();return Map<String,Map<String,dynamic>>.from(_rows);});
    for(final e in rows.entries) {
      final r=e.value;
      final valid=now-(r['at'] as int)<=240000 && r['policy']==policy && QqStore.acceptsIngress(r['identity'] as String,fence);
      if(valid && !await accept(Map<String,dynamic>.from(r['event'] as Map),r['group']==true,r['at'] as int))return;
      await _locked(() async {if(identical(_rows[e.key],r)){_rows.remove(e.key);await _save();}});
    }
  }
}
