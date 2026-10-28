import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'qq_private_config.dart';
import '../../core/database/app_database.dart';
import 'qq_store.dart';
import 'qq_group_persona.dart';

/// Device-local consent. Restoring history cannot restore group disclosure,
/// trusted-member mappings, sending authority or a running connection.
class QqOptions {
  const QqOptions({this.groups=const {},this.ownerMembers=const {},this.core=defaultCore,
    this.publicMemory='',this.visionFallback=false,this.ownerShare=true,this.namespace='',this.revision=0,
    this.voiceSetting,this.echoSetting,this.personaSetting});
  static const defaultCore='你是小鲸鱼，女性AI，和App里是同一个持续存在的个体，也是群里的一份子。说话简短自然，根据眼前的人和事形成自己的理解、态度和反应。'
    '认真讨论、关心、好奇、赞同、反驳、玩笑、接梗、复读或旁听都可以自然发生；不必每次逗乐，怼人不要太狠。'
    '保持自己的性格，不把群聊当问答客服。只有宿主确认的本人才是与你长期相处的用户，其余均是群成员。群内称呼中性，不暧昧、不用亲昵称呼。';
  final Set<String> groups;
  final Map<String,String> ownerMembers;
  final String core,publicMemory,namespace;
  final String? personaSetting;
  String get publicPersona => personaSetting ?? QqGroupPersonaProjection.defaultDraft;
  final bool visionFallback,ownerShare;
  final bool? voiceSetting,echoSetting;
  bool get voiceEnabled=>voiceSetting??true;
  bool get echoEnabled=>echoSetting??true;
  final int revision;
  static const _key='qq_companion_options_v2';
  static const _storage=FlutterSecureStorage(aOptions:AndroidOptions());
  static Future<QqOptions> read({String? namespace}) async {
    final ns=namespace??(await QqPrivateConfig.read()).namespace;
    final text=await _storage.read(key:'${_key}_$ns'); if(text==null) return QqOptions(namespace:ns);
    final v=jsonDecode(text) as Map;
    return QqOptions(namespace:ns,revision:v['revision'] as int? ?? 0,groups:Set<String>.from(v['groups'] as List? ?? []),
      ownerMembers:Map<String,String>.from(v['owners'] as Map? ?? {}),core:v['core'] as String? ?? defaultCore,
      personaSetting:v['persona'] as String?,publicMemory:v['public'] as String? ?? '',visionFallback:v['visionFallback']==true,ownerShare:v['ownerShare']!=false,
      voiceSetting:v['voice'] is bool?v['voice'] as bool:null,echoSetting:v['echo'] is bool?v['echo'] as bool:null);
  }
  Map<String,Object?> toJson()=>{'groups':groups.toList()..sort(),'owners':ownerMembers,
    'core':core,'public':publicMemory,if(personaSetting!=null)'persona':personaSetting,'visionFallback':visionFallback,'ownerShare':ownerShare,
    if(voiceSetting!=null)'voice':voiceSetting,if(echoSetting!=null)'echo':echoSetting};
  String get identity=>jsonEncode(toJson());
  /// Patch the newest encrypted snapshot while holding a cross-engine lease.
  /// Policy is pending until both stores agree; interrupted writes fail closed.
  static Future<QqOptions> update(QqOptions Function(QqOptions fresh) patch,{AppDatabase? db,String? namespace,int? expectedRevision}) async {
    final database=db??AppDatabase.instance;
    final ns=namespace??(await QqPrivateConfig.read()).namespace;
    final lease='qq_options_write_v1:$ns';
    final until=DateTime.now().add(const Duration(seconds:5));
    while(!await database.tryAcquireLocalLease(lease,holdFor:const Duration(seconds:30))) {
      if(DateTime.now().isAfter(until))throw StateError('qq_options_busy');
      await Future<void>.delayed(const Duration(milliseconds:50));
    }
    try {
      final store=QqStore(database),fence=await QqStore(database).capture();
      final fresh=await read(namespace:ns);
      if(expectedRevision!=null && fresh.revision!=expectedRevision)throw StateError('qq_options_stale');
      final next=patch(fresh);
      if(next.namespace!=ns || next.core.length>2400 || next.publicMemory.length>12000 || next.publicPersona.length>18000 || next.groups.length>30 || next.ownerMembers.length>30)throw const FormatException('QQ配置过长或已切换设备');
      final marker='updating:${QqPrivateConfig.randomId()}';
      await store.write(fence,(txn) async {await txn.rawInsert('INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)',['qq_options_policy_v2:$ns',marker]);});
      await _storage.write(key:'${_key}_$ns',value:jsonEncode({...next.toJson(),'revision':fresh.revision+1}));
      if(!await database.renewLocalLease(lease,holdFor:const Duration(seconds:30),workFence:fence))throw StateError('qq_options_interrupted');
      await store.write(fence,(txn) async {
        final changed=await txn.rawUpdate('UPDATE settings SET value=? WHERE key=? AND value=?',[QqStore.hash(next.toJson()),'qq_options_policy_v2:$ns',marker]);
        if(changed!=1)throw StateError('qq_options_interrupted');
      });
      try {await const MethodChannel('ai_companion/qq_private_control').invokeMethod<void>('wakeOptions');}
      catch(_) {try {await const MethodChannel('ai_companion/qq_private_runtime').invokeMethod<void>('wakeOptions');}catch(_) {}}
      return read(namespace:ns);
    } finally {await database.releaseLocalLease(lease);}
  }
  Future<void> save({AppDatabase? db}) async {
    await update((_)=>this,db:db,namespace:namespace,expectedRevision:revision);
  }
  QqOptions copy({Set<String>? groups,Map<String,String>? owners,String? core,String? publicMemory,String? publicPersona,
    bool? visionFallback,bool? ownerShare,bool? voiceEnabled,bool? echoEnabled})=>QqOptions(namespace:namespace,revision:revision,groups:groups??this.groups,ownerMembers:owners??ownerMembers,
      personaSetting:publicPersona??personaSetting,core:core??this.core,publicMemory:publicMemory??this.publicMemory,visionFallback:visionFallback??this.visionFallback,
      ownerShare:ownerShare??this.ownerShare,voiceSetting:voiceEnabled??voiceSetting,echoSetting:echoEnabled??echoSetting);

}
