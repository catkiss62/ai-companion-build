import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack_storage.dart';
import 'package:ai_companion_localfirst/core/storage/message_attachment_storage.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_session_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/storage/portable_companion_storage.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/core/sync/snapshot_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getTemporaryPath() async => p.join(root.path, 'temp');
  @override
  Future<String?> getApplicationSupportPath() async =>
      p.join(root.path, 'support');
}

class _Native extends NativePortableBackend {
  _Native(this.models);
  final Directory models;
  Map<String, dynamic> prefs = {
    'caicai_stage': {'motionSpeed': 1.2, 'legPivot': .87},
    'overlay_state': {'pet_motion_mode': 'half_left'},
    'companion_runtime': {'overlay_user_enabled': true},
  };
  Map<String, dynamic>? before;
  bool failApply = false;
  bool failFinishOnce = false;
  bool busy = false;
  int applyCount = 0;
  bool? restoredModels;
  @override
  Future<NativePortableSnapshot> begin({bool exporting = false}) async {
    if (busy) throw StateError('busy');
    busy = true;
    before = Map<String, dynamic>.from(jsonDecode(jsonEncode(prefs)));
    return NativePortableSnapshot('lease', models, prefs);
  }

  @override
  Future<void> validateModels(
    NativePortableSnapshot snapshot,
    Directory directory,
  ) async {
    if (await directory.exists() &&
        !(await directory.list().isEmpty) &&
        !await File(p.join(directory.path, '女仆', 'model.moc3')).exists()) {
      throw const FormatException('missing model');
    }
  }

  @override
  Future<void> validatePreferences(Map<String, dynamic> preferences) async {
    if (preferences.keys.toSet().length != 3)
      throw const FormatException('prefs');
  }

  @override
  Future<void> apply(
    NativePortableSnapshot snapshot,
    Map<String, dynamic> preferences, {
    bool restoreModels = true,
  }) async {
    applyCount++;
    restoredModels = restoreModels;
    prefs = Map<String, dynamic>.from(jsonDecode(jsonEncode(preferences)));
    if (failApply) throw StateError('simulated native preference failure');
  }

  @override
  Future<void> finish(
    NativePortableSnapshot snapshot, {
    required bool commit,
  }) async {
    if (!commit) prefs = before!;
    busy = false;
    if (commit && failFinishOnce) {
      failFinishOnce = false;
      throw StateError('simulated failure after database commit');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory root;
  late AppDatabase db;
  late _Native native;
  late SecureConfig secure;
  late PortableCompanionStorage portable;
  late SnapshotService service;
  late PathProviderPlatform previousPaths;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('portable-v7-test');
    await Directory(p.join(root.path, 'temp')).create();
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    native = _Native(Directory(p.join(root.path, 'native', 'current')));
    FlutterSecureStorage.setMockInitialValues({
      'deepseek_api_key': 'LOCAL_SECRET_KEEP',
      'cedar_toy_token': 'LOCAL_CEDAR_KEEP',
      'openrouter_jev_api_key': 'LOCAL_JEV_KEEP',
    });
    secure = SecureConfig.forTesting(const FlutterSecureStorage());
    portable = PortableCompanionStorage(
      native: native,
      secure: secure,
      stickerDirectory: Directory(
        p.join(root.path, 'support', 'sticker_packs'),
      ),
    );
    service = SnapshotService(db, portableStorage: portable);
    await db.setSetting('transfer_lock', '1');
    await db.setSetting('active_brain', '1');
  });
  tearDown(() async {
    PathProviderPlatform.instance = previousPaths;
    await db.closeForTesting();
    await root.delete(recursive: true);
  });
  Future<void> fixture() async {
    // Structural bytes only: these models are not rendered or distributed.
    final file = File(p.join(native.models.path, '女仆', 'model.moc3'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes([0, 1, 2, 3, 255]);
    final pack = Directory(
      p.join((await portable.stickerRoot).path, 'fixture-pack'),
    );
    await Directory(p.join(pack.path, 'memes')).create(recursive: true);
    await File(p.join(pack.path, 'manifest.json'))
        .writeAsString('{"id":"fixture-pack","name":"Fixture"}');
    final index = await databaseFactoryFfi.openDatabase(
      p.join(pack.path, 'index.db'),
    );
    await index.execute(
      'CREATE TABLE memes(path TEXT, tag TEXT, file_name TEXT, caption TEXT, keywords TEXT)',
    );
    await index.insert('memes', {
      'path': 'memes/1.png',
      'tag': 'happy',
      'file_name': '1.png',
      'caption': 'fixture',
      'keywords': 'fixture',
    });
    await index.close();
    await File(p.join(pack.path, 'memes', '1.png')).writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGP8z8DAwMDAxMDAwMDAAAANHQEDasKb6QAAAABJRU5ErkJggg==',
      ),
    );
    await secure.writeEndpoint('https://example.com/v1/chat/completions');
    await secure.writeJevEnabled(true);
    await db.setSetting('remembered_user_facts_v1', '{"fact":"中午一点吃饭"}');
    await db.setSetting('caicai_jev_motion', '0');
  }

  Future<Archive> decode(String path) async =>
      ZipDecoder().decodeBytes(await File(path).readAsBytes());
  Map<String, dynamic> object(Archive a, String name) =>
      Map<String, dynamic>.from(
        jsonDecode(utf8.decode(a.findFile(name)!.content as List<int>)),
      );
  Future<void> writeArchive(Archive archive, String path) async =>
      File(path).writeAsBytes(ZipEncoder().encode(archive));

  // Construct the previous v7 payload independently of the new exporter, so
  // compatibility tests cannot silently follow its settings-only behavior.
  Future<SnapshotBundle> legacyBackup() async {
    final bundle = await service.exportBackupBundle();
    final archive = await decode(bundle.filePath);
    final state = object(archive, 'state.json');
    final config = state['portable_state'] as Map;
    config['version'] = 1;
    config.remove('resource_files');
    final paths = <String, List<String>>{'live2d': [], 'stickers': []};
    final hashes = <String, String>{};
    var size = 0;
    for (final entry in {
      'live2d': native.models,
      'stickers': await portable.stickerRoot,
    }.entries) {
      if (!await entry.value.exists()) continue;
      await for (final file in entry.value.list(recursive: true)) {
        if (file is! File) continue;
        final relative = p.relative(file.path, from: entry.value.path)
            .replaceAll('\\', '/');
        final bytes = await file.readAsBytes();
        paths[entry.key]!.add(relative);
        hashes['${entry.key}/$relative'] = sha256.convert(bytes).toString();
        size += bytes.length;
        archive.addFile(ArchiveFile('portable/${entry.key}/$relative', bytes.length, bytes));
      }
    }
    config['file_paths'] = paths;
    final bytes = utf8.encode(jsonEncode(state));
    final manifest = object(archive, 'manifest.json');
    manifest['portable_files'] = hashes;
    manifest['portable_bytes'] = size;
    manifest['state_sha256'] = sha256.convert(bytes).toString();
    manifest['state_bytes'] = bytes.length;
    archive.addFile(ArchiveFile('state.json', bytes.length, bytes));
    final m = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('manifest.json', m.length, m));
    await writeArchive(archive, bundle.filePath);
    return bundle;
  }

  test('real backup restore keeps task budget but excludes clock and stale leases', () async {
    await fixture();
    await db.setSetting('transfer_lock', '0');
    final session = await CedarToyActivityStore(db).recordGuide(
        gameId: 'white_room', guide: '单人游戏。explore 探索。');
    await db.insertMessage(ChatMessage(id: 'task-reply', role: 'assistant',
        content: '好，我去玩。', createdAt: DateTime.now()));
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.stage(turnId: 'backup', assistantId: 'task-reply', session: session, minutes: 20);
    await tasks.activateCommitted(turnId: 'backup');
    final periods = CedarPlaySessionStore(db);
    final period = (await periods.load())!;
    await periods.save(period.tick(period.startedAt.add(const Duration(minutes: 1))));
    await db.setSetting('transfer_lock', '1');
    final bundle = await service.exportBackupBundle();
    final exported = object(await decode(bundle.filePath), 'state.json');
    final settings = (exported['tables']['settings'] as List)
        .map((r) => r as Map).toList();
    expect(settings.singleWhere((r) => r['key'] == CedarPlaySessionStore.key)['value'], '');
    expect(jsonDecode(settings.singleWhere((r) => r['key'] == CedarTimedPlayTaskStore.activeKey)['value'])['usedMs'], 60000);
    // Saving itself only pauses the clock, never ends the current task.
    expect(await tasks.active(), isNotNull);
    expect(await tasks.pendingReports(), isEmpty);
    await service.restoreBackupBundle(bundle.filePath);
    expect(await periods.load(), isNull);
    expect(await db.getSetting(CedarTimedPlayTaskStore.leaseKey), '0');
    expect((await tasks.active())!['usedMs'], 60000);
    await tasks.reconcile(DateTime.now().add(const Duration(hours: 4)));
    final resumed = (await periods.load())!;
    expect(resumed.usedMs, 60000);
    expect(resumed.limitMs, 1200000);
    expect(await tasks.pendingReports(), isEmpty);
    expect(native.restoredModels, false);
  });

  test('legacy full v7 backup still restores models stickers facts and non-secret settings', () async {
    await fixture();
    final bundle = await legacyBackup();
    final archive = await decode(bundle.filePath);
    expect(bundle.metadata.protocolVersion, 7);
    final state = object(archive, 'state.json');
    expect(jsonEncode(state), isNot(contains('LOCAL_SECRET_KEEP')));
    expect(jsonEncode(state), isNot(contains('LOCAL_CEDAR_KEEP')));
    expect(archive.findFile('portable/live2d/女仆/model.moc3'), isNotNull);
    expect(
      archive.findFile('portable/stickers/fixture-pack/memes/1.png'),
      isNotNull,
    );
    await native.models.delete(recursive: true);
    await (await portable.stickerRoot).delete(recursive: true);
    native.prefs = {
      'caicai_stage': {},
      'overlay_state': {},
      'companion_runtime': {},
    };
    await secure.writeEndpoint('https://local.invalid/v1');
    await secure.writeJevEnabled(false);
    await db.setSetting('remembered_user_facts_v1', 'changed');
    final result = await service.restoreBackupBundle(bundle.filePath);
    expect(result!.restoredFromBackup, true);
    expect(
      await File(p.join(native.models.path, '女仆', 'model.moc3')).readAsBytes(),
      [0, 1, 2, 3, 255],
    );
    expect(
      await secure.readEndpoint(),
      'https://example.com/v1/chat/completions',
    );
    expect(await secure.readJevEnabled(), true);
    expect(await secure.readApiKey(), 'LOCAL_SECRET_KEEP');
    expect(await secure.readCedarToyToken(), 'LOCAL_CEDAR_KEEP');
    expect(await secure.readOpenRouterApiKey(), 'LOCAL_JEV_KEEP');
    expect(await db.getSetting('remembered_user_facts_v1'), contains('中午一点吃饭'));
    expect(native.prefs['caicai_stage']['legPivot'], .87);
    expect(await db.getSetting('cedar_toy_play_session_v1'), '');
  });

  test('a failure after database commit completes new state instead of reporting rollback', () async {
    await fixture();
    final bundle = await service.exportBackupBundle();
    await db.setSetting('restore_sentinel', 'not-in-backup');
    await secure.writeEndpoint('https://local.invalid/v1');
    native.failFinishOnce = true;
    final result = await service.restoreBackupBundle(bundle.filePath);
    expect(result!.imported, isTrue);
    expect(result.recoveryPending, isFalse);
    expect(result.completionWarning, contains('数据已恢复'));
    expect(await db.getSetting('restore_sentinel'), isNull);
    expect(await secure.readEndpoint(), 'https://example.com/v1/chat/completions');
    expect(native.busy, isFalse);
    expect(native.restoredModels, isFalse);
    expect(await db.getSetting('snapshot_recovery_pending_v1'), '');
  });

  test('failure after native writes restores files prefs secure config and database', () async {
    await fixture();
    final bundle = await service.exportBackupBundle();
    await File(p.join(native.models.path, '女仆', 'model.moc3'))
        .writeAsString('LOCAL_MODEL');
    native.prefs['caicai_stage'] = {'legPivot': .96};
    await secure.writeEndpoint('https://local.invalid/v1');
    await db.setSetting('remembered_user_facts_v1', 'LOCAL_FACT');
    native.failApply = true;
    await expectLater(
      service.restoreBackupBundle(bundle.filePath),
      throwsStateError,
    );
    expect(
      await File(p.join(native.models.path, '女仆', 'model.moc3')).readAsString(),
      'LOCAL_MODEL',
    );
    expect(native.prefs['caicai_stage']['legPivot'], .96);
    expect(await secure.readEndpoint(), 'https://local.invalid/v1');
    expect(await db.getSetting('remembered_user_facts_v1'), 'LOCAL_FACT');
    expect(native.busy, false);
  });

  test(
    'database import failure rolls back already applied portable configuration',
    () async {
      await fixture();
      final bundle = await service.exportBackupBundle();
      final archive = await decode(bundle.filePath);
      // A non-map row reaches the actual database transaction after activation.
      final state = object(archive, 'state.json');
      state['tables']['messages'] = ['invalid-row'];
      final bytes = utf8.encode(jsonEncode(state));
      final manifest = object(archive, 'manifest.json');
      // Hash calculation is shared only by the fixture; production rereads all bytes.
      manifest['state_sha256'] = await _digest(bytes);
      manifest['state_bytes'] = bytes.length;
      archive.addFile(ArchiveFile('state.json', bytes.length, bytes));
      final m = utf8.encode(jsonEncode(manifest));
      archive.addFile(ArchiveFile('manifest.json', m.length, m));
      final path = p.join(root.path, 'bad-database.zip');
      await writeArchive(archive, path);
      await secure.writeEndpoint('https://local.invalid/v1');
      native.prefs['caicai_stage'] = {'legPivot': .96};
      final appliedBefore = native.applyCount;
      await expectLater(service.restoreBackupBundle(path), throwsA(anything));
      expect(native.applyCount, appliedBefore + 1);
      expect(await secure.readEndpoint(), 'https://local.invalid/v1');
      expect(native.prefs['caicai_stage']['legPivot'], .96);
    },
  );

  test('fresh installation restores relative model and sticker paths without copying ownership or keys', () async {
    await fixture();
    final bundle = await legacyBackup();
    final targetRoot = Directory(p.join(root.path, 'other-installation'));
    await targetRoot.create();
    await Directory(p.join(targetRoot.path, 'temp')).create();
    PathProviderPlatform.instance = _Paths(targetRoot);
    final targetDb = await AppDatabase.createForTesting(
      databaseFactoryFfi,
      path: p.join(targetRoot.path, 'target.db'),
    );
    try {
      final targetId = await targetDb.ensureDeviceId();
      await targetDb.setSetting('transfer_lock', '1');
      await targetDb.setSetting('active_brain', '0');
      // Separate secure-storage installation; source credentials stay absent.
      FlutterSecureStorage.setMockInitialValues({
        'deepseek_api_key': 'TARGET_SECRET_KEEP',
      });
      final targetNative = _Native(
        Directory(p.join(targetRoot.path, 'native', 'current')),
      );
      final targetPortable = PortableCompanionStorage(
        native: targetNative,
        secure: secure,
        stickerDirectory: Directory(
          p.join(targetRoot.path, 'support', 'sticker_packs'),
        ),
      );
      final targetService = SnapshotService(
        targetDb,
        portableStorage: targetPortable,
      );
      final restored = await targetService.restoreBackupBundle(
        bundle.filePath,
        allowLineageReplacement: true,
      );
      expect(restored!.requiresManualTakeover, true);
      expect(await targetDb.ensureDeviceId(), targetId);
      expect(await targetDb.getSetting('active_brain'), '0');
      expect(
        await targetDb.getSetting('remembered_user_facts_v1'),
        contains('中午一点吃饭'),
      );
      expect(
        await File(p.join(targetNative.models.path, '女仆', 'model.moc3'))
            .readAsBytes(),
        [0, 1, 2, 3, 255],
      );
      expect(
        await File(
          p.join(
            (await targetPortable.stickerRoot).path,
            'fixture-pack',
            'memes',
            '1.png',
          ),
        ).exists(),
        true,
      );
      expect(targetNative.prefs['caicai_stage']['legPivot'], .87);
      expect(await secure.readApiKey(), 'TARGET_SECRET_KEEP');
      expect(await secure.readCedarToyToken(), isNull);
      expect(
        await secure.readEndpoint(),
        'https://example.com/v1/chat/completions',
      );
    } finally {
      await targetDb.closeForTesting();
    }
  });

  test('corrupt missing and unsafe portable entries are rejected before installation', () async {
    await fixture();
    final bundle = await legacyBackup();
    for (final kind in ['corrupt', 'missing', 'unsafe']) {
      final archive = await decode(bundle.filePath);
      const model = 'portable/live2d/女仆/model.moc3';
      if (kind == 'missing') {
        archive.removeFile(archive.findFile(model)!);
      } else if (kind == 'corrupt') {
        archive.addFile(ArchiveFile(model, 3, [9, 9, 9]));
      } else {
        archive.addFile(ArchiveFile('portable/live2d/../secret', 1, [9]));
      }
      final path = p.join(root.path, '$kind.zip');
      await writeArchive(archive, path);
      await expectLater(service.inspectBundle(path), throwsFormatException);
      expect(native.busy, false);
    }
  });

  test('v6 archive leaves native and secure settings alone', () async {
    final bundle = await service.exportBackupBundle();
    final archive = await decode(bundle.filePath);
    final state = object(archive, 'state.json');
    state.remove('portable_state');
    final bytes = utf8.encode(jsonEncode(state));
    final manifest = object(archive, 'manifest.json');
    manifest['protocol_version'] = 6;
    manifest.remove('portable_files');
    manifest.remove('portable_bytes');
    manifest['state_sha256'] = await _digest(bytes);
    manifest['state_bytes'] = bytes.length;
    archive.addFile(ArchiveFile('state.json', bytes.length, bytes));
    final m = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('manifest.json', m.length, m));
    final path = p.join(root.path, 'v6.zip');
    await writeArchive(archive, path);
    await fixture();
    await secure.writeEndpoint('https://local.invalid/v1');
    await service.restoreBackupBundle(path);
    expect(await secure.readEndpoint(), 'https://local.invalid/v1');
    expect(
      await File(p.join(native.models.path, '女仆', 'model.moc3')).exists(),
      true,
    );
  });

  test('an empty v7 model domain restores absence instead of retaining a foreign model', () async {
    final bundle = await legacyBackup();
    await fixture();
    await service.restoreBackupBundle(bundle.filePath);
    expect(await native.models.list().isEmpty, true);
    expect(await (await portable.stickerRoot).list().isEmpty, true);
    expect(await secure.readApiKey(), 'LOCAL_SECRET_KEEP');
  });

  test('new backup restores settings while retaining externally imported resource files', () async {
    await fixture();
    final bundle = await service.exportBackupBundle();
    final archive = await decode(bundle.filePath);
    expect(archive.files.where((file) => file.name.startsWith('portable/')), isEmpty);
    expect(object(archive, 'manifest.json')['portable_bytes'], 0);
    final state = object(archive, 'state.json');
    expect(state['portable_state']['version'], 2);
    expect(state['portable_state']['resource_files'], 'external');
    final model = File(p.join(native.models.path, '女仆', 'model.moc3'));
    await model.writeAsString('KEEP_CURRENT_MODEL');
    native.prefs['caicai_stage'] = {'legPivot': .96};
    await service.restoreBackupBundle(bundle.filePath);
    expect(await model.readAsString(), 'KEEP_CURRENT_MODEL');
    expect(await File(p.join((await portable.stickerRoot).path,
      'fixture-pack', 'memes', '1.png')).exists(), true);
    expect(native.prefs['caicai_stage']['legPivot'], .87);
    expect(native.restoredModels, false);
  });

  test('settings-only archive on an installation without resources restores preferences without creating models', () async {
    await fixture();
    final bundle = await service.exportBackupBundle();
    await native.models.delete(recursive: true);
    await (await portable.stickerRoot).delete(recursive: true);
    native.prefs['caicai_stage'] = {};
    await service.restoreBackupBundle(bundle.filePath);
    expect(await native.models.exists(), false);
    expect(await (await portable.stickerRoot).exists(), false);
    expect(native.prefs['caicai_stage']['legPivot'], .87);
    expect(native.restoredModels, false);
  });

  test('settings-only payload cannot disguise resource entries as excluded', () {
    final config = {
      'version': 2, 'resource_files': 'external',
      'native_preferences': native.prefs,
      'secure_config': {for (final key in SecureConfig.portableKeys) key: null},
      'file_paths': {'live2d': ['model.moc3'], 'stickers': []},
    };
    expect(() => PortableCompanionStorage.validateState(config), throwsFormatException);
  });

  test('API URL credentials are stripped; unknown secure keys cannot enter portable config', () async {
    await secure.writeEndpoint(
      'https://user:pass@example.com/v1?api_key=SECRET&region=cn#token',
    );
    final state = await secure.exportPortableSettings();
    expect(state['deepseek_chat_endpoint'], 'https://example.com/v1?region=cn');
    expect(jsonEncode(state), isNot(contains('SECRET')));
    expect(
      () => SecureConfig.validatePortableSettings({
        ...state,
        'deepseek_api_key': 'SECRET',
      }),
      throwsFormatException,
    );
  });
  test('shared stickers survive backup on an empty device and keep local pack on restore', () async {
    await fixture();
    final stickers = StickerPackStorage(db: db);
    final pack = (await stickers.scanPacks()).single;
    final record = (await stickers.readRecords(pack)).single;
    final image = await stickers.prepareAttachment(pack: pack, record: record,
      messageId: 'shared-u', source: 'user_sticker:${pack.id}', attachments: MessageAttachmentStorage());
    await db.setSetting('transfer_lock', '0');
    await db.insertMessageWithAttachments(ChatMessage(id: 'shared-u', role: 'user',
      content: '', createdAt: DateTime.now()), [image]);
    await db.setSetting('transfer_lock', '1');
    final bundle = await service.exportBackupBundle();
    final archive = await decode(bundle.filePath);
    expect(archive.files.where((f) => f.name.startsWith('portable/stickers/')), isEmpty);
    expect(archive.files.where((f) => f.name.startsWith('media/originals/')).length, 1);
    await service.restoreBackupBundle(bundle.filePath);
    expect(await (await stickers.fileFor(pack, record)).exists(), isTrue);
    await stickers.deletePack(pack.id);
    await service.restoreBackupBundle(bundle.filePath);
    final restored = (await db.allMessageAttachments()).single;
    expect(await (await MessageAttachmentStorage().fileFor(restored.originalPath)).exists(), isTrue);
  });

  test('restoring an older backup preserves newly imported local shared originals', () async {
    await fixture();
    final old = await service.exportBackupBundle();
    final stickers = StickerPackStorage(db: db);
    final pack = (await stickers.scanPacks()).single;
    final record = (await stickers.readRecords(pack)).single;
    final before = await (await stickers.fileFor(pack, record)).readAsBytes();
    await service.restoreBackupBundle(old.filePath);
    expect(await (await stickers.fileFor(pack, record)).readAsBytes(), before);
    expect(await db.allMediaBlobs(), isEmpty);
  });

}

Future<String> _digest(List<int> bytes) async =>
    sha256.convert(bytes).toString();
