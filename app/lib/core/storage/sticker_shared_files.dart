import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// The pack-local ownership record lives with the pack's existing atomic swap.
/// It is never accepted from an imported ZIP and never exported in v7 backups.
class StickerSharedFiles {
  StickerSharedFiles({this.packRootOverride, this.mediaRootOverride});
  static const manifestName = 'shared_originals_v1.json';
  final Directory? packRootOverride;
  final Directory? mediaRootOverride;

  Future<Directory> get packRoot async => packRootOverride ??
      Directory(p.join((await getApplicationSupportDirectory()).path, 'sticker_packs'));
  Future<Directory> get mediaRoot async => mediaRootOverride ??
      Directory(p.join((await getApplicationSupportDirectory()).path, 'media_blobs'));

  static String safeOriginal(String value) {
    if (!RegExp(r'^originals/[a-f0-9]{64}\.(png|webp|gif|jpg|jpeg|bmp|heic)$').hasMatch(value)) {
      throw const FormatException('共享表情原图引用无效');
    }
    return value;
  }

  static String safePackPath(String value) {
    if (!value.startsWith('memes/') || value.contains('\\') ||
        value.split('/').any((s) => s.isEmpty || s == '.' || s == '..' || s.contains(':'))) {
      throw const FormatException('共享表情索引路径无效');
    }
    return value;
  }

  Future<Map<String, String>> readMap(Directory pack) async {
    final file = File(p.join(pack.path, manifestName));
    if (!await file.exists()) return {};
    if (await file.length() > 1024 * 1024) throw const FormatException('共享表情索引过大');
    final raw = jsonDecode(await file.readAsString());
    if (raw is! Map || raw['version'] != 1 || raw['originals'] is! Map) {
      throw const FormatException('共享表情索引损坏');
    }
    return (raw['originals'] as Map).map((k, v) =>
        MapEntry(safePackPath(k as String), safeOriginal(v as String)));
  }

  Future<File> resolve(Directory pack, String path) async {
    final mapping = await readMap(pack);
    return resolveFromMap(pack, path, mapping);
  }

  Future<File> resolveFromMap(Directory pack, String path, Map<String, String> mapping) async {
    safePackPath(path);
    final shared = mapping[path];
    return shared == null
        ? File(p.join(pack.path, path))
        : File(p.join((await mediaRoot).path, safeOriginal(shared)));
  }

  /// Includes transaction staging/previous directories: interruption may leave
  /// either as the only durable owner until the existing swap is resolved.
  Future<Set<String>> ownedOriginals({bool includeTransactions = true}) async {
    final root = await packRoot;
    final result = <String>{};
    if (!await root.exists()) return result;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory) continue;
      if (!includeTransactions && p.basename(entry.path).startsWith('.')) continue;
      result.addAll((await readMap(entry)).values);
    }
    return result;
  }

  Future<int> migrate(Directory pack, Iterable<String> paths, {
    Map<String, String> canonicalPaths = const {},
  }) async {
    final expected = paths.map(safePackPath).toSet();
    final before = await readMap(pack);
    if (before.isNotEmpty && (before.length != expected.length || !before.keys.toSet().containsAll(expected))) {
      throw const FormatException('共享表情索引与图库不一致');
    }
    final mapping = <String, String>{};
    final root = await mediaRoot;
    for (final path in expected) {
      final raw = File(p.join(pack.path, path));
      final existing = before[path];
      final source = existing == null ? raw : File(p.join(root.path, existing));
      if (!await source.exists()) throw const FileSystemException('表情原图缺失，未删除旧文件');
      final hash = (await sha256.bind(source.openRead()).first).toString();
      final handle = await source.open();
      late List<int> header;
      try { header = await handle.read(16); } finally { await handle.close(); }
      final String extension;
      if (header.length >= 8 && header[0] == 137 && header[1] == 80) {
        extension = '.png';
      } else if (header.length >= 3 && header[0] == 255 && header[1] == 216) {
        extension = '.jpg';
      } else if (header.length >= 6 && ascii.decode(header.take(3).toList(), allowInvalid: true) == 'GIF') {
        extension = '.gif';
      } else if (header.length >= 12 && ascii.decode(header.sublist(8, 12), allowInvalid: true) == 'WEBP') {
        extension = '.webp';
      } else {
        throw const FormatException('不支持的共享表情图片格式');
      }
      final relative = safeOriginal(canonicalPaths[hash] ?? existing ?? 'originals/$hash$extension');
      if (p.basenameWithoutExtension(relative) != hash) throw const FormatException('共享表情原图校验失败');
      final target = File(p.join(root.path, relative));
      if (await target.exists()) {
        if ((await sha256.bind(target.openRead()).first).toString() != hash) {
          throw const FormatException('共享表情原图已损坏');
        }
      } else {
        await target.parent.create(recursive: true);
        final temporary = File('${target.path}.${const Uuid().v4()}.saving');
        try {
          await source.copy(temporary.path);
          if ((await sha256.bind(temporary.openRead()).first).toString() != hash) {
            throw const FileSystemException('共享表情写入校验失败');
          }
          await temporary.rename(target.path);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
      }
      mapping[path] = relative;
    }
    // Commit ownership BEFORE removing any source. On restart the committed
    // map is sufficient to finish deleting verified legacy copies.
    final file = File(p.join(pack.path, manifestName));
    final pending = File('${file.path}.saving');
    await pending.writeAsString(jsonEncode({'version': 1, 'originals': mapping}), flush: true);
    await pending.rename(file.path);
    var removed = 0;
    for (final path in expected) {
      final raw = File(p.join(pack.path, path));
      if (await raw.exists()) {
        final hash = (await sha256.bind(raw.openRead()).first).toString();
        if (hash != p.basenameWithoutExtension(mapping[path]!)) {
          throw const FormatException('图库原件变化，已保留该文件');
        }
        await raw.delete();
        removed++;
      }
    }
    return removed;
  }
}
