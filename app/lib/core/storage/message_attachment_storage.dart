import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/message_attachment.dart';
import 'media_blob_storage.dart';
import 'snapshot_directory_swap.dart';

class PreparedImageAttachment {
  const PreparedImageAttachment({
    required this.id,
    required this.originalFile,
    required this.thumbnailFile,
    required this.originalExtension,
    required this.mimeType,
    required this.byteSize,
    required this.width,
    required this.height,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final File originalFile;
  final File thumbnailFile;
  final String originalExtension;
  final String mimeType;
  final int byteSize;
  final int width;
  final int height;
  final String source;
  final DateTime createdAt;
}

class MessageAttachmentStorage {
  MessageAttachmentStorage({Uuid? uuid, MediaBlobStorage? blobStorage})
      : _uuid = uuid ?? const Uuid(),
        blobStorage = blobStorage ?? MediaBlobStorage();

  static const int maxImageBytes = 25 * 1024 * 1024;
  static const int thumbnailLongestEdge = 1000;
  static const String rootFolderName = 'chat_attachments';

  final Uuid _uuid;
  final MediaBlobStorage blobStorage;

  Future<Directory> get rootDirectory async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, rootFolderName));
  }

  Future<PreparedImageAttachment> prepareImage({
    required String sourcePath,
    required String source,
    String? mimeType,
  }) async {
    final input = File(sourcePath);
    if (!await input.exists()) {
      throw const FileSystemException('没有找到所选图片');
    }
    final byteSize = await input.length();
    if (byteSize <= 0) throw const FormatException('图片文件为空');
    if (byteSize > maxImageBytes) {
      throw const FormatException('图片超过 25 MB，请先缩小后再发送');
    }

    final bytes = await input.readAsBytes();
    final decoded = await _decodeThumbnail(bytes);
    final id = _uuid.v4();
    final extension = _safeImageExtension(sourcePath, mimeType);
    final temp = await getTemporaryDirectory();
    final draftDirectory = Directory(
      p.join(temp.path, 'companion_attachment_drafts', id),
    );
    await draftDirectory.create(recursive: true);
    final original = File(p.join(draftDirectory.path, 'original$extension'));
    final thumbnail = File(p.join(draftDirectory.path, 'thumbnail.png'));
    try {
      await original.writeAsBytes(bytes, flush: true);
      await thumbnail.writeAsBytes(decoded.thumbnail, flush: true);
      return PreparedImageAttachment(
        id: id,
        originalFile: original,
        thumbnailFile: thumbnail,
        originalExtension: extension,
        mimeType: _normalizedMimeType(mimeType, extension),
        byteSize: byteSize,
        width: decoded.width,
        height: decoded.height,
        source: source,
        createdAt: DateTime.now(),
      );
    } catch (_) {
      if (await draftDirectory.exists()) {
        await draftDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<MessageAttachment> commitDraft(
    PreparedImageAttachment draft, {
    required String messageId,
  }) async {
    try {
      final blob = await blobStorage.store(
        original: draft.originalFile,
        thumbnail: draft.thumbnailFile,
        mimeType: draft.mimeType,
        width: draft.width,
        height: draft.height,
        createdAt: draft.createdAt,
      );
      await AppDatabase.instance.registerMediaBlob(blob);
      final canonical = await AppDatabase.instance.mediaBlobById(blob.id);
      if (canonical == null) throw StateError('media_blob_registration_failed');
      for (final extra in <String>{blob.originalPath, blob.thumbnailPath}
          .difference(<String>{
        canonical.originalPath,
        canonical.thumbnailPath,
      })) {
        final file = await blobStorage.fileFor(extra);
        if (await file.exists()) await file.delete();
      }
      return MessageAttachment(
        id: draft.id,
        messageId: messageId,
        kind: MessageAttachment.imageKind,
        originalPath: MediaBlobStorage.toReferencePath(canonical.originalPath),
        thumbnailPath: MediaBlobStorage.toReferencePath(canonical.thumbnailPath),
        mimeType: draft.mimeType,
        byteSize: draft.byteSize,
        width: draft.width,
        height: draft.height,
        source: draft.source,
        createdAt: draft.createdAt,
        blobId: canonical.id,
      );
    } finally {
      final draftDirectory = draft.originalFile.parent;
      if (await draftDirectory.exists()) {
        await draftDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> discardDraft(PreparedImageAttachment draft) async {
    final directory = draft.originalFile.parent;
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> deleteAttachmentFiles(MessageAttachment attachment) async {
    if (attachment.blobId.isNotEmpty) {
      final orphan = await AppDatabase.instance.removeUnreferencedMediaBlob(
        attachment.blobId,
      );
      if (orphan != null) {
        await blobStorage.deleteBlobFiles(orphan);
      } else if (await AppDatabase.instance.mediaBlobById(attachment.blobId) ==
          null) {
        // A failed insert can leave newly written content-addressed files with
        // no DB row. No registered owner can reference them, so cleanup is safe.
        for (final relative in <String>{
          attachment.originalPath,
          attachment.thumbnailPath,
        }) {
          if (!MediaBlobStorage.isMediaReference(relative)) continue;
          final file = await fileFor(relative);
          if (await file.exists()) await file.delete();
        }
      }
      return;
    }
    for (final relative in [attachment.originalPath, attachment.thumbnailPath]) {
      if (MediaBlobStorage.isMediaReference(relative)) continue;
      final file = await fileFor(relative);
      if (await file.exists()) await file.delete();
    }
  }

  Future<File> fileFor(String relativePath) async {
    if (MediaBlobStorage.isMediaReference(relativePath)) {
      return blobStorage.fileForReference(relativePath);
    }
    final safe = requireSafeRelativePath(relativePath);
    final root = await rootDirectory;
    return File(p.joinAll([root.path, ...safe.split('/')]));
  }

  Future<void> cleanOldDrafts({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final temp = await getTemporaryDirectory();
    final drafts = Directory(p.join(temp.path, 'companion_attachment_drafts'));
    if (!await drafts.exists()) return;
    final cutoff = DateTime.now().subtract(maxAge);
    await for (final entity in drafts.list(followLinks: false)) {
      if (entity is! Directory) continue;
      try {
        if ((await entity.stat()).modified.isBefore(cutoff)) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<void> installSnapshotAttachments(
    Directory extractedAttachments,
    Iterable<String> expectedPaths,
  ) async {
    final expected = expectedPaths.map(requireSafeRelativePath).toSet();
    final root = await rootDirectory;
    await root.create(recursive: true);
    for (final relative in expected) {
      final source = File(
        p.joinAll([extractedAttachments.path, ...relative.split('/')]),
      );
      final target = File(p.joinAll([root.path, ...relative.split('/')]));
      if (!await source.exists()) {
        if (await target.exists()) await target.delete();
        continue;
      }
      await target.parent.create(recursive: true);
      final temporary = File('${target.path}.importing');
      await source.copy(temporary.path);
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
    }

    for (final folder in const ['originals', 'thumbnails']) {
      final directory = Directory(p.join(root.path, folder));
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final relative = p.posix.join(folder, p.basename(entity.path));
        if (!expected.contains(relative)) await entity.delete();
      }
    }
  }

  Future<PreparedDirectorySwap> prepareSnapshotInstall({
    required Directory extractedAttachments,
    required Iterable<String> expectedPaths,
    required String snapshotId,
  }) async {
    return PreparedDirectorySwap.prepare(
      sourceDirectory: extractedAttachments,
      targetDirectory: await rootDirectory,
      expectedPaths: expectedPaths,
      validatePath: requireSafeRelativePath,
      token: '${snapshotId}_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  Future<int> pruneUnreferencedFiles(Iterable<String> referencedPaths) async {
    final referenced = referencedPaths
        .where((path) => !MediaBlobStorage.isMediaReference(path))
        .map(requireSafeRelativePath)
        .toSet();
    final root = await rootDirectory;
    var deleted = 0;
    for (final folder in const ['originals', 'thumbnails']) {
      final directory = Directory(p.join(root.path, folder));
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final relative = p.posix.join(folder, p.basename(entity.path));
        if (!referenced.contains(relative)) {
          await entity.delete();
          deleted++;
        }
      }
    }
    return deleted;
  }

  static String requireSafeRelativePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (MediaBlobStorage.isMediaReference(normalized)) {
      MediaBlobStorage.requireMediaReferencePath(normalized);
      return normalized;
    }
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.contains('..') ||
        p.posix.normalize(normalized) != normalized ||
        !(normalized.startsWith('originals/') ||
            normalized.startsWith('thumbnails/'))) {
      throw FormatException('不安全的图片附件路径：$value');
    }
    return normalized;
  }

  static String _safeImageExtension(String sourcePath, String? mimeType) {
    final extension = p.extension(sourcePath).toLowerCase();
    const allowed = {
      '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif',
    };
    if (allowed.contains(extension)) return extension;
    return switch (mimeType?.toLowerCase()) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/gif' => '.gif',
      'image/heic' || 'image/heif' => '.heic',
      _ => '.jpg',
    };
  }

  static String _normalizedMimeType(String? mimeType, String extension) {
    final normalized = mimeType?.trim().toLowerCase();
    if (normalized != null && normalized.startsWith('image/')) return normalized;
    return switch (extension) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      '.bmp' => 'image/bmp',
      '.heic' || '.heif' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  static Future<_DecodedThumbnail> _decodeThumbnail(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      if (width <= 0 || height <= 0) throw const FormatException('无法读取图片尺寸');
      codec = width >= height
          ? await descriptor.instantiateCodec(
              targetWidth: width > thumbnailLongestEdge
                  ? thumbnailLongestEdge
                  : width,
            )
          : await descriptor.instantiateCodec(
              targetHeight: height > thumbnailLongestEdge
                  ? thumbnailLongestEdge
                  : height,
            );
      final frame = await codec.getNextFrame();
      image = frame.image;
      final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null) throw const FormatException('无法生成图片缩略图');
      return _DecodedThumbnail(
        width: width,
        height: height,
        thumbnail: encoded.buffer.asUint8List(),
      );
    } catch (error) {
      if (error is FormatException) rethrow;
      throw FormatException('无法读取这张图片：$error');
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

class _DecodedThumbnail {
  const _DecodedThumbnail({
    required this.width,
    required this.height,
    required this.thumbnail,
  });

  final int width;
  final int height;
  final Uint8List thumbnail;
}
