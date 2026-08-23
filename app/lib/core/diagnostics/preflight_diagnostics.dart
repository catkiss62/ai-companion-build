import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
        'autonomousIntentReasonIncluded': false,
        'autonomousQueryOrUrlIncluded': false,
        'autonomousScreenOrWebContentIncluded': false,
        'publicWebCandidateTitleIncluded': false,
        'publicWebCandidateSummaryIncluded': false,
        'publicWebCandidateUrlIncluded': false,
        'publicWebQueryOrInterestKeyIncluded': false,
        'agentToolArgumentsIncluded': false,
        'agentToolResultBodiesIncluded': false,
        'overlayRawPackageIncluded': false,
        'historicalExitDescriptionIncluded': false,
        'historicalExitTraceIncluded': false,
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
      final somaticDiagnostics = await db.somaticDiagnosticStats();
      final emotionDiagnostics = await db.emotionDiagnosticStats(now: now);
      final chatTurnLease =
          await db.localLeaseDiagnostic('chat_turn_lease');
      final autonomousActions =
          await db.autonomousActionDiagnosticStats(now: now);
      final publicWebCandidates =
          await db.publicWebCandidateDiagnosticStats(now: now);
      final personalityTrials = await db.personalityTrialDiagnostics();
      final generationJob = await db.blockingGenerationJob();
      final failedGeneration = await db.failedGenerationNeedingAttention();
      final grounding = await GroundingEngine(db).capture(now: now);
      final desireSnapshot = await db.loadDesire();
      final desireThoughts = await db.activeThoughtMetadata(limit: 40);
      final activeSession = await db.activeInteractionSession();
      final intimacyAllowed = activeSession != null &&
          (activeSession.kind == 'intimacy' ||
              activeSession.kind == 'roleplay_intimacy');
      final desireCandidates = DesireCorePolicy.candidates(
        drives: desireSnapshot.drives,
        refractoryUntil: desireSnapshot.refractoryUntil,
        thoughts: desireThoughts,
        now: now,
        baselines: desireSnapshot.baselines,
        lastWildcardAt: desireSnapshot.lastWildcardAt,
        intimacyAllowed: intimacyAllowed,
      );
      final provenanceCounts = <String, int>{};
      for (final thought in desireThoughts) {
        final key = thought.provenance.key;
        provenanceCounts[key] = (provenanceCounts[key] ?? 0) + 1;
      }
      final residueOrdered = desireThoughts.toList()
        ..sort((a, b) {
          final aWeight = a.residualStrength > 0
              ? a.residualStrength
              : a.strength;
          final bWeight = b.residualStrength > 0
              ? b.residualStrength
              : b.strength;
          return bWeight.compareTo(aWeight);
        });
      final strongestResidue = residueOrdered.isEmpty ? null : residueOrdered.first;
      final strongestResidueWeight = strongestResidue == null
          ? 0.0
          : strongestResidue.residualStrength > 0
              ? strongestResidue.residualStrength
              : strongestResidue.strength;
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
        'chatTurnLease': chatTurnLease,
        'emotionObservability': emotionDiagnostics,
        'somaticObservability': somaticDiagnostics,
        'personalityTrials': personalityTrials,
        'nsfwRouting': {
          'active': (await db.getSetting('nsfw_active')) == '1',
          'referenceActive':
              (await db.getSetting('nsfw_reference_active')) == '1',
          'source': await db.getSetting('nsfw_route_source') ?? 'initial',
          'manualOverridePending':
              (await db.getSetting('nsfw_manual_override') ?? '').isNotEmpty,
          'promptBodiesIncluded': false,
          'chatContentIncluded': false,
        },
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
        'serviceTemplateGuard': {
          'matchCount': int.tryParse(
                await db.getSetting('service_template_guard_match_count') ?? '',
              ) ??
              0,
          'rewriteCount': int.tryParse(
                await db.getSetting('service_template_guard_rewrite_count') ?? '',
              ) ??
              0,
          'blockCount': int.tryParse(
                await db.getSetting('service_template_guard_block_count') ?? '',
              ) ??
              0,
          'lastAt': int.tryParse(
                await db.getSetting('service_template_guard_last_at') ?? '',
              ) ??
              0,
          'lastMode':
              await db.getSetting('service_template_guard_last_mode') ?? '',
          'lastAction':
              await db.getSetting('service_template_guard_last_action') ?? '',
          'lastReason':
              await db.getSetting('service_template_guard_last_reason') ?? '',
          'lastFamily':
              await db.getSetting('service_template_guard_last_family') ?? '',
          'matchedTextIncluded': false,
          'chatContentIncluded': false,
        },
        'agentTools': {
          'registry': 'unified_v1',
          'userTurnRequestCount': int.tryParse(
                await db.getSetting('agent_tool_user_turn_request_count') ?? '',
              ) ??
              0,
          'userTurnSuccessCount': int.tryParse(
                await db.getSetting('agent_tool_user_turn_success_count') ?? '',
              ) ??
              0,
          'userTurnFailureCount': int.tryParse(
                await db.getSetting('agent_tool_user_turn_failure_count') ?? '',
              ) ??
              0,
          'lastTool':
              await db.getSetting('agent_tool_user_turn_last_tool') ?? '',
          'lastStatus':
              await db.getSetting('agent_tool_user_turn_last_status') ?? '',
          'lastReasonTag':
              await db.getSetting('agent_tool_user_turn_last_reason_tag') ?? '',
          'lastResultCount': int.tryParse(
                await db.getSetting('agent_tool_user_turn_last_result_count') ??
                    '',
              ) ??
              0,
          'lastErrorCode':
              await db.getSetting('agent_tool_user_turn_last_error_code') ?? '',
          'lastAt': int.tryParse(
                await db.getSetting('agent_tool_user_turn_last_at') ?? '',
              ) ??
              0,
          'maxCallsPerTurn': 2,
          'countsAgainstAutonomousBudget': false,
          'argumentsIncluded': false,
          'resultBodiesIncluded': false,
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
          'intimacyActionAllowed': intimacyAllowed,
          'wildcardCooldownMinutes': desireSnapshot.lastWildcardAt == null
              ? 0
              : max(
                  0,
                  DesireCorePolicy.wildcardCooldown.inMinutes -
                      now.difference(desireSnapshot.lastWildcardAt!).inMinutes,
                ),
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
          'innerVoiceContinuity': {
            'policy': 'first_person_reaction_expression_v2',
            'usesPersistedDesireAndThoughtMetadata': true,
            'storesRawReasoningAsMemory': false,
            'strongestResidueDrive': strongestResidue?.driveKey ?? '',
            'strongestResidueState': strongestResidue?.lifecycleState ?? 'none',
            'strongestResidueBand': strongestResidueWeight >= 0.68
                ? 'high'
                : strongestResidueWeight >= 0.32
                    ? 'medium'
                    : 'low',
          },
        },
        'autonomousActions': autonomousActions,
        'publicWebCandidates': publicWebCandidates,
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
        'publicWebCompaction': {
          'enabled':
              (await db.getSetting('agnes_web_compaction_enabled')) != '0',
          'lastAttemptAt': int.tryParse(
                await db.getSetting('agnes_compaction_last_attempt_at') ?? '',
              ) ??
              0,
          'lastSuccessAt': int.tryParse(
                await db.getSetting('agnes_compaction_last_success_at') ?? '',
              ) ??
              0,
          'lastOutcome':
              await db.getSetting('agnes_compaction_last_outcome') ?? 'never',
          'lastInputCount': int.tryParse(
                await db.getSetting('agnes_compaction_last_input_count') ?? '',
              ) ??
              0,
          'lastOutputCount': int.tryParse(
                await db.getSetting('agnes_compaction_last_output_count') ?? '',
              ) ??
              0,
          'lastError':
              await db.getSetting('agnes_compaction_last_error') ?? '',
          'queryOrWebContentIncluded': false,
          'apiSecretIncluded': false,
        },
        'currentContext': {
          'available': (int.tryParse(
                    await db.getSetting('current_context_last_refresh_at') ?? '',
                  ) ??
                  0) >
              0,
          'lastRefreshAt': int.tryParse(
                await db.getSetting('current_context_last_refresh_at') ?? '',
              ) ??
              0,
          'lastRefreshReason':
              await db.getSetting('current_context_last_refresh_reason') ?? '',
          'refreshCount': int.tryParse(
                await db.getSetting('current_context_refresh_count') ?? '',
              ) ??
              0,
          'screenInteractive':
              (await db.getSetting('current_context_screen_interactive')) == '1',
          'deviceLocked':
              (await db.getSetting('current_context_device_locked')) == '1',
          'busyScore': double.tryParse(
                await db.getSetting('current_context_busy_score') ?? '',
              ) ??
              0.0,
          'currentActivityClass':
              await db.getSetting('current_context_current_activity') ?? '',
          'currentAppNameResolved':
              (await db.getSetting('current_context_current_app_resolved')) == '1',
          'currentAppNameIncluded': false,
          'currentAppSource':
              await db.getSetting('current_context_current_app_source') ?? 'none',
          'dominantActivityClass':
              await db.getSetting('current_context_dominant_activity') ?? '',
          'observationCount': int.tryParse(
                await db.getSetting('current_context_observation_count') ?? '',
              ) ??
              0,
          'lastError': await db.getSetting('current_context_last_error') ?? '',
          'rawPackageOrTextIncluded': false,
          'desireAdvancedByRefresh': false,
        },
      };
      checks.add(const PreflightCheck(
        id: 'database',
        title: '本地数据库',
        level: 'pass',
        summary: '数据库可打开，身份与 schema 可读取。',
      ));
      final aiToSelf = _asMap(somaticDiagnostics['aiToSelf']);
      final aiToSelfCount = (aiToSelf['total'] as num?)?.toInt() ?? 0;
      checks.add(PreflightCheck(
        id: 'somatic_ai_to_self',
        title: 'AI → self 感官回响',
        level: aiToSelfCount > 0 ? 'pass' : 'info',
        summary: aiToSelfCount > 0
            ? '至少一条已提交的 AI 自发完成动作产生了脱敏感官回响。'
            : '尚无 AI → self 正向事件；需用一条明确已完成的自发触碰动作定向验收。',
      ));
      final actionByStatus =
          _asMap(autonomousActions['byStatus']);
      final runningActions =
          (actionByStatus['running'] as num?)?.toInt() ?? 0;
      checks.add(PreflightCheck(
        id: 'autonomous_action_foundation',
        title: '自主行动公共底座',
        level: runningActions > 0 ? 'info' : 'pass',
        summary: runningActions > 0
            ? '当前存在已领取的自主工具任务；报告已保留脱敏执行状态。'
            : 'Desire → Intent → Tool Gate → Action → Outcome 持久化与脱敏诊断已就绪。',
      ));
      final publicWebRuntime =
          _asMap(publicWebCandidates['runtime']);
      final publicWebOutcome =
          publicWebRuntime['lastOutcome'] as String? ?? 'never';
      checks.add(PreflightCheck(
        id: 'public_web_discovery',
        title: '欲望驱动的公开网页发现',
        level: publicWebOutcome == 'provider_failure' ? 'warn' : 'pass',
        summary: publicWebOutcome == 'never'
            ? '真实 Provider 已接入；等待符合阈值的 Desire Intent，候选只进入不可信候选池。'
            : publicWebOutcome == 'provider_failure'
                ? '最近一次公开网页发现由 Provider/网络失败；脱敏原因已记录，未满足欲望。'
                : '公开网页发现已有脱敏运行结果；标题、摘要、网址、查询词均未进入报告。',
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
      final selfHealCount =
          (capabilities['overlaySelfHealCount'] as num?)?.toInt() ?? 0;
      final coverSessionId =
          (capabilities['overlayCoverSessionId'] as num?)?.toInt() ?? 0;
      final coverState = capabilities['overlayCoverState'] as String? ?? 'idle';
      final inputSuspect = capabilities['overlayInputSuspect'] == true;
      final systemCoverActive = capabilities['overlaySystemCoverActive'] == true;
      final recoveryInProgress =
          capabilities['overlayRecoveryInProgress'] == true;
      final transientCoverRecovery = inputSuspect &&
          (systemCoverActive ||
              recoveryInProgress ||
              coverState == 'covered_detached' ||
              coverState == 'covered_suspect' ||
              coverState == 'exit_pending' ||
              coverState == 'recovery_scheduled');
      final possibleRecoveryLoop = coverSessionId > 0 &&
          selfHealCount > (coverSessionId * 2 + 2);
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
        'selfHealCount': selfHealCount,
        'inputSuspect': inputSuspect,
        'lastSystemCoverAt': capabilities['overlayLastSystemCoverAt'] ?? 0,
        'lastSystemCoverReason': capabilities['overlayLastSystemCoverReason'] ?? '',
        'lastCoverRecoveryAt': capabilities['overlayLastCoverRecoveryAt'] ?? 0,
        'windowVisibility': capabilities['overlayLastWindowVisibility'] ?? 0,
        'recoveryInProgress': recoveryInProgress,
        'coverRecoveryCount': capabilities['overlayCoverRecoveryCount'] ?? 0,
        'coverState': coverState,
        'systemCoverActive': systemCoverActive,
        'coverSessionId': coverSessionId,
        'coverRecoveryAttempt': capabilities['overlayCoverRecoveryAttempt'] ?? 0,
        'lastCoverExitAt': capabilities['overlayLastCoverExitAt'] ?? 0,
        'lastCoverExitReason': capabilities['overlayLastCoverExitReason'] ?? '',
        'lastCoverRecoveryResult':
            capabilities['overlayLastCoverRecoveryResult'] ?? '',
        'coverDetachCount': capabilities['overlayCoverDetachCount'] ?? 0,
        'coverHistory': capabilities['overlayCoverHistory'] ?? const [],
        'rawPackageIncluded': false,
        'transientSystemCoverRecovery': transientCoverRecovery,
        'possibleRecoveryLoop': possibleRecoveryLoop,
        'selfHealsPerCoverSession': coverSessionId <= 0
            ? 0.0
            : double.parse((selfHealCount / coverSessionId).toStringAsFixed(2)),
      };
      report['backgroundContinuity'] = {
        'processAgeMs': capabilities['processAgeMs'] ?? 0,
        'serviceUptimeMs': capabilities['serviceUptimeMs'] ?? 0,
        'serviceStartCount': capabilities['serviceStartCount'] ?? 0,
        'serviceCleanStopCount': capabilities['serviceCleanStopCount'] ?? 0,
        'possibleUncleanRestartCount':
            capabilities['possibleUncleanRestartCount'] ?? 0,
        'lastPossibleUncleanRestartAt':
            capabilities['lastPossibleUncleanRestartAt'] ?? 0,
        'lastTaskRemovedAt': capabilities['lastTaskRemovedAt'] ?? 0,
        'lastTrimMemoryAt': capabilities['lastTrimMemoryAt'] ?? 0,
        'lastTrimMemoryLevel': capabilities['lastTrimMemoryLevel'] ?? 0,
        'backgroundBrainReadyAt': capabilities['backgroundBrainReadyAt'] ?? 0,
        'backgroundBrainReadyCount': capabilities['backgroundBrainReadyCount'] ?? 0,
        'backgroundBrainFailureAt': capabilities['backgroundBrainFailureAt'] ?? 0,
        'backgroundBrainFailureCount':
            capabilities['backgroundBrainFailureCount'] ?? 0,
        'backgroundBrainFailureReason':
            capabilities['backgroundBrainFailureReason'] ?? '',
        'historicalExitReason':
            capabilities['historicalExitReason'] ?? 'unavailable',
        'historicalExitAt': capabilities['historicalExitAt'] ?? 0,
        'historicalExitStatus': capabilities['historicalExitStatus'] ?? 0,
        'historicalExitImportance':
            capabilities['historicalExitImportance'] ?? 0,
        'historicalExitDescriptionIncluded': false,
        'historicalExitTraceIncluded': false,
        'batteryOptimizationIgnored':
            androidInfo['batteryOptimizationIgnored'] == true,
        'backgroundRestricted': androidInfo['backgroundRestricted'] == true,
        'contentsIncluded': false,
      };

      _addPermissionCheck(checks, 'overlay', '悬浮窗权限', capabilities['overlay'] == true);
      _addPermissionCheck(checks, 'usage', '使用情况访问', capabilities['usage'] == true);
      _addPermissionCheck(
        checks,
        'notification_listener',
        '通知访问',
        capabilities['notificationListener'] == true,
      );
      final accessibilityAuthorized =
          capabilities['accessibilityAuthorized'] == true ||
              capabilities['accessibility'] == true;
      final accessibilityConnected =
          capabilities['accessibilityConnected'] == true;
      final accessibilityComponentMatch =
          capabilities['accessibilityComponentMatch'] == true;
      final accessibilityPackageEntryCount =
          (capabilities['accessibilityPackageEntryCount'] as num?)?.toInt() ?? 0;
      final accessibilityEventCount =
          (capabilities['accessibilityEventCount'] as num?)?.toInt() ?? 0;
      final accessibilityLastEventAt =
          (capabilities['accessibilityLastEventAt'] as num?)?.toInt() ?? 0;
      final accessibilityProcessStartedAt =
          (capabilities['processStartedAt'] as num?)?.toInt() ?? 0;
      final accessibilityLastConnectedAt =
          (capabilities['accessibilityLastConnectedAt'] as num?)?.toInt() ?? 0;
      final accessibilityLastDisconnectedAt =
          (capabilities['accessibilityLastDisconnectedAt'] as num?)?.toInt() ?? 0;
      final accessibilityProbeAt =
          (capabilities['accessibilityStatusProbeAt'] as num?)?.toInt() ?? 0;
      final accessibilityProbeStale = accessibilityProbeAt > 0 &&
          now.millisecondsSinceEpoch - accessibilityProbeAt >
              const Duration(minutes: 2).inMilliseconds;
      final accessibilityProcessRestarted = !accessibilityConnected &&
          accessibilityLastConnectedAt > 0 &&
          accessibilityProcessStartedAt > accessibilityLastConnectedAt &&
          accessibilityLastDisconnectedAt < accessibilityLastConnectedAt;
      final accessibilityEventStalled = accessibilityConnected &&
          accessibilityEventCount > 0 &&
          accessibilityLastEventAt > 0 &&
          capabilities['screenInteractive'] == true &&
          capabilities['deviceLocked'] != true &&
          now.millisecondsSinceEpoch - accessibilityLastEventAt >
              const Duration(minutes: 45).inMilliseconds;
      final accessibilityHealthState = accessibilityProbeStale
          ? 'STALE_UI'
          : !accessibilityComponentMatch &&
                  accessibilityPackageEntryCount > 0
              ? 'COMPONENT_MISMATCH'
              : !accessibilityAuthorized
                  ? 'SYSTEM_DISABLED'
                  : !accessibilityConnected
                      ? accessibilityProcessRestarted
                          ? 'PROCESS_RESTARTED'
                          : 'ENABLED_NOT_CONNECTED'
                      : accessibilityEventCount <= 0 ||
                              accessibilityLastEventAt <= 0
                          ? 'CONNECTED_NO_EVENTS'
                          : accessibilityEventStalled
                              ? 'EVENT_STREAM_STALLED'
                              : 'CONNECTED_EVENTS_OK';
      report['accessibilityLifecycle'] = {
        'healthState': accessibilityHealthState,
        'authorized': accessibilityAuthorized,
        'componentMatch': accessibilityComponentMatch,
        'enabledEntryCount':
            capabilities['accessibilityEnabledEntryCount'] ?? 0,
        'packageEntryCount': accessibilityPackageEntryCount,
        'statusProbeAt': accessibilityProbeAt,
        'lastStatusProbeAt':
            capabilities['accessibilityLastStatusProbeAt'] ?? 0,
        'lastAuthorizationChangedAt':
            capabilities['accessibilityLastAuthorizationChangedAt'] ?? 0,
        'authorizationChangeCount':
            capabilities['accessibilityAuthorizationChangeCount'] ?? 0,
        'connected': accessibilityConnected,
        'serviceGeneration':
            capabilities['accessibilityServiceGeneration'] ?? 0,
        'connectCount': capabilities['accessibilityConnectCount'] ?? 0,
        'disconnectCount':
            capabilities['accessibilityDisconnectCount'] ?? 0,
        'interruptCount':
            capabilities['accessibilityInterruptCount'] ?? 0,
        'destroyCount': capabilities['accessibilityDestroyCount'] ?? 0,
        'eventCount': accessibilityEventCount,
        'allowedEventCount':
            capabilities['accessibilityAllowedEventCount'] ?? 0,
        'lastEventAt': accessibilityLastEventAt,
        'lastEventType': capabilities['accessibilityLastEventType'] ?? '',
        'lastEventPackageHash':
            capabilities['accessibilityLastEventPackageHash'] ?? '',
        'lastWindowEventAt':
            capabilities['accessibilityLastWindowEventAt'] ?? 0,
        'lastReadableRootAt': capabilities['accessibilityLastRootAt'] ?? 0,
        'rawPackageOrTextIncluded': false,
        'lastConnectedAt': capabilities['accessibilityLastConnectedAt'] ?? 0,
        'lastDisconnectedAt':
            capabilities['accessibilityLastDisconnectedAt'] ?? 0,
        'lastInterruptAt': capabilities['accessibilityLastInterruptAt'] ?? 0,
        'lastReason': capabilities['accessibilityLastReason'] ?? '',
      };
      checks.add(PreflightCheck(
        id: 'accessibility',
        title: 'Accessibility 轻视觉',
        level: accessibilityHealthState == 'CONNECTED_EVENTS_OK'
            ? 'pass'
            : accessibilityHealthState == 'CONNECTED_NO_EVENTS'
                ? 'info'
                : 'warn',
        summary: switch (accessibilityHealthState) {
          'SYSTEM_DISABLED' => '系统当前未授权；轻视觉不会运行。',
          'COMPONENT_MISMATCH' =>
            '系统存在本 App 的无障碍条目，但组件名不匹配；请保存本报告。',
          'ENABLED_NOT_CONNECTED' =>
            '系统已授权但服务未连接；请进入无障碍设置重新开关后保存本报告。',
          'PROCESS_RESTARTED' =>
            'App 进程曾重启，系统授权仍在但服务尚未重新连接。',
          'CONNECTED_NO_EVENTS' =>
            '服务已连接，但本次安装尚未收到 AccessibilityEvent。',
          'EVENT_STREAM_STALLED' =>
            '服务仍标记连接，但事件流长时间无心跳，疑似已停滞。',
          'STALE_UI' => '当前权限快照已过期，请刷新页面后重新导出诊断。',
          _ => '系统授权、服务连接与事件流心跳均正常。',
        },
      ));
      _addPermissionCheck(
        checks,
        'post_notifications',
        '发送通知',
        capabilities['postNotifications'] == true,
      );

      report['currentAppFusion'] = {
        'source': capabilities['currentAppFusionSource'] ?? 'none',
        'ageMs': capabilities['currentAppFusionAgeMs'] ?? -1,
        'usageEventCount':
            capabilities['currentAppFusionUsageEventCount'] ?? 0,
        'labelResolved':
            capabilities['currentAppFusionLabelResolved'] == true,
        'rawPackageIncluded': false,
      };
      report['currentAppTracker'] = {
        'hasCandidate': capabilities['currentAppTrackerHasCandidate'] == true,
        'candidatePackageHash':
            capabilities['currentAppTrackerPackageHash'] ?? '',
        'observedAt': capabilities['currentAppTrackerObservedAt'] ?? 0,
        'ageMs': capabilities['currentAppTrackerAgeMs'] ?? -1,
        'source': capabilities['currentAppTrackerSource'] ?? '',
        'invalidatedAt':
            capabilities['currentAppTrackerInvalidatedAt'] ?? 0,
        'invalidationReason':
            capabilities['currentAppTrackerInvalidationReason'] ?? '',
        'windowProbeAt': capabilities['currentAppWindowProbeAt'] ?? 0,
        'windowCount': capabilities['currentAppWindowCount'] ?? 0,
        'activeWindowCount':
            capabilities['currentAppWindowActiveCount'] ?? 0,
        'focusedWindowCount':
            capabilities['currentAppWindowFocusedCount'] ?? 0,
        'candidateWindowCount':
            capabilities['currentAppWindowCandidateCount'] ?? 0,
        'windowResult': capabilities['currentAppWindowResult'] ?? '',
        'lastRetryCount': capabilities['currentAppLastRetryCount'] ?? 0,
        'lastRetryResult': capabilities['currentAppLastRetryResult'] ?? '',
        'lastRetryAt': capabilities['currentAppLastRetryAt'] ?? 0,
        'rawPackageIncluded': false,
      };
      report['proactiveNotificationDelivery'] = {
        'notificationsEnabled':
            capabilities['companionNotificationsEnabled'] == true,
        'lastPosted':
            capabilities['companionNotificationLastPosted'] == true,
        'lastAt': capabilities['companionNotificationLastAt'] ?? 0,
        'lastReason':
            capabilities['companionNotificationLastReason'] ?? '',
        'lastChannel':
            capabilities['companionNotificationLastChannel'] ?? '',
        'lastChannelImportance':
            capabilities['companionNotificationLastChannelImportance'] ?? -1,
        'lastSound': capabilities['companionNotificationLastSound'] ?? '',
        'style': capabilities['companionNotificationStyle'] ?? '',
        'lastAcknowledgedAt':
            capabilities['companionNotificationLastAcknowledgedAt'] ?? 0,
        'lastAcknowledgeReason':
            capabilities['companionNotificationLastAcknowledgeReason'] ?? '',
        'messageBodyIncluded': false,
      };
      final delayedStatus =
          capabilities['delayedProactiveTestStatus'] as String? ?? 'idle';
      report['delayedProactiveTest'] = {
        'status': delayedStatus,
        'scheduledAt':
            capabilities['delayedProactiveTestScheduledAt'] ?? 0,
        'dueAt': capabilities['delayedProactiveTestDueAt'] ?? 0,
        'firedAt': capabilities['delayedProactiveTestFiredAt'] ?? 0,
        'latencyMs': capabilities['delayedProactiveTestLatencyMs'] ?? -1,
        'appSource':
            capabilities['delayedProactiveTestAppSource'] ?? 'none',
        'appAgeMs': capabilities['delayedProactiveTestAppAgeMs'] ?? -1,
        'appCategory':
            capabilities['delayedProactiveTestAppCategory'] ?? 'unknown',
        'packageHash':
            capabilities['delayedProactiveTestPackageHash'] ?? '',
        'labelHash': capabilities['delayedProactiveTestLabelHash'] ?? '',
        'labelResolved':
            capabilities['delayedProactiveTestLabelResolved'] == true,
        'appResolutionResult':
            capabilities['delayedProactiveTestAppResolutionResult'] ?? 'not_run',
        'appRetryCount':
            capabilities['delayedProactiveTestAppRetryCount'] ?? 0,
        'overlayAssessment':
            capabilities['delayedProactiveTestOverlayAssessment'] ?? '',
        'notificationPosted':
            capabilities['delayedProactiveTestNotificationPosted'] == true,
        'notificationReason':
            capabilities['delayedProactiveTestNotificationReason'] ?? '',
        'cancelledAt':
            capabilities['delayedProactiveTestCancelledAt'] ?? 0,
        'cancelReason':
            capabilities['delayedProactiveTestCancelReason'] ?? '',
        'cancelRejectedAt':
            capabilities['delayedProactiveTestCancelRejectedAt'] ?? 0,
        'cancelRejectedReason':
            capabilities['delayedProactiveTestCancelRejectedReason'] ?? '',
        'rawAppIncluded': false,
        'memoryWritten': false,
        'modelCalled': false,
      };
      if (delayedStatus == 'completed') {
        final notificationPosted =
            capabilities['delayedProactiveTestNotificationPosted'] == true;
        final appResolved =
            capabilities['delayedProactiveTestLabelResolved'] == true;
        checks.add(PreflightCheck(
          id: 'delayed_proactive_notification',
          title: '5分钟测试 · 通知送达',
          level: notificationPosted ? 'pass' : 'warn',
          summary: notificationPosted
              ? '测试已到点并成功向 Android 发布对话通知。'
              : '测试已到点，但通知未成功发布；请查看通知原因与频道状态。',
        ));
        checks.add(PreflightCheck(
          id: 'delayed_proactive_current_app',
          title: '5分钟测试 · 当前 App',
          level: appResolved ? 'pass' : 'warn',
          summary: appResolved
              ? '提醒触发时成功解析当前 App；来源和取样次数已脱敏记录。'
              : '提醒触发时多次取样仍未解析当前 App；通知成功不再掩盖此项失败。',
        ));
      } else if (delayedStatus == 'cancelled') {
        checks.add(PreflightCheck(
          id: 'delayed_proactive_cancelled',
          title: '5分钟测试 · 已取消',
          level: 'info',
          summary: '这次测试没有触发通知；取消时间和确认入口已脱敏记录。',
        ));
      }

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
            : possibleRecoveryLoop
                ? 'warn'
                : bubbleAttached && bubbleTouchable && bubblePositionSafe &&
                        (!chatWindowAttached || chatExpanded)
                    ? 'pass'
                    : transientCoverRecovery
                        ? 'info'
                        : 'warn',
        summary: !overlayEnabled
            ? '悬浮陪伴未启用，本轮不检查触摸窗口。'
            : possibleRecoveryLoop
                ? '系统页面次数与自愈次数不成比例，疑似重复恢复循环。'
                : bubbleAttached && bubbleTouchable && bubblePositionSafe &&
                        (!chatWindowAttached || chatExpanded)
                    ? '悬浮入口已附着、可触摸且位于系统安全区域。'
                    : transientCoverRecovery
                        ? '系统图片/文件/权限页面刚退出，悬浮输入通道正在一次性恢复。'
                        : '悬浮入口存在输入通道、坐标或隐藏聊天窗口异常；服务会尝试自动恢复。',
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
    final native = _asMap(snapshot.report['native']);
    final app = _asMap(native['app']);
    final versionName = (app['versionName'] as String? ?? '').trim();
    final versionCode = (app['versionCode'] as num?)?.toInt() ?? 0;
    final buildLabel = versionName.isEmpty
        ? 'unknown build'
        : versionCode > 0
            ? 'v$versionName+$versionCode'
            : 'v$versionName';
    final text = StringBuffer()
      ..writeln('AI Companion $buildLabel · REDACTED LOCAL DIAGNOSTIC REPORT')
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
