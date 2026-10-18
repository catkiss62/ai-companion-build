import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/model_dialogue/model_dialogue_controller.dart';
import '../../core/model_dialogue/model_dialogue_archive_worker.dart';
import '../../core/model_dialogue/model_dialogue_gateway.dart';
import '../../core/model_dialogue/model_dialogue_models.dart';
import '../../core/model_dialogue/model_dialogue_repository.dart';
import '../../core/platform/android_bridge.dart';

const modelDialogueBackground='assets/model_dialogue/background.jpg';
const modelDialogueDeepSeekAvatar='assets/model_dialogue/deepseek.jpg';
const modelDialogueGeminiAvatar='assets/model_dialogue/gemini.jpg';
const _ink=Color(0xFF173452);
const _blue=Color(0xFF24649D);
const _purple=Color(0xFF7257A5);

class _DialogueBackdrop extends StatelessWidget {
  const _DialogueBackdrop({required this.child});
  final Widget child;
  @override Widget build(BuildContext context)=>Stack(fit:StackFit.expand,children:[
    Image.asset(modelDialogueBackground,fit:BoxFit.cover,alignment:Alignment.topCenter),
    const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(
      begin:Alignment.topCenter,end:Alignment.bottomCenter,
      colors:[Color(0x18102740),Color(0x40102740)]))),child]);
}

class ModelDialogueLobbyPage extends StatefulWidget {
  const ModelDialogueLobbyPage({super.key,this.repository,this.configurationLoader});
  final ModelDialogueRepository? repository;
  final Future<ModelDialogueConfiguration> Function()? configurationLoader;
  @override State<ModelDialogueLobbyPage> createState()=>_ModelDialogueLobbyPageState();
}
class _ModelDialogueLobbyPageState extends State<ModelDialogueLobbyPage> {
  late final repository=widget.repository??ModelDialogueRepository(AppDatabase.instance);
  List<ModelDialogueRoom> _rooms=const [];
  bool _loading=true,_creating=false;
  String _error='';
  @override void initState(){super.initState();unawaited(_load());}
  Future<void> _load() async {
    try {
      final rooms=await repository.listRooms();
      if(mounted)setState((){_rooms=rooms;_loading=false;_error='';});
    } catch(_) {if(mounted)setState((){_loading=false;_error='房间列表暂时无法读取。';});}
  }
  void _showError(String message) {
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
  }
  Future<void> _create() async {
    if(_creating)return;
    final title=TextEditingController(text:'新的模型对谈');
    final topic=TextEditingController();var first='deepseek';
    try {
      final approved=await showDialog<bool>(context:context,builder:(dialog)=>StatefulBuilder(
        builder:(context,update)=>AlertDialog(title:const Text('创建对谈房间'),
          content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
            TextField(controller:title,maxLength:40,decoration:const InputDecoration(labelText:'房间名称')),
            TextField(controller:topic,minLines:2,maxLines:5,maxLength:2000,
              decoration:const InputDecoration(labelText:'话题（可选）',hintText:'留空，由先发言的一方自己开场。')),
            DropdownButtonFormField<String>(initialValue:first,isExpanded:true,
              decoration:const InputDecoration(labelText:'先发言的模型'),
              items:const [DropdownMenuItem(value:'deepseek',child:Text('DeepSeek')),
                DropdownMenuItem(value:'gemini',child:Text('Gemini'))],
              onChanged:(value)=>update(()=>first=value??'deepseek')),
            const SizedBox(height:12),
            const Text('使用已配置的两方模型。共享小鲸鱼已有记忆；结束后选择性保留对谈经历。',style:TextStyle(fontSize:12)),
          ])),actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('取消')),
            FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('创建'))])));
      if(approved!=true||!mounted)return;
      setState(()=>_creating=true);
      final configuration=await (widget.configurationLoader?.call()??ModelDialogueConfiguration.load(repository.db));
      configuration.validate();
      final room=await repository.create(title:title.text,topic:topic.text,
        participants:configuration.snapshot,firstSpeaker:first);
      if(mounted)await _open(room);
    } on ModelDialogueConfigurationError catch(e){_showError(e.message);}
      catch(_){_showError('暂时无法创建房间，请确认当前设备可运行且未在备份或恢复。');}
    finally {title.dispose();topic.dispose();if(mounted)setState(()=>_creating=false);}
  }
  Future<void> _open(ModelDialogueRoom room) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>ModelDialogueRoomPage(
      roomId:room.id,repository:repository,configurationLoader:widget.configurationLoader)));
    if(mounted)await _load();
  }
  Future<void> _manage(ModelDialogueRoom room,String action) async {
    if(action=='rename') {
      final title=TextEditingController(text:room.title);
      try {
        final approved=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
          title:const Text('修改房间名称'),content:TextField(controller:title,maxLength:40),
          actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('取消')),
            FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('保存'))]));
        if(approved==true&&!await repository.rename(room.id,title.text))_showError('当前状态暂时无法修改。');
      }finally{title.dispose();}
    } else if(action=='delete') {
      final approved=await _confirmDelete(context,room.title);
      if(approved&&!await repository.delete(room.id))_showError('备份或恢复期间暂时无法删除。');
    }
    if(mounted)await _load();
  }
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:Colors.black,
    appBar:AppBar(backgroundColor:Colors.black,foregroundColor:Colors.white,title:const Text('模型对谈')),
    floatingActionButton:FloatingActionButton.extended(onPressed:_creating?null:_create,
      icon:const Icon(Icons.add),label:Text(_creating?'创建中':'创建房间')),
    body:SafeArea(child:_loading?const Center(child:CircularProgressIndicator()):
      RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.fromLTRB(16,16,16,100),children:[
        const Padding(padding:EdgeInsets.all(14),child:Text(
          '让 DeepSeek 和 Gemini 交换想法。\n你可以旁观、插话，也可以暂离后再继续。',
          style:TextStyle(color:Colors.white70,height:1.5))),
        if(_error.isNotEmpty)Padding(padding:const EdgeInsets.all(12),child:Text(_error,style:const TextStyle(color:Colors.white70))),
        if(_rooms.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('还没有对谈房间。',style:TextStyle(color:Colors.white70))),
        ..._rooms.map((room)=>Padding(padding:const EdgeInsets.only(top:12),child:Card(
          color:const Color(0xFF19191D),child:ListTile(
          title:Text(room.title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600)),
          subtitle:Text('${room.ended?'已结束 · 可回看':'暂离后可继续'}${room.topic.isEmpty?'':'\n${room.topic}'}',
            maxLines:3,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white60)),
          leading:Icon(room.ended?Icons.forum_outlined:Icons.chat_bubble_outline,color:const Color(0xFFB99BE7)),
          trailing:PopupMenuButton<String>(iconColor:Colors.white70,onSelected:(value)=>_manage(room,value),itemBuilder:(_)=>const [
            PopupMenuItem(value:'rename',child:Text('修改名称')),PopupMenuItem(value:'delete',child:Text('删除房间'))]),
          onTap:()=>_open(room))))),
      ]))));
}

Widget _glass({required Widget child})=>DecoratedBox(decoration:BoxDecoration(
  color:Colors.white.withValues(alpha:.9),borderRadius:BorderRadius.circular(16),
  border:Border.all(color:Colors.white.withValues(alpha:.6))),child:child);

Future<bool> _confirmDelete(BuildContext context,String title) async =>
    await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
      title:const Text('删除这个对谈房间？'),content:Text('“$title”的本场记录将被删除。'),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('取消')),
        FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('删除'))]))??false;

class ModelDialogueRoomPage extends StatefulWidget {
  const ModelDialogueRoomPage({super.key,required this.roomId,this.repository,
    this.configurationLoader,this.gateway});
  final String roomId;
  final ModelDialogueRepository? repository;
  final Future<ModelDialogueConfiguration> Function()? configurationLoader;
  final ModelDialogueGateway? gateway;
  @override State<ModelDialogueRoomPage> createState()=>_ModelDialogueRoomPageState();
}
class _ModelDialogueRoomPageState extends State<ModelDialogueRoomPage> with WidgetsBindingObserver {
  late final repository=widget.repository??ModelDialogueRepository(AppDatabase.instance);
  late final controller=ModelDialogueController(roomId:widget.roomId,repository:repository,
    configurationLoader:widget.configurationLoader,gateway:widget.gateway);
  final input=TextEditingController();
  final scroll=ScrollController();
  bool _follow=true,_scrollScheduled=false,_archiveStarted=false;
  @override void initState(){
    super.initState();WidgetsBinding.instance.addObserver(this);
    unawaited(AndroidBridge.instance.setImmersiveChatPageVisible(true));
    controller.addListener(_changed);unawaited(controller.initialize());
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state!=AppLifecycleState.resumed)unawaited(controller.pause());
  }
  void _changed(){
    if(!mounted)return;setState((){});
    final room=controller.room;
    if(room?.ended==true&&room!.archiveState=='pending'&&!_archiveStarted) {
      _archiveStarted=true;
      unawaited(_archive(room.id));
    }
    if(!_follow||_scrollScheduled)return;
    _scrollScheduled=true;
    WidgetsBinding.instance.addPostFrameCallback((_){
      _scrollScheduled=false;
      if(mounted&&_follow&&scroll.hasClients)scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }
  Future<void> _archive(String id) async {
    try {
      await ModelDialogueArchiveWorker(repository.db).drainOne(roomId:id);
      if(mounted)await controller.reload();
    } catch(_) {} // Original records and the durable retry job remain available.
  }
  @override void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    unawaited(AndroidBridge.instance.setImmersiveChatPageVisible(false));
    controller.removeListener(_changed);controller.dispose();input.dispose();scroll.dispose();super.dispose();
  }
  Future<bool> _leave() async {try{await controller.pause();}catch(_){}return true;}
  Future<void> _send() async {
    final text=input.text.trim();if(text.isEmpty||controller.busy)return;
    input.clear();_follow=true;
    final accepted=await controller.advance(userText:text);
    if(!accepted&&mounted&&input.text.isEmpty)input.text=text;
  }
  Future<void> _menu(String action) async {
    final room=controller.room;if(room==null)return;
    if(action=='leave') {await _leave();if(mounted)Navigator.pop(context);}
    if(action=='end') {
      final approved=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(
        title:const Text('结束这场对谈？'),content:const Text('保留本场记录供回看，结束后不再继续生成，并整理本场值得保留的讨论经历。'),
        actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('取消')),
          FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('结束'))]));
      if(approved==true)await controller.end();
    }
    if(action=='delete'&&mounted&&await _confirmDelete(context,room.title)) {
      await controller.pause();
      if(await repository.delete(room.id)){if(mounted)Navigator.pop(context);}
      else if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('当前状态暂时无法删除。')));
    }
    if(action=='info'&&mounted)await showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
      title:const Text('本场模型'),content:Text('DeepSeek\n${room.modelName('deepseek')}\n\nGemini\n${room.modelName('gemini')}\n\n共享小鲸鱼已有记忆；结束后按发言者整理，选择性保留讨论经历。'),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('知道了'))]));
  }
  @override Widget build(BuildContext context)=>WillPopScope(onWillPop:_leave,child:Scaffold(
    appBar:AppBar(title:Text(controller.room?.title??'模型对谈',overflow:TextOverflow.ellipsis,
      style:const TextStyle(fontSize:16)),actions:[PopupMenuButton<String>(onSelected:_menu,itemBuilder:(_)=>[
        const PopupMenuItem(value:'info',child:Text('本场模型')),
        if(controller.room?.ended!=true)const PopupMenuItem(value:'leave',child:Text('暂时离开')),
        if(controller.room?.ended!=true)const PopupMenuItem(value:'end',child:Text('结束本场')),
        const PopupMenuItem(value:'delete',child:Text('删除房间'))])]),
    body:_DialogueBackdrop(child:SafeArea(top:false,child:controller.loading?
      const Center(child:CircularProgressIndicator()):LayoutBuilder(builder:(context,size)=>Column(children:[
        if(controller.room?.topic.isNotEmpty==true)Container(width:double.infinity,
          color:const Color(0xCC102B48),padding:const EdgeInsets.symmetric(horizontal:14,vertical:7),
          child:Text(controller.room!.topic,maxLines:2,overflow:TextOverflow.ellipsis,
            style:const TextStyle(color:Colors.white,fontSize:12))),
        Expanded(child:NotificationListener<UserScrollNotification>(onNotification:(event){
          if(scroll.hasClients)_follow=scroll.position.maxScrollExtent-scroll.offset<40;return false;
        },child:ListView(controller:scroll,padding:const EdgeInsets.symmetric(horizontal:12,vertical:14),children:[
          if(controller.messages.isEmpty&&!controller.busy)_glass(child:const Padding(padding:EdgeInsets.all(16),
            child:Text('准备好就开始。话题为空时，由先发言的一方自己找个话头。',style:TextStyle(color:_ink,height:1.5)))),
          if(controller.room?.archiveSummary.isNotEmpty==true)_glass(child:ExpansionTile(
            title:const Text('本场对谈摘要',style:TextStyle(color:_ink)),
            childrenPadding:const EdgeInsets.all(14),children:[SelectableText(controller.room!.archiveSummary,
              style:const TextStyle(color:_ink,height:1.5))])),
          ...controller.messages.map((m)=>_bubble(m.speaker,m.text,model:m.model)),
          if(controller.busy&&controller.attempt>0)_bubble(controller.speaking.isEmpty?(controller.room?.nextSpeaker??'deepseek'):controller.speaking,
            controller.preview.isEmpty?'正在回应…':controller.preview,streaming:true),
        ]))),
        ConstrainedBox(constraints:BoxConstraints(maxHeight:size.maxHeight*.55),
          child:SingleChildScrollView(child:_footer())),
      ]))))));

  Widget _bubble(String speaker,String text,{String model='',bool streaming=false}) {
    final color=speaker=='deepseek'?_blue:speaker=='gemini'?_purple:const Color(0xFF9B4971);
    return Align(alignment:speaker=='deepseek'?Alignment.centerLeft:speaker=='gemini'?Alignment.centerRight:Alignment.center,
      child:FractionallySizedBox(widthFactor:speaker=='user' ? 0.94 : 0.9,child:Container(
        margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(color:(speaker=='user'?const Color(0xFFFFF0F6):Colors.white).withValues(alpha:.68),
          borderRadius:BorderRadius.circular(15),border:Border.all(color:color.withValues(alpha:.3))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[CircleAvatar(radius:16,backgroundColor:color,
            backgroundImage:speaker=='user'?null:AssetImage(speaker=='deepseek'?modelDialogueDeepSeekAvatar:modelDialogueGeminiAvatar),
            child:speaker=='user'?const Text('你',style:TextStyle(fontSize:11,color:Colors.white)):null),
            const SizedBox(width:7),Expanded(child:Text('${modelDialogueLabel(speaker)}${streaming?' · 生成中':''}',
              style:TextStyle(color:color,fontWeight:FontWeight.w700,fontSize:12))),
            if(model.isNotEmpty)Tooltip(message:model,child:Icon(Icons.info_outline,size:15,color:color))]),
          const SizedBox(height:8),SelectableText(text,style:const TextStyle(color:_ink,fontSize:15,height:1.55)),
        ]))));
  }
  Widget _footer() {
    final room=controller.room;
    return Container(width:double.infinity,color:const Color(0xEB102B48),padding:const EdgeInsets.fromLTRB(12,9,12,12),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(controller.error.isNotEmpty)Padding(padding:const EdgeInsets.only(bottom:8),
          child:Text(controller.error,style:const TextStyle(color:Color(0xFFFFC5CA),fontSize:13))),
        if(controller.notice.isNotEmpty)Padding(padding:const EdgeInsets.only(bottom:6),
          child:Text(controller.notice,style:const TextStyle(color:Colors.white70,fontSize:12))),
        if(room?.ended==true)Padding(padding:const EdgeInsets.all(6),
          child:Text(room!.archiveState=='pending'?'本场已结束，记录保留；摘要待整理，网络恢复后重试。':
            room.archiveState=='remembered'?'本场已结束，已保留一条对谈经历。':'本场已结束，记录可回看。',
            style:const TextStyle(color:Colors.white))),
        if(room!=null&&!room.ended) ...[
          if(room.closingSpeaker.isNotEmpty)Padding(padding:const EdgeInsets.only(bottom:6),child:Text(
            '${modelDialogueLabel(room.closingSpeaker)} 准备结束，可再继续一次收尾；你也可以插话。',
            style:const TextStyle(color:Colors.white70,fontSize:12))),
          Row(children:[Expanded(child:TextField(controller:input,enabled:!controller.busy,
            minLines:1,maxLines:3,maxLength:6000,style:const TextStyle(color:Colors.white,fontSize:14),
            decoration:InputDecoration(hintText:'插一句（可选）',hintStyle:const TextStyle(color:Colors.white60),
              counterText:'',isDense:true,filled:true,fillColor:Colors.white.withValues(alpha:.08),
              border:OutlineInputBorder(borderRadius:BorderRadius.circular(12))),
            onSubmitted:(_)=>unawaited(_send()))),
            IconButton(tooltip:'发送',onPressed:controller.busy?null:_send,
              color:Colors.white,disabledColor:Colors.white30,icon:const Icon(Icons.send_rounded))]),
          const SizedBox(height:8),
          Row(children:[
            if(controller.busy)OutlinedButton.icon(onPressed:()=>controller.pause(),
              style:OutlinedButton.styleFrom(foregroundColor:const Color(0xFFFFD1DA)),
              icon:const Icon(Icons.stop_rounded,size:18),label:const Text('停止'))
            else FilledButton.icon(onPressed:(){_follow=true;unawaited(controller.advance().then((_) {}));},
              icon:const Icon(Icons.play_arrow_rounded,size:18),
              label:Text(controller.error.isNotEmpty?'重试本方':controller.messages.isEmpty?'开始对谈':room.closingSpeaker.isNotEmpty?'继续收尾':'继续对谈')),
            const SizedBox(width:10),Expanded(child:Text(controller.busy?
              controller.attempt==0?'准备对谈…':'${modelDialogueLabel(controller.speaking.isEmpty?room.nextSpeaker:controller.speaking)} · 请求 ${controller.attempt}/2':
              '下一位：${modelDialogueLabel(room.nextSpeaker)}',maxLines:2,overflow:TextOverflow.ellipsis,
              style:const TextStyle(color:Colors.white70,fontSize:12))),
          ]),
        ],
      ]));
  }
}
