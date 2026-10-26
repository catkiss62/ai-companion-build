import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'qq_private_config.dart';
import '../../core/database/app_database.dart';
import 'qq_store.dart';

/// Device-local consent. Restoring history cannot restore group disclosure,
/// trusted-member mappings, sending authority or a running connection.
class QqOptions {
  const QqOptions({this.groups=const {},this.ownerMembers=const {},this.core=defaultCore,
    this.publicMemory='',this.visionFallback=false,this.ownerShare=true,this.namespace=''});
  static const defaultCore='你是小鲸鱼，女性AI，和App里是同一个持续存在的个体。说话简短自然，可以幽默、吐槽、反驳、接梗、复读，也可以只发表情包或旁听。'
    '保持自己的性格，不把群聊当问答客服。只有宿主确认的本人才是与你长期相处的用户，其余均是群成员。群内称呼中性，不暧昧、不用亲昵称呼。';
  final Set<String> groups;
  final Map<String,String> ownerMembers;
  final String core,publicMemory,namespace;
  final bool visionFallback,ownerShare;
  static const _key='qq_companion_options_v2';
  static const _storage=FlutterSecureStorage(aOptions:AndroidOptions());
  static Future<QqOptions> read({String? namespace}) async {
    final ns=namespace??(await QqPrivateConfig.read()).namespace;
    final text=await _storage.read(key:'${_key}_$ns'); if(text==null) return QqOptions(namespace:ns);
    final v=jsonDecode(text) as Map;
    return QqOptions(namespace:ns,groups:Set<String>.from(v['groups'] as List? ?? []),
      ownerMembers:Map<String,String>.from(v['owners'] as Map? ?? {}),core:v['core'] as String? ?? defaultCore,
      publicMemory:v['public'] as String? ?? '',visionFallback:v['visionFallback']==true,ownerShare:v['ownerShare']!=false);
  }
  Map<String,Object?> toJson()=>{'groups':groups.toList()..sort(),'owners':ownerMembers,
    'core':core,'public':publicMemory,'visionFallback':visionFallback,'ownerShare':ownerShare};
  String get identity=>jsonEncode(toJson());
  Future<void> save({AppDatabase? db}) async {
    if(core.length>2400 || publicMemory.length>12000 || groups.length>30 || ownerMembers.length>30) throw const FormatException('QQ配置过长');
    // Invalidate in-flight share authority BEFORE changing secure options.
    await (db??AppDatabase.instance).setSetting('qq_options_policy_v2:$namespace',QqStore.hash(toJson()));
    await _storage.write(key:'${_key}_$namespace',value:identity);
  }
  QqOptions copy({Set<String>? groups,Map<String,String>? owners,String? core,String? publicMemory,
    bool? visionFallback,bool? ownerShare})=>QqOptions(namespace:namespace,groups:groups??this.groups,ownerMembers:owners??ownerMembers,
      core:core??this.core,publicMemory:publicMemory??this.publicMemory,visionFallback:visionFallback??this.visionFallback,
      ownerShare:ownerShare??this.ownerShare);

}
