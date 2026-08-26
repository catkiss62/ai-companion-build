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
  }) async {
    if (!await source.exists()) {
      throw const FileSystemException('相册候选缩略图不存在');
    }
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) throw const FormatException('相册候选缩略图为空');
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
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
    return StoredAlbumThumbnail(
      relativePath: relative,
      contentSha256: sha256.convert(bytes).toString(),
    );
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
