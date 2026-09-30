import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../widgets/caicai_live2d_stage.dart';
import '../stickers/sticker_pack_storage.dart';
import 'secure_config.dart';
import 'snapshot_directory_swap.dart';

class NativePortableSnapshot {
  const NativePortableSnapshot(
    this.token,
    this.live2dDirectory,
    this.preferences,
  );
  final String token;
  final Directory? live2dDirectory;
  final Map<String, dynamic> preferences;
}

abstract class NativePortableBackend {
  Future<NativePortableSnapshot> begin({bool exporting = false});
  Future<void> validateModels(
    NativePortableSnapshot snapshot,
    Directory directory,
  );
  Future<void> validatePreferences(Map<String, dynamic> preferences);
  Future<void> apply(
    NativePortableSnapshot snapshot,
    Map<String, dynamic> preferences,
  );
  Future<void> finish(NativePortableSnapshot snapshot, {required bool commit});
}

class AndroidPortableBackend implements NativePortableBackend {
  static const _channel = MethodChannel('ai_companion/caicai_live2d');
  @override
  Future<NativePortableSnapshot> begin({bool exporting = false}) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'portableBegin',
      {'exporting': exporting},
    );
    if (raw == null ||
        raw['token'] is! String ||
        raw['live2dDirectory'] is! String ||
        raw['preferences'] is! Map) {
      throw const FormatException('无法完整读取 Live2D 与本机显示设置');
    }
    return NativePortableSnapshot(
      raw['token'],
      Directory(raw['live2dDirectory']),
      Map<String, dynamic>.from(raw['preferences']),
    );
  }

  @override
  Future<void> validateModels(
    NativePortableSnapshot snapshot,
    Directory directory,
  ) => _channel.invokeMethod<void>('portableValidate', {
    'token': snapshot.token,
    'directory': directory.path,
  });
  @override
  Future<void> validatePreferences(Map<String, dynamic> preferences) =>
      _channel.invokeMethod<void>('portableValidatePreferences', {
        'preferences': preferences,
      });
  @override
  Future<void> apply(
    NativePortableSnapshot snapshot,
    Map<String, dynamic> preferences,
  ) => _channel.invokeMethod<void>('portableApply', {
    'token': snapshot.token,
    'preferences': preferences,
  });
  @override
  Future<void> finish(
    NativePortableSnapshot snapshot, {
    required bool commit,
  }) async {
    await _channel.invokeMethod<void>('portableFinish', {
      'token': snapshot.token,
      'commit': commit,
    });
    // Recreate the stage so it rereads the installed package and calibration.
    CaicaiLive2DService.revision.value++;
  }
}

class _NoNativeBackend implements NativePortableBackend {
  @override
  Future<NativePortableSnapshot> begin({bool exporting = false}) async =>
      const NativePortableSnapshot('', null, {
        'caicai_stage': {},
        'overlay_state': {},
        'companion_runtime': {},
      });
  @override
  Future<void> validateModels(
    NativePortableSnapshot snapshot,
    Directory directory,
  ) async {
    if (await directory.exists() && !(await directory.list().isEmpty)) {
      throw const FormatException('此平台不能恢复 Live2D 模型文件');
    }
  }

  @override
  Future<void> validatePreferences(Map<String, dynamic> preferences) async {}
  @override
  Future<void> apply(
    NativePortableSnapshot snapshot,
    Map<String, dynamic> preferences,
  ) async {}
  @override
  Future<void> finish(
    NativePortableSnapshot snapshot, {
    required bool commit,
  }) async {}
}

class PortableExport {
  const PortableExport(this.state, this.hashes, this.bytes);
  final Map<String, dynamic> state;
  final Map<String, String> hashes;
  final int bytes;
}

/// The portable domain covers imported models, sticker packs, native visual
/// preferences and the explicit non-secret secure-storage configuration.
class PortableCompanionStorage {
  PortableCompanionStorage({
    NativePortableBackend? native,
    SecureConfig? secure,
    Directory? stickerDirectory,
    StickerPackStorage? stickers,
  }) : native =
           native ??
           (Platform.isAndroid ? AndroidPortableBackend() : _NoNativeBackend()),
       secure = secure ?? (Platform.isAndroid ? SecureConfig.instance : null),
       stickerDirectory = stickerDirectory,
       stickers = stickers ?? StickerPackStorage();
  final NativePortableBackend native;
  final SecureConfig? secure;
  final Directory? stickerDirectory;
  final StickerPackStorage stickers;
  Future<Directory> get stickerRoot async =>
      stickerDirectory ??
      Directory(
        p.join((await getApplicationSupportDirectory()).path, 'sticker_packs'),
      );

  static String safePath(String value) {
    final segments = value.split('/');
    if (value.isEmpty ||
        value.contains('\\') ||
        value.startsWith('/') ||
        segments.any(
          (part) =>
              part.isEmpty ||
              part == '.' ||
              part == '..' ||
              part.contains(':') ||
              part.contains('\u0000'),
        )) {
      throw const FormatException('可迁移文件路径不安全');
    }
    return value;
  }

  static String archivePath(String value) {
    final safe = safePath(value);
    if (!safe.startsWith('live2d/') && !safe.startsWith('stickers/')) {
      throw const FormatException('状态包包含未知的可迁移文件');
    }
    return safe;
  }

  Future<PortableExport> exportTo(
    Directory directory,
    NativePortableSnapshot snapshot,
  ) async {
    final roots = <String, Directory>{
      if (snapshot.live2dDirectory != null) 'live2d': snapshot.live2dDirectory!,
      'stickers': await stickerRoot,
    };
    final paths = <String, List<String>>{'live2d': [], 'stickers': []};
    final hashes = <String, String>{};
    var bytes = 0;
    for (final entry in roots.entries) {
      final root = entry.value;
      if (entry.key == 'stickers')
        await stickers.validateSnapshotDirectory(
          root,
          allowLocalTemporary: true,
        );
      if (!await root.exists()) continue;
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is Link) throw const FormatException('可迁移文件不能包含符号链接');
        if (entity is! File) continue;
        final relative = safePath(
          p.relative(entity.path, from: root.path).replaceAll('\\', '/'),
        );
        if (entry.key == 'stickers' &&
            relative.split('/').first.startsWith('.'))
          continue;
        final name = '${entry.key}/$relative';
        paths[entry.key]!.add(relative);
        bytes += await entity.length();
        if (bytes > 8 * 1024 * 1024 * 1024 || hashes.length >= 160000) {
          throw const FormatException('可迁移文件超过存档容量限制');
        }
        final target = File(p.joinAll([directory.path, ...name.split('/')]));
        await target.parent.create(recursive: true);
        await entity.copy(target.path);
        hashes[name] = (await sha256.bind(target.openRead()).first).toString();
      }
    }
    for (final values in paths.values) {
      values.sort();
    }
    final config = secure == null
        ? {for (final key in SecureConfig.portableKeys) key: null}
        : await secure!.exportPortableSettings();
    return PortableExport(
      {
        'version': 1,
        'secure_config': config,
        'native_preferences': snapshot.preferences,
        'file_paths': paths,
      },
      hashes,
      bytes,
    );
  }

  static Map<String, dynamic> validateState(Object? raw) {
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['native_preferences'] is! Map ||
        raw['file_paths'] is! Map) {
      throw const FormatException('状态包缺少可迁移配置');
    }
    SecureConfig.validatePortableSettings(raw['secure_config']);
    final paths = raw['file_paths'] as Map;
    if (paths.length != 2 ||
        paths['live2d'] is! List ||
        paths['stickers'] is! List) {
      throw const FormatException('状态包可迁移文件清单不完整');
    }
    for (final domain in ['live2d', 'stickers']) {
      final values = paths[domain] as List;
      if (values.any((item) => item is! String) ||
          values.toSet().length != values.length) {
        throw const FormatException('状态包可迁移文件清单格式无效');
      }
      for (final item in values) {
        safePath(item);
      }
    }
    return Map<String, dynamic>.from(raw);
  }

  static Future<void> validatePayload({
    required Directory root,
    required Object? state,
    required Object? rawHashes,
    required Object? declaredBytes,
    required int observedBytes,
  }) async {
    final config = validateState(state);
    if (rawHashes is! Map) throw const FormatException('状态包缺少可迁移文件校验清单');
    final expected = <String>{
      for (final domain in ['live2d', 'stickers'])
        for (final path in config['file_paths'][domain]) '$domain/$path',
    };
    if (rawHashes.keys.toSet().length != expected.length ||
        !rawHashes.keys.toSet().containsAll(expected)) {
      throw const FormatException('可迁移文件清单与配置不一致');
    }
    final observed = <String>{};
    var bytes = 0;
    if (await root.exists()) {
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is Link) throw const FormatException('可迁移文件不能包含符号链接');
        if (entity is! File) continue;
        final relative = archivePath(
          p.relative(entity.path, from: root.path).replaceAll('\\', '/'),
        );
        observed.add(relative);
        bytes += await entity.length();
        final digest = rawHashes[relative];
        if (digest is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
            (await sha256.bind(entity.openRead()).first).toString() != digest) {
          throw const FormatException('可迁移文件 SHA-256 校验失败');
        }
      }
    }
    if (observed.length != expected.length ||
        !observed.containsAll(expected) ||
        bytes != observedBytes ||
        declaredBytes != bytes) {
      throw const FormatException('可迁移文件缺失或总大小不一致');
    }
  }

  Future<PreparedPortableState> prepare(
    Directory root,
    Object? raw,
    String token,
  ) async {
    final state = validateState(raw);
    final preferences = Map<String, dynamic>.from(state['native_preferences']);
    await native.validatePreferences(preferences);
    final snapshot = await native.begin();
    PreparedDirectorySwap? live2d;
    PreparedDirectorySwap? packs;
    try {
      final models = Directory(p.join(root.path, 'live2d'));
      await native.validateModels(snapshot, models);
      final incomingStickers = Directory(p.join(root.path, 'stickers'));
      await stickers.validateSnapshotDirectory(incomingStickers);
      if (snapshot.live2dDirectory != null) {
        live2d = await PreparedDirectorySwap.prepare(
          sourceDirectory: models,
          targetDirectory: snapshot.live2dDirectory!,
          expectedPaths: List<String>.from(state['file_paths']['live2d']),
          validatePath: safePath,
          token: token,
        );
      }
      packs = await PreparedDirectorySwap.prepare(
        sourceDirectory: incomingStickers,
        targetDirectory: await stickerRoot,
        expectedPaths: List<String>.from(state['file_paths']['stickers']),
        validatePath: safePath,
        token: token,
      );
      return PreparedPortableState(
        native,
        snapshot,
        secure,
        live2d,
        packs,
        preferences,
        SecureConfig.validatePortableSettings(state['secure_config']),
        await secure?.readPortableSettings(),
      );
    } catch (_) {
      try {
        await packs?.rollback();
      } finally {
        try {
          await live2d?.rollback();
        } finally {
          await native.finish(snapshot, commit: false);
        }
      }
      rethrow;
    }
  }
}

class PreparedPortableState {
  PreparedPortableState(
    this.native,
    this.snapshot,
    this.secure,
    this.live2d,
    this.stickers,
    this.preferences,
    this.config,
    this.previousConfig,
  );
  final NativePortableBackend native;
  final NativePortableSnapshot snapshot;
  final SecureConfig? secure;
  final PreparedDirectorySwap? live2d;
  final PreparedDirectorySwap stickers;
  final Map<String, dynamic> preferences;
  final Map<String, String?> config;
  final Map<String, String?>? previousConfig;
  bool _finished = false;
  bool _configTouched = false;
  Future<void> activate() async {
    await live2d?.activate();
    await stickers.activate();
    await native.apply(snapshot, preferences);
    _configTouched = true;
    await secure?.replacePortableSettings(config);
  }

  Future<void> rollback() async {
    if (_finished) return;
    try {
      await stickers.rollback();
    } finally {
      try {
        await live2d?.rollback();
      } finally {
        try {
          if (_configTouched && previousConfig != null)
            await secure?.replacePortableSettings(
              previousConfig!,
              restoringLocal: true,
            );
        } finally {
          await native.finish(snapshot, commit: false);
          _finished = true;
        }
      }
    }
  }

  Future<void> commit() async {
    if (_finished) return;
    // The database is authoritative now. Finish only after its transaction
    // succeeds; directory rollback candidates are private until this point.
    await native.finish(snapshot, commit: true);
    _finished = true;
    await live2d?.commit();
    await stickers.commit();
  }
}
