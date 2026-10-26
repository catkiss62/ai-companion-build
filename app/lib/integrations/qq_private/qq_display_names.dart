import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'qq_store.dart';

/// Presentation metadata only: names never authorize an owner or enter policy.
class QqDisplayNames {
  QqDisplayNames({Map<String,String>? groups,Map<String,String>? members})
    :groups=groups??{},members=members??{};
  final Map<String,String> groups,members;
  static String shortId(String value)=>value.length<=6?value:value.substring(value.length-6);
  static String key(String scope)=>'qq_display_names_v1:$scope';
  static String memberKey(String group,String member)=>QqStore.hash([group,member]);
  static String clean(String value,int limit)=>String.fromCharCodes(value.runes
    .where((r)=>r>=32 && r!=127 && !(r>=0x202a && r<=0x202e) && !(r>=0x2066 && r<=0x2069)).take(limit)).trim();
  String group(String target)=>groups[target]??'未命名群聊';
  String? member(String group,String member)=>members[memberKey(group,member)];
  static Future<QqDisplayNames> read(DatabaseExecutor sql,String scope)async{
    final rows=await sql.query('settings',columns:['value'],where:'key=?',whereArgs:[key(scope)],limit:1);
    try {
      final v=rows.isEmpty?const <String,dynamic>{}:jsonDecode(rows.single['value'] as String) as Map;
      Map<String,String> strings(Object? raw)=>raw is Map?{
        for(final e in raw.entries) if(e.key is String && e.value is String)e.key as String:e.value as String}:{};
      return QqDisplayNames(groups:strings(v['groups']),members:strings(v['members']));
    }catch(_){return QqDisplayNames();}
  }
  static Future<void> write(DatabaseExecutor sql,String scope,{String? group,String? name,String? member,String? nickname})async{
    final names=await read(sql,scope);
    if(group!=null && name!=null) {
      final value=clean(name,80);
      if(value.isEmpty) {names.groups.remove(group);} else {names.groups[group]=value;}
    }
    if(group!=null && member!=null && nickname!=null) {
      final value=clean(nickname,80);
      if(value.isNotEmpty) {
        final id=memberKey(group,member);names.members.remove(id);names.members[id]=value;
      }
    }
    while(names.groups.length>200) {names.groups.remove(names.groups.keys.first);}
    while(names.members.length>1000) {names.members.remove(names.members.keys.first);}
    await sql.insert('settings',{'key':key(scope),'value':jsonEncode({'groups':names.groups,'members':names.members})},
      conflictAlgorithm:ConflictAlgorithm.replace);
  }
}
