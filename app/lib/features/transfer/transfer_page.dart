import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/platform/android_bridge.dart';
import '../../core/sync/snapshot_service.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final db = AppDatabase.instance;
  final android = AndroidBridge.instance;
  late final SnapshotService snapshots = SnapshotService(db);

  StreamSubscription<NearbyEvent>? sub;
  final Map<String, String> endpoints = {};
  SnapshotBundle? outboundBundle;
  SnapshotMetadata? importedMetadata;
  String? connectedEndpoint;
  String? receivedPath;
  String? log;
  bool busy = false;
  bool awaitingTakeoverAck = false;
  bool importedStandby = false;

  @override
  void initState() {
    super.initState();
    sub = android.nearbyEvents.listen(_onNearbyEvent);
    unawaited(_restoreStandbyUiState());
  }

  Future<void> _restoreStandbyUiState() async {
    final active = await db.getSetting('active_brain');
    final pending = await db.pendingImportedTransfer();
    if (!mounted) return;
    if (active == '0') {
      setState(() {
        importedStandby = true;
        if (pending != null) {
          importedMetadata = SnapshotMetadata(
            snapshotId: pending.snapshotId,
            lineageId: pending.lineageId,
            sourceDeviceId: pending.sourceDeviceId,
            sourceGeneration: pending.sourceGeneration,
            targetActivationGeneration: pending.sourceGeneration + 1,
            stateSha256: pending.stateSha256,
            stateBytes: 0,
            schemaVersion: AppDatabase.schemaVersion,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            protocolVersion: 2,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(sub?.cancel() ?? Future<void>.value());
    unawaited(android.stopNearby());
    if (outboundBundle != null || awaitingTakeoverAck) {
      // Leaving the UI cancels transport. If this is the target it remains
      // active_brain=0; if this is the source, stopNearby disconnects the peer
      // and invalidates the unsafely half-finished handoff.
      unawaited(db.setSetting('transfer_lock', '0'));
    }
    final sourcePath = outboundBundle?.filePath;
    final incomingPath = receivedPath;
    if (sourcePath != null) unawaited(_deleteCachePath(sourcePath));
    if (incomingPath != null) unawaited(_deleteCachePath(incomingPath));
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

  Future<void> _clearSourceSnapshot({bool unlock = true}) async {
    final bundle = outboundBundle;
    outboundBundle = null;
    if (bundle != null) await _deleteCachePath(bundle.filePath);
    if (unlock) await db.setSetting('transfer_lock', '0');
  }

  Future<void> _clearReceivedSnapshot() async {
    final path = receivedPath;
    receivedPath = null;
    if (path != null) await _deleteCachePath(path);
  }

  void _append(String text) {
    if (!mounted) return;
    final now = TimeOfDay.now().format(context);
    setState(() => log = '${log ?? ''}${log == null ? '' : '\n'}[$now] $text');
  }

  Future<void> _onNearbyEvent(NearbyEvent event) async {
    if (!mounted) return;
    switch (event.type) {
      case 'endpointFound':
        final id = event.data['endpointId'] as String?;
        final name = event.data['endpointName'] as String? ?? '附近设备';
        if (id != null) setState(() => endpoints[id] = name);
        break;
      case 'endpointLost':
        final id = event.data['endpointId'] as String?;
        if (id != null) setState(() => endpoints.remove(id));
        break;
      case 'connectionInitiated':
        final id = event.data['endpointId'] as String?;
        final name = event.data['endpointName'] as String? ?? '附近设备';
        final code = event.data['verificationCode']?.toString() ?? '无';
        _append('连接验证：$name · $code');
        if (id != null && mounted) {
          final accepted = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('确认附近设备'),
                  content: Text(
                    '请确认两台设备显示相同验证码：\n\n$code\n\n设备：$name',
                    textAlign: TextAlign.center,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('拒绝'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('验证码一致，连接'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (accepted) {
            await android.acceptNearbyConnection(id);
          } else {
            await android.rejectNearbyConnection(id);
          }
        }
        break;
      case 'connected':
        final id = event.data['endpointId'] as String?;
        if (id != null) {
          connectedEndpoint = id;
          _append('已连接 ${event.data['endpointName'] ?? id}');
          final bundle = outboundBundle;
          if (bundle != null) {
            final meta = bundle.metadata;
            await android.sendNearbyFile(
              endpointId: id,
              filePath: bundle.filePath,
              snapshotId: meta.snapshotId,
              lineageId: meta.lineageId,
              sourceDeviceId: meta.sourceDeviceId,
              sourceGeneration: meta.sourceGeneration,
              stateSha256: meta.stateSha256,
            );
            _append('开始发送第 ${meta.sourceGeneration} 代状态包');
          }
        }
        break;
      case 'connectionFailed':
        if (outboundBundle != null) {
          await _clearSourceSnapshot();
          if (mounted) setState(() {});
        }
        _append('连接失败：${event.data['status'] ?? ''}。请重新生成状态包后再试。');
        break;
      case 'sendComplete':
        _append('状态包发送完成，等待目标设备校验和导入');
        break;
      case 'fileReceived':
        final path = event.data['filePath'] as String?;
        final id = event.data['endpointId'] as String?;
        if (id != null) connectedEndpoint = id;
        if (path != null) {
          setState(() => receivedPath = path);
          _append('收到状态包，可校验后导入到本机');
        }
        break;
      case 'transferFailed':
        if (outboundBundle != null) {
          await _clearSourceSnapshot();
          if (mounted) setState(() {});
        }
        _append('传输失败：${event.data['status'] ?? ''}。本次包已作废，请重新生成。');
        break;
      case 'takeoverConfirmed':
        if (awaitingTakeoverAck) {
          final snapshotId = event.data['snapshotId'] as String? ?? '';
          final expectedActivation = (event.data['targetActivationGeneration'] as num?)?.toInt();
          try {
            final activatedGeneration = await db.activatePendingImportedBrain(
              expectedSnapshotId: snapshotId,
            );
            if (expectedActivation != null && expectedActivation != activatedGeneration) {
              throw StateError('ACK 目标代次与数据库激活代次不一致。');
            }
            try {
              await android.reconcileOverlayAfterTakeover();
            } catch (_) {
              // Ownership is already committed. Overlay restoration is best
              // effort and must never undo a successful Active Brain takeover.
            }
            await _clearReceivedSnapshot();
            if (!mounted) return;
            setState(() {
              awaitingTakeoverAck = false;
              importedStandby = false;
              importedMetadata = null;
            });
            _append('旧设备已确认下线，本机成为第 $activatedGeneration 代 Active Brain。');
          } catch (e) {
            await db.setSetting('active_brain', '0');
            await db.setSetting('transfer_lock', '0');
            if (!mounted) return;
            setState(() {
              awaitingTakeoverAck = false;
              importedStandby = true;
            });
            _append('收到 ACK，但本机状态身份校验失败：$e。本机继续待机。');
          }
        }
        break;
      case 'takeoverAckFailed':
        if (awaitingTakeoverAck) {
          await db.setSetting('active_brain', '0');
          await db.setSetting('transfer_lock', '0');
          if (!mounted) return;
          setState(() {
            awaitingTakeoverAck = false;
            importedStandby = true;
          });
          _append('接管确认没有可靠送达，本机保持待机，避免双 Active Brain。');
        } else {
          // Source-side ACK send failure occurs only after NativeEventStore has
          // atomically fenced this source. Never reactivate it automatically.
          await db.setSetting('active_brain', '0');
          await db.setSetting('transfer_lock', '0');
          if (mounted) setState(() => importedStandby = true);
          _append('确认回执发送失败；本机已经安全下线。确认另一台状态后再决定是否手动恢复。');
        }
        break;
      case 'takeoverRejected':
        final reason = event.data['reason'] ?? 'metadata_mismatch';
        if (awaitingTakeoverAck) {
          await db.setSetting('active_brain', '0');
          await db.setSetting('transfer_lock', '0');
          if (!mounted) return;
          setState(() {
            awaitingTakeoverAck = false;
            importedStandby = true;
          });
        } else if (outboundBundle != null) {
          await _clearSourceSnapshot();
          if (mounted) setState(() {});
        }
        _append('接管协议拒绝了不匹配的会话：$reason。没有改变 Active Brain 所有权。');
        break;
      case 'remoteTookOver':
        // NativeEventStore already fenced the exact source snapshot generation
        // atomically before this event is emitted.
        await _clearSourceSnapshot(unlock: false);
        if (!mounted) return;
        setState(() {
          importedStandby = true;
          awaitingTakeoverAck = false;
        });
        _append('另一台设备已用本次状态包接管，本机已经下线；本地数据仍完整保留。');
        break;
      case 'disconnected':
        connectedEndpoint = null;
        if (outboundBundle != null) {
          await _clearSourceSnapshot();
          if (mounted) setState(() {});
        }
        if (awaitingTakeoverAck) {
          await db.setSetting('active_brain', '0');
          await db.setSetting('transfer_lock', '0');
          if (!mounted) return;
          setState(() {
            awaitingTakeoverAck = false;
            importedStandby = true;
          });
        } else if (receivedPath != null && !importedStandby) {
          await _clearReceivedSnapshot();
          if (mounted) setState(() {});
        }
        _append('附近设备连接已断开。未完成状态包自动失效；已导入状态仍保持 standby。');
        break;
      default:
        _append('Nearby: ${event.type}');
    }
  }

  Future<void> _prepareAndDiscover() async {
    await _clearSourceSnapshot();
    await _clearReceivedSnapshot();
    if (!mounted) return;
    setState(() {
      busy = true;
      endpoints.clear();
      log = null;
      receivedPath = null;
    });
    try {
      final ok = await android.requestNearbyPermissions();
      if (!ok) {
        _append('附近设备权限未完整授予');
        return;
      }
      await db.setSetting('transfer_lock', '1');
      await _waitForStateWriters();
      final bundle = await snapshots.exportBundle();
      outboundBundle = bundle;
      _append(
        '状态包已冻结：第 ${bundle.metadata.sourceGeneration} 代 · '
        'SHA-256 ${bundle.sha256Hex.substring(0, 12)}…',
      );
      await android.startNearbyDiscovery();
      _append('正在搜索附近接收设备…');
    } catch (e) {
      await db.setSetting('transfer_lock', '0');
      _append('发送准备失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _waitForStateWriters() async {
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    const keys = <String>[
      'chat_turn_lease',
      'recovery_orchestrator_lease_until',
      'post_turn_memory_lease',
      'proactive_lease_until',
      'relationship_assimilation_lease_until',
      'deferred_followup_lease_until',
      'self_drive_lease_until',
      'thought_lifecycle_lease_until',
      'memory_maintenance_lease_until',
      'thought_consolidation_lease_until',
      'ai_self_reflection_lease_until',
      'conversation_summary_lease_until',
      'long_running_maintenance_lease',
    ];
    while (DateTime.now().isBefore(deadline)) {
      var held = false;
      for (final key in keys) {
        if (await db.isLocalLeaseHeld(key)) {
          held = true;
          break;
        }
      }
      if (!held) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw StateError('当前仍有聊天、记忆或后台整理正在写入，请等这一轮完成后重新发送状态包。');
  }

  Future<void> _receive() async {
    await _clearSourceSnapshot();
    await _clearReceivedSnapshot();
    if (!mounted) return;
    setState(() {
      busy = true;
      log = null;
      receivedPath = null;
    });
    try {
      final ok = await android.requestNearbyPermissions();
      if (!ok) {
        _append('附近设备权限未完整授予');
        return;
      }
      await android.startNearbyReceive();
      _append('本机正在等待另一台设备发送状态包…');
    } catch (e) {
      _append('接收启动失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
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

  Future<SnapshotImportResult?> _importPath(
    String path, {
    required bool allowLegacy,
    required bool nearbyTakeover,
  }) async {
    final metadata = await snapshots.inspectBundle(path, allowLegacy: allowLegacy);
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
    importedMetadata = result.metadata;
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
    if (nearbyTakeover && !result.metadata.legacy && connectedEndpoint != null) {
      await _beginTakeoverHandshake(result.metadata);
    } else {
      await db.setSetting('active_brain', '0');
      await db.setSetting('transfer_lock', '0');
      _append(
        result.metadata.legacy
            ? '旧版状态包已安全导入，本机保持待机；确认旧设备下线后再手动接管。'
            : '状态已导入，本机保持待机；确认源设备已下线后可手动接管。',
      );
    }
    return result;
  }

  Future<void> _importReceived() async {
    final path = receivedPath;
    if (path == null) return;
    setState(() => busy = true);
    var waitingForAck = false;
    try {
      final result = await _importPath(
        path,
        allowLegacy: false,
        nearbyTakeover: true,
      );
      if (result == null) return;
      waitingForAck = awaitingTakeoverAck;
      await _clearReceivedSnapshot();
      if (result.imported) {
        _append('状态包身份、代次、大小与 SHA-256 均校验通过。');
      }
    } catch (e) {
      final active = await db.getSetting('active_brain');
      if (active == '0') {
        await db.setSetting('transfer_lock', '0');
        if (mounted) setState(() => importedStandby = true);
        _append('导入/接管没有完成：$e。本机保持待机。');
      } else {
        await db.setSetting('transfer_lock', '0');
        _append('导入失败：$e；本机原数据未被半覆盖。');
      }
    } finally {
      if (!waitingForAck && !awaitingTakeoverAck) {
        final active = await db.getSetting('active_brain');
        if (active != '0') await db.setSetting('transfer_lock', '0');
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _beginTakeoverHandshake(SnapshotMetadata metadata) async {
    final endpoint = connectedEndpoint;
    if (endpoint == null) {
      await db.setSetting('active_brain', '0');
      await db.setSetting('transfer_lock', '0');
      if (mounted) setState(() => importedStandby = true);
      _append('状态已导入，但连接已经断开，本机保持待机。');
      return;
    }
    final targetDeviceId = await db.ensureDeviceId();
    if (!mounted) return;
    setState(() {
      awaitingTakeoverAck = true;
      importedStandby = true;
    });
    await android.confirmNearbyTakeover(
      endpointId: endpoint,
      snapshotId: metadata.snapshotId,
      lineageId: metadata.lineageId,
      sourceDeviceId: metadata.sourceDeviceId,
      sourceGeneration: metadata.sourceGeneration,
      stateSha256: metadata.stateSha256,
      targetDeviceId: targetDeviceId,
      targetActivationGeneration: metadata.targetActivationGeneration,
    );
    unawaited(_takeoverAckTimeout(metadata.snapshotId));
    _append('状态已导入，正在等待旧设备对本次状态包进行绑定确认…');
  }

  Future<void> _takeoverAckTimeout(String snapshotId) async {
    await Future<void>.delayed(const Duration(seconds: 12));
    if (!mounted || !awaitingTakeoverAck) return;
    final pending = await db.pendingImportedTransfer();
    if (pending?.snapshotId != snapshotId) return;
    await db.setSetting('active_brain', '0');
    await db.setSetting('transfer_lock', '0');
    if (!mounted || !awaitingTakeoverAck) return;
    setState(() {
      awaitingTakeoverAck = false;
      importedStandby = true;
    });
    _append('等待绑定 ACK 超时。本机保持待机；不会根据迟到的旧 ACK 自动上线。');
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
        await android.reconcileOverlayAfterTakeover();
      } catch (_) {
        // The database ownership epoch is authoritative; overlay restoration
        // remains best effort.
      }
      if (!mounted) return;
      setState(() {
        awaitingTakeoverAck = false;
        importedStandby = false;
        importedMetadata = null;
      });
      _append('已手动接管，本机现在是第 $generation 代 Active Brain。');
    } catch (e) {
      _append('手动接管失败：$e');
    }
  }

  Future<String?> _askPassphrase({required bool confirm}) async {
    if (!mounted) return null;
    final first = TextEditingController();
    final second = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(confirm ? '设置手动接管口令' : '输入手动接管口令'),
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
      try {
        await android.suspendOverlayForStandby();
      } catch (_) {
        // The source is already fenced in SQLite. Stopping the visual overlay
        // is best effort and must not reactivate or invalidate the export.
      }
      await _clearSourceSnapshot(unlock: false);
      if (!mounted) return;
      setState(() => importedStandby = true);
      _append(
        '加密手动接管包已保存。本机已主动进入 standby；把 .aicomp 文件传到目标设备后再导入。',
      );
    } catch (e) {
      await db.setSetting('transfer_lock', '0');
      if (bundle != null) await _clearSourceSnapshot(unlock: false);
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
        nearbyTakeover: false,
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('手机 ↔ 平板 · 同一个她', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          '正常使用采用 Nearby 本地直传 + 单 Active Brain。状态包带关系谱系、单调代次、会话 ID 与 SHA-256；只有旧设备确认同一包后，新设备才会上线。',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: busy || awaitingTakeoverAck ? null : _prepareAndDiscover,
                icon: const Icon(Icons.upload_rounded),
                label: const Text('从本机发送'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || awaitingTakeoverAck ? null : _receive,
                icon: const Icon(Icons.download_rounded),
                label: const Text('本机接收'),
              ),
            ),
          ],
        ),
        if (endpoints.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('发现的设备', style: Theme.of(context).textTheme.titleMedium),
          ...endpoints.entries.map((entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.devices),
                title: Text(entry.value),
                subtitle: Text(entry.key),
                trailing: FilledButton(
                  onPressed: () async {
                    _append('请求连接 ${entry.value}…');
                    await android.connectNearby(entry.key);
                  },
                  child: const Text('连接'),
                ),
              )),
        ],
        if (receivedPath != null) ...[
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: busy || awaitingTakeoverAck ? null : _importReceived,
            icon: const Icon(Icons.restore),
            label: Text(awaitingTakeoverAck ? '等待旧设备绑定确认…' : '校验、导入并接管'),
          ),
        ],
        if (importedStandby && !awaitingTakeoverAck) ...[
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
        Text('手动备用', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          '仅在 Nearby 实机不可靠时使用。文件使用口令派生密钥 + AES-256-GCM 加密；口令不会保存。手动导出成功后源设备会先进入 standby。',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || awaitingTakeoverAck ? null : _manualExport,
                icon: const Icon(Icons.lock_outline),
                label: const Text('导出加密接管包'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || awaitingTakeoverAck ? null : _manualImport,
                icon: const Icon(Icons.folder_open),
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
          '安全边界：旧状态包、重复投递、损坏/截断文件、错会话 ACK 都不能激活本机。被挤下线的设备只改变 Active Brain 身份，不删除它本地保存的数据。',
        ),
      ],
    );
  }
}
