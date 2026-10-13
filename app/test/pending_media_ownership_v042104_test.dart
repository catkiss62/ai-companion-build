import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/brain_work_fence.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/generation_job.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';
import 'package:ai_companion_localfirst/core/storage/media_storage_optimizer.dart';
import 'package:ai_companion_localfirst/core/storage/message_attachment_storage.dart';
import 'package:ai_companion_localfirst/core/storage/pending_media_owner.dart';
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
  @override
  Future<String?> getTemporaryPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late Directory root;
  late MessageAttachmentStorage storage;
  late PathProviderPlatform previousPaths;
  var sequence = 0;
  const channel = MethodChannel('ai_companion/system');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pending-media-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    storage = MessageAttachmentStorage(db: db);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async =>
            call.method == 'runtimeProcessEpoch' ? 'media-test-process' : null);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await db.closeForTesting();
    PathProviderPlatform.instance = previousPaths;
    await root.delete(recursive: true);
  });

  Future<GenerationJob> start(String id) async {
    final job = await db.createGenerationTurn(user: ChatMessage(
      id: 'u-$id', role: 'user', content: '给我一张图片', createdAt: DateTime.now()),
      assistantMessageId: 'a-$id', model: 'deepseek-v4-flash', reasoningEffort: 'high');
    return (await db.claimGenerationJob(job.id))!;
  }
  Future<PendingMediaOwner> owner(GenerationJob job) async =>
      PendingMediaOwner.generation((await db.captureGenerationAttemptFence(job))!);
  Future<PreparedImageAttachment> draft({String original = 'image', String thumbnail = 'thumb'}) async {
    final id = 'draft-${sequence++}';
    final dir = await Directory(p.join(root.path, id)).create();
    final image = await File(p.join(dir.path, 'original.png')).writeAsString(original);
    final thumb = await File(p.join(dir.path, 'thumbnail.png')).writeAsString(thumbnail);
    // Preparation is already complete. These tests exercise the production
    // file-install / SQLite owner / GC boundary, not the image decoder.
    return PreparedImageAttachment(id: id, originalFile: image, thumbnailFile: thumb,
      originalExtension: '.png', mimeType: 'image/png', byteSize: original.length,
      width: 1, height: 1, source: 'synthetic', createdAt: DateTime.now());
  }
  Future<MessageAttachment> prepare(PendingMediaOwner pin,
      {String original = 'image', String thumbnail = 'thumb'}) async =>
      storage.commitDraft(await draft(original: original, thumbnail: thumbnail),
        messageId: pin.messageId, pendingOwner: pin);
  Future<bool> commit(GenerationJob job, PendingMediaOwner pin, MessageAttachment image) =>
      db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
        pendingMediaOwner: pin, assistant: ChatMessage(id: job.assistantMessageId,
          role: 'assistant', content: '这张图片', createdAt: DateTime.now(), attachments: [image]));
  Future<int> pendingCount() async =>
      (await (await db.database).query('pending_media_owners')).length;

  test('optimizer runs during final-provider wait and preserves a pending image until atomic commit', () async {
    final job = await start('wait');
    final pin = await owner(job);
    final prepared = Completer<MessageAttachment>();
    final finishProvider = Completer<void>();
    final reply = () async {
      final image = await prepare(pin);
      prepared.complete(image);
      await finishProvider.future;
      return commit(job, pin, image);
    }();
    final image = await prepared.future;
    expect((await db.mediaBlobById(image.blobId))!.messageRefCount, 0);
    expect(await pendingCount(), 1);
    // Must complete while the provider is still blocked: no media lock across LLM.
    await MediaStorageOptimizer(db: db).optimize().timeout(const Duration(seconds: 5));
    expect(await (await storage.fileFor(image.originalPath)).exists(), isTrue);
    expect(await db.deleteMediaCacheBlobs({image.blobId}), isEmpty);
    await storage.deleteAttachmentFiles(image);
    expect(await (await storage.fileFor(image.thumbnailPath)).exists(), isTrue);
    finishProvider.complete();
    expect(await reply, isTrue);
    expect(await pendingCount(), 0);
    await MediaStorageOptimizer(db: db).optimize();
    expect((await db.messageById(job.assistantMessageId))!.attachments.single.blobId, image.blobId);
    expect((await db.mediaBlobById(image.blobId))!.messageRefCount, 1);
    expect(await (await storage.fileFor(image.originalPath)).exists(), isTrue);
  });

  test('Stop before registration rejects the original owner; Stop after prepare makes its orphan collectible', () async {
    final job = await start('stop');
    final pin = await owner(job);
    final image = await prepare(pin);
    expect(await db.cancelGenerationJobByUser(job.id), isTrue);
    await expectLater(prepare(pin, original: 'late-image'), throwsA(isA<BrainWorkInvalidated>()));
    expect(await commit(job, pin, image), isFalse);
    await MediaStorageOptimizer(db: db).optimize();
    expect(await pendingCount(), 0);
    expect(await db.mediaBlobById(image.blobId), isNull);
    expect(await (await storage.fileFor(image.originalPath)).exists(), isFalse);
  });

  test('temporary brain gates prevent commit but never make a live attempt collectible', () async {
    final job = await start('freeze');
    final pin = await owner(job);
    final image = await prepare(pin);
    for (final gate in {
      'transfer_lock': '1', 'active_brain': '0',
      'snapshot_recovery_pending_v1': 'recovery-in-progress',
    }.entries) {
      final previous = await db.getSetting(gate.key) ?? '';
      await db.setSetting(gate.key, gate.value);
      expect(await commit(job, pin, image), isFalse);
      await MediaStorageOptimizer(db: db).optimize();
      expect(await pendingCount(), 1);
      expect(await (await storage.fileFor(image.originalPath)).exists(), isTrue);
      await db.setSetting(gate.key, previous);
    }
    expect(await commit(job, pin, image), isTrue);
    expect(await pendingCount(), 0);
    expect(await (await storage.fileFor(image.originalPath)).exists(), isTrue);
  });

  test('recovery changes attempt ownership and old cleanup cannot release a new pin on identical bytes', () async {
    final oldJob = await start('recover');
    final oldPin = await owner(oldJob);
    final oldImage = await prepare(oldPin);
    // Simulate the real claim path for a process that stopped checkpointing.
    await (await db.database).update('generation_jobs', {'updated_at': 0},
      where: 'id = ?', whereArgs: [oldJob.id]);
    final recovered = (await db.claimGenerationJob(oldJob.id))!;
    final newPin = await owner(recovered);
    final newImage = await prepare(newPin);
    expect(newImage.blobId, oldImage.blobId);
    await db.releasePendingMedia(oldPin);
    await storage.deleteAttachmentFiles(oldImage);
    await MediaStorageOptimizer(db: db).optimize();
    expect(await pendingCount(), 1);
    await expectLater(prepare(oldPin), throwsA(isA<BrainWorkInvalidated>()));
    expect(await commit(recovered, newPin, newImage), isTrue);
    await db.releasePendingMedia(oldPin);
    await storage.deleteAttachmentFiles(oldImage);
    expect((await db.messageById(recovered.assistantMessageId))!.attachments.single.blobId, newImage.blobId);
    expect((await db.mediaBlobById(newImage.blobId))!.messageRefCount, 1);
    expect(await (await storage.fileFor(newImage.originalPath)).exists(), isTrue);
  });

  test('interrupted text draft does not manufacture recoverable attachment ownership', () async {
    final job = await start('draft');
    final pin = await owner(job);
    final image = await prepare(pin);
    expect(await db.holdGenerationJobForUserDecision(job.id, runToken: job.runToken,
      partialReasoning: '', partialContent: '尚未确认的正文'), isNotNull);
    await MediaStorageOptimizer(db: db).optimize();
    expect(await pendingCount(), 0);
    expect(await db.mediaBlobById(image.blobId), isNull);
    expect((await db.generationJobById(job.id))!.status, 'awaiting_confirmation');
  });

  test('proactive original lease pins media without a generation job until that lease is replaced', () async {
    expect(await db.tryAcquireProactiveLease(), isTrue);
    final fence = (await db.captureBrainWorkFence(leaseKey: 'proactive_lease_until'))!;
    final pin = PendingMediaOwner.proactive(messageId: 'proactive-image', fence: fence);
    final image = await prepare(pin);
    await MediaStorageOptimizer(db: db).optimize();
    expect(await (await storage.fileFor(image.originalPath)).exists(), isTrue);
    await db.releaseProactiveLease();
    expect(await db.tryAcquireProactiveLease(), isTrue);
    await expectLater(prepare(pin), throwsA(isA<BrainWorkInvalidated>()));
    await MediaStorageOptimizer(db: db).optimize();
    expect(await pendingCount(), 0);
    expect(await db.mediaBlobById(image.blobId), isNull);
    await db.releaseProactiveLease();
  });

  test('proactive terminal transaction transfers pending media to the real message', () async {
    expect(await db.tryAcquireProactiveLease(), isTrue);
    final fence = (await db.captureBrainWorkFence(leaseKey: 'proactive_lease_until'))!;
    final pin = PendingMediaOwner.proactive(messageId: 'proactive-commit', fence: fence);
    final image = await prepare(pin);
    final blocked = await db.commitProactiveMessageIfCurrent(
      message: ChatMessage(id: pin.messageId, role: 'assistant', content: '图片已就绪',
        createdAt: DateTime.now(), isProactive: true, attachments: [image]),
      evaluationStartedAt: DateTime.now(), workFence: fence, pendingMediaOwner: pin);
    expect(blocked, isNull);
    expect(await pendingCount(), 0);
    await db.releasePendingMedia(pin);
    await storage.deleteAttachmentFiles(image);
    expect((await db.mediaBlobById(image.blobId))!.messageRefCount, 1);
    expect((await db.messageById(pin.messageId))!.attachments.single.blobId, image.blobId);
    expect(await (await storage.fileFor(image.originalPath)).exists(), isTrue);
    await db.releaseProactiveLease();
  });

  test('expired or unknown proactive lease preserves files until ownership is explicitly ended', () async {
    expect(await db.tryAcquireProactiveLease(), isTrue);
    final fence = (await db.captureBrainWorkFence(leaseKey: 'proactive_lease_until'))!;
    final pin = PendingMediaOwner.proactive(messageId: 'expired-proactive', fence: fence);
    final image = await prepare(pin);
    for (final value in ['${fence.leaseToken}|0', 'unrecognized-lease']) {
      await db.setSetting('proactive_lease_until', value);
      await expectLater(prepare(pin), throwsA(isA<BrainWorkInvalidated>()));
      await MediaStorageOptimizer(db: db).optimize();
      expect(await pendingCount(), 1);
      expect(await (await storage.fileFor(image.originalPath)).exists(), isTrue);
    }
    await db.setSetting('proactive_lease_until', '0');
    await MediaStorageOptimizer(db: db).optimize();
    expect(await pendingCount(), 0);
    expect(await (await storage.fileFor(image.originalPath)).exists(), isFalse);
  });

  test('persisted proactive owner retains exact source settings and rejects malformed fences', () async {
    expect(await db.tryAcquireProactiveLease(), isTrue);
    await db.setSetting('pending_media_source_fixture', 'original-source');
    final fence = (await db.captureBrainWorkFence(leaseKey: 'proactive_lease_until',
      settingKeys: ['pending_media_source_fixture']))!;
    final pin = PendingMediaOwner.proactive(messageId: 'source-proactive', fence: fence);
    final encoded = jsonDecode(jsonEncode(pin.toJson())) as Map<String, dynamic>;
    expect(PendingMediaOwner.decode(encoded)!.fence.expectedSettings,
      {'pending_media_source_fixture': 'original-source'});
    expect(PendingMediaOwner.decode({...encoded, 'expected_settings': {'x': 1}}), isNull);
    expect(PendingMediaOwner.decode({...encoded}..remove('expected_settings')), isNull);
    expect(PendingMediaOwner.decode({...encoded, 'schema': 999}), isNull);
    final image = await prepare(pin);
    await db.setSetting('pending_media_source_fixture', 'replaced-source');
    await MediaStorageOptimizer(db: db).optimize();
    expect(await pendingCount(), 0);
    expect(await db.mediaBlobById(image.blobId), isNull);
    await db.releaseProactiveLease();
  });

  test('export excludes pending owners and restore cannot resurrect the old pin', () async {
    final job = await start('restore');
    final pin = await owner(job);
    await prepare(pin);
    final snapshot = await db.exportAll();
    expect((snapshot['tables'] as Map).containsKey('pending_media_owners'), isFalse);
    await db.importAll(jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>,
      runtimeSettingOverrides: {'runtime_state_epoch_v1': 'restored-epoch'});
    expect(await pendingCount(), 0);
    await expectLater(prepare(pin), throwsA(isA<BrainWorkInvalidated>()));
  });

  test('canonical duplicate does not delete a thumbnail owned by another prepared image', () async {
    final job = await start('shared-thumbnail');
    final pin = await owner(job);
    final first = await prepare(pin, original: 'same-original', thumbnail: 'old-thumbnail');
    final other = await prepare(pin, original: 'other-original', thumbnail: 'shared-thumbnail');
    final duplicate = await prepare(pin, original: 'same-original', thumbnail: 'shared-thumbnail');
    expect(duplicate.blobId, first.blobId);
    expect(duplicate.thumbnailPath, first.thumbnailPath);
    expect(await (await storage.fileFor(other.thumbnailPath)).readAsString(), 'shared-thumbnail');
    await MediaStorageOptimizer(db: db).optimize();
    expect(await (await storage.fileFor(other.thumbnailPath)).exists(), isTrue);
  });
}
