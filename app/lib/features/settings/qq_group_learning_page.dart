import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../integrations/qq_private/qq_archive_reader.dart';
import '../../integrations/qq_private/qq_group_learning.dart';
import '../../integrations/qq_private/qq_store.dart';

class QqGroupLearningPage extends StatefulWidget {
  const QqGroupLearningPage({super.key,required this.cid,required this.title,this.database});
  final String cid,title;final AppDatabase? database;
  @override State<QqGroupLearningPage> createState()=>_QqGroupLearningPageState();
}
class _QqGroupLearningPageState extends State<QqGroupLearningPage> {
  late final learning=QqGroupLearning(QqStore(widget.database??AppDatabase.instance));
  List<Map<String,Object?>> _rows=[];bool _enabled=false,_loading=true,_busy=false;String _notice='';
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    try {final enabled=await learning.enabled(widget.cid),rows=await learning.profiles(widget.cid);
      if(mounted)setState((){_enabled=enabled;_rows=rows;_loading=false;});}
    catch(_) {if(mounted)setState((){_loading=false;_notice='读取失败，请刷新重试。';});}
  }
  Future<void> _run(Future<void> Function() action) async {
    if(_busy)return;setState((){_busy=true;_notice='';});
    try {await action();await _load();}catch(_) {if(mounted)setState(()=>_notice='资料已变化或操作失败，请刷新后重试。');}
    finally {if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _sources(Map<String,Object?> row) async {
    try {
      final ids=(jsonDecode(row['sources'] as String) as List).cast<int>();final sql=await learning.store.db.database;
      final rows=await sql.query('qq_archive',where:'conversation_id=? AND seq IN (${List.filled(ids.length,'?').join(',')})',whereArgs:[widget.cid,...ids],orderBy:'seq');
      final texts=<String>[];for(final source in rows)texts.add(await QqArchiveReader(sql).display(source,speaker:source['owner']==1?'你':'群成员'));
      if(!mounted)return;
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('表达观察的来源'),content:SizedBox(width:480,child:SingleChildScrollView(child:SelectableText(texts.join('\n\n')))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('关闭'))]));
    }catch(_) {if(mounted)setState(()=>_notice='来源读取失败。');}
  }
  Future<void> _edit(Map<String,Object?> row) async {
    final result=await showDialog<String>(context:context,builder:(_)=>_ExpressionEditor(initial:row['content'] as String));
    if(result!=null && mounted)await _run(()=>learning.edit(row,content:result));
  }
  Future<void> _delete(Map<String,Object?> row) async {
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('删除这条表达观察？'),content:const Text('停止使用这条观察。原文和私人记忆保留；同一批旧发言不会重新学习。'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('取消')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('删除'))]));
    if(yes==true && mounted)await _run(()=>learning.edit(row,delete:true));
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('${widget.title} · 群聊表达'),actions:[IconButton(onPressed:_busy?null:_load,icon:const Icon(Icons.refresh))]),
    body:_loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('学习本群的聊天表达'),value:_enabled,onChanged:_busy?null:(v)=>_run(()=>learning.setEnabled(widget.cid,v))),
      const Text('每群独立开启，仅观察开启之后真人的新发言。积累至少12条、间隔至少6小时才尝试整理一次，不逐句调用。可学习接梗、复读、节奏与语气，不改变她的人格、认主、私人记忆或欲望。只在本群回复时参考。'),
      const SizedBox(height:12),const Text('观察、来源和修改状态随存档保存。关闭后保留资料但不读取；重新开启从新发言开始。删除来源原文时，依赖它的表达观察一并撤下。'),
      if(_busy)const LinearProgressIndicator(),if(_notice.isNotEmpty)Text(_notice),
      if(_rows.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Text('暂时没有表达观察。开启后需要积累新发言。')),
      for(final row in _rows)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(row['enabled']==0?'已停用':(row['edited_at'] as int)>0?'你修改的表达观察':'自动观察'),const SizedBox(height:8),SelectableText(row['content'] as String),
        Wrap(children:[TextButton(onPressed:_busy?null:()=>_sources(row),child:const Text('查看来源')),TextButton(onPressed:_busy?null:()=>_edit(row),child:const Text('编辑')),
          TextButton(onPressed:_busy?null:()=>_run(()=>learning.edit(row,enabled:row['enabled']==0)),child:Text(row['enabled']==0?'启用':'停用')),TextButton(onPressed:_busy?null:()=>_delete(row),child:const Text('删除'))])]))),
    ]));
}
class _ExpressionEditor extends StatefulWidget {
  const _ExpressionEditor({required this.initial});final String initial;
  @override State<_ExpressionEditor> createState()=>_ExpressionEditorState();
}
class _ExpressionEditorState extends State<_ExpressionEditor> {
  late final controller=TextEditingController(text:widget.initial);
  @override void dispose(){controller.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(title:const Text('编辑表达观察'),content:SizedBox(width:480,child:TextField(controller:controller,minLines:4,maxLines:10,maxLength:1600)),actions:[
    TextButton(onPressed:()=>Navigator.pop(context),child:const Text('取消')),FilledButton(onPressed:(){if(controller.text.trim().isNotEmpty)Navigator.pop(context,controller.text.trim());},child:const Text('保存'))]);
}
