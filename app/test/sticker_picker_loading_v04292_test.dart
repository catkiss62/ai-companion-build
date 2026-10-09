import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack_storage.dart';
import 'package:ai_companion_localfirst/core/storage/sticker_shared_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Storage extends StickerPackStorage {
  _Storage(this.root, AppDatabase db) : super(db: db);
  final Directory root;
  int indexReads = 0;
  int individualResolves = 0;
  @override
  Future<Directory> get rootDirectory async => root;
  @override
  Future<List<StickerRecord>> readRecords(StickerPackMeta pack, {bool applyEdits = true}) {
    indexReads++;
    return super.readRecords(pack, applyEdits: applyEdits);
  }
  @override
  Future<File> fileFor(StickerPackMeta pack, StickerRecord record) {
    individualResolves++;
    return super.fileFor(pack, record);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory root;
  late AppDatabase db;
  late _Storage storage;
  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGP8z8DAwMDAxMDAwMDAAAANHQEDasKb6QAAAABJRU5ErkJggg==');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('picker-loading');
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    storage = _Storage(Directory('${root.path}/sticker_packs'), db);
  });
  tearDown(() async {
    await db.closeForTesting();
    await root.delete(recursive: true);
  });
  Future<StickerPackMeta> importPack(String name, {int count = 1, String caption = '开心'}) async {
    final archive = Archive();
    for (var i = 0; i < count; i++) {
      final data = count == 1 ? png : img.encodePng(
          img.Image(width: 2, height: 2)
            ..setPixelRgba(0, 0, i % 256, i ~/ 256, 100, 255));
      archive.addFile(ArchiveFile('$name/$caption$i.png', data.length, data));
    }
    final file = File('${root.path}/$name.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return (await storage.importZip(file.path)).imports.single.pack;
  }
  Future<List<String>> originals() async =>
      (await Directory('${root.path}/media_blobs').list(recursive: true)
          .where((entry) => entry is File).map((entry) => entry.path).toList())..sort();

  test('600 stickers load once per pack; reopen/new storage reuse metadata without image copies', () async {
    await importPack('大包', count: 600);
    storage.indexReads = 0;
    final files = await originals();
    final watch = Stopwatch()..start();
    final first = await storage.loadPickerCatalog();
    final cold = watch.elapsedMicroseconds;
    watch.reset();
    final again = await storage.loadPickerCatalog();
    final warm = watch.elapsedMicroseconds;
    watch.stop();
    expect(first.items.length, 600);
    expect(storage.indexReads, 1);
    expect(storage.individualResolves, 0);
    expect(identical(first, again), isTrue);
    final other = _Storage(storage.root, db);
    expect(identical(await other.loadPickerCatalog(), first), isTrue);
    expect(other.indexReads, 0);
    expect(await originals(), files);
    expect(files.length, 600);
    expect(() => first.items.clear(), throwsUnsupportedError);
    // Report evidence, not a machine-dependent timing assertion.
    // ignore: avoid_print
    print('picker 600 items: cold=${cold}us warm=${warm}us indexReads=1 individualResolves=0');
  });

  test('concurrent opens share one completed load', () async {
    await importPack('猫猫');
    storage.indexReads = 0;
    final results = await Future.wait(List.generate(4, (_) => storage.loadPickerCatalog()));
    expect(results.every((item) => identical(item, results.first)), isTrue);
    expect(storage.indexReads, 1);
  });

  test('enable and disable through another instance refresh the next open', () async {
    final pack = await importPack('开关');
    final first = await storage.loadPickerCatalog();
    final other = _Storage(storage.root, db);
    await other.setPackEnabled(pack.id, false);
    expect((await storage.loadPickerCatalog()).items, isEmpty);
    await other.setPackEnabled(pack.id, true);
    final enabled = await storage.loadPickerCatalog();
    expect(enabled.items.length, 1);
    expect(identical(first, enabled), isFalse);
  });

  test('saved captions refresh; rejected edits leave the displayed caption intact', () async {
    await importPack('描述');
    final before = await storage.loadPickerCatalog();
    final key = before.items.single.record.usageKey;
    await _Storage(storage.root, db).saveCaptionEdits({key: '偷偷看你'});
    expect((await storage.loadPickerCatalog()).items.single.record.caption, '偷偷看你');
    await expectLater(storage.saveCaptionEdits({key: ' '}), throwsFormatException);
    expect((await storage.loadPickerCatalog()).items.single.record.caption, '偷偷看你');
  });

  test('same-id reimport and deletion cannot reuse an old catalog', () async {
    final pack = await importPack('换包');
    final old = await storage.loadPickerCatalog();
    await importPack('换包', count: 2, caption: '晚安');
    final replacement = await storage.loadPickerCatalog();
    expect(replacement.items.length, 2);
    expect(identical(old, replacement), isFalse);
    expect(replacement.items.every((item) => item.record.caption.startsWith('晚安')), isTrue);
    await storage.deletePack(pack.id);
    expect((await storage.loadPickerCatalog()).packs, isEmpty);
  });

  test('restore epoch and database settings changed outside this instance invalidate cache', () async {
    await importPack('恢复');
    final before = await storage.loadPickerCatalog();
    await db.setSetting('runtime_state_epoch_v1', 'new-restore-transaction');
    final restored = await storage.loadPickerCatalog();
    expect(identical(before, restored), isFalse);
    await db.setSetting(StickerPackStorage.captionOverridesSetting,
        jsonEncode({restored.items.single.record.usageKey: '恢复后的描述'}));
    expect((await storage.loadPickerCatalog()).items.single.record.caption, '恢复后的描述');
    await db.setSetting(StickerPackStorage.enabledPacksSetting, '[]');
    expect((await storage.loadPickerCatalog()).items, isEmpty);
  });

  test('broken map is not cached; repair makes the pack visible again', () async {
    final pack = await importPack('映射');
    await storage.loadPickerCatalog();
    final map = File('${pack.rootPath}/${StickerSharedFiles.manifestName}');
    final good = await map.readAsString();
    await map.writeAsString('{"version":999}');
    expect((await storage.loadPickerCatalog()).items, isEmpty);
    await map.writeAsString(good);
    expect((await storage.loadPickerCatalog()).items.length, 1);
  });

  test('missing originals invalidate the catalog and later repair is retried', () async {
    await importPack('损坏');
    final old = await storage.loadPickerCatalog();
    await old.items.single.file.delete();
    expect((await storage.loadPickerCatalog()).items, isEmpty);
    // Import restores the content-addressed original; failed load was not cached.
    await importPack('正常');
    expect((await storage.loadPickerCatalog()).packs.length, 2);
  });

  test('legacy migration resolves final shared paths and is reused on reopen', () async {
    final pack = await importPack('旧包');
    final record = (await storage.readRecords(pack)).single;
    final shared = await storage.fileFor(pack, record);
    final raw = File('${pack.rootPath}/${record.path}');
    await raw.parent.create(recursive: true);
    await shared.copy(raw.path);
    await File('${pack.rootPath}/${StickerSharedFiles.manifestName}').delete();
    final catalog = await storage.loadPickerCatalog();
    expect(await raw.exists(), isFalse);
    expect(catalog.items.single.file.path, shared.path);
    expect(await catalog.items.single.file.readAsBytes(), png);
    expect(identical(await storage.loadPickerCatalog(), catalog), isTrue);
  });
}
