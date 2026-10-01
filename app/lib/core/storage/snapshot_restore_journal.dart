import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'snapshot_directory_swap.dart';

/// Private write-ahead record. Never included in an exported state bundle.
/// SQLite's transaction marker decides rollback versus completion on restart.
class SnapshotRestoreJournal {
  SnapshotRestoreJournal(this.directory);
  final Directory directory;
  File get file => File(p.join(directory.path, 'snapshot_restore_v1.json'));

  Future<Map<String, dynamic>?> read() async {
    if (!await file.exists()) return null;
    if (await file.length() > 1024 * 1024) {
      throw const FormatException('恢复日志大小异常，已保留现场');
    }
    final record = Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map);
    if (record['version'] != 1 || record['id'] is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(record['id']) ||
        record['swaps'] is! List) {
      throw const FormatException('恢复日志格式异常，已保留现场');
    }
    return record;
  }

  Future<void> write(Map<String, dynamic> record) async {
    if (await file.exists()) throw StateError('上次恢复尚未完成');
    await directory.create(recursive: true);
    final temporary = File('${file.path}.writing');
    await temporary.writeAsString(jsonEncode(record), flush: true);
    await temporary.rename(file.path);
  }

  Future<void> recoverDirectories(Map<String, dynamic> record, {
    required bool committed,
  }) async {
    final swaps = (record['swaps'] as List).cast<Map>();
    for (final raw in committed ? swaps : swaps.reversed) {
      await PreparedDirectorySwap.recover(Map<String, dynamic>.from(raw),
          committed: committed);
    }
  }

  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}
