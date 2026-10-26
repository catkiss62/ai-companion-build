import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'qq_private_config.dart';
import 'qq_options.dart';
import '../../core/database/app_database.dart';
import 'qq_store.dart';

/// Group requests are untrusted candidates. A public code alone grants nothing:
/// only the already-bound private owner or a local App confirmation can finish.
abstract final class QqGroupBinding {
  static const _storage=FlutterSecureStorage(aOptions:AndroidOptions());
  static const _key='qq_group_identity_requests_v1';
  static Future<bool> _current(QqPrivateConfig c) async {
    final fresh=await QqPrivateConfig.read();
    return c.owner.isNotEmpty && fresh.owner==c.owner && fresh.namespace==c.namespace &&
      fresh.appId==c.appId && fresh.secret==c.secret;
  }

  /// Candidates come from platform-authenticated history, never claimed names.
  static Future<List<Map<String,Object?>>> members(QqPrivateConfig c,String group,{AppDatabase? db}) async {
    if(!await _current(c)) return [];
    final sql=await (db??AppDatabase.instance).database;
    final scope=QqStore.hash([c.appId,c.namespace,c.owner]);
    return sql.rawQuery('SELECT a.sender,a.content,a.observed_at FROM qq_archive a '
      'JOIN qq_conversations c ON c.id=a.conversation_id '
      "WHERE c.scope=? AND c.kind='group' AND c.target=? AND a.role='user' "
      'AND a.seq=(SELECT MAX(b.seq) FROM qq_archive b WHERE b.conversation_id=a.conversation_id '
      "AND b.sender=a.sender AND b.role='user') ORDER BY a.seq DESC LIMIT 100",[scope,group]);
  }

  static bool validManualMember(String value)=>
    RegExp(r'^[A-Za-z0-9_-]{8,256}$').hasMatch(value) && !RegExp(r'^\d+$').hasMatch(value);

  /// Called only by an explicit physical-App confirmation. A known OpenID can
  /// be preset; observed identities can be selected without a public command.
  static Future<bool> confirmLocal(QqPrivateConfig c,String group,String? member,
      {bool requireObserved=true,AppDatabase? db}) async {
    if(!await _current(c)) return false;
    final database=db??AppDatabase.instance;final sql=await database.database;
    final scope=QqStore.hash([c.appId,c.namespace,c.owner]);
    if((await sql.query('qq_conversations',columns:['id'],
      where:"scope=? AND kind='group' AND target=?",whereArgs:[scope,group],limit:1)).isEmpty) return false;
    if(member!=null) {
      if(requireObserved) {
        if(!(await members(c,group,db:database)).any((row)=>row['sender']==member)) return false;
      } else if(!validManualMember(member)) {return false;}
    }
    if(!await _current(c)) return false;
    await QqOptions.update((fresh) {final owners={...fresh.ownerMembers};
      if(member==null) {owners.remove(group);} else {owners[group]=member;}
      return fresh.copy(owners:owners);},namespace:c.namespace,db:database);
    return true;
  }
  static Future<List<Map<String,dynamic>>> requests(QqPrivateConfig c) async {
    final raw=await _storage.read(key:'${_key}_${c.namespace}');if(raw==null) return [];
    final rows=(jsonDecode(raw) as List).map((r)=>Map<String,dynamic>.from(r as Map)).toList();
    return rows.where((r)=>r['namespace']==c.namespace && r['owner']==c.owner &&
      r['expires'] is int && (r['expires'] as int)>DateTime.now().millisecondsSinceEpoch).take(20).toList();
  }
  static Future<String?> request(QqPrivateConfig c,String group,String member) async {
    final rows=await requests(c);final now=DateTime.now().millisecondsSinceEpoch;
    if(rows.any((r)=>r['group']==group && now-(r['at'] as int)<60000)) return null;
    final code=QqPrivateConfig.randomId(8);
    rows.add({'namespace':c.namespace,'owner':c.owner,'group':group,'member':member,
      'code':code,'at':now,'expires':now+300000,'consumed':false});
    await _storage.write(key:'${_key}_${c.namespace}',value:jsonEncode(rows.length>20?rows.sublist(rows.length-20):rows));
    return code;
  }
  static Future<bool> confirm(QqPrivateConfig c,String code,{AppDatabase? db}) async {
    final fresh=await QqPrivateConfig.read();
    if(c.owner.isEmpty || fresh.owner!=c.owner || fresh.namespace!=c.namespace || fresh.appId!=c.appId) return false;
    final rows=await requests(c);final selected=rows.where((r)=>r['code']==code && r['consumed']!=true).firstOrNull;
    if(selected==null) return false;
    await QqOptions.update((fresh)=>fresh.copy(owners:{...fresh.ownerMembers,selected['group'] as String:selected['member'] as String}),namespace:c.namespace,db:db);
    selected['consumed']=true;await _storage.write(key:'${_key}_${c.namespace}',value:jsonEncode(rows));
    return true;
  }
}
