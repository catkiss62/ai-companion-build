import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack_storage.dart';
import 'package:ai_companion_localfirst/core/storage/media_blob_storage.dart';
import 'package:ai_companion_localfirst/core/storage/message_attachment_storage.dart';
import 'package:ai_companion_localfirst/core/storage/shared_media_lock.dart';
import 'package:ai_companion_localfirst/core/storage/sticker_shared_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getTemporaryPath() async => p.join(root.path, 'temp');
  @override
  Future<String?> getApplicationSupportPath() async => p.join(root.path, 'support');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory root;
  late AppDatabase db;
  late StickerPackStorage packs;
  late MediaBlobStorage blobs;
  late PathProviderPlatform previous;
  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGP8z8DAwMDAxMDAwMDAAAANHQEDasKb6QAAAABJRU5ErkJggg==');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('shared-stickers');
    await Directory(p.join(root.path, 'temp')).create();
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    packs = StickerPackStorage(db: db);
    blobs = MediaBlobStorage(db: db);
    await db.setSetting('active_brain', '1');
    await db.setSetting('transfer_lock', '0');
  });
  tearDown(() async {
    await db.closeForTesting();
    PathProviderPlatform.instance = previous;
    await root.delete(recursive: true);
  });
  Future<StickerPackMeta> importPack(String name, {List<int>? bytes}) async {
    final data = bytes ?? png;
    final archive = Archive()..addFile(ArchiveFile('$name/开心.png', data.length, data));
    final zip = File(p.join(root.path, '$name.zip'));
    await zip.writeAsBytes(ZipEncoder().encode(archive));
    return (await packs.importZip(zip.path)).imports.single.pack;
  }
  Future<MessageAttachment> send(StickerPackMeta pack, String id, {String role = 'user'}) async {
    final record = (await packs.readRecords(pack)).single;
    final attachment = await packs.prepareAttachment(pack: pack, record: record,
      messageId: id, source: '${role}_sticker:${pack.id}',
      attachments: MessageAttachmentStorage());
    await db.insertMessageWithAttachments(ChatMessage(id: id, role: role,
      content: '', createdAt: DateTime.now()), [attachment]);
    return attachment;
  }
  Future<List<String>> mediaFiles() async => (await (await blobs.rootDirectory)
      .list(recursive: true).where((e) => e is File).map((e) => e.path).toList())..sort();

  test('user and assistant send only references and share one thumbnail', () async {
    final pack = await importPack('猫猫');
    expect((await mediaFiles()).length, 1);
    final record = (await packs.readRecords(pack)).single;
    expect(await File(p.join(pack.rootPath, record.path)).exists(), isFalse);
    final first = await send(pack, 'u1');
    final files = await mediaFiles();
    final a = await send(pack, 'a1', role: 'assistant');
    final u = await send(pack, 'u2');
    expect(a.blobId, first.blobId);
    expect(u.blobId, first.blobId);
    expect(await mediaFiles(), files);
    expect(files.length, 2);
    expect((await db.mediaBlobById(first.blobId))!.messageRefCount, 3);
    expect(await Directory(p.join(root.path, 'temp', 'companion_attachment_drafts')).exists(), isFalse);
  });

  test('two packs share original; deleting pack retains messages and other pack', () async {
    final one = await importPack('一');
    final two = await importPack('二');
    final a = await send(one, 'u1');
    final original = await blobs.fileForReference(a.originalPath);
    expect((await mediaFiles()).length, 2);
    await packs.deletePack(one.id);
    expect(await original.exists(), isTrue);
    expect(await (await packs.fileFor(two, (await packs.readRecords(two)).single)).readAsBytes(), png);
    await packs.deletePack(two.id);
    expect(await original.exists(), isTrue);
    final orphans = await db.deleteMediaCacheBlobs({a.blobId});
    for (final orphan in orphans) { await blobs.deleteBlobFiles(orphan); }
    expect(await original.exists(), isFalse);
  });

  test('deleting chat media cannot remove a pack-owned original', () async {
    final pack = await importPack('保留');
    final a = await send(pack, 'u1');
    for (final orphan in await db.deleteMediaCacheBlobs({a.blobId})) {
      await blobs.deleteBlobFiles(orphan);
    }
    await blobs.pruneUnreferencedFiles([]);
    final file = await packs.fileFor(pack, (await packs.readRecords(pack)).single);
    expect(await file.readAsBytes(), png);
    final again = await send(pack, 'u2');
    expect(again.blobId, a.blobId);
  });

  test('same named replacement changes new reference but never old chat pixels', () async {
    final pack = await importPack('替换');
    final old = await send(pack, 'old');
    final changed = await importPack('替换', bytes: [...png, 0]);
    final latest = await send(changed, 'new');
    expect(latest.blobId, isNot(old.blobId));
    expect(await (await blobs.fileForReference(old.originalPath)).readAsBytes(), png);
    expect(await (await blobs.fileForReference(latest.originalPath)).readAsBytes(), [...png, 0]);
  });

  test('legacy pack plus existing chat blob migrates without copying another original', () async {
    final pack = await importPack('迁移');
    final a = await send(pack, 'old');
    final record = (await packs.readRecords(pack)).single;
    final legacy = File(p.join(pack.rootPath, record.path));
    await legacy.parent.create(recursive: true);
    await legacy.writeAsBytes(png);
    await File(p.join(pack.rootPath, StickerSharedFiles.manifestName)).delete();
    final before = await mediaFiles();
    await packs.scanPacks();
    expect(await legacy.exists(), isFalse);
    expect(await mediaFiles(), before);
    expect((await db.allMessageAttachments()).single.blobId, a.blobId);
    await packs.scanPacks();
    expect(await mediaFiles(), before);
  });

  test('interruption after map commit safely resumes removal of legacy copy', () async {
    final pack = await importPack('中断');
    final record = (await packs.readRecords(pack)).single;
    final legacy = File(p.join(pack.rootPath, record.path));
    await legacy.parent.create(recursive: true);
    await legacy.writeAsBytes(png);
    await packs.scanPacks();
    expect(await legacy.exists(), isFalse);
    expect(await (await packs.fileFor(pack, record)).readAsBytes(), png);
  });

  test('missing source before ownership commit never deletes remaining legacy original', () async {
    final raw = Directory(p.join(root.path, 'incomplete'));
    final source = File(p.join(raw.path, 'memes', 'ok.png'));
    await source.parent.create(recursive: true);
    await source.writeAsBytes(png);
    await expectLater(StickerSharedFiles().migrate(raw, ['memes/ok.png', 'memes/missing.png']), throwsA(anything));
    expect(await source.readAsBytes(), png);
    expect(await File(p.join(raw.path, StickerSharedFiles.manifestName)).exists(), isFalse);
  });

  test('restore directory swap preserves local pack-only original and rolls back safely', () async {
    final pack = await importPack('本机');
    final record = (await packs.readRecords(pack)).single;
    final incoming = Directory(p.join(root.path, 'incoming'));
    await incoming.create();
    final swap = await SharedMediaLock.run(() => blobs.prepareSnapshotInstall(
      extractedMedia: incoming, expectedPaths: [], snapshotId: 'test'), db: db);
    await swap.activate();
    expect(await (await packs.fileFor(pack, record)).readAsBytes(), png);
    await swap.rollback();
    expect(await (await packs.fileFor(pack, record)).readAsBytes(), png);
  });

  test('invalid map fails closed during cleanup instead of deleting unknown owners', () async {
    final pack = await importPack('损坏');
    final files = await mediaFiles();
    await File(p.join(pack.rootPath, StickerSharedFiles.manifestName)).writeAsString('{}');
    await expectLater(blobs.pruneUnreferencedFiles([]), throwsFormatException);
    expect(await mediaFiles(), files);
  });

  test('original SHA matches immutable path after migration', () async {
    final pack = await importPack('身份');
    final map = await StickerSharedFiles().readMap(Directory(pack.rootPath));
    expect(p.basenameWithoutExtension(map.values.single), sha256.convert(png).toString());
  });
}
