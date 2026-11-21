import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../storage/shared_media_lock.dart';
import 'collected_sticker_storage.dart';
import 'simple_sticker_archive.dart';
import 'sticker_pack_storage.dart';

class CollectionImportResult {
  const CollectionImportResult(this.added,this.existing);
  final int added, existing;
  String get message => '新增 $added 张，已有 $existing 张';
}

class CollectedStickerArchive {
  CollectedStickerArchive(this.db);
  final AppDatabase db;
  static const marker = 'collected-stickers.json';
  static final imagePath = RegExp(r'^memes/[0-9a-f]{64}\.(gif|png|jpg|webp)$');
  static String name(DateTime t) => '收集的表情_${t.toIso8601String().split('.').first.replaceAll('T','_').replaceAll(':','-')}.zip';

  Future<File> exportZip() => SharedMediaLock.run(() async {
    final packs = StickerPackStorage(db:db);
    final rows = await packs.loadPackEntries(CollectedStickerStorage.packId);
    if(rows.isEmpty) throw const FormatException('还没有收集的表情');
    final sources = await CollectedStickerStorage(db:db).sources();
    final directory = await (await getTemporaryDirectory()).createTemp('collected_');
    final file = File(p.join(directory.path,name(DateTime.now())));
    final encoder = ZipFileEncoder();
    try {
      encoder.create(file.path);
      try {
        final entries = <Map<String,Object?>>[];
        for(final entry in rows) {
          final row = entry.record;
          final image = entry.file;
          if(!imagePath.hasMatch(row.path) || (await sha256.bind(image.openRead()).first).toString()!=p.basenameWithoutExtension(row.path)) {
            throw const FormatException('收藏原图缺失或内容不符');
          }
          await encoder.addFile(image,row.path);
          final info=sources[row.path];
          entries.add({'path':row.path,'caption':row.caption,'source':info?['source']??'user','at':info?['collected_at']});
        }
        final manifest=File(p.join(directory.path,marker));
        await manifest.writeAsString(jsonEncode({'version':1,'entries':entries}));
        await encoder.addFile(manifest,marker);
      } finally {await encoder.close();}
      return file;
    } catch (_) {await directory.delete(recursive:true);rethrow;}
  },db:db);

  // Null delegates an ordinary pack to the original gallery importer.
  Future<CollectionImportResult?> importZip(String path) async {
    final input=InputFileStream(path);
    try {
      final archive=ZipDecoder().decodeStream(input);
      final manifest=archive.findFile(marker);
      if(manifest==null) return null;
      if(manifest.isSymbolicLink) throw const FormatException('收藏包清单无效');
      if(!manifest.isFile || manifest.size>2*1024*1024 || archive.length>StickerPackStorage.maxStickers+1) {
        throw const FormatException('收藏包清单无效');
      }
      final data=jsonDecode(utf8.decode(manifest.content));
      if(data is! Map || data['version']!=1 || data['entries'] is! List) throw const FormatException('收藏包格式无效');
      final rows=List<Map>.from(data['entries'] as List);
      final images=<String,ArchiveFile>{};
      for(final f in archive) {
        if(f.name==marker)continue;
        if(!imagePath.hasMatch(f.name) || !f.isFile || f.isSymbolicLink || f.size<=0 || f.size>CollectedStickerStorage.maxBytes || images.containsKey(f.name)) {
          throw const FormatException('收藏包图片条目无效');
        }
        images[f.name]=f;
      }
      final paths=rows.map((r)=>r['path']).toSet();
      if(rows.length!=paths.length || rows.length!=images.length || archive.length!=rows.length+1 || !paths.containsAll(images.keys)) throw const FormatException('收藏包与清单不符');
      return await SharedMediaLock.run(() async {
        var added=0;
        for(final r in rows) {
          final f=images[r['path']]!;
          try {
            final bytes=f.content;
            if('memes/${sha256.convert(bytes)}${SimpleStickerArchive.imageExtension(bytes)}'!=f.name) throw const FormatException('收藏图片校验失败');
            if(await CollectedStickerStorage(db:db).collect(bytes,caption:r['caption'] as String,
              source:r['source'] as String,sourceId:'import',collectedAt:r['at'] as int?)) added++;
          } catch(error) {
            throw FormatException('已新增 $added 张，读取这张时停止。可修复后重复导入：$error');
          } finally {
            // ZipDecoder caches inflated bytes. Release each GIF before reading the next.
            f.clear();
          }
        }
        return CollectionImportResult(added,rows.length-added);
      },db:db);
    } finally {await input.close();}
  }

  Future<CollectionImportResult> importLegacy(Directory pack, Map edits) async {
    final index=File(p.join(pack.path,'index.db'));
    if(!await index.exists()) throw const FormatException('这个存档没有收集的表情');
    final sql=await openDatabase(index.path,readOnly:true,singleInstance:false);
    try {
      final rows=await sql.query('memes');
      var added=0;
      for(final row in rows) {
        final path=row['path'] as String;
        if(!imagePath.hasMatch(path))throw const FormatException('旧收藏路径无效');
        final file=File(p.join(pack.path,path));
        if(await file.length()>CollectedStickerStorage.maxBytes)throw const FormatException('旧收藏图片过大');
        final bytes=await file.readAsBytes();
        if(p.basenameWithoutExtension(path)!=sha256.convert(bytes).toString())throw const FormatException('旧收藏图片校验失败');
        if(await CollectedStickerStorage(db:db).collect(bytes,
          caption:(edits['${CollectedStickerStorage.packId}:$path']??row['caption']) as String,
          source:row['source'] as String? ?? 'user',sourceId:'import',collectedAt:row['collected_at'] as int?))added++;
      }
      return CollectionImportResult(added,rows.length-added);
    } finally {await sql.close();}
  }
}
