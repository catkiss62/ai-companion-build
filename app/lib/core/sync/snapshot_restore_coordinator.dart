import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../phone/calendar_reminder_store.dart';
import '../storage/portable_companion_storage.dart';
import '../storage/snapshot_directory_swap.dart';
import '../storage/snapshot_restore_journal.dart';
import '../storage/shared_media_lock.dart';

class SnapshotInstallPlan {
  SnapshotInstallPlan(this.directories, {this.portable});
  final List<PreparedDirectorySwap> directories;
  final PreparedPortableState? portable;
  Iterable<PreparedDirectorySwap> get allDirectories sync* {
    yield* directories;
    final models = portable?.live2d;
    final stickers = portable?.stickers;
    if (models != null) yield models;
    if (stickers != null) yield stickers;
  }

  Future<void> activate() async {
    for (final directory in directories) {
      await directory.activate();
    }
    await portable?.activate();
  }

  Future<void> rollback() async {
    Object? failure;
    try { await portable?.rollback(); } catch (error) { failure = error; }
    for (final directory in directories.reversed) {
      try { await directory.rollback(); } catch (error) { failure ??= error; }
    }
    if (failure != null) throw failure;
  }

  Future<void> commit() async {
    await portable?.commit();
    for (final directory in directories) {
      await directory.commit();
    }
  }
}

class SnapshotCommitOutcome {
  const SnapshotCommitOutcome({this.warning = '', this.recoveryPending = false});
  final String warning;
  final bool recoveryPending;
}

class SnapshotRecoveryRequired implements Exception {
  const SnapshotRecoveryRequired();
  @override
  String toString() => '恢复尚未完整结束，已保留恢复日志并暂停后台写入。请重新打开应用完成恢复。';
}

/// A single durable decision joins file renames, native/secure preferences and
/// SQLite. The commit marker is written IN the import transaction. Recovery is
/// serialized across Flutter engines with the existing process-aware DB lease.
class SnapshotRestoreCoordinator {
  SnapshotRestoreCoordinator(this.db, this.portableStorage, {this.journal});
  final AppDatabase db;
  final PortableCompanionStorage portableStorage;
  SnapshotRestoreJournal? journal;
  static const leaseKey = 'snapshot_restore_lease_v1';
  static const pendingKey = 'snapshot_recovery_pending_v1';
  static const commitKey = 'snapshot_restore_commit_v1';

  Future<SnapshotRestoreJournal> _journal() async => journal ??=
      SnapshotRestoreJournal(await getApplicationSupportDirectory());

  Future<void> ensureRecovered() async {
    while (!await recoverIfPending()) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<bool> recoverIfPending() => SharedMediaLock.run(_recoverIfPending, db: db);

  Future<bool> _recoverIfPending() async {
    final log = await _journal();
    if (await log.read() == null) {
      if ((await db.getSetting(pendingKey) ?? '').isNotEmpty) {
        throw const SnapshotRecoveryRequired();
      }
      return true;
    }
    if (!await db.tryAcquireLocalLease(leaseKey,
        holdFor: const Duration(minutes: 30))) return false;
    try {
      await _recoverLocked(log);
      return true;
    } finally {
      await db.releaseLocalLease(leaseKey);
    }
  }

  Future<void> _recoverLocked(SnapshotRestoreJournal log) async {
    final record = await log.read();
    if (record == null) return;
    final id = record['id'] as String;
    final committed = await db.getSetting(commitKey) == id;
    final needsPreferences = (await db.getSetting(pendingKey) ?? '').isNotEmpty || !committed;
    // Restore directories before the legacy model index can refer to them.
    await log.recoverDirectories(record, committed: committed);
    if (needsPreferences && record['portable'] is Map) {
      await portableStorage.recover(
        Map<String, dynamic>.from(record['portable'] as Map), committed: committed,
      );
    }
    await _markConsistent(record, committed: committed, recovered: true);
    await log.clear();
  }

  Future<void> _markConsistent(Map<String, dynamic> record, {
    required bool committed,
    bool recovered = false,
  }) async {
    final id = record['id'] as String;
    if (Platform.isAndroid) {
      final scheduled = await CalendarReminderStore(db).sync();
      await db.setSetting('calendar_native_sync_warning', scheduled ? '' : 'alarm_schedule_unavailable');
    }
    final pending = await db.getSetting(pendingKey) ?? '';
    if (pending.isNotEmpty && pending != id) throw const SnapshotRecoveryRequired();
    final marked = await db.setSettingsAtomically({
      pendingKey: '',
      'snapshot_restore_outcome_v1': jsonEncode({
        'committed': committed, 'recoveredOnRestart': recovered,
        'at': DateTime.now().millisecondsSinceEpoch,
      }),
    }, expectedSettings: {pendingKey: pending});
    if (!marked) throw const SnapshotRecoveryRequired();
    if (!committed) {
      final owner = record['freezeOwner'] as String? ?? '';
      // Only release the exact abandoned local-backup freeze, never another
      // operation's lock or a durable transfer awaiting remote acknowledgement.
      if (owner.contains(':backup_restore:')) {
        await db.setSettingsAtomically({'transfer_lock': '0', 'transfer_lock_owner': ''},
            expectedSettings: {'transfer_lock_owner': owner});
      }
    }
  }

  Future<SnapshotCommitOutcome> install({
    required Future<SnapshotInstallPlan> Function(String transactionId) prepare,
    required Future<void> Function(Map<String, String> runtime) commitDatabase,
  }) => SharedMediaLock.run(() => _install(prepare: prepare, commitDatabase: commitDatabase), db: db);

  Future<SnapshotCommitOutcome> _install({
    required Future<SnapshotInstallPlan> Function(String transactionId) prepare,
    required Future<void> Function(Map<String, String> runtime) commitDatabase,
  }) async {
    if (!await db.tryAcquireLocalLease(leaseKey,
        holdFor: const Duration(minutes: 30))) {
      throw StateError('另一个恢复操作尚未完成');
    }
    try {
      final log = await _journal();
      await _recoverLocked(log);
      final id = const Uuid().v4();
      final plan = await prepare(id);
      final record = <String, dynamic>{
        'version': 1, 'id': id,
        'freezeOwner': await db.getSetting('transfer_lock_owner') ?? '',
        'swaps': plan.allDirectories.map((item) => item.recoveryRecord).toList(),
        'portable': plan.portable?.recoveryRecord,
      };
      var warning = '';
      try {
        await log.write(record);
        await db.setSetting(pendingKey, id);
        await plan.activate();
        await commitDatabase({
          commitKey: id, pendingKey: id,
          'runtime_state_epoch_v1': id,
          leaseKey: await db.getSetting(leaseKey) ?? '',
          SharedMediaLock.leaseKey: await db.getSetting(SharedMediaLock.leaseKey) ?? '',
        });
      } catch (error) {
        // importAll may report a seed/maintenance error AFTER its transaction
        // committed. Its durable marker, not the exception, decides rollback.
        if (await db.getSetting(commitKey) != id) {
          try {
            await plan.rollback();
            await log.recoverDirectories(record, committed: false);
            await _markConsistent(record, committed: false);
            await log.clear();
          } catch (_) {
            throw const SnapshotRecoveryRequired();
          }
          rethrow;
        }
        warning = '数据已恢复，部分后续整理需在重新打开应用后完成。';
      }
      try {
        try {
          await plan.commit();
        } catch (_) {
          // Activity detachment/refresh can fail after the database committed.
          // Replay the chosen NEW preferences, never roll back only that half.
          if (record['portable'] is Map) {
            await portableStorage.recover(
              Map<String, dynamic>.from(record['portable'] as Map), committed: true,
            );
          }
          warning = '数据已恢复，本机显示设置已重新同步。';
        }
        await log.recoverDirectories(record, committed: true);
        await _markConsistent(record, committed: true);
        try {
          await log.clear();
        } catch (_) {
          // Consistency was durably confirmed above. A leftover journal only
          // needs deletion; it must not be reported as a blocked half-restore.
          warning = '数据已恢复，恢复日志将在下次启动时清理。';
        }
        return SnapshotCommitOutcome(warning: warning);
      } catch (_) {
        return const SnapshotCommitOutcome(
          warning: '数据已恢复，但本机设置或文件收尾尚未完成。请重新打开应用，自动完成恢复后再继续。',
          recoveryPending: true,
        );
      }
    } finally {
      await db.releaseLocalLease(leaseKey);
    }
  }
}
