import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SnapshotCacheJanitor {
  const SnapshotCacheJanitor._();

  static const Duration staleAfter = Duration(hours: 24);

  static const List<String> _knownPrefixes = <String>[
    'companion_snapshot_work_',
    'companion_import_',
    'ai_companion_received_',
    'ai_companion_manual_',
    'ai_companion_backup_',
    'ai_companion_20',
  ];

  static Future<int> clean({Set<String> activePaths = const <String>{}}) async {
    final root = await getTemporaryDirectory();
    return cleanDirectory(
      root,
      activePaths: activePaths,
      now: DateTime.now(),
    );
  }

  static Future<int> cleanDirectory(
    Directory root, {
    Set<String> activePaths = const <String>{},
    DateTime? now,
  }) async {
    if (!await root.exists()) return 0;
    final instant = now ?? DateTime.now();
    final protected = activePaths.map(_canonical).toSet();
    var removed = 0;
    await for (final entity in root.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (!_knownPrefixes.any(name.startsWith)) continue;
      final canonical = _canonical(entity.path);
      if (protected.contains(canonical)) continue;
      FileStat stat;
      try {
        stat = await entity.stat();
      } catch (_) {
        continue;
      }
      if (instant.difference(stat.modified) < staleAfter) continue;
      try {
        if (entity is Directory) {
          await entity.delete(recursive: true);
        } else if (entity is File) {
          await entity.delete();
        } else {
          continue;
        }
        removed += 1;
      } catch (_) {
        // Cleanup is best effort. Export/import correctness never depends on
        // deleting a stale cache artifact successfully.
      }
    }
    return removed;
  }

  static String _canonical(String path) => p.normalize(p.absolute(path));
}
