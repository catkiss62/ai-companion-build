import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../desire/desire_core_policy.dart';
import '../grounding/grounding_engine.dart';
import '../models/desire_state.dart';
import '../models/thought.dart';
import '../platform/android_bridge.dart';
import '../tts/tts_service.dart';
import '../tts/tts_provider.dart';

class PreflightCheck {
  const PreflightCheck({
    required this.id,
    required this.title,
    required this.level,
    required this.summary,
  });

  final String id;
  final String title;
  final String level; // pass / warn / fail / info
  final String summary;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'level': level,
        'summary': summary,
      };
}

class PreflightSnapshot {
  const PreflightSnapshot({
    required this.createdAt,
    required this.deep,
    required this.checks,
    required this.report,
  });

  final DateTime createdAt;
  final bool deep;
  final List<PreflightCheck> checks;
  final Map<String, Object?> report;

  int get failures => checks.where((e) => e.level == 'fail').length;
  int get warnings => checks.where((e) => e.level == 'warn').length;
  bool get readyForDeviceCheckpoint => failures == 0;
}

/// Builds a local-only, redacted device-readiness report.
///
/// Privacy invariant: this service never queries message bodies, Thought bodies, memories,
/// RelationshipEvent content, Reference text, notification/accessibility raw
/// text or API credentials. Device/lineage/snapshot identities are emitted only
/// as short SHA-256 fingerprints.
class PreflightDiagnosticsService {
  PreflightDiagnosticsService({
    AppDatabase? db,
    AndroidBridge? android,
    TtsService? tts,
  })  : db = db ?? AppDatabase.instance,
        android = android ?? AndroidBridge.instance,
        tts = tts ?? TtsService();

  final AppDatabase db;
  final AndroidBridge android;
  final TtsService tts;

  Future<PreflightSnapshot> run({bool deep = false}) async {
    final now = DateTime.now();
    final checks = <PreflightCheck>[];
    final report = <String, Object?>{
      'format': 'ai-companion-redacted-preflight-v1',
      'createdAt': now.toUtc().toIso8601String(),
      'deep': deep,
      'privacy': {
        'relationshipPlaintextIncluded': false,
        'messageBodiesIncluded': false,
        'rawNotificationTextIncluded': false,
        'rawAccessibilityTextIncluded': false,
        'apiSecretsIncluded': false,
        'fullOwnershipIdsIncluded': false,
      },
    };

    try {
      await db.ensureReady();
      final identity = await db.transferStateIdentity();
      final active = (await db.getSetting('active_brain')) != '0';
      final transferLock = (await db.getSetting('transfer_lock')) == '1';
      final pendingImport = await db.pendingImportedTransfer();
      final pendingOutboundId = await db.getSetting('pending_outbound_snapshot_id') ?? '';
      final pendingOutboundGeneration =
          int.tryParse(await db.getSetting('pending_outbound_generation') ?? '') ?? 0;
      final lastTakeoverAt = int.tryParse(await db.getSetting('last_takeover_at') ?? '') ?? 0;
      final jobs = await db.postTurnJobStats();
      final memoryStats = await db.memoryStats();
      final generationJob = await db.blockingGenerationJob();
      final failedGeneration = await db.failedGenerationNeedingAttention();
      final grounding = await GroundingEngine(db).capture(now: now);
      final desireSnapshot = await db.loadDesire();
      final desireThoughts = await db.activeThoughtMetadata(limit: 40);
      final desireCandidates = DesireCorePolicy.candidates(
        drives: desireSnapshot.drives,
        refractoryUntil: desireSnapshot.refractoryUntil,
        thoughts: desireThoughts,
        now: now,
      );
      final provenanceCounts = <String, int>{};
      for (final thought in desireThoughts) {
        final key = thought.provenance.key;
        provenanceCounts[key] = (provenanceCounts[key] ?? 0) + 1;
      }
      final refractoryMinutes = <String, int>{};
      for (final entry in desireSnapshot.refractoryUntil.entries) {
        if (!entry.value.isAfter(now)) continue;
        refractoryMinutes[entry.key.name] = entry.value.difference(now).inMinutes;
      }

      report['database'] = {
        'schemaVersion': AppDatabase.schemaVersion,
        'deviceFp': _fingerprint(identity.deviceId),
        'lineageFp': _fingerprint(identity.lineageId),
        'stateGeneration': identity.generation,
        'activeBrain': active,
        'transferLock': transferLock,
        'pendingOutbound': pendingOutboundId.isEmpty
            ? null
            : {
                'snapshotFp': _fingerprint(pendingOutboundId),
                'generation': pendingOutboundGeneration,
              },
        'pendingImport': pendingImport == null
            ? null
            : {
                'snapshotFp': _fingerprint(pendingImport.snapshotId),
                'lineageFp': _fingerprint(pendingImport.lineageId),
                'sourceDeviceFp': _fingerprint(pendingImport.sourceDeviceId),
                'generation': pendingImport.sourceGeneration,
                'stateHashFp': _fingerprint(pendingImport.stateSha256),
              },
        'lastTakeoverAt': lastTakeoverAt,
        'postTurnJobs': jobs,
        'blockingGenerationStatus': generationJob?.status ?? 'none',
        'failedGenerationNeedsAttention': failedGeneration != null,
        'recordCounts': memoryStats,
        'errorFlags': {
          'backgroundErrorCount':
              int.tryParse(await db.getSetting('background_error_count') ?? '') ?? 0,
          'hasBackgroundError': (await db.getSetting('last_background_error') ?? '').isNotEmpty,
          'hasGenerationRecoveryError':
              (await db.getSetting('last_generation_recovery_error') ?? '').isNotEmpty,
          'hasAsyncWorkerError': (await db.getSetting('last_async_worker_error') ?? '').isNotEmpty,
          'hasMaintenanceError':
              (await db.getSetting('last_long_running_maintenance_error') ?? '').isNotEmpty,
          'hasDailyContinuityError':
              (await db.getSetting('last_daily_continuity_error') ?? '').isNotEmpty,
          'hasTtsError': (await db.getSetting('last_tts_error') ?? '').isNotEmpty,
        },
        'recovery': {
          'state': await db.getSetting('recovery_orchestrator_state') ?? 'never',
          'cycleCount': int.tryParse(
                await db.getSetting('recovery_orchestrator_cycle_count') ?? '',
              ) ??
              0,
          'hasLastError':
              (await db.getSetting('recovery_orchestrator_last_error') ?? '').isNotEmpty,
        },
        'grounding': {
          ...grounding.toRedactedJson(),
          'proactiveGuardBlockCount': int.tryParse(
                await db.getSetting('grounding_guard_block_count') ?? '',
              ) ??
              0,
          'proactiveGuardLastAt': int.tryParse(
                await db.getSetting('grounding_guard_last_at') ?? '',
              ) ??
              0,
          'proactiveGuardLastReason':
              await db.getSetting('grounding_guard_last_reason') ?? '',
          'proactiveGroundingRetryCount': int.tryParse(
                await db.getSetting('grounding_retry_count') ?? '',
              ) ??
              0,
          'proactiveGroundingRetryLastAt': int.tryParse(
                await db.getSetting('grounding_retry_last_at') ?? '',
              ) ??
              0,
          'proactiveGroundingRetryLastReason':
              await db.getSetting('grounding_retry_last_reason') ?? '',
        },
        'companionVoice': {
          'enabled': (await db.getSetting('companion_voice_enabled')) == '1',
          'retryCount': int.tryParse(
                await db.getSetting('companion_voice_retry_count') ?? '',
              ) ??
              0,
          'retryLastAt': int.tryParse(
                await db.getSetting('companion_voice_retry_last_at') ?? '',
              ) ??
              0,
          'retryLastReason':
              await db.getSetting('companion_voice_retry_last_reason') ?? '',
          'blockCount': int.tryParse(
                await db.getSetting('companion_voice_block_count') ?? '',
              ) ??
              0,
          'blockLastAt': int.tryParse(
                await db.getSetting('companion_voice_block_last_at') ?? '',
              ) ??
              0,
          'blockLastReason':
              await db.getSetting('companion_voice_block_last_reason') ?? '',
        },
        'desireCore': {
          'drives': {
            for (final entry in desireSnapshot.drives.entries)
              entry.key.name: double.parse(entry.value.toStringAsFixed(4)),
          },
          'baselines': {
            for (final entry in desireSnapshot.baselines.entries)
              entry.key.name: double.parse(entry.value.toStringAsFixed(4)),
          },
          'refractoryMinutes': refractoryMinutes,
          'lastIntent': desireSnapshot.lastIntent ?? '',
          'lastIntentDrive': desireSnapshot.lastIntentDrive ?? '',
          'lastIntentScore': desireSnapshot.lastIntentScore == null
              ? null
              : double.parse(desireSnapshot.lastIntentScore!.toStringAsFixed(4)),
          'lastSatisfiedAction': desireSnapshot.lastSatisfiedAction ?? '',
          'lastSatisfiedAt': desireSnapshot.lastSatisfiedAt?.millisecondsSinceEpoch ?? 0,
          'fatigueGateActive':
              (desireSnapshot.drives.values.isEmpty ? 0.0 : desireSnapshot.drives[DriveKey.fatigue] ?? 0.0) >=
                  DesireCorePolicy.fatigueRestGate,
          'selected': desireCandidates.isEmpty
              ? null
              : {
                  'drive': desireCandidates.first.drive.name,
                  'action': desireCandidates.first.action,
                  'score': double.parse(desireCandidates.first.score.toStringAsFixed(4)),
                  'reasonSource': ThoughtProvenancePolicy
                      .fromSource(desireCandidates.first.reasonSource)
                      .key,
                  'hasThought': desireCandidates.first.thoughtId != null,
                },
          'topCandidates': desireCandidates.take(4).map((candidate) => {
                'drive': candidate.drive.name,
                'action': candidate.action,
                'score': double.parse(candidate.score.toStringAsFixed(4)),
                'hasThought': candidate.thoughtId != null,
              }).toList(),
          'activeThoughtCount': desireThoughts.length,
          'thoughtProvenanceCounts': provenanceCounts,
        },
        'backgroundPresence': {
          'lastWakeReason':
              await db.getSetting('recovery_orchestrator_last_wake_reason') ?? '',
          'lastProactiveReason':
              await db.getSetting('recovery_orchestrator_last_proactive_reason') ?? '',
          'lastPerceptionAt': int.tryParse(
                await db.getSetting('last_perception_capture_at') ?? '',
              ) ??
              0,
          'nextHeartbeatAt': int.tryParse(
                await db.getSetting('recovery_orchestrator_next_heartbeat_at') ?? '',
              ) ??
              0,
          'presenceMomentum': double.tryParse(
                await db.getSetting('presence_momentum_score') ?? '',
              ) ??
              0.0,
          'presenceSignalClass':
              await db.getSetting('presence_last_signal_class') ?? '',
          'presenceLastThoughtAt': int.tryParse(
                await db.getSetting('presence_last_thought_at') ?? '',
              ) ??
              0,
          'presenceLastThoughtStrength': double.tryParse(
                await db.getSetting('presence_last_thought_strength') ?? '',
              ) ??
              0.0,
          'lastGateBreakdown': _safeJsonObject(
            await db.getSetting('presence_last_gate_breakdown') ?? '',
          ),
        },
      };
      checks.add(const PreflightCheck(
        id: 'database',
        title: '本地数据库',
        level: 'pass',
        summary: '数据库可打开，身份与 schema 可读取。',
      ));
      if (transferLock) {
        final expected = pendingImport != null || pendingOutboundId.isNotEmpty;
        checks.add(PreflightCheck(
          id: 'transfer_lock',
          title: '设备接管锁',
          level: expected ? 'warn' : 'fail',
          summary: expected
              ? '当前有未完成的接管会话，写入已冻结。'
              : 'transfer_lock=1 但没有对应 pending snapshot，需要恢复检查。',
        ));
      } else if (pendingImport != null) {
        checks.add(const PreflightCheck(
          id: 'pending_import',
          title: '待接管状态',
          level: 'warn',
          summary: '存在已导入但尚未激活的状态包，本机应保持 standby。',
        ));
      } else {
        checks.add(PreflightCheck(
          id: 'ownership',
          title: 'Active Brain',
          level: active ? 'pass' : 'info',
          summary: active ? '本机是当前 Active Brain。' : '本机当前是 standby。',
        ));
      }
    } catch (_) {
      report['database'] = {'available': false};
      checks.add(const PreflightCheck(
        id: 'database',
        title: '本地数据库',
        level: 'fail',
        summary: '数据库或 ownership 状态无法读取。',
      ));
    }

    try {
      final native = _normalizeMap(await android.preflightStatus());
      report['native'] = native;
      final capabilities = _asMap(native['capabilities']);
      final nearby = _asMap(native['nearby']);
      final androidInfo = _asMap(native['android']);
      final audio = _asMap(native['audio']);
      report['overlayTouch'] = {
        'bubbleAttached': capabilities['overlayBubbleAttached'] == true,
        'bubbleTouchable': capabilities['overlayBubbleTouchable'] == true,
        'positionSafe': capabilities['overlayPositionSafe'] == true,
        'chatWindowAttached': capabilities['overlayChatWindowAttached'] == true,
        'chatExpanded': capabilities['overlayChatExpanded'] == true,
        'lastTouchAt': capabilities['overlayLastTouchAt'] ?? 0,
        'lastTouchAction': capabilities['overlayLastTouchAction'] ?? '',
        'lastSelfHealAt': capabilities['overlayLastSelfHealAt'] ?? 0,
        'lastSelfHealReason': capabilities['overlayLastSelfHealReason'] ?? '',
        'selfHealCount': capabilities['overlaySelfHealCount'] ?? 0,
        'inputSuspect': capabilities['overlayInputSuspect'] == true,
        'lastSystemCoverAt': capabilities['overlayLastSystemCoverAt'] ?? 0,
        'lastSystemCoverReason': capabilities['overlayLastSystemCoverReason'] ?? '',
        'lastCoverRecoveryAt': capabilities['overlayLastCoverRecoveryAt'] ?? 0,
        'windowVisibility': capabilities['overlayLastWindowVisibility'] ?? 0,
        'recoveryInProgress': capabilities['overlayRecoveryInProgress'] == true,
        'coverRecoveryCount': capabilities['overlayCoverRecoveryCount'] ?? 0,
      };

      _addPermissionCheck(checks, 'overlay', '悬浮窗权限', capabilities['overlay'] == true);
      _addPermissionCheck(checks, 'usage', '使用情况访问', capabilities['usage'] == true);
      _addPermissionCheck(
        checks,
        'notification_listener',
        '通知访问',
        capabilities['notificationListener'] == true,
      );
      _addPermissionCheck(
        checks,
        'accessibility',
        'Accessibility 轻视觉',
        capabilities['accessibility'] == true,
      );
      _addPermissionCheck(
        checks,
        'post_notifications',
        '发送通知',
        capabilities['postNotifications'] == true,
      );

      final overlayEnabled = capabilities['overlayUserEnabled'] == true;
      final overlayRunning = capabilities['overlayRunning'] == true;
      final backgroundReady = capabilities['backgroundBrainReady'] == true;
      checks.add(PreflightCheck(
        id: 'background_brain',
        title: '后台大脑连接',
        level: !overlayEnabled
            ? 'info'
            : overlayRunning && backgroundReady
                ? 'pass'
                : 'warn',
        summary: !overlayEnabled
            ? '悬浮陪伴未启用，本轮不要求后台 FlutterEngine 常驻。'
            : overlayRunning && backgroundReady
                ? '常驻服务与后台 Dart 命令通道均已就绪。'
                : '悬浮服务已启用，但后台 Dart 命令通道尚未就绪或正在恢复。',
      ));

      final bubbleAttached = capabilities['overlayBubbleAttached'] == true;
      final bubbleTouchable = capabilities['overlayBubbleTouchable'] == true;
      final bubblePositionSafe = capabilities['overlayPositionSafe'] == true;
      final chatWindowAttached = capabilities['overlayChatWindowAttached'] == true;
      final chatExpanded = capabilities['overlayChatExpanded'] == true;
      checks.add(PreflightCheck(
        id: 'overlay_touch',
        title: '悬浮球触摸健康',
        level: !overlayEnabled
            ? 'info'
            : bubbleAttached && bubbleTouchable && bubblePositionSafe &&
                    (!chatWindowAttached || chatExpanded)
                ? 'pass'
                : 'warn',
        summary: !overlayEnabled
            ? '悬浮陪伴未启用，本轮不检查触摸窗口。'
            : bubbleAttached && bubbleTouchable && bubblePositionSafe &&
                    (!chatWindowAttached || chatExpanded)
                ? '悬浮球窗口已附着、可触摸且位于系统安全区域。'
                : '悬浮球存在输入通道、坐标或隐藏聊天窗口异常；服务会尝试自动恢复。',
      ));

      final nearbyPermission = nearby['permissionsGranted'] == true;
      final playServices = nearby['googlePlayServicesAvailable'] == true;
      final bluetooth = nearby['bluetoothEnabled'] == true;
      checks.add(PreflightCheck(
        id: 'nearby',
        title: '手机 / 平板 Nearby',
        level: nearbyPermission && playServices && bluetooth ? 'pass' : 'warn',
        summary: nearbyPermission && playServices && bluetooth
            ? 'Nearby 所需权限、Google Play services 与蓝牙条件可用。'
            : 'Nearby 条件未完全满足；深度真机接管前需要处理。',
      ));

      final backgroundRestricted = androidInfo['backgroundRestricted'] == true;
      final batteryIgnored = androidInfo['batteryOptimizationIgnored'] == true;
      checks.add(PreflightCheck(
        id: 'background',
        title: 'Android 后台条件',
        level: backgroundRestricted ? 'warn' : 'pass',
        summary: backgroundRestricted
            ? '系统报告 App 处于后台受限状态。'
            : batteryIgnored
                ? '未发现后台限制，且已忽略电池优化。'
                : '未发现后台限制；电池优化仍可能由厂商系统影响长期保活。',
      ));

      final outputs = (audio['outputDevices'] as List?) ?? const [];
      final audioMode = (audio['mode'] as num?)?.toInt() ?? 0;
      checks.add(PreflightCheck(
        id: 'audio_route',
        title: 'Android 音频输出',
        level: outputs.isEmpty || audioMode != 0 ? 'warn' : 'pass',
        summary: outputs.isEmpty
            ? '没有读取到可用输出设备。'
            : audioMode != 0
                ? '当前 Android 音频模式不是普通模式，来电/通话可能影响 TTS。'
                : '已读取到本机音频输出路由。',
      ));
    } catch (_) {
      report['native'] = {'available': false};
      checks.add(const PreflightCheck(
        id: 'android_bridge',
        title: 'Android 原生桥',
        level: 'fail',
        summary: '无法读取 Android preflight 状态。',
      ));
    }

    try {
      TtsStatus status = await tts.status();
      if (deep) {
        status = await tts.verifyArtifacts();
        if (status.integrityVerified) status = await tts.initialize();
      }
      report['tts'] = {
        'available': status.available,
        'initialized': status.initialized,
        'engine': status.engine,
        'integrity': status.integrity,
        'artifactCount': status.artifactCount,
        'goldenReference': status.goldenReference,
        'diagnosticStage': status.diagnosticStage,
        'diagnosticTrace': status.diagnosticTrace,
        // Detail is intentionally omitted from export: native errors are kept
        // in the redacted RuntimeDiagnosticStore instead.
      };
      final ok = status.available && (!deep || (status.integrityVerified && status.initialized));
      checks.add(PreflightCheck(
        id: 'tts',
        title: deep ? 'TTS 黄金资源 + JNI/MNN' : 'TTS 本地核心',
        level: ok ? 'pass' : 'fail',
        summary: deep
            ? ok
                ? '37 项黄金负载校验通过，JNI/MNN 初始化成功；本次未播放声音。'
                : '黄金校验或 JNI/MNN 初始化未通过。'
            : status.available
                ? 'TTS 核心资源存在；深度自检时再执行黄金校验与初始化。'
                : 'TTS 核心资源不可用。',
      ));
    } catch (_) {
      report['tts'] = {'available': false, 'deepAttempted': deep};
      checks.add(PreflightCheck(
        id: 'tts',
        title: 'TTS 本地核心',
        level: 'fail',
        summary: deep ? '深度 TTS 自检发生异常。' : 'TTS 状态无法读取。',
      ));
    }

    try {
      final events = await android.runtimeDiagnostics(limit: 120);
      report['runtimeDiagnostics'] = events.map(_normalizeMap).toList();
      final errors = events.where((e) => e['severity'] == 'error').length;
      checks.add(PreflightCheck(
        id: 'runtime_history',
        title: '本机运行诊断历史',
        level: errors == 0 ? 'pass' : 'warn',
        summary: errors == 0
            ? '最近的脱敏 Native 诊断中没有 error。'
            : '最近脱敏 Native 诊断中有 $errors 条 error，可随报告导出定位。',
      ));
    } catch (_) {
      report['runtimeDiagnostics'] = const [];
    }

    report['checks'] = checks.map((e) => e.toJson()).toList();
    return PreflightSnapshot(
      createdAt: now,
      deep: deep,
      checks: checks,
      report: report,
    );
  }

  Future<bool> export(PreflightSnapshot snapshot) async {
    final temp = await getTemporaryDirectory();
    final stamp = snapshot.createdAt
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File(p.join(temp.path, 'ai_companion_diagnostics_$stamp.txt'));
    final encoder = const JsonEncoder.withIndent('  ');
    final text = StringBuffer()
      ..writeln('AI Companion v0.31.2+43 · REDACTED LOCAL DIAGNOSTIC REPORT')
      ..writeln('This report intentionally excludes relationship/chat/reference plaintext and API secrets.')
      ..writeln()
      ..writeln(encoder.convert(snapshot.report));
    await file.writeAsString(text.toString(), flush: true);
    try {
      return await android.saveDiagnosticReport(
        sourcePath: file.path,
        suggestedName: 'ai_companion_diagnostics_$stamp.txt',
      );
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<void> clearNativeHistory() => android.clearRuntimeDiagnostics();

  void _addPermissionCheck(
    List<PreflightCheck> checks,
    String id,
    String title,
    bool enabled,
  ) {
    checks.add(PreflightCheck(
      id: id,
      title: title,
      level: enabled ? 'pass' : 'warn',
      summary: enabled ? '已授权。' : '尚未授权；相关能力在真机测试时不可用。',
    ));
  }

  String _fingerprint(String raw) {
    if (raw.trim().isEmpty) return '';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 12);
  }

  Map<String, Object?> _safeJsonObject(String raw) {
    if (raw.trim().isEmpty) return const <String, Object?>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <String, Object?>{};
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return const <String, Object?>{};
    }
  }

  Map<String, Object?> _normalizeMap(Map<dynamic, dynamic> raw) => {
        for (final entry in raw.entries)
          entry.key.toString(): _normalizeValue(entry.value),
      };

  Object? _normalizeValue(Object? value) {
    if (value is Map) return _normalizeMap(value);
    if (value is List) return value.map(_normalizeValue).toList();
    if (value is num || value is bool || value is String || value == null) return value;
    return value.toString();
  }

  Map<String, Object?> _asMap(Object? value) =>
      value is Map ? _normalizeMap(value) : const <String, Object?>{};
}
