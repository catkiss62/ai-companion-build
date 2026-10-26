import 'qq_archive_month_page.dart';
import 'package:flutter/material.dart';
import 'qq_group_identity_page.dart';
import 'qq_group_name_dialog.dart';
import '../../integrations/qq_private/qq_display_names.dart';
import '../../core/database/app_database.dart';
import '../../integrations/qq_private/qq_archive_reader.dart';
import '../../integrations/qq_private/qq_group_binding.dart';
import '../../integrations/qq_private/qq_options.dart';
import '../../integrations/qq_private/qq_private_config.dart';
import '../../integrations/qq_private/qq_runtime.dart';
import '../../integrations/qq_private/qq_store.dart';

class QqGroupsPage extends StatefulWidget {
  const QqGroupsPage({super.key});
  @override State<QqGroupsPage> createState()=>_QqGroupsPageState();
}
class _QqGroupsPageState extends State<QqGroupsPage> {
  final _core=TextEditingController(),_public=TextEditingController();
  QqOptions _options=const QqOptions();QqPrivateConfig _config=const QqPrivateConfig();
  List<Map<String,Object?>> _groups=[];List<Map<String,dynamic>> _requests=[];
  bool _loading=true,_busy=false;String _notice='';QqDisplayNames _names=QqDisplayNames();
  @override void initState(){super.initState();_load(initial:true);}
  Future<void> _load({bool initial=false}) async {
    try {
      final c=await QqPrivateConfig.read();final o=await QqOptions.read();
      final groups=(await QqStore(AppDatabase.instance).conversations(QqRuntime.scope(c))).where((g)=>g['kind']=='group').toList();
      final requests=await QqGroupBinding.requests(c);
      final names=await QqDisplayNames.read(await AppDatabase.instance.database,QqRuntime.scope(c));
      if(!mounted) return;
      setState((){_config=c;_options=o;_names=names;_groups=groups;_requests=requests;_loading=false;
        if(initial){_core.text=o.core;_public.text=o.publicMemory;}});
    } catch(_){if(mounted) setState((){_loading=false;_notice='读取失败，请稍后刷新。';});}
  }
  Future<void> _run(Future<void> Function() task) async {
    if(_busy) return;setState((){_busy=true;_notice='';});
    try {await task();await _load();} catch(_){if(mounted) setState(()=>_notice='操作失败，请稍后重试。');}
    finally {if(mounted) setState(()=>_busy=false);}
  }
  Future<void> _confirm(Map<String,dynamic> r) async {
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('这是你刚刚在群里发起的吗？'),
      content:Text('申请 ${r['code']}\n群：${r['group']}\n成员：${r['member']}\n只有与你本人刚刚发送的 /关联本人 对应时才确认；群名、昵称和群管理身份不能代替本人身份。'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')),
        TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('确认是我'))]));
    if(yes!=true || !mounted) return;
    await _run(() async {if(!await QqGroupBinding.confirm(_config,r['code'] as String)) throw StateError('expired');});
  }
  @override void dispose(){_core.dispose();_public.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('QQ 群聊与公开资料'),actions:[
    IconButton(onPressed:_busy?null:()=>_load(),icon:const Icon(Icons.refresh))]),body:_loading?const Center(child:CircularProgressIndicator()):ListView(
      padding:const EdgeInsets.all(16),children:[
        const Text('群聊使用同一个小鲸鱼，但只读取本群资料和你在下面明确公开的内容。私人完整记忆不会注入群模型。群内称呼保持中性。'),
        const SizedBox(height:12),
        const Text('先把机器人加入群并 @ 一次，再刷新列表。未开启的群只登记入口，不读私人记忆或调用模型。普通消息旁听还需腾讯平台提供群全量消息权限；仅收到@时无法看到未投递的消息。'),
        for(final g in _groups) Column(children:[SwitchListTile(contentPadding:EdgeInsets.zero,
          title:Text(_names.group(g['target'] as String)),subtitle:Text('群标识末六位 ${QqDisplayNames.shortId(g['target'] as String)} · ${_options.ownerMembers.containsKey(g['target'])?'已确认你在本群的身份':'尚未关联本人；昵称不自动认主'}'),
          value:_options.groups.contains(g['target']),onChanged:_busy?null:(enabled)=>_run(() async {
            final o=await QqOptions.read();final ids={...o.groups};enabled?ids.add(g['target'] as String):ids.remove(g['target']);await o.copy(groups:ids).save();})),
          Align(alignment:Alignment.centerRight,child:TextButton(onPressed:_busy?null:()=>_run(() => editQqGroupName(context,_config,g['target'] as String)),child:const Text('群名称 / 备注'))),
          Align(alignment:Alignment.centerRight,child:TextButton(onPressed:_busy?null:() async {
            await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>QqGroupIdentityPage(config:_config,group:g['target'] as String)));
            if(mounted) await _load();
          },child:const Text('设置本群中的我')))]),
        if(_groups.isEmpty) const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('还没有发现群。请先完成私聊绑定，再在群里 @ 机器人。')),
        const Divider(),const Text('认主可在上方选中自己的发言直接确认，不必公开发口令。也保留群里 /关联本人 → 已绑定私聊确认的方式。昵称和普通QQ号不直接授予本人身份。'),
        for(final r in _requests.where((r)=>r['consumed']!=true)) ListTile(contentPadding:EdgeInsets.zero,
          title:Text('待确认申请 ${r['code']}'),subtitle:Text('群 ${r['group']} · 成员 ${r['member']}'),
          trailing:TextButton(onPressed:_busy?null:()=>_confirm(r),child:const Text('核对并确认'))),
        const SizedBox(height:16),
        TextField(controller:_core,maxLines:5,maxLength:2400,decoration:const InputDecoration(labelText:'群聊基础人格 / 小卡',
          helperText:'只填写适合在群里使用的性格。小卡读取会使用这部分的简短投影。',helperMaxLines:3)),
        const SizedBox(height:12),
        TextField(controller:_public,maxLines:7,maxLength:12000,decoration:const InputDecoration(labelText:'允许在群里表达的背景与共同记忆',
          helperText:'这里保存的内容会对已开启的群公开。留空也可聊天；私人完整记忆仍不会注入群模型。',helperMaxLines:3)),
        FilledButton(onPressed:_busy?null:()=>_run(() async {
          final o=await QqOptions.read();await o.copy(core:_core.text.trim(),publicMemory:_public.text.trim()).save();
          if(mounted) setState(()=>_notice='公开资料已保存。');}),child:const Text('保存公开资料')),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('QQ 识图失败时使用第一通道兜底'),
          subtitle:const Text('先使用App视觉模型，再尝试第一通道当前模型的真实图片输入。接口不支持图片时保留识别失败。'),
          value:_options.visionFallback,onChanged:_busy?null:(v)=>_run(() async {await (await QqOptions.read()).copy(visionFallback:v).save();})),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('允许向本人分享群聊见闻'),subtitle:const Text('仅向你分享，仍受睡眠、节奏和防重复控制。'),
          value:_options.ownerShare,onChanged:_busy?null:(v)=>_run(() async {await (await QqOptions.read()).copy(ownerShare:v).save();})),
        const SizedBox(height:12),const Text('群聊优先用JEV快速判断，未启用或请求失败时第一通道兜底。每条新消息可触发，短时连发合并；正在和她聊天时可连续接话，普通加入保持较低频率。复读、玩梗和纯表情包也可参与，旁听过的消息不会反复读取。'),
        const SizedBox(height:12),const Text('夜间沿用共同起床边界：群里仍可接收归档，默认不识图、不主动接话，也不批量补看整夜图片。本人私聊保留回应。QQ不会增加主系统疲劳、压力或互动满足。'),
        if(_notice.isNotEmpty) Padding(padding:const EdgeInsets.only(top:12),child:Text(_notice)),
      ]));
}

class QqArchivesPage extends StatefulWidget {
  const QqArchivesPage({super.key});
  @override State<QqArchivesPage> createState()=>_QqArchivesPageState();
}
class _QqArchivesPageState extends State<QqArchivesPage> {
  List<Map<String,Object?>>? _rows;String _notice='';final _names=<String,QqDisplayNames>{};
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    try {final sql=await AppDatabase.instance.database;final rows=await sql.rawQuery('SELECT c.*,COUNT(a.seq) AS messages FROM qq_conversations c LEFT JOIN qq_archive a ON a.conversation_id=c.id GROUP BY c.id ORDER BY MAX(a.observed_at) DESC LIMIT 200');
      for(final scope in rows.map((r)=>r['scope'] as String).toSet()) {_names[scope]=await QqDisplayNames.read(sql,scope);}
      if(mounted) setState(()=>_rows=rows);
    } catch(_){if(mounted) setState(()=>_notice='档案读取失败。');}
  }
  Future<void> _open(Map<String,Object?> c) async {
    final names=_names[c['scope']]??QqDisplayNames();
    await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>QqArchiveConversationPage(
      conversation:c,title:c['kind']=='group'?names.group(c['target'] as String):'与你的QQ私聊',names:names)));
    if(mounted) await _load();
  }
  Future<void> _forget(Map<String,Object?> c) async {
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('删除这份QQ档案？'),
      content:const Text('删除该会话的原文、图片描述、关联整理笔记和分享记录。不会删除App原有聊天/记忆；已有备份不受影响。'),actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')),
        TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('删除'))]));
    if(yes!=true) return;
    try {final store=QqStore(AppDatabase.instance);await store.forget(await store.capture(),c['id'] as String);await _load();}
    catch(_){if(mounted) setState(()=>_notice='暂时不能删除，可能正在迁移或备份。');}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('QQ 档案'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    body:_rows==null?Center(child:_notice.isEmpty?const CircularProgressIndicator():Text(_notice)):ListView(children:[
      const Padding(padding:EdgeInsets.all(16),child:Text('QQ原文、来源和整理笔记随App存档保存；机器人凭据、群公开授权和临时图片不随档案恢复。')),
      for(final c in _rows!) ListTile(title:Text(c['kind']=='group'?(_names[c['scope']]??QqDisplayNames()).group(c['target'] as String):'与你的QQ私聊'),subtitle:Text('${c['messages']} 条记录${c['kind']=='group'?' · 群标识末六位 ${QqDisplayNames.shortId(c['target'] as String)}':''}'),
        onTap:()=>_open(c),trailing:IconButton(onPressed:()=>_forget(c),icon:const Icon(Icons.delete_outline))),
      if(_notice.isNotEmpty) Text(_notice)]));
}
