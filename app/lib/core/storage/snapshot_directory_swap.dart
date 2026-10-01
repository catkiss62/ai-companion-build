import 'dart:io';

import 'package:path/path.dart' as p;

typedef SnapshotPathValidator = String Function(String value);

/// A complete directory tree prepared beside its live destination.
///
/// The staged/live rename happens on the same filesystem. Until [commit], an
/// activated tree can be rolled back to the exact directory that was live
/// before the snapshot import began.
class PreparedDirectorySwap {
  PreparedDirectorySwap._({
    required this.targetDirectory,
    required this.stagedDirectory,
    required this.backupDirectory,
    required this.hadTarget,
  });

  final Directory targetDirectory;
  final Directory stagedDirectory;
  final Directory backupDirectory;
  final bool hadTarget;

  Map<String, Object?> get recoveryRecord => {
    'target': targetDirectory.path,
    'staged': stagedDirectory.path,
    'previous': backupDirectory.path,
    'hadTarget': hadTarget,
  };

  bool _activated = false;
  bool _committed = false;

  static Future<PreparedDirectorySwap> prepare({
    required Directory sourceDirectory,
    required Directory targetDirectory,
    required Iterable<String> expectedPaths,
    required SnapshotPathValidator validatePath,
    required String token,
  }) async {
    final safeToken = token.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (safeToken.isEmpty) {
      throw const FormatException('状态包目录切换标识无效');
    }
    final parent = targetDirectory.parent;
    await parent.create(recursive: true);
    final base = p.basename(targetDirectory.path);
    final staged = Directory(p.join(parent.path, '.$base.snapshot-$safeToken.staged'));
    final backup = Directory(p.join(parent.path, '.$base.snapshot-$safeToken.previous'));
    if (await staged.exists() || await backup.exists()) {
      throw const FileSystemException('状态包暂存目录已存在，请重新生成状态包');
    }
    await staged.create(recursive: true);
    try {
      for (final rawPath in expectedPaths.toSet()) {
        final relative = validatePath(rawPath);
        final source = File(
          p.joinAll([sourceDirectory.path, ...relative.split('/')]),
        );
        if (!await source.exists()) continue;
        final target = File(p.joinAll([staged.path, ...relative.split('/')]));
        await target.parent.create(recursive: true);
        await source.copy(target.path);
      }
      return PreparedDirectorySwap._(
        targetDirectory: targetDirectory,
        stagedDirectory: staged,
        backupDirectory: backup,
        hadTarget: await targetDirectory.exists(),
      );
    } catch (_) {
      if (await staged.exists()) await staged.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> activate({Future<void> Function()? afterPreviousMoved}) async {
    if (_committed) throw StateError('状态包目录已经提交');
    if (_activated) return;
    var movedPrevious = false;
    try {
      if (await targetDirectory.exists()) {
        await targetDirectory.rename(backupDirectory.path);
        movedPrevious = true;
        await afterPreviousMoved?.call();
      }
      await stagedDirectory.rename(targetDirectory.path);
      _activated = true;
    } catch (_) {
      if (movedPrevious &&
          !await targetDirectory.exists() &&
          await backupDirectory.exists()) {
        await backupDirectory.rename(targetDirectory.path);
      }
      rethrow;
    }
  }

  /// Uses filesystem evidence, not process-local flags. Safe to repeat after a
  /// process exits between either rename, rollback steps or backup cleanup.
  static Future<void> recover(Map<String, dynamic> record, {
    required bool committed,
    Future<void> Function()? afterTargetRemoved,
  }) async {
    final target = Directory(record['target'] as String);
    final staged = Directory(record['staged'] as String);
    final previous = Directory(record['previous'] as String);
    if (!p.isAbsolute(target.path) ||
        p.dirname(target.path) != p.dirname(staged.path) ||
        p.dirname(target.path) != p.dirname(previous.path) ||
        !p.basename(staged.path).startsWith('.${p.basename(target.path)}.snapshot-') ||
        !staged.path.endsWith('.staged') ||
        previous.path != '${staged.path.substring(0, staged.path.length - 7)}.previous') {
      throw const FormatException('恢复日志的目录关系无效');
    }
    if (committed) {
      if (!await target.exists()) {
        throw const FileSystemException('已提交的恢复目录缺失，保留恢复日志');
      }
      if (await previous.exists()) await previous.delete(recursive: true);
    } else if (await previous.exists()) {
      if (await target.exists()) await target.delete(recursive: true);
      await afterTargetRemoved?.call();
      await previous.rename(target.path);
    } else if (record['hadTarget'] == false && !await staged.exists()) {
      if (await target.exists()) await target.delete(recursive: true);
    }
    if (await staged.exists()) await staged.delete(recursive: true);
  }

  Future<void> rollback() async {
    if (_committed) return;
    if (_activated) {
      if (await targetDirectory.exists()) {
        await targetDirectory.delete(recursive: true);
      }
      if (await backupDirectory.exists()) {
        await backupDirectory.rename(targetDirectory.path);
      }
      _activated = false;
    } else if (await stagedDirectory.exists()) {
      await stagedDirectory.delete(recursive: true);
    }
  }

  Future<void> commit() async {
    if (!_activated) throw StateError('状态包目录尚未启用');
    _committed = true;
    try {
      if (await backupDirectory.exists()) {
        await backupDirectory.delete(recursive: true);
      }
    } catch (_) {
      // The new tree is already authoritative. A stale private backup is safer
      // than reporting a failed import after the database has committed.
    }
  }
}
