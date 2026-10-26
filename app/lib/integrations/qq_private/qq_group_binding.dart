import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'qq_private_config.dart';
import 'qq_options.dart';
import '../../core/database/app_database.dart';

/// Group requests are untrusted candidates. A public code alone grants nothing:
/// only the already-bound private owner or a local App confirmation can finish.
abstract final class QqGroupBinding {
  static const _storage=FlutterSecureStorage(aOptions:AndroidOptions());
  static const _key='qq_group_identity_requests_v1';
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
    final o=await QqOptions.read(namespace:c.namespace);
    await o.copy(owners:{...o.ownerMembers,selected['group'] as String:selected['member'] as String}).save(db:db);
    selected['consumed']=true;await _storage.write(key:'${_key}_${c.namespace}',value:jsonEncode(rows));
    return true;
  }
}
