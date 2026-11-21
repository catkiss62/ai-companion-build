import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../storage/shared_media_lock.dart';
import '../storage/sticker_shared_files.dart';
import '../storage/companion_album_storage.dart';
import '../models/companion_album.dart';
import 'sticker_pack_storage.dart';
import 'simple_sticker_archive.dart';

/// A normal indexed pack, so selection and portable backups use their existing
/// contracts. Publish blob ownership BEFORE the SQLite row. Interrupted writes
/// may retain an extra owned blob, but cannot publish a row without its bytes.
class CollectedStickerStorage {
  CollectedStickerStorage({AppDatabase? db}) : db=db??AppDatabase.instance;
  final AppDatabase db;
  static const packId='companion-collected-v1';
  static const autoSetting='sticker_auto_collect_v1';
  static const maxBytes=6*1024*1024;
  Future<bool> enabled() async=>await db.getSetting(autoSetting)!='false';

  Future<bool> collectAlbum(CompanionAlbumItem item,{String? caption,bool automatic=false,
      Future<bool> Function()? current}) async {
    if(item.lifecycle!='saved' || item.originalPath.isEmpty) throw StateError('相册原图不可用');
    final file=await CompanionAlbumStorage(db:db).fileFor(item.originalPath);
    if(await file.length()>maxBytes) throw const FormatException('收藏图片不能超过6 MB');
    final bytes=await file.readAsBytes();
    if(item.originalContentSha256.isEmpty || sha256.convert(bytes).toString()!=item.originalContentSha256) {
      throw StateError('相册原图已变化');
    }
    return collect(bytes,caption:caption??item.summary,source:'album',sourceId:item.id,
      automatic:automatic,current:current);
  }

  Future<bool> collect(Uint8List bytes,{required String caption,required String source,
      required String sourceId,int? collectedAt,bool automatic=false,Future<bool> Function()? current}) =>
    SharedMediaLock.run(() async {
      if(automatic && !await enabled()) throw StateError('自动收集已关闭');
      if(!const {'qq','album','web','user'}.contains(source)) throw const FormatException('收藏来源无效');
      if(bytes.isEmpty || bytes.length>maxBytes) throw const FormatException('收藏图片为空或超过6 MB');
      final description=StickerPackStorage.validateCaption(
        String.fromCharCodes(caption.trim().runes.take(240)));
      final ext=SimpleStickerArchive.imageExtension(bytes);
      final buffer=await ui.ImmutableBuffer.fromUint8List(bytes);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor=await ui.ImageDescriptor.encoded(buffer);
        if(descriptor.width>8192 || descriptor.height>8192 || descriptor.width*descriptor.height>32*1024*1024) {
          throw const FormatException('收藏图片尺寸过大');
        }
        final codec=await descriptor.instantiateCodec(targetWidth:128);
        try {final frame=await codec.getNextFrame();frame.image.dispose();} finally {codec.dispose();}
      } finally {descriptor?.dispose();buffer.dispose();}
      if(current!=null && !await current()) throw StateError('收藏来源已变化');
      final relative='memes/${sha256.convert(bytes)}$ext';
      final packs=StickerPackStorage(db:db);
      final root=await packs.rootDirectory;
      await root.create(recursive:true);
      final target=Directory(p.join(root.path,packId));
      final fresh=!await File(p.join(target.path,'index.db')).exists();
      if(fresh && await target.exists()) {
        if(await target.list().isEmpty) {await target.delete();}
        else {throw const FormatException('收集表情索引损坏，未覆盖原文件');}
      }
      final work=fresh?Directory(p.join(root.path,'.$packId.initial')):target;
      if(fresh) {if(await work.exists())await work.delete(recursive:true);await work.create();}
      final shared=StickerSharedFiles(packRootOverride:root,
        mediaRootOverride:Directory(p.join(root.parent.path,'media_blobs')));
      final index=await openDatabase(p.join(work.path,'index.db'),singleInstance:false);
      var published=false;
      try {
        await index.execute('CREATE TABLE IF NOT EXISTS memes (path TEXT PRIMARY KEY, file_name TEXT NOT NULL, tag TEXT NOT NULL, caption TEXT NOT NULL, keywords TEXT NOT NULL, tone_scope TEXT NOT NULL, intensity INTEGER NOT NULL, enabled INTEGER NOT NULL, source TEXT, source_id TEXT, collected_at INTEGER)');
        if((await index.query('memes',where:'path=?',whereArgs:[relative])).isNotEmpty) return false;
        final count=Sqflite.firstIntValue(await index.rawQuery('SELECT COUNT(*) FROM memes'))??0;
        if(count>=StickerPackStorage.maxStickers) throw StateError('收集表情已达1200张，请先整理');
        // Stage only the new image. migrate deduplicates against canonical album
        // originals, without copying every existing collected image.
        final scratch=Directory(p.join(root.path,'.$packId.new'));
        if(await scratch.exists())await scratch.delete(recursive:true);
        await Directory(p.join(scratch.path,'memes')).create(recursive:true);
        try {
          await File(p.join(scratch.path,relative)).writeAsBytes(bytes,flush:true);
          await shared.migrate(scratch,[relative],canonicalPaths:{for(final b in await db.allMediaBlobs()) b.id:b.originalPath});
          final mapping=await shared.readMap(work);
          mapping.addAll(await shared.readMap(scratch));
          if(current!=null && !await current()) throw StateError('收藏来源已变化');
          if(automatic && !await enabled()) throw StateError('自动收集已关闭');
          // The duplicate check above preserves edits on an existing row.
          await packs.clearCollectedCaptionEdits(path:relative);
          await writeMap(work,mapping);
          await index.insert('memes',{'path':relative,'file_name':p.basename(relative),
            'tag':'收集','caption':description,'keywords':'','tone_scope':'general','intensity':1,'enabled':1,
            'source':source,'source_id':String.fromCharCodes(sourceId.runes.take(220)),
            'collected_at':collectedAt ?? DateTime.now().millisecondsSinceEpoch});
          published=true;
        } finally {if(await scratch.exists())await scratch.delete(recursive:true);}
        if(fresh) await File(p.join(work.path,'manifest.json')).writeAsString(jsonEncode({
          'id':packId,'name':'收集的表情','description':'她从QQ、相册和联网图片中收集的表情',
          'license':'personal collection','imported_at':DateTime.now().millisecondsSinceEpoch}),flush:true);
      } finally {await index.close();}
      if(fresh && published) await work.rename(target.path);
      // Only enable on first creation; respect a user's later pack disable.
      if(fresh) await packs.setPackEnabled(packId,true);
      return true;
    },db:db);

  static Future<void> writeMap(Directory pack,Map<String,String> mapping) async {
    final file=File(p.join(pack.path,StickerSharedFiles.manifestName));
    final temporary=File('${file.path}.saving');
    await temporary.writeAsString(jsonEncode({'version':1,'originals':mapping}),flush:true);
    await temporary.rename(file.path);
  }

  Future<Map<String,Map<String,Object?>>> sources() => SharedMediaLock.run(() async {
    final root=await StickerPackStorage(db:db).rootDirectory;
    final path=p.join(root.path,packId,'index.db');
    if(!await File(path).exists())return {};
    final sql=await openDatabase(path,readOnly:true,singleInstance:false);
    try {
      final columns=(await sql.rawQuery('PRAGMA table_info(memes)')).map((r)=>r['name']).toSet();
      if(!columns.containsAll({'source','source_id','collected_at'}))return {};
      return {for(final row in await sql.query('memes',columns:['path','source','source_id','collected_at'])) row['path'] as String:row};
    } finally {await sql.close();}
  },db:db);

  Future<void> remove(String path) => SharedMediaLock.run(() async {
    StickerSharedFiles.safePackPath(path);
    final packs=StickerPackStorage(db:db),root=await StickerPackStorage(db:db).rootDirectory;
    final pack=Directory(p.join(root.path,packId));
    if(!await pack.exists())return;
    final index=await openDatabase(p.join(pack.path,'index.db'),singleInstance:false);
    late int remaining;
    try {
      final count=Sqflite.firstIntValue(await index.rawQuery('SELECT COUNT(*) FROM memes'))??0;
      final found=await index.query('memes',where:'path=?',whereArgs:[path]);
      if(found.isEmpty)return;
      if(count==1) {remaining=0;} else {
        await index.delete('memes',where:'path=?',whereArgs:[path]);remaining=count-1;
      }
    } finally {await index.close();}
    if(remaining==0) {await packs.deletePack(packId);return;}
    final shared=StickerSharedFiles(packRootOverride:root,
      mediaRootOverride:Directory(p.join(root.parent.path,'media_blobs')));
    await packs.clearCollectedCaptionEdits(path:path);
    final mapping=await shared.readMap(pack);mapping.remove(path);await writeMap(pack,mapping);
    // Orphan reclamation remains with the existing shared-media optimizer.
  },db:db);
}
