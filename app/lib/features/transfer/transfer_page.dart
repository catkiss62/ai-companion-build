import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/sync/snapshot_cache_janitor.dart';
import '../../core/sync/snapshot_service.dart';
import '../../core/sync/snapshot_restore_coordinator.dart';
import '../../core/phone/calendar_reminder_store.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key, this.database});

  final AppDatabase? database;

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  static const int _maxManualBytes = 512 * 1024 * 1024;
  late final db = widget.database ?? AppDatabase.instance;
  final android = AndroidBridge.instance;
  late final SnapshotService snapshots = SnapshotService(db);

  SnapshotBundle? outboundBundle;
  String? log;
  bool busy = false;
  bool importedStandby = false;

  @override
  void initState() {
    super.initState();
    unawaited(SnapshotCacheJanitor.clean());
    unawaited(_restoreStandbyUiState());
  }

  Future<void> _syncRemindersSafely() async {
    try {
      if (!await CalendarReminderStore(db).sync()) {
        _append('数据状态已更新，提醒响铃暂未能全部排入系统；请检查闹钟权限。');
      }
    } catch (_) {
      _append('数据状态已更新，本机提醒将在下次打开应用时重新同步。');
    }
  }

  Future<void> _restoreStandbyUiState() async {
    final active = await db.getSetting('active_brain');
    if (!mounted) return;
    if (active == '0') {
      setState(() {
        importedStandby = true;
      });
    }
  }

  @override
  void dispose() {
    if (outboundBundle != null) {
      unawaited(_clearSourceSnapshot());
    }
    super.dispose();
  }

  Future<void> _deleteCachePath(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // App-private cache cleanup is best effort and must never break takeover.
    }
  }

  Future<void> _clearSourceSnapshot({
    bool unlock = true,
    bool invalidatePending = true,
  }) async {
    final bundle = outboundBundle;
    outboundBundle = null;
    try {
      if (bundle != null && invalidatePending) {
        await db.cancelPreparedTransferSnapshot(bundle.metadata.snapshotId);
      }
    } finally {
      if (bundle != null) await _deleteCachePath(bundle.filePath);
      if (unlock) await db.setSetting('transfer_lock', '0');
    }
  }

  void _append(String text) {
    if (!mounted) return;
    final now = TimeOfDay.now().format(context);
    setState(() => log = '${log ?? ''}${log == null ? '' : '\n'}[$now] $text');
  }

  Future<void> _waitForStateWriters() async {
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    const keys = <String>[
      'chat_turn_lease',
      'immersive_room_lease',
      'calendar_reminder_followup_lease_until',
      'immersive_archive_lease_until',
      'simulated_phone_refresh_lease_until',
      'simulated_phone_media_lease_until',
      'cedar_toy_action_lease_until',
      'recovery_orchestrator_lease_until',
      'post_turn_memory_lease',
      'proactive_lease_until',
      'relationship_assimilation_lease_until',
      'deferred_followup_lease_until',
      'self_drive_lease_until',
      'companion_wish_review_lease_until',
      'deep_reflection_prepare_lease_until',
      'thought_lifecycle_lease_until',
      'memory_maintenance_lease_until',
      'thought_consolidation_lease_until',
      'ai_self_reflection_lease_until',
      'conversation_summary_lease_until',
      'long_running_maintenance_lease',
    ];
    var lastHeldKey = '';
    while (DateTime.now().isBefore(deadline)) {
      var held = false;
      for (final key in keys) {
        if (await db.isLocalLeaseHeld(key)) {
          held = true;
          lastHeldKey = key;
          break;
        }
      }
      if (!held) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw StateError(
      '当前仍有聊天、记忆或后台整理正在写入（阻塞项：'
      '${lastHeldKey.isEmpty ? 'unknown' : lastHeldKey}），'
      '请等这一轮完成后重试。',
    );
  }

  Future<bool> _confirmLineageReplacement(SnapshotMetadata metadata) async {
    final local = await db.transferStateIdentity();
    if (metadata.lineageId == local.lineageId) return true;
    if (await db.isPristineForLineageAdoption()) return true;
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('替换本机现有关系数据？'),
            content: const Text(
              '这个状态包属于另一段 Companion 数据谱系。继续会用发送设备的完整关系、记忆和聊天替换本机当前内容。'
              '\n\n本机安装身份会保留，但原来的这段关系数据不会与新状态自动合并。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认替换'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmIncompleteArchive(SnapshotMetadata metadata) async {
    if (metadata.hasCompleteArchiveState) return true;
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('这是旧版状态包'),
            content: const Text(
              '这个包不包含她的自主联网记录、查手机浏览器历史和私人相册。'
              '\n\n继续导入会清空本机这三类内容，避免把另一段关系的数据混进来；聊天、记忆等旧包已有内容仍会正常恢复。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('了解并继续'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<SnapshotImportResult?> _importPath(
    String path, {
    required bool allowLegacy,
  }) async {
    final metadata = await snapshots.inspectBundle(path, allowLegacy: allowLegacy);
    if (!await _confirmIncompleteArchive(metadata)) {
      _append('已取消导入，不改变本机数据。');
      return null;
    }
    final allowReplace = await _confirmLineageReplacement(metadata);
    if (!allowReplace) {
      _append('已取消导入，不改变本机数据。');
      return null;
    }

    await db.setSetting('transfer_lock', '1');
    await _waitForStateWriters();
    final result = await snapshots.importBundle(
      path,
      allowLineageReplacement: true,
      allowLegacy: allowLegacy,
    );
    if (result.recoveryPending) throw const SnapshotRecoveryRequired();
    if (result.completionWarning.isNotEmpty) _append(result.completionWarning);
    final pending = await db.pendingImportedTransfer();
    if (result.duplicate && pending?.snapshotId != result.metadata.snapshotId) {
      // The same snapshot was successfully imported in the past and this device
      // has already advanced beyond it. Replay is a true no-op.
      await db.setSetting('transfer_lock', '0');
      _append('检测到已经处理过的同一状态包，已忽略重放，没有覆盖当前数据。');
      return result;
    }

    if (!mounted) return result;
    setState(() => importedStandby = true);
    await db.setSetting('active_brain', '0');
    await _syncRemindersSafely();
    await db.setSetting('transfer_lock', '0');
    _append(
      result.metadata.legacy
          ? '旧版状态包已安全导入，本机保持待机；确认旧设备下线后再手动接管。'
          : '状态已导入，本机保持待机；确认源设备已下线后可手动接管。',
    );
    return result;
  }

  Future<void> _forceTakeover() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('确认手动接管'),
            content: const Text(
              '只有在你已经确认另一台设备处于下线/standby 状态时才继续。'
              '\n\n手动接管会创建新的状态代次，使之前导出的旧状态包失效。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('另一台已下线，接管'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      final pending = await db.pendingImportedTransfer();
      final generation = pending != null
          ? await db.activatePendingImportedBrain(expectedSnapshotId: pending.snapshotId)
          : await db.forceLocalBrainTakeover();
      try {
        await _syncRemindersSafely();
          await android.reconcileOverlayAfterTakeover();
      } catch (_) {
        // The database ownership epoch is authoritative; overlay restoration
        // remains best effort.
      }
      if (!mounted) return;
      setState(() {
        importedStandby = false;
      });
      _append('已手动接管，本机现在是第 $generation 代 Active Brain。');
    } catch (e) {
      _append('手动接管失败：$e');
    }
  }

  Future<String?> _askPassphrase({
    required bool confirm,
  }) async {
    if (!mounted) return null;
    final first = TextEditingController();
    final second = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            confirm
                ? '设置手动接管口令'
                : '输入手动接管口令',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: first,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '口令（至少 8 个字符）',
                ),
              ),
              if (confirm) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: second,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '再次输入口令'),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final value = first.text;
                if (value.length < 8 || value.length > 128) {
                  setDialogState(() => error = '口令长度需要 8–128 个字符。');
                  return;
                }
                if (confirm && value != second.text) {
                  setDialogState(() => error = '两次口令不一致。');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('继续'),
            ),
          ],
        ),
      ),
    );
    first.dispose();
    second.dispose();
    return result;
  }

  Future<void> _manualExport() async {
    final passphrase = await _askPassphrase(confirm: true);
    if (passphrase == null || !mounted) return;
    setState(() => busy = true);
    SnapshotBundle? bundle;
    try {
      await db.setSetting('transfer_lock', '1');
      await _waitForStateWriters();
      bundle = await snapshots.exportBundle();
      outboundBundle = bundle;
      final bundleBytes = await File(bundle.filePath).length();
      if (bundleBytes > _maxManualBytes) {
        await _clearSourceSnapshot();
        bundle = null;
        _append(
          '接管包超过 512 MiB，已取消本次接管冻结；本机保持 Active。'
          '请使用“保存备份”，它会保存成一个可直接选择的备份文件。',
        );
        return;
      }
      final saved = await android.saveManualSnapshot(
        sourcePath: bundle.filePath,
        passphrase: passphrase,
        suggestedName: 'ai_companion_gen_${bundle.metadata.sourceGeneration}.aicomp',
      );
      if (!saved) {
        await _clearSourceSnapshot();
        _append('已取消保存手动接管包，本机继续运行。');
        return;
      }
      await db.pauseAfterManualTransferExport(
        snapshotId: bundle.metadata.snapshotId,
        lineageId: bundle.metadata.lineageId,
        generation: bundle.metadata.sourceGeneration,
      );
      await _syncRemindersSafely();
      try {
        await android.suspendOverlayForStandby();
      } catch (_) {
        // The source is already fenced in SQLite. Stopping the visual overlay
        // is best effort and must not reactivate or invalidate the export.
      }
      await _clearSourceSnapshot(
        unlock: false,
        invalidatePending: false,
      );
      if (!mounted) return;
      setState(() => importedStandby = true);
      _append(
        '加密手动接管包已保存。本机已主动进入 standby；把 .aicomp 文件传到目标设备后再导入。',
      );
    } catch (e) {
      if (bundle != null) {
        await _clearSourceSnapshot();
      } else {
        await db.setSetting('transfer_lock', '0');
      }
      _append('手动导出失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _manualImport() async {
    final passphrase = await _askPassphrase(confirm: false);
    if (passphrase == null || !mounted) return;
    setState(() => busy = true);
    String? decryptedPath;
    try {
      decryptedPath = await android.openManualSnapshot(passphrase: passphrase);
      if (decryptedPath == null) {
        _append('已取消选择手动接管包。');
        return;
      }
      final result = await _importPath(
        decryptedPath,
        allowLegacy: true,
      );
      if (result != null && result.imported) {
        _append('加密包与内部状态 SHA-256 校验通过。');
      }
    } catch (e) {
      final active = await db.getSetting('active_brain');
      if (active != '0') await db.setSetting('transfer_lock', '0');
      _append('手动导入失败（口令错误、文件损坏或状态包不兼容）：$e');
    } finally {
      if (decryptedPath != null) await _deleteCachePath(decryptedPath);
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> _confirmBackupRestore(SnapshotMetadata metadata) async {
    if (!mounted) return false;
    final local = await db.transferStateIdentity();
    final sameInstallation = metadata.sourceDeviceId == local.deviceId;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('恢复这份备份？'),
            content: Text(
              '继续会用备份里的聊天、记忆、联网记录、浏览器和私人相册完整替换本机当前关系数据。'
              '\n\n${sameInstallation ? '这是本机创建的备份；恢复成功后本机仍是当前主设备，可以继续正常使用。' : '这份备份来自另一台设备；恢复后本机先保持待机，确认原设备已停用后才能手动接管。'}'
              '\n\n当前本机数据不会与备份自动合并。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认完整替换'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _backupExport() async {
    setState(() => busy = true);
    SnapshotBundle? bundle;
    String? freezeToken;
    try {
      await SnapshotCacheJanitor.clean();
      _append('正在冻结本机写入并等待当前任务安全停下…');
      final acquiredFreeze =
          await db.acquireTransferFreeze(purpose: 'backup_export');
      freezeToken = acquiredFreeze;
      await _waitForStateWriters();
      if (!await db.ownsTransferFreeze(acquiredFreeze)) {
        throw StateError('备份冻结所有权已变化，已拒绝导出不一致状态。');
      }
      _append('正在整理聊天、记忆与媒体并生成备份文件…');
      bundle = await snapshots.exportBackupBundle();
      if (!bundle.metadata.isBackup) {
        throw const FormatException('新备份没有通过内部完整性检查。');
      }
      // Export already hashes every source entry while constructing the ZIP.
      // Android performs the independent portable-ZIP and copy/hash check
      // after the picker. Avoid a redundant full extract/hash pass here: on a
      // large relationship state it delayed the picker without adding a new
      // integrity boundary.
      await db.releaseTransferFreeze(acquiredFreeze);
      freezeToken = null;
      _append('备份已经生成，正在打开系统保存位置…');
      final now = DateTime.now().toUtc();
      final stamp = now.toIso8601String().replaceAll(':', '-').split('.').first;
      final saved = await android.savePlainBackup(
        sourcePath: bundle.filePath,
        suggestedName: 'AI_Companion_Backup_$stamp.aibackup',
      );
      if (saved == null || saved['saved'] != true) {
        _append('已取消保存备份，本机数据没有改变，仍可继续使用。');
        return;
      }
      if (saved['verified'] != true || saved['zipVerified'] != true) {
        throw const FormatException('保存后的备份文件没有通过自动核对。');
      }
      final bytes = (saved['bytes'] as num?)?.toInt() ?? 0;
      _append(
        '备份文件已保存，兼容性与完整性自动检查通过（'
        '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB）。'
        '以后恢复时直接选择这个 .aibackup 文件即可；本机仍可继续正常使用。',
      );
    } catch (e) {
      _append('保存备份失败：$e。本机数据和主设备状态没有改变。');
    } finally {
      if (bundle != null) await _deleteCachePath(bundle.filePath);
      if (freezeToken != null) {
        await db.releaseTransferFreeze(freezeToken);
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _backupImport() => _restoreBackupFromPicker(
        picker: android.openPlainBackup,
        cancelMessage: '已取消选择备份文件。',
      );

  Future<void> _legacyBackupImport() => _restoreBackupFromPicker(
        picker: android.openMultipartBackup,
        cancelMessage: '已取消选择旧版备份文件夹。',
      );

  Future<void> _restoreBackupFromPicker({
    required Future<Map<String, Object?>?> Function() picker,
    required String cancelMessage,
  }) async {
    setState(() => busy = true);
    String? restoredPath;
    String? freezeToken;
    try {
      await SnapshotCacheJanitor.clean();
      final opened = await picker();
      restoredPath = opened?['filePath'] as String?;
      if (restoredPath == null) {
        _append(cancelMessage);
        return;
      }
      final result = await snapshots.restoreBackupBundle(
        restoredPath,
        allowLineageReplacement: true,
        confirmRestore: (metadata) async {
          if (!await _confirmBackupRestore(metadata)) return false;
          if (!await _confirmLineageReplacement(metadata)) return false;
          final acquiredFreeze =
              await db.acquireTransferFreeze(purpose: 'backup_restore');
          freezeToken = acquiredFreeze;
          await _waitForStateWriters();
          if (!await db.ownsTransferFreeze(acquiredFreeze)) {
            throw StateError('恢复冻结所有权已变化，已拒绝替换本机状态。');
          }
          return true;
        },
      );
      if (result == null) {
        if (freezeToken != null) {
          await db.releaseTransferFreeze(freezeToken!);
          freezeToken = null;
        }
        _append('已取消恢复，不改变本机数据。');
        return;
      }
      if (result.recoveryPending) {
        _append(result.completionWarning);
        return;
      }
      if (result.completionWarning.isNotEmpty) _append(result.completionWarning);
      if (result.requiresManualTakeover) {
        if (mounted) setState(() => importedStandby = true);
        _append('备份已恢复并通过校验。这是另一台设备的备份，本机先保持待机；确认原设备已停用后再手动接管。');
      } else {
        try {
          await _syncRemindersSafely();
          await android.reconcileOverlayAfterTakeover();
        } catch (_) {}
        if (mounted) setState(() => importedStandby = false);
        _append('备份已恢复并通过校验。本机仍是当前主设备，可以继续正常使用。');
      }
    } catch (e) {
      _append('恢复备份未完成：$e');
    } finally {
      if (restoredPath != null) await _deleteCachePath(restoredPath);
      if (freezeToken != null) {
        await db.releaseTransferFreeze(freezeToken!);
      }
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('备份与恢复', style: Theme.of(context).textTheme.headlineSmall),
        if (importedStandby) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : _forceTakeover,
            icon: const Icon(Icons.power_settings_new),
            label: const Text('确认另一台已下线，手动接管本机'),
          ),
        ],
        const SizedBox(height: 22),
        const Divider(),
        const SizedBox(height: 10),
        Text('备份', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          '点击保存后会得到一个备份文件，并自动检查是否完整。恢复时直接选择这个文件；不需要口令，也不用处理文件夹或分卷。',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _backupExport,
                icon: const Icon(Icons.save_alt),
                label: const Text('保存备份'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _backupImport,
                icon: const Icon(Icons.restore),
                label: const Text('恢复备份'),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: busy ? null : _legacyBackupImport,
            child: const Text('恢复旧版文件夹备份'),
          ),
        ),
        const SizedBox(height: 22),
        Text('换机与旧接管包', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          '保留旧版 .aicomp 加密接管包的导入和换机功能。导出后本机会进入待机；日常保存进度请使用上方“保存备份”。',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _manualExport,
                icon: const Icon(Icons.phonelink_erase),
                label: const Text('导出加密接管包'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _manualImport,
                icon: const Icon(Icons.phonelink_setup),
                label: const Text('打开加密接管包'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (log != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(log!),
          ),
        const SizedBox(height: 18),
        const Text(
          '恢复另一台设备的备份后，确认旧设备已停用，再将本机设为主设备。待机不会删除本机数据。',
        ),
      ],
    );
  }
}
