import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../storage/snapshot_directory_swap.dart';
import 'sticker_pack.dart';

class StickerPackStorage {
  StickerPackStorage({AppDatabase? db}) : db = db ?? AppDatabase.instance;

  static const modeSetting = 'sticker_expression_mode_v1';
  static const enabledPacksSetting = 'sticker_enabled_pack_ids_v1';
  static const usageHistorySetting = 'sticker_usage_history_v1';
  static const maxArchiveBytes = 512 * 1024 * 1024;
  static const maxExpandedBytes = 768 * 1024 * 1024;
  static const maxEntries = 2400;
  static const maxStickers = 1200;
  static const maxBundlePacks = 20;

  final AppDatabase db;

  Future<Directory> get rootDirectory async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'sticker_packs'));
  }

  Future<List<StickerPackMeta>> scanPacks() async {
    final root = await rootDirectory;
    if (!await root.exists()) return const <StickerPackMeta>[];
    final packs = <StickerPackMeta>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory || p.basename(entity.path).startsWith('.')) {
        continue;
      }
      try {
        packs.add(await _readPack(entity));
      } catch (_) {
        // A broken local pack is ignored, never allowed to break chat startup.
      }
    }
    packs.sort((a, b) => a.id.compareTo(b.id));
    return packs;
  }

  Future<Set<String>> enabledPackIds() async {
    final raw = await db.getSetting(enabledPacksSetting) ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .map((item) => item.toString())
          .where(_validPackId)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> setPackEnabled(String id, bool enabled) async {
    if (!_validPackId(id)) throw const FormatException('表情包 ID 无效');
    final values = await enabledPackIds();
    enabled ? values.add(id) : values.remove(id);
    await _writeEnabledPackIds(values);
  }

  Future<void> _setPacksEnabled(Iterable<String> ids) async {
    final values = await enabledPackIds();
    for (final id in ids) {
      if (!_validPackId(id)) throw const FormatException('表情包 ID 无效');
      values.add(id);
    }
    await _writeEnabledPackIds(values);
  }

  Future<void> _writeEnabledPackIds(Set<String> values) async {
    final sorted = values.toList()..sort();
    await db.setSetting(enabledPacksSetting, jsonEncode(sorted));
  }

  Future<StickerImportBatchResult> importZip(String zipPath) async {
    final source = File(zipPath);
    if (!await source.exists() ||
        !await source
            .stat()
            .then((value) => value.type == FileSystemEntityType.file)) {
      throw const FileSystemException('没有找到表情包 ZIP');
    }
    final compressedBytes = await source.length();
    if (compressedBytes <= 0 || compressedBytes > maxArchiveBytes) {
      throw const FormatException('表情包 ZIP 为空或超过 512 MB');
    }
    final archive = _decodeZip(zipPath);
    final outerShape = _validateArchive(archive);
    final temp = await Directory.systemTemp.createTemp('companion_sticker_import_');
    final prepared = <_PreparedStickerPackImport>[];
    try {
      final packManifests = _packManifestPaths(outerShape.names);
      final hasRootChildZip = outerShape.names.any(
        (name) => !name.contains('/') && p.extension(name).toLowerCase() == '.zip',
      );
      if (packManifests.length == 1 && !hasRootChildZip) {
        prepared.add(await _prepareArchive(
          archive: archive,
          manifestPath: packManifests.single,
          extractionDirectory: Directory(p.join(temp.path, 'single')),
        ));
      } else {
        final childNames = requireRootBundleZipPaths(archive);
        await extractArchiveToDisk(archive, temp.path);
        var totalEntries = archive.length;
        var totalExpanded = outerShape.expandedBytes;
        for (var index = 0; index < childNames.length; index++) {
          final childPath = p.join(temp.path, childNames[index]);
          final childArchive = _decodeZip(childPath);
          final childShape = _validateArchive(childArchive);
          totalEntries += childArchive.length;
          totalExpanded += childShape.expandedBytes;
          if (totalEntries > maxEntries || totalExpanded > maxExpandedBytes) {
            throw const FormatException('组合表情包解压总量或条目数超过限制');
          }
          final manifests = _packManifestPaths(childShape.names);
          if (manifests.length != 1) {
            throw FormatException('子 ZIP 必须且只能包含一个表情包：${childNames[index]}');
          }
          prepared.add(await _prepareArchive(
            archive: childArchive,
            manifestPath: manifests.single,
            extractionDirectory: Directory(p.join(temp.path, 'pack_$index')),
          ));
        }
      }

      final ids = prepared.map((item) => item.meta.id).toList(growable: false);
      if (ids.toSet().length != ids.length) {
        throw const FormatException('组合包包含重复的表情包 ID');
      }
      try {
        for (final item in prepared) {
          await item.swap.activate();
        }
        await _setPacksEnabled(ids);
        for (final item in prepared) {
          await item.swap.commit();
        }
      } catch (_) {
        for (final item in prepared.reversed) {
          await item.swap.rollback();
        }
        rethrow;
      }
      final imports = <StickerImportResult>[];
      for (final item in prepared) {
        imports.add(StickerImportResult(
          pack: await _readPack(item.target),
          replaced: item.replaced,
        ));
      }
      return StickerImportBatchResult(imports: imports);
    } catch (_) {
      for (final item in prepared.reversed) {
        await item.swap.rollback();
      }
      rethrow;
    } finally {
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  }

  Archive _decodeZip(String zipPath) {
    final input = InputFileStream(zipPath);
    try {
      return ZipDecoder().decodeStream(input);
    } finally {
      input.close();
    }
  }

  _StickerArchiveShape _validateArchive(Archive archive) {
    if (archive.isEmpty || archive.length > maxEntries) {
      throw const FormatException('表情包 ZIP 为空或条目过多');
    }
    var expanded = 0;
    final names = <String>{};
    for (final entry in archive) {
      if (entry.isSymbolicLink || (!entry.isFile && !entry.isDirectory)) {
        throw FormatException('表情包 ZIP 包含不支持的条目：${entry.name}');
      }
      final safe = requireSafeArchivePath(entry.name);
      if (!names.add(safe)) throw FormatException('表情包路径重复：$safe');
      if (entry.isFile) {
        expanded += entry.size;
        if (expanded > maxExpandedBytes) {
          throw const FormatException('表情包解压后超过 768 MB');
        }
      }
    }
    return _StickerArchiveShape(names: names, expandedBytes: expanded);
  }

  Future<_PreparedStickerPackImport> _prepareArchive({
    required Archive archive,
    required String manifestPath,
    required Directory extractionDirectory,
  }) async {
    await extractionDirectory.create(recursive: true);
    await extractArchiveToDisk(archive, extractionDirectory.path);
    final prefix = manifestPath.substring(
      0,
      manifestPath.length - 'manifest.json'.length,
    );
    final extractedRoot = Directory(p.joinAll([
      extractionDirectory.path,
      ...prefix.split('/').where((part) => part.isNotEmpty),
    ]));
    final meta = await _validateExtractedPack(extractedRoot);
    final target = Directory(p.join((await rootDirectory).path, meta.id));
    final expected = <String>['manifest.json', 'index.db'];
    final records = await readRecords(meta);
    expected.addAll(records.map((item) => item.path));
    final swap = await PreparedDirectorySwap.prepare(
      sourceDirectory: extractedRoot,
      targetDirectory: target,
      expectedPaths: expected,
      validatePath: requireSafePackPath,
      token: '${meta.id}_${DateTime.now().microsecondsSinceEpoch}',
    );
    return _PreparedStickerPackImport(
      meta: meta,
      target: target,
      replaced: await target.exists(),
      swap: swap,
    );
  }

  static List<String> _packManifestPaths(Set<String> names) => names
      .where((name) =>
          name == 'manifest.json' || name.endsWith('/manifest.json'))
      .where((name) {
        final prefix = name.substring(0, name.length - 'manifest.json'.length);
        return names.contains('${prefix}index.db');
      })
      .toList(growable: false);

  static List<String> requireRootBundleZipPaths(Archive archive) {
    return requireRootBundleZipNames(
      archive.where((entry) => entry.isFile).map((entry) => entry.name),
      hasDirectory: archive.any((entry) => entry.isDirectory),
    );
  }

  static List<String> requireRootBundleZipNames(
    Iterable<String> rawNames, {
    bool hasDirectory = false,
  }) {
    if (hasDirectory) {
      throw const FormatException('组合包根目录只能直接放置子 ZIP，不能包含文件夹');
    }
    final names = rawNames.map(requireSafeArchivePath).toList(growable: false)
      ..sort();
    if (names.length < 2 || names.length > maxBundlePacks) {
      throw const FormatException('组合包必须包含 2–20 个子 ZIP');
    }
    if (names.any((name) =>
        name.contains('/') || p.extension(name).toLowerCase() != '.zip')) {
      throw const FormatException('组合包根目录只能直接放置子 ZIP');
    }
    return names;
  }

  Future<void> deletePack(String id) async {
    if (!_validPackId(id)) throw const FormatException('表情包 ID 无效');
    final target = Directory(p.join((await rootDirectory).path, id));
    if (await target.exists()) await target.delete(recursive: true);
    await setPackEnabled(id, false);
  }

  Future<List<StickerRecord>> readRecords(StickerPackMeta pack) async {
    final indexPath = p.join(pack.rootPath, 'index.db');
    final database = await openDatabase(
      indexPath,
      readOnly: true,
      singleInstance: false,
    );
    try {
      final columns = (await database.rawQuery('PRAGMA table_info(memes)'))
          .map((row) => row['name']?.toString() ?? '')
          .toSet();
      const required = {'path', 'tag', 'file_name', 'caption', 'keywords'};
      if (!columns.containsAll(required)) {
        throw const FormatException('index.db 缺少 memes 标准字段');
      }
      final optional = <String>[
        if (columns.contains('tone_scope')) 'tone_scope',
        if (columns.contains('intensity')) 'intensity',
        if (columns.contains('enabled')) 'enabled',
      ];
      final rows = await database.query(
        'memes',
        columns: ['path', 'tag', 'caption', 'keywords', ...optional],
        limit: maxStickers + 1,
      );
      if (rows.isEmpty || rows.length > maxStickers) {
        throw const FormatException('表情包必须包含 1–1200 条索引');
      }
      final result = <StickerRecord>[];
      final seen = <String>{};
      for (final row in rows) {
        final path = requireSafePackPath(row['path']?.toString() ?? '');
        if (!path.startsWith('memes/')) {
          throw FormatException('表情包图片必须位于 memes/：$path');
        }
        if (!seen.add(path)) throw FormatException('索引路径重复：$path');
        final file = File(p.joinAll([pack.rootPath, ...path.split('/')]));
        if (!await file.exists()) throw FormatException('索引图片缺失：$path');
        final bytes = await file.length();
        if (bytes <= 0 || bytes > 25 * 1024 * 1024) {
          throw FormatException('表情包图片为空或超过 25 MB：$path');
        }
        final extension = p.extension(path).toLowerCase();
        if (!const {'.jpg', '.jpeg', '.png', '.webp', '.gif'}.contains(extension)) {
          throw FormatException('不支持的表情格式：$path');
        }
        result.add(StickerRecord(
          packId: pack.id,
          path: path,
          tag: (row['tag']?.toString() ?? '').trim().toLowerCase(),
          caption: _bounded(row['caption']?.toString() ?? '', 120),
          keywords: _bounded(row['keywords']?.toString() ?? '', 240),
          toneScope: _safeTone(row['tone_scope']?.toString() ?? 'general'),
          intensity:
              ((row['intensity'] as num?)?.toInt() ?? 1).clamp(1, 3).toInt(),
          enabled: (row['enabled'] as num?)?.toInt() != 0,
        ));
      }
      return result;
    } finally {
      await database.close();
    }
  }

  Future<File> fileFor(StickerPackMeta pack, StickerRecord record) async {
    if (pack.id != record.packId) throw const FormatException('表情包归属不一致');
    final safe = requireSafePackPath(record.path);
    final file = File(p.joinAll([pack.rootPath, ...safe.split('/')]));
    if (!await file.exists()) throw const FileSystemException('表情包图片已丢失');
    return file;
  }

  Future<StickerPackMeta> _validateExtractedPack(Directory root) async {
    final pack = await _readPack(root);
    await readRecords(pack);
    return pack;
  }

  Future<StickerPackMeta> _readPack(Directory root) async {
    final manifestFile = File(p.join(root.path, 'manifest.json'));
    final indexFile = File(p.join(root.path, 'index.db'));
    if (!await manifestFile.exists() || !await indexFile.exists()) {
      throw const FormatException('表情包缺少 manifest.json 或 index.db');
    }
    final raw = jsonDecode(await manifestFile.readAsString());
    if (raw is! Map) throw const FormatException('manifest.json 不是对象');
    final manifest = raw.map((key, value) => MapEntry(key.toString(), value));
    final id = (manifest['id']?.toString() ?? p.basename(root.path)).trim();
    if (!_validPackId(id)) throw const FormatException('manifest 的 id 无效');
    final countDb = await openDatabase(indexFile.path, readOnly: true, singleInstance: false);
    int count;
    try {
      count = Sqflite.firstIntValue(
            await countDb.rawQuery('SELECT COUNT(*) FROM memes'),
          ) ??
          0;
    } finally {
      await countDb.close();
    }
    if (count <= 0 || count > maxStickers) {
      throw const FormatException('表情包索引数量无效');
    }
    return StickerPackMeta(
      id: id,
      name: _bounded(manifest['name']?.toString() ?? id, 80),
      description: _bounded(manifest['description']?.toString() ?? '', 240),
      license: _bounded(manifest['license']?.toString() ?? 'unspecified', 80),
      rootPath: root.path,
      count: count,
    );
  }

  static String requireSafeArchivePath(String raw) {
    final value = raw.replaceAll('\\', '/');
    final canonical = value.endsWith('/')
        ? value.substring(0, value.length - 1)
        : value;
    if (canonical.isEmpty ||
        canonical.startsWith('/') ||
        value.contains('\u0000') ||
        value.split('/').contains('..') ||
        p.posix.normalize(canonical) != canonical) {
      throw FormatException('不安全的 ZIP 路径：$raw');
    }
    return canonical;
  }

  static String requireSafePackPath(String raw) {
    final value = raw.replaceAll('\\', '/');
    if (value.isEmpty ||
        value.startsWith('/') ||
        value.endsWith('/') ||
        value.contains('\u0000') ||
        value.split('/').contains('..') ||
        p.posix.normalize(value) != value) {
      throw FormatException('不安全的表情包路径：$raw');
    }
    return value;
  }

  static bool _validPackId(String value) =>
      RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(value);

  static String _safeTone(String value) =>
      const {'general', 'bold', 'nsfw', 'disabled'}
              .contains(value.trim().toLowerCase())
          ? value.trim().toLowerCase()
          : 'general';

  static String _bounded(String value, int limit) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= limit ? normalized : normalized.substring(0, limit);
  }
}

class _StickerArchiveShape {
  const _StickerArchiveShape({
    required this.names,
    required this.expandedBytes,
  });

  final Set<String> names;
  final int expandedBytes;
}

class _PreparedStickerPackImport {
  const _PreparedStickerPackImport({
    required this.meta,
    required this.target,
    required this.replaced,
    required this.swap,
  });

  final StickerPackMeta meta;
  final Directory target;
  final bool replaced;
  final PreparedDirectorySwap swap;
}
