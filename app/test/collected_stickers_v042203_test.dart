import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/stickers/collected_sticker_storage.dart';
import 'package:ai_companion_localfirst/core/stickers/collected_sticker_archive.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack_storage.dart';
import 'package:ai_companion_localfirst/core/storage/message_attachment_storage.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_sticker_collection.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_voice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path); final String path;
  @override Future<String?> getApplicationSupportPath()async=>'$path/support';
  @override Future<String?> getTemporaryPath()async=>'$path/temp';
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();databaseFactory=databaseFactoryFfi;
  late Directory root;late AppDatabase db;late PathProviderPlatform previous;
  late CollectedStickerStorage storage;late StickerPackStorage packs;
  final png=base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGP8z8DAwMDAxMDAwMDAAAANHQEDasKb6QAAAABJRU5ErkJggg==');
  final gif=base64Decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7');
  setUp(()async{
    root=await Directory.systemTemp.createTemp('collected-stickers');
    await Directory('${root.path}/temp').create();previous=PathProviderPlatform.instance;
    PathProviderPlatform.instance=_Paths(root.path);
    db=await AppDatabase.createForTesting(databaseFactoryFfi);
    storage=CollectedStickerStorage(db:db);packs=StickerPackStorage(db:db);
  });
  tearDown(()async{await db.closeForTesting();PathProviderPlatform.instance=previous;await root.delete(recursive:true);});
  test('single imports append and deduplicate across sources, retaining GIF bytes',()async{
    expect(await storage.collect(png,caption:'困得想摸鱼',source:'qq',sourceId:'group:a'),true);
    expect(await storage.collect(gif,caption:'无语',source:'user',sourceId:'manual'),true);
    expect(await storage.collect(png,caption:'重复图',source:'web',sourceId:'page'),false);
    final pack=(await packs.scanPacks()).single;
    expect(pack.count,2);
    final records=await packs.readRecords(pack);
    final animated=records.singleWhere((r)=>r.path.endsWith('.gif'));
    expect(await (await packs.fileFor(pack,animated)).readAsBytes(),gif);
    await storage.remove(animated.path);
    final restarted=StickerPackStorage(db:db);
    expect((await restarted.loadPickerCatalog()).items.single.record.caption,'困得想摸鱼');
    expect((await storage.sources()).length,1);
  });
  test('collection ZIP preserves local edits on duplicates and uses archive captions after deletion',() async {
    await storage.collect(png,caption:'包里的文字',source:'user',sourceId:'a');
    await storage.collect(gif,caption:'动图',source:'user',sourceId:'b');
    final archive=CollectedStickerArchive(db);
    final zip=await archive.exportZip();
    final rows=await packs.loadPackEntries(CollectedStickerStorage.packId);
    final photo=rows.singleWhere((e)=>e.record.path.endsWith('.png')).record;
    final animation=rows.singleWhere((e)=>e.record.path.endsWith('.gif')).record;
    final edits={photo.usageKey:'本地修改',animation.usageKey:'动图修改'};
    await packs.saveCaptionEdits(edits);
    await archive.importZip(zip.path);
    expect(await packs.captionOverrides(),edits);
    await storage.remove(photo.path);
    expect(await packs.captionOverrides(),{animation.usageKey:'动图修改'});
    await storage.remove(animation.path);
    expect(await packs.captionOverrides(),isEmpty);
    // Recover orphan edits left by older builds. Other packs keep their keys.
    await packs.saveCaptionEdits({photo.usageKey:'旧版本残留','other:memes/a.png':'其他图库'});
    await archive.importZip(zip.path);
    final restored=await packs.loadPackEntries(CollectedStickerStorage.packId);
    expect(restored.map((e)=>e.record.caption),unorderedEquals(['包里的文字','动图']));
    expect(await restored.singleWhere((e)=>e.record.path==animation.path).file.readAsBytes(),gif);
    await packs.saveCaptionEdits(edits);
    await packs.deletePack(CollectedStickerStorage.packId);
    expect(await packs.captionOverrides(),{'other:memes/a.png':'其他图库'});
  });
  test('interrupted index update reconciles extra ownership without losing a valid image',()async{
    await storage.collect(png,caption:'开心',source:'user',sourceId:'a');
    await storage.collect(gif,caption:'无语',source:'user',sourceId:'b');
    final pack=(await packs.scanPacks()).single;
    final sql=await openDatabase('${pack.rootPath}/index.db',singleInstance:false);
    try {await sql.delete('memes',where:'path LIKE ?',whereArgs:['%.gif']);} finally {await sql.close();}
    final recovered=(await packs.scanPacks()).single;
    final records=await packs.readRecords(recovered);
    expect(records.single.caption,'开心');
    expect(await (await packs.fileFor(recovered,records.single)).readAsBytes(),png);
    final ownership=jsonDecode(await File('${pack.rootPath}/shared_originals_v1.json').readAsString());
    expect((ownership['originals'] as Map).length,1);
    await packs.setPackEnabled(pack.id,false);
    await storage.collect(gif,caption:'再次收藏',source:'user',sourceId:'b');
    expect(await packs.enabledPackIds(),isNot(contains(pack.id)));
  });
  test('manual semantic edit persists into shared selection, deleting collection preserves chat ownership',()async{
    await storage.collect(png,caption:'开心',source:'user',sourceId:'manual');
    final pack=(await packs.scanPacks()).single, record=(await packs.loadPickerCatalog()).items.single.record;
    await packs.saveCaptionEdits({record.usageKey:'开心到起飞'});
    expect((await StickerPackStorage(db:db).loadPickerCatalog()).items.single.record.caption,'开心到起飞');
    final attachment=await packs.prepareAttachment(pack:pack,record:record,messageId:'m1',source:'assistant_sticker',attachments:MessageAttachmentStorage(db:db));
    await db.insertMessageWithAttachments(ChatMessage(id:'m1',role:'assistant',content:'',createdAt:DateTime.now()),[attachment]);
    final original=await packs.fileFor(pack,record);
    await storage.remove(record.path);
    expect(await original.readAsBytes(),png);
    expect(await packs.scanPacks(),isEmpty);
  });
  test('auto off blocks collection but manual add works; stale source does not append',()async{
    await db.setSetting(CollectedStickerStorage.autoSetting,'false');
    await expectLater(storage.collect(png,caption:'开心',source:'qq',sourceId:'a',automatic:true),throwsStateError);
    await storage.collect(png,caption:'开心',source:'user',sourceId:'a');
    await expectLater(storage.collect(gif,caption:'无语',source:'qq',sourceId:'b',current:()async=>false),throwsStateError);
    expect((await packs.loadPickerCatalog()).items.length,1);
  });
  test('source invalidated while staging never publishes a new index row',()async{
    await storage.collect(png,caption:'现有收藏',source:'user',sourceId:'a');
    var checks=0;
    await expectLater(storage.collect(gif,caption:'失效候选',source:'web',sourceId:'b',
      automatic:true,current:()async=>++checks==1),throwsStateError);
    expect(checks,2);
    expect((await packs.loadPickerCatalog()).items.single.record.caption,'现有收藏');
  });
  test('bad image, oversize and empty meaning never publish a pack',()async{
    for(final bytes in [Uint8List.fromList([1,2,3]),Uint8List(CollectedStickerStorage.maxBytes+1)]) {
      await expectLater(storage.collect(bytes,caption:'开心',source:'user',sourceId:'a'),throwsFormatException);
    }
    await expectLater(storage.collect(png,caption:' ',source:'user',sourceId:'a'),throwsFormatException);
    expect(await packs.scanPacks(),isEmpty);
  });
  test('QQ collection requires one explicit candidate and semantic caption, internal tag is hidden',(){
    const tag='<qq_collect>{"candidate":"c1","caption":"上班困成一团"}</qq_collect>';
    expect(QqCollectCandidate.caption(tag),'上班困成一团');
    expect(QqCollectCandidate.caption('$tag$tag'),isNull);
    expect(QqCollectCandidate.caption('<qq_collect>{"candidate":"c2","caption":"开心"}</qq_collect>'),isNull);
    expect(QqCollectCandidate.caption('<qq_collect>{"candidate":"c1"}</qq_collect>'),isNull);
    expect(QqCollectCandidate.visible('你好$tag'),'你好');
    expect(QqCollectCandidate.visible('你好<qq_collect>broken'),'你好');
  });
  test('QQ cute preference leaves missing or explicit daily choices and frequency reminders intact',(){
    expect(QqVoiceChoice.groupPrompt,contains('轻松吐槽、普通开心或俏皮表达优先考虑cute'));
    expect(QqVoiceChoice.prompt,contains('不必为了音色强行撒娇'));
    expect(QqVoiceChoice.parse('<qq_voice>{"language":"zh","text":"你好"}</qq_voice>')!.voice,'daily');
    expect(QqVoiceChoice.parse('<qq_voice>{"language":"zh","text":"你好","voice":"daily"}</qq_voice>')!.voice,'daily');
    expect(QqVoiceChoice.groupReminder,contains('最近20条'));
  });
}
