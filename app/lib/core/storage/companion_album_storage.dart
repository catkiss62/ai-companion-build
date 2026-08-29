import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredAlbumThumbnail {
  const StoredAlbumThumbnail({
    required this.relativePath,
    required this.contentSha256,
  });

  final String relativePath;
  final String contentSha256;
}

/// Owns only bounded, EXIF-free thumbnails selected for the private album.
/// Chat originals and browser cache are deliberately outside this directory.
class CompanionAlbumStorage {
  static const String rootFolderName = 'companion_album';

  Future<Directory> get rootDirectory async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, rootFolderName));
  }

  Future<StoredAlbumThumbnail> saveThumbnail({
    required String id,
    required File source,
    required String expectedContentSha256,
  }) async {
    if (!await source.exists()) {
      throw const FileSystemException('相册候选缩略图不存在');
    }
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) throw const FormatException('相册候选缩略图为空');
    final sourceSha = sha256.convert(bytes).toString();
    if (expectedContentSha256.isEmpty || sourceSha != expectedContentSha256) {
      throw const AlbumImageBindingException('source_changed');
    }
    // The producer is required to pass the existing <=1000 px PNG thumbnail.
    if (bytes.length > 6 * 1024 * 1024) {
      throw const FormatException('相册缩略图异常过大');
    }
    final safeId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (safeId.isEmpty) throw const FormatException('相册图片 ID 无效');
    final relative = p.posix.join('thumbnails', '$safeId.png');
    final root = await rootDirectory;
    final target = File(p.join(root.path, 'thumbnails', '$safeId.png'));
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.saving');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      final storedSha = await contentSha256(target);
      if (storedSha != expectedContentSha256) {
        throw const AlbumImageBindingException('stored_bytes_mismatch');
      }
      return StoredAlbumThumbnail(
        relativePath: relative,
        contentSha256: storedSha,
      );
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<void> requireContentSha256(
    File source,
    String expectedContentSha256,
  ) async {
    if (expectedContentSha256.isEmpty ||
        await contentSha256(source) != expectedContentSha256) {
      throw const AlbumImageBindingException('source_changed');
    }
  }

  Future<String> contentSha256(File source) async {
    if (!await source.exists()) {
      throw const AlbumImageBindingException('source_missing');
    }
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) {
      throw const AlbumImageBindingException('source_empty');
    }
    return sha256.convert(bytes).toString();
  }

  Future<File> fileFor(String relativePath) async {
    final safe = requireSafeRelativePath(relativePath);
    final root = await rootDirectory;
    return File(p.joinAll([root.path, ...safe.split('/')]));
  }

  Future<void> deleteThumbnail(String relativePath) async {
    if (relativePath.trim().isEmpty) return;
    final file = await fileFor(relativePath);
    if (await file.exists()) await file.delete();
  }

  Future<int> pruneUnreferencedFiles(Iterable<String> referencedPaths) async {
    final referenced = referencedPaths
        .where((value) => value.trim().isNotEmpty)
        .map(requireSafeRelativePath)
        .toSet();
    final root = await rootDirectory;
    final directory = Directory(p.join(root.path, 'thumbnails'));
    if (!await directory.exists()) return 0;
    var removed = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || entity.path.endsWith('.saving')) continue;
      final relative = p.posix.join('thumbnails', p.basename(entity.path));
      if (!referenced.contains(relative)) {
        await entity.delete();
        removed++;
      }
    }
    return removed;
  }

  static String requireSafeRelativePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    if (!normalized.startsWith('thumbnails/') ||
        normalized.contains('..') ||
        p.posix.normalize(normalized) != normalized) {
      throw FormatException('不安全的相册缩略图路径：$value');
    }
    return normalized;
  }
}

/// Fixed, content-free failure used by diagnostics when the image observed by
/// vision is not byte-identical to the image about to be committed.
class AlbumImageBindingException implements Exception {
  const AlbumImageBindingException(this.reason);

  final String reason;

  @override
  String toString() => 'album_image_binding_mismatch:$reason';
}
