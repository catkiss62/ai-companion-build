import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/stickers/collected_sticker_storage.dart';
import '../../core/stickers/sticker_pack_storage.dart';
import '../../core/stickers/sticker_pack.dart';
import '../../core/models/companion_album.dart';

class CollectedStickersPage extends StatefulWidget {
  const CollectedStickersPage({super.key});
  @override State<CollectedStickersPage> createState()=>_CollectedStickersPageState();
}
class _CollectedStickersPageState extends State<CollectedStickersPage> {
  final db=AppDatabase.instance;
  late final storage=CollectedStickerStorage(db:db);
  late final packs=StickerPackStorage(db:db);
  List<StickerPickerEntry> entries=[];
  Map<String,Map<String,Object?>> sources={};
  bool busy=true,automatic=true;
  String? status;
  String filter='all';
  List<StickerPickerEntry> get visible=>entries.where((e) {
    final source=sources[e.record.path]?['source'];
    final mine=source=='user' || source=='album';
    return filter=='all' || (filter=='mine'?mine:!mine);
  }).toList();
  @override void initState(){super.initState();_run(_load);}
  Future<void> _load() async {
    automatic=await storage.enabled();
    final all=await packs.scanPacks();entries=[];
    for(final pack in all.where((p)=>p.id==CollectedStickerStorage.packId)) {
      for(final record in await packs.readRecords(pack)) {
        entries.add(StickerPickerEntry(pack:pack,record:record,file:await packs.fileFor(pack,record)));
      }
    }
    sources=await storage.sources();
    entries.sort((a,b)=>((sources[b.record.path]?['collected_at'] as num?)??0)
      .compareTo((sources[a.record.path]?['collected_at'] as num?)??0));
  }
  Future<void> _run(Future<void> Function() action) async {
    if(mounted)setState(()=>busy=true);
    try {await action();} catch(e){status='未完成：$e';}
    finally {if(mounted)setState(()=>busy=false);}
  }
  Future<String?> _captionDialog(String initial,{File? file}) async {
    final controller=TextEditingController(text:initial);
    final result=await showDialog<String>(context:context,builder:(context)=>StatefulBuilder(
      builder:(context,setDialogState)=>AlertDialog(title:const Text('表情语义（描述）'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          if(file!=null) Image.file(file,height:120,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image)),
          TextField(controller:controller,maxLength:240,maxLines:3,
            decoration:const InputDecoration(hintText:'例如：上班困到失去灵魂；表示困倦和不想上班'))])),
        actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('取消')),
          FilledButton(onPressed:(){
            try {Navigator.pop(context,StickerPackStorage.validateCaption(controller.text));}
            catch(_){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('请填写1–240字的语义描述')));}
          },child:const Text('保存'))])));
    // The dialog route may still be animating; dispose after its transition.
    Future<void>.delayed(const Duration(milliseconds:350),controller.dispose);
    return result;
  }
  Future<void> _upload() async {
    await _run(() async {
      final image=await ImagePicker().pickImage(source:ImageSource.gallery,requestFullMetadata:false);
      if(image==null || !mounted)return;
      if(await image.length()>CollectedStickerStorage.maxBytes)throw const FormatException('图片不能超过6 MB');
      final caption=await _captionDialog('',file:File(image.path));
      if(caption==null)return;
      final added=await storage.collect(await image.readAsBytes(),caption:caption,source:'user',sourceId:'manual');
      status=added?'已添加表情':'图片已存在，没有重复保存；可在列表修改语义';await _load();
    });
  }
  Future<void> _edit(StickerPickerEntry entry) async {
    final caption=await _captionDialog(entry.record.caption,file:entry.file);
    if(caption==null)return;
    await _run(() async {await packs.saveCaptionEdits({entry.record.usageKey:caption});status='语义已保存';await _load();});
  }
  Future<void> _album() => _run(() async {
    final items=(await db.companionAlbumItems(limit:200))
      .where((i)=>i.lifecycle=='saved' && i.hasOriginal).toList();
    if(!mounted)return;
    final picked=await showDialog<CompanionAlbumItem>(context:context,builder:(context)=>SimpleDialog(
      title:const Text('从最近200条相册记录中选择'),
      children:[if(items.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('暂无可用原图')),
        for(final item in items)SimpleDialogOption(onPressed:()=>Navigator.pop(context,item),
          child:Text(item.summary.isEmpty?item.title:item.summary,maxLines:2,overflow:TextOverflow.ellipsis))]));
    if(picked==null || !mounted)return;
    final caption=await _captionDialog(String.fromCharCodes(picked.summary.runes.take(240)));
    if(caption==null)return;
    // Preserve the original item/hash; only the human-provided caption changes.
    final added=await storage.collectAlbum(picked,caption:caption);
    status=added?'已加入收集的表情':'这张图已收藏，没有重复保存';await _load();
  });
  Future<void> _remove(StickerRecord record) async {
    final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:const Text('删除这张收藏？'),content:const Text('已有聊天和相册中的图片仍保留。以后她仍可能再次收藏；可关闭自动收集。'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('取消')),
        FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('删除'))]));
    if(yes!=true)return;
    await _run(() async {await storage.remove(record.path);status='已删除收藏';await _load();});
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('收集的表情')),
    body:Column(children:[SwitchListTile(title:const Text('允许她自动收集'),
      subtitle:const Text('从已识别的QQ图片及已下载的联网图片中自行选择，不额外逐图调用模型。关闭后仍可手动收藏。'),
      value:automatic,onChanged:busy?null:(v)=>_run(() async {
        await db.setSetting(CollectedStickerStorage.autoSetting,'$v');automatic=v;})),
      TextButton.icon(onPressed:busy?null:_upload,icon:const Icon(Icons.add_photo_alternate_outlined),label:const Text('单张上传')),
      TextButton.icon(onPressed:busy?null:_album,icon:const Icon(Icons.photo_library_outlined),label:const Text('从相册收藏')),
      Wrap(spacing:8,children:[for(final pair in const {'all':'全部','hers':'她收集的','mine':'我添加的'}.entries)
        ChoiceChip(label:Text(pair.value),selected:filter==pair.key,onSelected:(_)=>setState(()=>filter=pair.key))]),
      if(status!=null)Padding(padding:const EdgeInsets.all(8),child:Text(status!)),
      if(busy)const LinearProgressIndicator(),
      Expanded(child:visible.isEmpty?const Center(child:Text('还没有收集的表情')):ListView.builder(
        itemCount:visible.length,itemBuilder:(context,index){final entry=visible[index];
          final origin=sources[entry.record.path]?['source'];
          final source=origin=='qq'?'QQ':origin=='web'?'联网图片':origin=='user'?'我上传的':'从相册添加';
          return ListTile(leading:Image.file(File(entry.file.path),width:56,height:56,fit:BoxFit.contain,
            errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)),
            title:Text(entry.record.caption.trim().isEmpty?'未填写语义，点击编辑补充':entry.record.caption),subtitle:Text(source),
            onTap:()=>showDialog<void>(context:context,builder:(context)=>Dialog(child:InteractiveViewer(
              child:Image.file(entry.file,errorBuilder:(_,__,___)=>const Text('图片不可用'))))),
            trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'修改语义',onPressed:busy?null:()=>_edit(entry),icon:const Icon(Icons.edit_outlined)),IconButton(onPressed:busy?null:()=>_remove(entry.record),icon:const Icon(Icons.delete_outline))]));
        }))]));
}
