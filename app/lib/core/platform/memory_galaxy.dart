import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../memory/memory_browse_repository.dart';
import '../memory/memory_galaxy_projection.dart';

class MemoryGalaxyLauncher {
  static const _channel = MethodChannel('ai_companion/memory_galaxy_native');
  static bool _opening = false;

  /// The native page receives a private snapshot file, not a large Binder JSON.
  /// It stays open until back/close; the snapshot is removed on every exit.
  static Future<void> open() async {
    if (_opening) return;
    if (!Platform.isAndroid) {
      throw UnsupportedError('记忆星谷目前支持 Android');
    }
    _opening = true;
    File? snapshot;
    try {
      final items = await MemoryBrowseRepository(AppDatabase.instance)
          .allActive();
      final temp = await getTemporaryDirectory();
      final directory = Directory(path.join(temp.path, 'memory_galaxy'));
      await directory.create(recursive: true);
      snapshot = File(
        path.join(
          directory.path,
          'galaxy-${DateTime.now().millisecondsSinceEpoch}-${const Uuid().v4()}.json',
        ),
      );
      await snapshot.writeAsString(
        jsonEncode(MemoryGalaxyProjection.fromItems(items)),
        flush: true,
      );
      await _channel.invokeMethod<bool>('open', {'dataPath': snapshot.path});
    } finally {
      try {
        if (snapshot != null && await snapshot.exists())
          await snapshot.delete();
      } finally {
        _opening = false;
      }
    }
  }
}
