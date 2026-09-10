import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/media_blob.dart';
import 'snapshot_directory_swap.dart';

/// Shared, content-addressed storage used by message, album and sticker refs.
class MediaBlobStorage {
  static const String rootFolderName = 'media_blobs';
  static const String referencePrefix = 'media/';

  Future<Directory> get rootDirectory async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, rootFolderName));
  }

  Future<MediaBlob> store({
    required File original,
    required File thumbnail,
    required String mimeType,
    required int width,
    required int height,
    required DateTime createdAt,
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

  Future<void> deleteBlobFiles(MediaBlob blob) async {
    for (final path in <String>[blob.originalPath, blob.thumbnailPath]) {
      final file = await fileFor(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<int> pruneUnreferencedFiles(Iterable<String> referencedPaths) async {
    final referenced = referencedPaths.map(requireSafeRelativePath).toSet();
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
  }

  Future<PreparedDirectorySwap> prepareSnapshotInstall({
    required Directory extractedMedia,
    required Iterable<String> expectedPaths,
    required String snapshotId,
  }) async =>
      PreparedDirectorySwap.prepare(
        sourceDirectory: extractedMedia,
        targetDirectory: await rootDirectory,
        expectedPaths: expectedPaths,
        validatePath: requireSafeRelativePath,
        token: '${snapshotId}_${DateTime.now().microsecondsSinceEpoch}',
      );

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
