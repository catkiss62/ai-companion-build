import 'dart:async';
import 'dart:io';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_phone_repository.dart';
import 'package:ai_companion_localfirst/core/storage/companion_album_storage.dart';
import 'package:ai_companion_localfirst/core/storage/message_attachment_storage.dart';
import 'package:ai_companion_localfirst/core/storage/portable_companion_storage.dart';
import 'package:ai_companion_localfirst/core/storage/media_storage_optimizer.dart';
import 'package:ai_companion_localfirst/core/storage/pending_media_owner.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/core/storage/shared_media_lock.dart';
import 'package:ai_companion_localfirst/features/chat/chat_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ai_companion_localfirst/core/storage/snapshot_directory_swap.dart';
import 'package:ai_companion_localfirst/core/storage/snapshot_restore_journal.dart';
import 'package:ai_companion_localfirst/core/sync/snapshot_restore_coordinator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getApplicationSupportPath() async => root.path;
}

class _CommittedDraftBarrier extends MessageAttachmentStorage {
  _CommittedDraftBarrier(AppDatabase db) : super(db: db);
  final committed = Completer<void>();
  final release = Completer<void>();
  @override
  Future<MessageAttachment> commitDraft(PreparedImageAttachment draft, {
    required String messageId, PendingMediaOwner? pendingOwner,
  }) async {
    final attachment = await super.commitDraft(draft,
      messageId: messageId, pendingOwner: pendingOwner);
    committed.complete();
    await release.future;
    // The fixture already has a vision index, avoiding unrelated network work.
    return attachment.copyWith(visionStatus: MessageAttachment.visionCompletedStatus,
      visionSummary: 'fixture image', visionModel: 'fixture');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late Directory root;
  late PathProviderPlatform previousPaths;
  const channel = MethodChannel('ai_companion/system');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('media-ownership-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async =>
            call.method == 'runtimeProcessEpoch' ? 'current-process' : null);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    PathProviderPlatform.instance = previousPaths;
    await db.closeForTesting();
    await root.delete(recursive: true);
  });
  Future<File> file(String relative) async {
    final f = File(p.join(root.path, relative));
    await f.parent.create(recursive: true);
    await f.writeAsString(relative);
    return f;
  }
  Map<String, Object?> album(int i, {String lifecycle = 'saved', bool shared = false}) => {
    'id': 'album-$i', 'source_kind': 'fixture', 'source_id': '$i',
    'lifecycle_state': lifecycle, 'created_at': i, 'updated_at': i, 'saved_at': i,
    'original_path': '${shared ? 'media/' : ''}originals/$i.jpg',
    'thumbnail_path': '${shared ? 'media/' : ''}thumbnails/$i.png',
  };
  MessageAttachment attachment(String id) => MessageAttachment(
    id: id, messageId: 'message-$id', kind: 'image', originalPath: 'originals/$id.jpg',
    thumbnailPath: 'thumbnails/$id.png', mimeType: 'image/jpeg', byteSize: 4,
    width: 2, height: 2, source: 'fixture', createdAt: DateTime(2026),
  );

  test('sendPreparedImage keeps zero-ref committed bytes alive until the user-message transaction', () async {
    FlutterSecureStorage.setMockInitialValues({
      'deepseek_api_key': 'fixture-key', 'qwen_vision_api_key': 'fixture-vision',
    });
    final storage = _CommittedDraftBarrier(db);
    final original = await file('draft/original.jpg');
    final thumbnail = await file('draft/thumbnail.png');
    final draft = PreparedImageAttachment(id: 'draft', originalFile: original,
      thumbnailFile: thumbnail, originalExtension: '.jpg', mimeType: 'image/jpeg',
      byteSize: await original.length(), width: 2, height: 2, source: 'gallery',
      createdAt: DateTime(2026));
    final controller = ChatController(db: db, attachmentStorage: storage,
      secureConfig: SecureConfig.forTesting(const FlutterSecureStorage()));
    final sending = controller.sendPreparedImage(draft, caption: 'fixture');
    try {
      await storage.committed.future;
      expect(await db.allMessageAttachments(), isEmpty);
      expect((await db.allMediaBlobs()).single.messageRefCount, 0);
      var optimized = false;
      final optimizing = MediaStorageOptimizer(db: db).optimize().then((result) {
        optimized = true;
        return result;
      });
      var collected = false;
      final collecting = SimulatedPhoneRepository(db).deleteAlbumItem('absent-item')
          .then((_) { collected = true; });
      await Future<void>.delayed(Duration.zero);
      expect(optimized, isFalse);
      expect(collected, isFalse);
      storage.release.complete();
      expect(await sending, isTrue);
      await optimizing;
      await collecting;
      final owner = (await db.allMessageAttachments()).single;
      expect((await db.allMediaBlobs()).single.messageRefCount, 1);
      expect(await (await storage.fileFor(owner.originalPath)).exists(), isTrue);
      expect(await (await storage.fileFor(owner.thumbnailPath)).exists(), isTrue);
      // Observe the no-op vision follow-up's actual release; do not close its
      // database after an arbitrary scheduling delay on a slow CI worker.
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (await db.getSetting('image_vision_lease') != '0') {
        if (DateTime.now().isAfter(deadline)) {
          fail('completed-vision follow-up did not release its lease');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    } finally {
      if (!storage.release.isCompleted) storage.release.complete();
      await sending;
      controller.dispose();
    }
  });

  for (final count in [501, 1001]) {
    test('real album cleanup preserves all $count mixed saved/retained owners', () async {
      final sql = await db.database;
      final batch = sql.batch();
      for (var i = 0; i < count; i++) {
        // The oldest owner is legacy, while half the newer owners are shared.
        batch.insert('companion_album_candidates', album(i,
          lifecycle: i % 3 == 0 ? 'soft_deleted' : 'saved', shared: i.isOdd));
        if (i.isEven) {
          await file('companion_album/originals/$i.jpg');
          await file('companion_album/thumbnails/$i.png');
        }
      }
      await batch.commit(noResult: true);
      final orphan = await file('companion_album/originals/orphan.jpg');
      final saving = await file('companion_album/originals/inflight.jpg.saving');
      expect(await SimulatedPhoneRepository(db).clearAlbumCache(), 1);
      expect(await orphan.exists(), isFalse);
      expect(await saving.exists(), isTrue);
      for (var i = 0; i < count; i += 2) {
        expect(await File(p.join(root.path, 'companion_album/originals/$i.jpg')).exists(), isTrue);
        expect(await File(p.join(root.path, 'companion_album/thumbnails/$i.png')).exists(), isTrue);
      }
      expect((await db.allCompanionAlbumItemsForMediaMigration()).length, count);
    });
  }

  for (final albumMode in [false, true]) {
    test('${albumMode ? 'album' : 'chat'} prune queued behind real restore reads NEW owners', () async {
      final folder = albumMode ? 'companion_album' : 'chat_attachments';
      final sql = await db.database;
      if (albumMode) {
        await sql.insert('companion_album_candidates', album(0));
      } else {
        await sql.insert('message_attachments', attachment('old').toDb());
      }
      await file('$folder/originals/old.jpg');
      final source = await Directory(p.join(root.path, 'new-tree')).create();
      await File(p.join(source.path, 'new.jpg')).writeAsString('new owner bytes');
      final entered = Completer<void>();
      final release = Completer<void>();
      final coordinator = SnapshotRestoreCoordinator(db, PortableCompanionStorage(),
          journal: SnapshotRestoreJournal(root));
      final restoring = coordinator.install(prepare: (id) async {
        entered.complete();
        await release.future;
        return SnapshotInstallPlan([await PreparedDirectorySwap.prepare(
          sourceDirectory: source, targetDirectory: Directory(p.join(root.path, folder, 'originals')),
          expectedPaths: ['new.jpg'], validatePath: (path) => path, token: id,
        )]);
      }, commitDatabase: (runtime) async {
        await sql.transaction((txn) async {
          if (albumMode) {
            await txn.delete('companion_album_candidates');
            await txn.insert('companion_album_candidates', {...album(1),
              'original_path': 'originals/new.jpg', 'thumbnail_path': ''});
          } else {
            await txn.delete('message_attachments');
            await txn.insert('message_attachments', attachment('new').toDb());
          }
          for (final entry in runtime.entries) {
            await txn.insert('settings', {'key': entry.key, 'value': entry.value},
              conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
      });
      await entered.future;
      var pruned = false;
      final pruning = (albumMode
          ? CompanionAlbumStorage().pruneUnreferencedFiles(db: db)
          : MessageAttachmentStorage(db: db).pruneUnreferencedFiles(db: db))
          .then((value) { pruned = true; return value; });
      await Future<void>.delayed(Duration.zero);
      expect(pruned, isFalse);
      release.complete();
      expect((await restoring).recoveryPending, isFalse);
      expect(await pruning, 0);
      expect(await File(p.join(root.path, folder, 'originals/new.jpg')).readAsString(), 'new owner bytes');
    });
  }

  test('two DB hosts in the same native process cannot steal an expired media operation', () async {
    await db.closeForTesting();
    final path = p.join(root.path, 'shared.db');
    db = await AppDatabase.createForTesting(databaseFactoryFfi, path: path);
    final other = await AppDatabase.createForTesting(databaseFactoryFfi,
      path: path, reopenExisting: true);
    try {
      expect(await db.tryAcquireLocalLease(SharedMediaLock.leaseKey,
        holdFor: Duration.zero, requireProcessExitBeforeSteal: true), isTrue);
      expect(await other.tryAcquireLocalLease(SharedMediaLock.leaseKey,
        holdFor: Duration.zero, requireProcessExitBeforeSteal: true), isFalse);
      // Other lease kinds keep their existing TTL policy.
      expect(await db.tryAcquireLocalLease('fixture_expiring', holdFor: Duration.zero), isTrue);
      expect(await other.tryAcquireLocalLease('fixture_expiring'), isTrue);
      await db.releaseLocalLease(SharedMediaLock.leaseKey);
      expect(await other.tryAcquireLocalLease(SharedMediaLock.leaseKey,
        requireProcessExitBeforeSteal: true), isTrue);
      await other.releaseLocalLease(SharedMediaLock.leaseKey);
    } finally {
      await other.closeForTesting();
    }
  });
  test('strict media lease reclaims a proven old process but preserves an unknown identity', () async {
    await db.setSetting(SharedMediaLock.leaseKey, 'dead-process:11111111-1111-4111-8111-111111111111|1');
    expect(await db.tryAcquireLocalLease(SharedMediaLock.leaseKey,
      requireProcessExitBeforeSteal: true), isTrue);
    await db.releaseLocalLease(SharedMediaLock.leaseKey);
    await db.setSetting(SharedMediaLock.leaseKey, 'dart-unknown:11111111-1111-4111-8111-111111111111|1');
    expect(await db.tryAcquireLocalLease(SharedMediaLock.leaseKey,
      requireProcessExitBeforeSteal: true), isFalse);
    await db.setSetting(SharedMediaLock.leaseKey, '');
  });

  for (final purpose in ['backup_export', 'backup_restore']) {
    test('startup clears only proven dead native process $purpose with no intent', () async {
      await db.setSettingsAtomically({'transfer_lock': '1',
        'transfer_lock_owner': 'dead-process:$purpose:token'});
      final recovery = SnapshotRestoreCoordinator(db, PortableCompanionStorage(),
        journal: SnapshotRestoreJournal(root));
      expect(await recovery.recoverIfPending(), isTrue);
      expect(await db.brainWorkAllowed(), isTrue);
      expect(await recovery.recoverIfPending(), isTrue);
    });
  }
  for (final owner in ['current-process:backup_export:token', 'current-process:backup_restore:token',
    'dead-process:transfer:token', 'dart-old:backup_export:token', 'malformed']) {
    test('startup preserves live or unprovable freeze $owner', () async {
      await db.setSettingsAtomically({'transfer_lock': '1', 'transfer_lock_owner': owner});
      expect(await SnapshotRestoreCoordinator(db, PortableCompanionStorage(),
        journal: SnapshotRestoreJournal(root)).recoverIfPending(), isTrue);
      expect(await db.getSetting('transfer_lock_owner'), owner);
      expect(await db.getSetting('transfer_lock'), '1');
    });
  }
  for (final pending in ['pending_outbound_snapshot_id', 'pending_import_snapshot_id',
    SnapshotRestoreCoordinator.pendingKey]) {
    test('durable intent $pending prevents orphan freeze cleanup', () async {
      await db.setSettingsAtomically({'transfer_lock': '1',
        'transfer_lock_owner': 'dead-process:backup_restore:token', pending: 'durable'});
      final recovery = SnapshotRestoreCoordinator(db, PortableCompanionStorage(),
        journal: SnapshotRestoreJournal(root));
      if (pending == SnapshotRestoreCoordinator.pendingKey) {
        await expectLater(recovery.recoverIfPending(), throwsA(isA<SnapshotRecoveryRequired>()));
      } else {
        expect(await recovery.recoverIfPending(), isTrue);
      }
      expect(await db.getSetting('transfer_lock'), '1');
    });
  }
  test('unknown native process identity cannot authorize unfreezing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    await db.setSettingsAtomically({'transfer_lock': '1',
      'transfer_lock_owner': 'dead-process:backup_export:token'});
    expect(await SnapshotRestoreCoordinator(db, PortableCompanionStorage(),
      journal: SnapshotRestoreJournal(root)).recoverIfPending(), isTrue);
    expect(await db.getSetting('transfer_lock'), '1');
  });
}
