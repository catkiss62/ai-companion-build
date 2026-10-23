import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models/room_background_config.dart';
import '../core/storage/message_attachment_storage.dart';
import '../core/storage/room_background_storage.dart';
import 'room_image_background.dart';

class RoomBackgroundEditor extends StatefulWidget {
  const RoomBackgroundEditor({super.key, required this.storage, required this.initial});
  final RoomBackgroundStorage storage;
  final RoomBackgroundSnapshot initial;
  @override State<RoomBackgroundEditor> createState() => _RoomBackgroundEditorState();
}

class _RoomBackgroundEditorState extends State<RoomBackgroundEditor> {
  late RoomBackgroundConfig config = widget.initial.config;
  PreparedImageAttachment? image;
  final drafts = <PreparedImageAttachment>[];
  final scale = TextEditingController(), x = TextEditingController(), y = TextEditingController();
  bool busy = false;
  String error = '';
  RoomBackgroundConfig? gestureStart;
  Offset focalStart = Offset.zero;
  @override void initState() { super.initState(); _syncFields(); }
  void _syncFields() {
    scale.text = (config.scale*100).toStringAsFixed(1);
    x.text = (config.x*100).toStringAsFixed(1);
    y.text = (config.y*100).toStringAsFixed(1);
  }
  @override void dispose() {
    scale.dispose(); x.dispose(); y.dispose();
    for (final draft in drafts) {
      draft.originalFile.parent.delete(recursive:true).catchError((_)=>draft.originalFile.parent);
    }
    super.dispose();
  }
  Future<void> _upload() async {
    setState(() { busy=true; error=''; });
    try {
      final picked = await ImagePicker().pickImage(source:ImageSource.gallery);
      if (picked == null || !mounted) return;
      final prepared = await MessageAttachmentStorage(db:widget.storage.db)
          .prepareImage(sourcePath:picked.path,source:'immersive_background');
      if (!mounted) { await prepared.originalFile.parent.delete(recursive:true); return; }
      drafts.add(prepared);
      if (mounted) setState(() { image=prepared;
        config=const RoomBackgroundConfig(mode:'custom'); _syncFields(); });
    } catch (_) {
      if (mounted) setState(()=>error='没有读到可用图片，请重新选择。');
    } finally { if (mounted) setState(()=>busy=false); }
  }
  bool _readFields() {
    final s=double.tryParse(scale.text), dx=double.tryParse(x.text), dy=double.tryParse(y.text);
    if (s==null || dx==null || dy==null) return false;
    final next=config.copyWith(scale:s/100,x:dx/100,y:dy/100);
    try { next.encode(); } catch (_) { return false; }
    setState(()=>config=next); return true;
  }
  Future<void> _save() async {
    if (!_readFields()) { setState(()=>error='请输入有效位置；缩放范围为 1%～10000%。'); return; }
    setState(() { busy=true; error=''; });
    try {
      await widget.storage.save(widget.initial,config,image:image);
      if (mounted) Navigator.pop(context,true);
    } catch (e) {
      if (mounted) setState(()=>error=e.toString().replaceFirst('Bad state: ',''));
    } finally { if (mounted) setState(()=>busy=false); }
  }
  Widget _number(TextEditingController controller,String label) => Expanded(child:TextField(
    controller:controller,enabled:!busy,
    keyboardType:const TextInputType.numberWithOptions(signed:true,decimal:true),
    decoration:InputDecoration(labelText:label,isDense:true),
    onChanged:(_)=>_readFields()));
  @override Widget build(BuildContext context) => AlertDialog(
    title:const Text('沉浸房间背景'),
    content:SizedBox(width:480,child:SingleChildScrollView(child:Column(
      mainAxisSize:MainAxisSize.min,children:[
        LayoutBuilder(builder:(context,size)=>GestureDetector(
          onScaleStart:busy?null:(details) {
            FocusScope.of(context).unfocus(); gestureStart=config; focalStart=details.localFocalPoint;
          },
          onScaleUpdate:busy?null:(details) {
            final start=gestureStart; if(start==null || !start.visible)return;
            final nextScale=(start.scale*details.scale).clamp(.01,100.0).toDouble();
            final factor=nextScale/start.scale, width=size.maxWidth;
            final center=width*(.5+start.x), top=width*start.y;
            setState(() { config=start.copyWith(scale:nextScale,
              x:(details.localFocalPoint.dx+(center-focalStart.dx)*factor-width/2)/width,
              y:(details.localFocalPoint.dy+(top-focalStart.dy)*factor)/width); _syncFields(); });
          },
          child:SizedBox(height:230,width:double.infinity,child:RoomImageBackground(
            config:config,imageFile:image?.originalFile ?? widget.initial.file,
            aspectRatio:image==null?widget.initial.aspectRatio:image!.width/image!.height)))),
        const SizedBox(height:10),
        const Text('拖动移动，双指缩放；图片可以移出画面。位置按屏宽百分比保存，所有沉浸房间共用。',
          style:TextStyle(fontSize:12)),
        const SizedBox(height:12),
        Row(children:[_number(scale,'缩放 %'),const SizedBox(width:8),
          _number(x,'水平 %'),const SizedBox(width:8),_number(y,'垂直 %')]),
        const SizedBox(height:8),
        Wrap(spacing:8,children:[
          TextButton(onPressed:busy?null:_upload,child:const Text('上传')),
          TextButton(onPressed:busy?null:()=>setState(() {
            config=config.copyWith(scale:1,x:0,y:0);_syncFields();
          }),child:const Text('重置位置')),
          TextButton(onPressed:busy?null:()=>setState(() {
            image=null;config=const RoomBackgroundConfig();_syncFields();
          }),child:const Text('恢复默认')),
          TextButton(onPressed:busy?null:()=>setState(() {
            image=null;config=const RoomBackgroundConfig(mode:'none');_syncFields();
          }),child:const Text('删除')),
        ]),
        if(error.isNotEmpty) Text(error,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      ]))),
    actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context,false),child:const Text('取消')),
      FilledButton(onPressed:busy?null:_save,child:Text(busy?'保存中…':'保存'))]);
}
