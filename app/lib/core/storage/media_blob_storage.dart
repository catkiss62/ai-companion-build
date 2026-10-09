import 'dart:io';
import 'dart:typed_data';
import '../database/app_database.dart';
import 'shared_media_lock.dart';
import 'sticker_shared_files.dart';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/media_blob.dart';
import 'snapshot_directory_swap.dart';

/// Shared, content-addressed storage used by message, album and sticker refs.
class MediaBlobStorage {
  MediaBlobStorage({AppDatabase? db, StickerSharedFiles? stickerFiles})
      : db = db ?? AppDatabase.instance, stickerFiles = stickerFiles ?? StickerSharedFiles();
  final AppDatabase db;
  final StickerSharedFiles stickerFiles;
  static const String rootFolderName = 'media_blobs';
  static const String referencePrefix = 'media/';

  Future<Directory> get rootDirectory async {
    if (stickerFiles.mediaRootOverride != null) return stickerFiles.mediaRootOverride!;
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, rootFolderName));
  }

  Future<MediaBlob> store({
    required File original, required File thumbnail, required String mimeType,
    required int width, required int height, required DateTime createdAt,
  }) => SharedMediaLock.run(() async {
    final blob = await _store(original: original, thumbnail: thumbnail,
        mimeType: mimeType, width: width, height: height, createdAt: createdAt);
    // Publish the DB identity before releasing the file lease. Album/chat
    // callers then add their existing transactional owner references.
    await db.registerMediaBlob(blob);
    return blob;
  }, db: db);

  Future<MediaBlob> _store({
    required File original, required File thumbnail, required String mimeType,
    required int width, required int height, required DateTime createdAt,
  }) async {
    if (!await original.exists() || !await thumbnail.exists()) {
      throw const FileSystemException('待保存媒体文件不存在');
    }
    final originalSize = await original.length();
    final thumbnailSize = await thumbnail.length();
    if (originalSize <= 0 || thumbnailSize <= 0) {
      throw const FormatException('待保存媒体文件为空');
    }
    final originalSha = await contentSha256(original);
    final thumbnailSha = await contentSha256(thumbnail);
    final extension = _extensionFor(mimeType, original.path);
    final originalPath = p.posix.join('originals', '$originalSha$extension');
    final thumbnailPath = p.posix.join('thumbnails', '$thumbnailSha.png');
    await _install(original, originalPath, originalSha);
    await _install(thumbnail, thumbnailPath, thumbnailSha);
    return MediaBlob(
      id: originalSha,
      originalPath: originalPath,
      thumbnailPath: thumbnailPath,
      originalSha256: originalSha,
      thumbnailSha256: thumbnailSha,
      mimeType: mimeType.trim().isEmpty ? _mimeFor(extension) : mimeType.trim(),
      byteSize: originalSize,
      thumbnailByteSize: thumbnailSize,
      width: width,
      height: height,
      messageRefCount: 0,
      albumRefCount: 0,
      createdAt: createdAt,
    );
  }

  Future<File> fileFor(String relativePath) async {
    final safe = requireSafeRelativePath(relativePath);
    final root = await rootDirectory;
    return File(p.joinAll(<String>[root.path, ...safe.split('/')]));
  }

  Future<File> fileForReference(String referencePath) =>
      fileFor(requireMediaReferencePath(referencePath));

  Future<void> deleteBlobFiles(MediaBlob blob) => SharedMediaLock.run(() async {
    // A restore/new sender may have re-registered this identity after the
    // caller removed the old DB row. Recheck under the shared file lease.
    if (await db.mediaBlobById(blob.id) != null) return;
    final protected = await stickerFiles.ownedOriginals();
    for (final current in await db.allMediaBlobs()) {
      protected.addAll([current.originalPath, current.thumbnailPath]);
    }
    for (final path in <String>[blob.originalPath, blob.thumbnailPath]) {
      if (protected.contains(path)) continue;
      final file = await fileFor(path);
      if (await file.exists()) await file.delete();
    }
  }, db: db);

  Future<int> pruneUnreferencedFiles(Iterable<String> referencedPaths) => SharedMediaLock.run(() async {
    final referenced = referencedPaths.map(requireSafeRelativePath).toSet()
      ..addAll(await stickerFiles.ownedOriginals());
    for (final blob in await db.allMediaBlobs()) {
      referenced.addAll([blob.originalPath, blob.thumbnailPath]);
    }
    final root = await rootDirectory;
    var removed = 0;
    for (final folder in const <String>['originals', 'thumbnails']) {
      final directory = Directory(p.join(root.path, folder));
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || entity.path.endsWith('.saving')) continue;
        final relative = p.posix.join(folder, p.basename(entity.path));
        if (!referenced.contains(relative)) {
          await entity.delete();
          removed++;
        }
      }
    }
    return removed;
  }, db: db);

  Future<PreparedDirectorySwap> prepareSnapshotInstall({
    required Directory extractedMedia,
    required Iterable<String> expectedPaths,
    required String snapshotId,
  }) async {
    // The validated backup excludes full installed packs. Preserve local pack
    // originals in the same staged directory so rollback covers the union.
    final union = expectedPaths.toSet();
    for (final path in await stickerFiles.ownedOriginals()) {
      if (union.contains(path)) continue;
      final source = await fileFor(path);
      if (!await source.exists() || await contentSha256(source) != p.basenameWithoutExtension(path)) {
        throw const FileSystemException('本机表情原图缺失或损坏，已停止恢复');
      }
      final target = File(p.join(extractedMedia.path, path));
      await target.parent.create(recursive: true);
      await source.copy(target.path);
      union.add(path);
    }
    return PreparedDirectorySwap.prepare(
      sourceDirectory: extractedMedia,
      targetDirectory: await rootDirectory,
      expectedPaths: union,
      validatePath: requireSafeRelativePath,
      token: '${snapshotId}_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  Future<MediaBlob> storeSharedImage({required File original,
    required Uint8List thumbnail, required String mimeType,
    required int width, required int height, required DateTime createdAt}) async {
    final originalSha = await contentSha256(original);
    final thumbnailSha = sha256.convert(thumbnail).toString();
    final originalPath = p.posix.join('originals', '$originalSha${_extensionFor(mimeType, original.path)}');
    final thumbnailPath = p.posix.join('thumbnails', '$thumbnailSha.png');
    await _install(original, originalPath, originalSha);
    final target = await fileFor(thumbnailPath);
    if (!await target.exists()) {
      await target.parent.create(recursive: true);
      final temporary = File('${target.path}.saving');
      try {
        await temporary.writeAsBytes(thumbnail, flush: true);
        await temporary.rename(target.path);
      } finally { if (await temporary.exists()) await temporary.delete(); }
    } else if (await contentSha256(target) != thumbnailSha) {
      throw const FileSystemException('共享缩略图校验失败');
    }
    return MediaBlob(id: originalSha, originalPath: originalPath,
      thumbnailPath: thumbnailPath, originalSha256: originalSha,
      thumbnailSha256: thumbnailSha, mimeType: mimeType,
      byteSize: await original.length(), thumbnailByteSize: thumbnail.length,
      width: width, height: height, messageRefCount: 0, albumRefCount: 0, createdAt: createdAt);
  }

  Future<void> _install(File source, String relative, String expectedSha) async {
    final target = await fileFor(relative);
    if (await target.exists()) {
      if (await contentSha256(target) != expectedSha) {
        throw const FileSystemException('内容寻址媒体发生哈希冲突');
      }
      return;
    }
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.saving');
    try {
      await source.copy(temporary.path);
      if (await contentSha256(temporary) != expectedSha) {
        throw const FileSystemException('媒体写入校验失败');
      }
      try {
        await temporary.rename(target.path);
      } on FileSystemException {
        if (!await target.exists() || await contentSha256(target) != expectedSha) {
          rethrow;
        }
        await temporary.delete();
      }
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  static Future<String> contentSha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static bool isMediaReference(String value) =>
      value.replaceAll('\\', '/').startsWith(referencePrefix);

  static String toReferencePath(String relativePath) =>
      '$referencePrefix${requireSafeRelativePath(relativePath)}';

  static String requireMediaReferencePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (!normalized.startsWith(referencePrefix)) {
      throw FormatException('不是共享媒体引用路径：$value');
    }
    return requireSafeRelativePath(normalized.substring(referencePrefix.length));
  }

  static String requireSafeRelativePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.contains('..') ||
        p.posix.normalize(normalized) != normalized ||
        !(normalized.startsWith('originals/') ||
            normalized.startsWith('thumbnails/'))) {
      throw FormatException('不安全的共享媒体路径：$value');
    }
    return normalized;
  }

  static String _extensionFor(String mimeType, String path) =>
      switch (mimeType.trim().toLowerCase()) {
        'image/png' => '.png',
        'image/webp' => '.webp',
        'image/gif' => '.gif',
        'image/bmp' => '.bmp',
        'image/heic' || 'image/heif' => '.heic',
        'image/jpeg' || 'image/jpg' => '.jpg',
        _ => _safeExtension(p.extension(path)),
      };

  static String _safeExtension(String value) {
    final normalized = value.trim().toLowerCase();
    const allowed = <String>{
      '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic', '.heif',
    };
    return allowed.contains(normalized) ? normalized : '.jpg';
  }

  static String _mimeFor(String extension) => switch (extension) {
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.gif' => 'image/gif',
        '.bmp' => 'image/bmp',
        '.heic' || '.heif' => 'image/heic',
        _ => 'image/jpeg',
      };
}
