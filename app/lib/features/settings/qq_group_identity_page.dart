import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../integrations/qq_private/qq_archive_reader.dart';
import '../../integrations/qq_private/qq_group_binding.dart';
import '../../integrations/qq_private/qq_display_names.dart';
import '../../integrations/qq_private/qq_options.dart';
import '../../integrations/qq_private/qq_private_config.dart';
import '../../integrations/qq_private/qq_store.dart';

class QqGroupIdentityPage extends StatefulWidget {
  const QqGroupIdentityPage({super.key,required this.config,required this.group,this.database});
  final QqPrivateConfig config;
  final String group;
  final AppDatabase? database;
  @override State<QqGroupIdentityPage> createState()=>_QqGroupIdentityPageState();
}

class _QqGroupIdentityPageState extends State<QqGroupIdentityPage> {
  final _manual=TextEditingController();
  List<Map<String,Object?>> _members=[];
  String? _selected,_bound;String _notice='';
  bool _loading=true,_busy=false,_manualMode=false;QqDisplayNames _names=QqDisplayNames();
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    try {
      final rows=await QqGroupBinding.members(widget.config,widget.group,db:widget.database);
      final o=await QqOptions.read(namespace:widget.config.namespace);
      final names=await QqDisplayNames.read(await (widget.database??AppDatabase.instance).database,QqStore.hash([widget.config.appId,widget.config.namespace,widget.config.owner]));
      if(mounted) setState((){_members=rows;_names=names;_bound=o.ownerMembers[widget.group];_loading=false;});
    } catch(_) {if(mounted) setState((){_loading=false;_notice='读取失败，请稍后刷新。';});}
  }
  Future<void> _save({bool clear=false}) async {
    if(_busy) return;
    final member=clear?null:_manualMode?_manual.text.trim():_selected;
    if(!clear && (member==null || member.isEmpty || _manualMode && !QqGroupBinding.validManualMember(member))) {
      setState(()=>_notice='请选择你的发言，或填写该群成员的真实OpenID；QQ号和昵称不能代替。');return;
    }
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(clear?'解除本群本人身份？':'确认这个群成员是你本人？'),
      content:Text(clear?'此群恢复为尚未认主，其他群和私聊绑定保持原样。':
        '群：${widget.group}\n成员OpenID：$member\n请按你自己的发言核对；这会将该成员标记为与你长期相处的本人。'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(clear?'解除':'确认是我'))]));
    if(yes!=true || !mounted) return;
    setState((){_busy=true;_notice='';});
    try {
      final ok=await QqGroupBinding.confirmLocal(widget.config,widget.group,member,
        requireObserved:!_manualMode,db:widget.database);
      if(!ok) throw StateError('identity_changed');
      await _load();if(mounted) setState(()=>_notice=clear?'已解除本群本人身份。':'已保存，之后本群会按平台身份认出你。');
    } catch(_) {if(mounted) setState(()=>_notice='未能保存，绑定或群消息可能已变化，请刷新后重试。');}
    finally {if(mounted) setState(()=>_busy=false);}
  }
  @override void dispose(){_manual.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('设置本群中的你'),actions:[IconButton(onPressed:_busy?null:_load,icon:const Icon(Icons.refresh))]),
    body:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      const Text('不必在群里发送认主口令。选中你自己的最近一条发言，在App确认即可。身份按平台OpenID保存，改昵称不会改变身份。'),
      if(_bound!=null) Padding(padding:const EdgeInsets.symmetric(vertical:12),child:SelectableText('当前本人OpenID：$_bound')),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('手动预设已知成员OpenID'),
        subtitle:const Text('只在你已知道真实成员OpenID时使用；普通QQ号和群昵称不能直接匹配。'),
        value:_manualMode,onChanged:_busy?null:(v)=>setState(()=>_manualMode=v)),
      if(_manualMode) TextField(controller:_manual,maxLength:256,decoration:const InputDecoration(labelText:'本群成员OpenID')),
      if(!_manualMode && _members.isEmpty) const Padding(padding:EdgeInsets.symmetric(vertical:12),
        child:Text('还没有成员消息。先开启此群并让她收到你正常发送的一句话，再刷新；只接收@消息的群需要@一次。不必发送特殊认主命令。')),
      if(!_manualMode) for(final member in _members) ListTile(contentPadding:EdgeInsets.zero,
        leading:Icon(_selected==member['sender']?Icons.radio_button_checked:Icons.radio_button_off),
        title:Text(QqArchiveReader.bound('${member['content']}',140),maxLines:3,overflow:TextOverflow.ellipsis),
        subtitle:Text('${_names.member(widget.group,member['sender'] as String)??'未取得昵称'} · 成员OpenID：${member['sender']}'),
        onTap:_busy?null:()=>setState(()=>_selected=member['sender'] as String)),
      const SizedBox(height:12),FilledButton(onPressed:_busy?null:()=>_save(),child:const Text('确认本人身份')),
      if(_bound!=null) OutlinedButton(onPressed:_busy?null:()=>_save(clear:true),child:const Text('解除本群本人身份')),
      if(_notice.isNotEmpty) Padding(padding:const EdgeInsets.only(top:12),child:Text(_notice)),
    ]));
}
