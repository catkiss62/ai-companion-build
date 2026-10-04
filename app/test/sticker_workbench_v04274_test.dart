import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_expression_service.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack_storage.dart';
import 'package:ai_companion_localfirst/core/stickers/simple_sticker_archive.dart';
import 'package:ai_companion_localfirst/features/chat/sticker_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Storage extends StickerPackStorage {
  _Storage(this.root, AppDatabase db) : super(db: db);
  final Directory root;
  @override
  Future<Directory> get rootDirectory async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory root;
  late AppDatabase db;
  late _Storage storage;
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGP8z8DAwMDAxMDAwMDAAAANHQEDasKb6QAAAABJRU5ErkJggg==',
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sticker-workbench');
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    storage = _Storage(Directory('${root.path}/packs'), db);
  });
  tearDown(() async {
    await db.closeForTesting();
    await root.delete(recursive: true);
  });
  Future<String> zip(String name, Map<String, List<int>> files) async {
    final a = Archive();
    for (final e in files.entries) {
      a.addFile(ArchiveFile(e.key, e.value.length, e.value));
    }
    final f = File('${root.path}/$name.zip');
    await f.writeAsBytes(ZipEncoder().encode(a));
    return f.path;
  }

  Future<StickerPackMeta> fixture() async => (await storage.importZip(
    await zip('猫咪表情', {'猫咪表情/猫咪开心.png': png}),
  )).imports.single.pack;

  test(
    'ordinary ZIP creates named category and repeats replace, preserving manual edits',
    () async {
      final pack = await fixture();
      expect(pack.name, '猫咪表情');
      final r = (await storage.readRecords(pack)).single;
      expect(r.tag, '猫咪表情');
      expect(r.caption, '猫咪开心');
      await storage.saveCaptionEdits({r.usageKey: '猫咪气鼓鼓'});
      final again = await storage.importZip(
        await zip('猫咪表情', {'猫咪表情/改名了.png': png}),
      );
      expect(again.imports.single.replaced, true);
      expect((await storage.scanPacks()).length, 1);
      final updated = (await storage.readRecords(
        again.imports.single.pack,
      )).single;
      expect(updated.usageKey, r.usageKey);
      expect(updated.caption, '猫咪气鼓鼓');
      expect(updated.keywords, '');
      await storage.importZip(await zip('狗狗表情', {'狗狗表情/狗狗开心.png': png}));
      expect((await storage.scanPacks()).map((p) => p.name), ['猫咪表情', '狗狗表情']);
    },
  );

  test(
    'corrupt, traversal, mixed roots and fake webq never replace an installed pack',
    () async {
      await fixture();
      for (final entries in [
        {
          '猫咪表情/坏图.png': [1, 2, 3],
        },
        {'../逃逸.png': png},
        {'猫咪表情/a.png': png, '另一个/b.png': png},
        {'猫咪表情/伪装.webq': png},
        {'猫咪表情/manifest.json': utf8.encode('{}'), '猫咪表情/a.png': png},
      ]) {
        await expectLater(
          storage.importZip(await zip('invalid', entries)),
          throwsA(anything),
        );
        expect(
          (await storage.readRecords(
            (await storage.scanPacks()).single,
          )).single.caption,
          '猫咪开心',
        );
      }
    },
  );

  test(
    'saved description reaches AI candidates and custom pack emotion matching',
    () async {
      final pack = await fixture();
      final row = (await storage.readRecords(pack)).single;
      await storage.saveCaptionEdits({row.usageKey: '狗狗生气了'});
      final service = StickerExpressionService(db: db, packStorage: storage);
      final candidates = await service.replyCandidates(
        seed: 'test',
        context: '发张生气的表情包',
      );
      expect(candidates.single.record.caption, '狗狗生气了');
      expect(
        StickerExpressionService.moodForRecord(candidates.single.record),
        'angry',
      );
      final prompt = StickerExpressionService.replyChoicePrompt(candidates);
      expect(prompt, contains('狗狗生气了'));
      expect(prompt, contains('不必与你自身身份和外貌一致'));
      expect(prompt, isNot(contains('猫咪开心')));
    },
  );

  test('real WebP and webq alias decode and normalize to webp', () async {
    final webp = base64Decode(
      'UklGRjoAAABXRUJQVlA4IC4AAACQAQCdASoCAAIAAUAmJaACdLoAA5gA/vtV4/+lwf/S4P/pcH/pcH8bss4bpAAA',
    );
    for (final ext in ['webp', 'webq']) {
      final imported = await storage.importZip(
        await zip('鲸鱼', {'鲸鱼/开心.$ext': webp}),
      );
      final row = (await storage.readRecords(
        imported.imports.single.pack,
      )).single;
      expect(row.path, endsWith('.webp'));
      expect(row.caption, '开心');
    }
    expect((await storage.scanPacks()).length, 1);
  });

  test(
    'indexed bundle remains compatible and rejects broken child without replacing',
    () async {
      final pack = await fixture();
      final files = <String, List<int>>{};
      await for (final entity in Directory(
        pack.rootPath,
      ).list(recursive: true)) {
        if (entity is File) {
          files[entity.path.substring(pack.rootPath.length + 1)] = await entity
              .readAsBytes();
        }
      }
      final children = <String, List<int>>{};
      for (final id in [
        'personal-001',
        'official-001',
        'q-whale-001',
        'dafeiyu-001',
      ]) {
        final manifest =
            jsonDecode(utf8.decode(files['manifest.json']!)) as Map;
        manifest['id'] = id;
        final child = await zip(id, {
          ...files,
          'manifest.json': utf8.encode(jsonEncode(manifest)),
        });
        children['$id.zip'] = await File(child).readAsBytes();
      }
      final bundle = await zip('整合', children);
      await storage.importZip(bundle);
      final again = await storage.importZip(bundle);
      expect(again.imports.every((i) => i.replaced), isTrue);
      expect((await storage.scanPacks()).map((p) => p.id), [
        'personal-001',
        'official-001',
        'q-whale-001',
        'dafeiyu-001',
        pack.id,
      ]);
      final before = (await storage.scanPacks()).length;
      await expectLater(
        storage.importZip(
          await zip('损坏整合', {
            ...children,
            'zzz-broken.zip': [1, 2, 3],
          }),
        ),
        throwsA(anything),
      );
      expect((await storage.scanPacks()).length, before);
      expect(
        (await storage.readRecords(
          (await storage.scanPacks()).first,
        )).single.caption,
        '猫咪开心',
      );
    },
  );

  test('duplicates by image bytes collapse within ordinary pack', () async {
    final r = await storage.importZip(
      await zip('猫咪表情', {'猫咪表情/a.png': png, '猫咪表情/b.png': png}),
    );
    expect(r.stickerCount, 1);
  });

  test('caption commit atomic failure keeps all previous values', () async {
    final p = await fixture();
    final r = (await storage.readRecords(p)).single;
    await storage.saveCaptionEdits({r.usageKey: '原编辑'});
    final sql = await db.database;
    await sql.execute(
      "CREATE TRIGGER reject_caption BEFORE INSERT ON settings WHEN NEW.key = '${StickerPackStorage.captionOverridesSetting}' BEGIN SELECT RAISE(ABORT,'disk failure'); END",
    );
    await expectLater(
      storage.saveCaptionEdits({r.usageKey: '新编辑', 'other:memes/a.png': '另一张'}),
      throwsA(anything),
    );
    expect(await storage.captionOverrides(), {r.usageKey: '原编辑'});
  });

  test('invalid caption rejects entire batch before save', () async {
    await expectLater(
      storage.saveCaptionEdits({'a:memes/a.png': '好', 'a:memes/b.png': ' '}),
      throwsFormatException,
    );
    expect(await storage.captionOverrides(), isEmpty);
    expect(
      SimpleStickerArchive.packId('猫咪表情'),
      SimpleStickerArchive.packId(' 猫咪表情 '),
    );
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showGeneralDialog<SelectedUserSticker>(
                context: context,
                barrierDismissible: false,
                pageBuilder: (context, _, _) =>
                    StickerPickerSheet(storage: storage),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('打开'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
  }

  Future<void> edit(WidgetTester tester, String caption) async {
    await tester.tap(find.text('修改表情包'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('sticker-caption-input')),
      caption,
    );
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'confirm only stages; outside tap stays; exit and route disposal discard',
    (tester) async {
      await tester.runAsync(fixture);
      await open(tester);
      await edit(tester, '狗狗偷听');
      expect(await tester.runAsync(storage.captionOverrides), isEmpty);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('保存'), findsOneWidget);
      await tester.tap(find.text('退出'));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(storage.captionOverrides), isEmpty);
      await edit(tester, '未保存草稿');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await tester.runAsync(storage.captionOverrides), isEmpty);
    },
  );
  testWidgets(
    'save applies caption to picker and future selection; reset uses session baseline',
    (tester) async {
      await tester.runAsync(fixture);
      await open(tester);
      await edit(tester, '猫咪偷听');
      await tester.runAsync(() async {
        await tester.tap(find.text('保存'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      final records = await tester.runAsync(
        () async => storage.readRecords((await storage.scanPacks()).single),
      );
      expect(records!.single.caption, '猫咪偷听');
      await tester.tap(find.text('修改表情包'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '待重置');
      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      expect(find.text('猫咪偷听'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'small phone keyboard layout and failed Save retain drafts for retry',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.runAsync(fixture);
      await open(tester);
      await edit(tester, '保留草稿');
      await tester.drag(find.text('修改表情包 · 确认后点击保存才生效'), const Offset(0, 220));
      await tester.pumpAndSettle();
      expect(find.text('保存'), findsOneWidget);
      await tester.runAsync(() async {
        final sql = await db.database;
        await sql.execute(
          "CREATE TRIGGER reject_caption BEFORE INSERT ON settings WHEN NEW.key = '${StickerPackStorage.captionOverridesSetting}' BEGIN SELECT RAISE(ABORT,'disk failure'); END",
        );
        await tester.tap(find.text('保存'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(find.text('保存失败'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('知道了'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      expect(find.text('保留草稿'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('确认'));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await (await db.database).execute('DROP TRIGGER reject_caption');
        await tester.tap(find.text('保存'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(storage.captionOverrides))!.values.single,
        '保留草稿',
      );
    },
  );
}
