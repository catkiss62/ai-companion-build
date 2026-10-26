import 'package:flutter/material.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import '../../core/database/app_database.dart';
import '../../integrations/qq_private/qq_display_names.dart';
import '../../integrations/qq_private/qq_private_config.dart';
import '../../integrations/qq_private/qq_runtime.dart';

Future<void> editQqGroupName(BuildContext context,QqPrivateConfig config,String group,{AppDatabase? database})async{
  final db=database??AppDatabase.instance;final sql=await db.database;
  final scope=QqRuntime.scope(config);final names=await QqDisplayNames.read(sql,scope);
  if(!context.mounted) return;
  final text=TextEditingController(text:names.groups[group]??'');
  QqApi? lookup;bool busy=false;String notice='';
  String? result;
  try {
    result=await showDialog<String>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
      title:const Text('群名称 / 中文备注'),content:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('名称只方便查看，不改变群身份或认主。腾讯未开放群名接口时，可手动填写。'),
        TextField(controller:text,maxLength:80,decoration:const InputDecoration(labelText:'群名称')),
        TextButton(onPressed:busy?null:()async{
          update((){busy=true;notice='';});
          final api=QqApi(appId:config.appId,secret:config.secret);lookup=api;
          try {
            final info=await api.authenticated('GET','/v2/groups/${Uri.encodeComponent(group)}/info').timeout(const Duration(seconds:8));
            final name=info['group_name'];
            if(name is! String || name.trim().isEmpty) throw StateError('name_unavailable');
            if(ctx.mounted) update((){text.text=QqDisplayNames.clean(name,80);notice='已读取，点击保存后使用。';});
          }catch(_){if(ctx.mounted) update(()=>notice='暂时无法读取群名，可能未获平台权限或网络不可用；可手动填写。');}
          finally {api.close();if(identical(lookup,api)) lookup=null;if(ctx.mounted) update(()=>busy=false);}
        },child:Text(busy?'正在读取…':'从QQ读取群名称')),
        if(notice.isNotEmpty) Text(notice),
      ]),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(ctx),child:const Text('取消')),
        FilledButton(onPressed:busy?null:()=>Navigator.pop(ctx,text.text),child:const Text('保存名称'))])));
  }finally{lookup?.close();text.dispose();}
  if(result==null) return;
  final current=await QqPrivateConfig.read();
  if(QqRuntime.scope(current)!=scope || current.secret!=config.secret) return;
  await sql.transaction((txn)=>QqDisplayNames.write(txn,scope,group:group,name:result));
}
