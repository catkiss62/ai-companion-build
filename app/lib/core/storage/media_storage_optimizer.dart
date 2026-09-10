import 'dart:io';

import '../database/app_database.dart';
import '../models/companion_album.dart';
import '../models/message_attachment.dart';
import '../models/media_blob.dart';
import 'companion_album_storage.dart';
import 'media_blob_storage.dart';
import 'message_attachment_storage.dart';

class MediaOptimizationReport {
  const MediaOptimizationReport({
    required this.messageReferences,
    required this.albumReferences,
    required this.distinctBlobs,
    required this.currentBytes,
    required this.optimizedBytes,
    required this.reclaimableBytes,
    required this.missingFiles,
    required this.cleanupPending,
  });

  final int messageReferences;
  final int albumReferences;
  final int distinctBlobs;
  final int currentBytes;
  final int optimizedBytes;
  final int reclaimableBytes;
  final int missingFiles;
  final bool cleanupPending;

  bool get hasWork =>
      messageReferences + albumReferences > 0 || cleanupPending;
}

class MediaOptimizationResult {
  const MediaOptimizationResult({
    required this.before,
    required this.migratedMessageReferences,
    required this.migratedAlbumReferences,
    required this.deletedLegacyFiles,
  });

  final MediaOptimizationReport before;
  final int migratedMessageReferences;
  final int migratedAlbumReferences;
  final int deletedLegacyFiles;
}

/// Manual, idempotent migration from UUID copies to shared exact-SHA blobs.
///
/// The source backup is never touched. Only files referenced by the live DB are
/// considered, and no visual/perceptual similarity is used for merging.
class MediaStorageOptimizer {
  MediaStorageOptimizer({
    AppDatabase? db,
    MessageAttachmentStorage? attachmentStorage,
    CompanionAlbumStorage? albumStorage,
    MediaBlobStorage? blobStorage,
  })  : db = db ?? AppDatabase.instance,
        blobStorage = blobStorage ?? MediaBlobStorage(),
        attachmentStorage = attachmentStorage ?? MessageAttachmentStorage(),
        albumStorage = albumStorage ?? CompanionAlbumStorage();

  final AppDatabase db;
  final MessageAttachmentStorage attachmentStorage;
  final CompanionAlbumStorage albumStorage;
  final MediaBlobStorage blobStorage;

  Future<MediaOptimizationReport> scan() async => (await _buildPlan()).report;

  Future<MediaOptimizationResult> optimize() async {
    final plan = await _buildPlan();
    if (!plan.report.hasWork) {
      final deleted = await _pruneUnreferencedStorage();
      await _markCompleted();
      return MediaOptimizationResult(
        before: plan.report,
        migratedMessageReferences: 0,
        migratedAlbumReferences: 0,
        deletedLegacyFiles: deleted,
      );
    }
    // An empty marker makes an interrupted run discoverable on the next scan,
    // even when every DB reference was already migrated before termination.
    await db.setSetting('media_storage_optimizer_last_completed_at', '');
    final legacyMessagePaths = <String>{};
    final legacyAlbumPaths = <String>{};
    var migratedMessages = 0;
    var migratedAlbums = 0;
    for (final group in plan.groups.values) {
      final canonical = group.records.first;
      final blob = await blobStorage.store(
        original: canonical.original,
        thumbnail: canonical.thumbnail,
        mimeType: canonical.mimeType,
        width: canonical.width,
        height: canonical.height,
        createdAt: canonical.createdAt,
      );
      final messageIds = group.records
          .where((record) => record.messageAttachment != null)
          .map((record) => record.messageAttachment!.id)
          .toSet();
      final albumIds = group.records
          .where((record) => record.albumItem != null)
          .map((record) => record.albumItem!.id)
          .toSet();
      await db.migrateMediaBlobReferences(
        blob: blob,
        messageAttachmentIds: messageIds,
        albumItemIds: albumIds,
      );
      migratedMessages += messageIds.length;
      migratedAlbums += albumIds.length;
      for (final record in group.records) {
        if (record.messageAttachment != null) {
          legacyMessagePaths
            ..add(record.originalRelative)
            ..add(record.thumbnailRelative);
        } else {
          legacyAlbumPaths
            ..add(record.originalRelative)
            ..add(record.thumbnailRelative);
        }
      }
    }
    var deleted = 0;
    for (final relative in legacyMessagePaths) {
      if (MediaBlobStorage.isMediaReference(relative)) continue;
      final file = await attachmentStorage.fileFor(relative);
      if (await file.exists()) {
        await file.delete();
        deleted++;
      }
    }
    for (final relative in legacyAlbumPaths) {
      if (MediaBlobStorage.isMediaReference(relative)) continue;
      final file = await albumStorage.fileFor(relative);
      if (await file.exists()) {
        await file.delete();
        deleted++;
      }
    }
    deleted += await _pruneUnreferencedStorage();
    await _markCompleted();
    return MediaOptimizationResult(
      before: plan.report,
      migratedMessageReferences: migratedMessages,
      migratedAlbumReferences: migratedAlbums,
      deletedLegacyFiles: deleted,
    );
  }

  Future<int> _pruneUnreferencedStorage() async {
    await db.rebuildMediaBlobRefCounts();
    var deleted = 0;
    for (final orphan in await db.takeUnreferencedMediaBlobs()) {
      for (final relative in <String>{
        orphan.originalPath,
        orphan.thumbnailPath,
      }) {
        final file = await blobStorage.fileFor(relative);
        if (await file.exists()) deleted++;
      }
      await blobStorage.deleteBlobFiles(orphan);
    }
    final liveAttachments = await db.allMessageAttachments();
    deleted += await attachmentStorage.pruneUnreferencedFiles(
      liveAttachments.expand((item) => <String>[
        item.originalPath,
        item.thumbnailPath,
      ]),
    );
    final liveAlbum = await db.allCompanionAlbumItemsForMediaMigration();
    deleted += await albumStorage.pruneUnreferencedFiles(
      liveAlbum.expand((item) => <String>[
        item.originalPath,
        item.thumbnailPath,
      ]),
    );
    final referenced = (await db.allMediaBlobs())
        .expand((blob) => <String>[blob.originalPath, blob.thumbnailPath]);
    deleted += await blobStorage.pruneUnreferencedFiles(referenced);
    return deleted;
  }

  Future<void> _markCompleted() async {
    await db.setSetting(
      'media_storage_optimizer_last_completed_at',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  Future<_OptimizationPlan> _buildPlan() async {
    final groups = <String, _MediaGroup>{};
    var currentBytes = 0;
    var missing = 0;
    var messageReferences = 0;
    var albumReferences = 0;

    for (final attachment in await db.allMessageAttachments()) {
      if (attachment.blobId.isNotEmpty ||
          MediaBlobStorage.isMediaReference(attachment.originalPath)) {
        continue;
      }
      try {
        final original = await attachmentStorage.fileFor(attachment.originalPath);
        final thumbnail = await attachmentStorage.fileFor(attachment.thumbnailPath);
        if (!await original.exists() || !await thumbnail.exists()) {
          missing++;
          continue;
        }
        final sha = await MediaBlobStorage.contentSha256(original);
        final record = _LegacyMediaRecord(
          original: original,
          thumbnail: thumbnail,
          originalRelative: attachment.originalPath,
          thumbnailRelative: attachment.thumbnailPath,
          mimeType: attachment.mimeType,
          width: attachment.width,
          height: attachment.height,
          createdAt: attachment.createdAt,
          messageAttachment: attachment,
        );
        groups.putIfAbsent(sha, () => _MediaGroup()).records.add(record);
        currentBytes += (await original.length()) + (await thumbnail.length());
        messageReferences++;
      } catch (_) {
        missing++;
      }
    }

    for (final item in await db.allCompanionAlbumItemsForMediaMigration()) {
      if (item.blobId.isNotEmpty ||
          item.originalPath.isEmpty ||
          MediaBlobStorage.isMediaReference(item.originalPath)) {
        continue;
      }
      try {
        final original = await albumStorage.fileFor(item.originalPath);
        final thumbnail = await albumStorage.fileFor(item.thumbnailPath);
        if (!await original.exists() || !await thumbnail.exists()) {
          missing++;
          continue;
        }
        final sha = await MediaBlobStorage.contentSha256(original);
        if (item.originalContentSha256.isNotEmpty &&
            item.originalContentSha256 != sha) {
          missing++;
          continue;
        }
        final record = _LegacyMediaRecord(
          original: original,
          thumbnail: thumbnail,
          originalRelative: item.originalPath,
          thumbnailRelative: item.thumbnailPath,
          mimeType: item.originalMimeType,
          width: item.width,
          height: item.height,
          createdAt: item.savedAt ?? item.createdAt,
          albumItem: item,
        );
        groups.putIfAbsent(sha, () => _MediaGroup()).records.add(record);
        currentBytes += (await original.length()) + (await thumbnail.length());
        albumReferences++;
      } catch (_) {
        missing++;
      }
    }

    var optimizedBytes = 0;
    for (final group in groups.values) {
      final canonical = group.records.first;
      optimizedBytes += (await canonical.original.length()) +
          (await canonical.thumbnail.length());
    }
    final completedMarker =
        await db.getSetting('media_storage_optimizer_last_completed_at');
    return _OptimizationPlan(
      groups: groups,
      report: MediaOptimizationReport(
        messageReferences: messageReferences,
        albumReferences: albumReferences,
        distinctBlobs: groups.length,
        currentBytes: currentBytes,
        optimizedBytes: optimizedBytes,
        reclaimableBytes:
            (currentBytes - optimizedBytes).clamp(0, currentBytes).toInt(),
        missingFiles: missing,
        cleanupPending: completedMarker == null || completedMarker.isEmpty,
      ),
    );
  }
}

class _OptimizationPlan {
  const _OptimizationPlan({required this.groups, required this.report});

  final Map<String, _MediaGroup> groups;
  final MediaOptimizationReport report;
}

class _MediaGroup {
  final List<_LegacyMediaRecord> records = <_LegacyMediaRecord>[];
}

class _LegacyMediaRecord {
  const _LegacyMediaRecord({
    required this.original,
    required this.thumbnail,
    required this.originalRelative,
    required this.thumbnailRelative,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.createdAt,
    this.messageAttachment,
    this.albumItem,
  });

  final File original;
  final File thumbnail;
  final String originalRelative;
  final String thumbnailRelative;
  final String mimeType;
  final int width;
  final int height;
  final DateTime createdAt;
  final MessageAttachment? messageAttachment;
  final CompanionAlbumItem? albumItem;
}
