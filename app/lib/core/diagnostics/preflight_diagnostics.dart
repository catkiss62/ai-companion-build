import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'conversation_initiative_telemetry.dart';
import 'attachment_pipeline_telemetry.dart';
import 'conversation_initiative_ablation_telemetry.dart';
import 'dialogue_expression_telemetry.dart';
import 'provider_health.dart';
import 'visible_reasoning_language_telemetry.dart';
import '../desire/desire_core_policy.dart';
import '../grounding/grounding_engine.dart';
import '../integration/moe_expression_prompt_adapter.dart';
import '../moe/application/moe_dynamics_policy.dart';
import '../moe/infrastructure/sqlite_moe_repository.dart';
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
        'memoryBodiesIncluded': false,
        'memoryRetrievalQueriesIncluded': false,
        'visionImageBytesIncluded': false,
        'visionPathsIncluded': false,
        'visionCaptionIncluded': false,
        'visionSummaryIncluded': false,
        'visionRawErrorIncluded': false,
        'attachmentPipelinePathsIncluded': false,
        'attachmentPipelineImageBytesIncluded': false,
        'attachmentPipelineCaptionOrSummaryIncluded': false,
        'attachmentPipelineRawErrorsIncluded': false,
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
        'companionAlbumImageBytesIncluded': false,
        'companionAlbumPathsIncluded': false,
        'companionAlbumSourceUrlsIncluded': false,
        'companionAlbumTitlesOrSummariesIncluded': false,
        'companionAlbumReasonsOrCommentsIncluded': false,
        'companionAlbumContentHashesIncluded': false,
        'providerHealthRawErrorIncluded': false,
        'providerHealthQueryOrUrlIncluded': false,
        'providerHealthImageContentIncluded': false,
        'proactivePolicyAppIdentityIncluded': false,
        'proactivePolicyThoughtOrMessageTextIncluded': false,
        'proactivePolicyExternalContentIncluded': false,
        'circadianFatigueThoughtOrMessageTextIncluded': false,
        'circadianFatigueUserScheduleTextIncluded': false,
        'runtimeErrorTextIncluded': false,
        'agentToolArgumentsIncluded': false,
        'agentToolResultBodiesIncluded': false,
        'agentToolOutcomeDeviceIdsIncluded': false,
        'albumSearchQueryIncluded': false,
        'albumSearchTitlesOrSummariesIncluded': false,
        'albumSearchImageBytesOrPathsIncluded': false,
        'albumSearchUrlsOrHashesIncluded': false,
        'albumSearchCommentsIncluded': false,
        'overlayRawPackageIncluded': false,
        'historicalExitDescriptionIncluded': false,
        'historicalExitTraceIncluded': false,
        'reasoningLanguageTextIncluded': false,
        'reasoningLanguageMatchedWordsIncluded': false,
        'moePromptBodiesIncluded': false,
        'moeStyleDirectivesIncluded': false,
        'moeAxisOrRecipeNamesIncluded': false,
        'personalityTemplateBodiesIncluded': false,
        'personalityExecutionAnchorBodyIncluded': false,
        'moeValuesOrThresholdsIncluded': false,
        'conversationInitiativePromptBodiesIncluded': false,
        'conversationInitiativeMessageBodiesIncluded': false,
        'conversationInitiativeThoughtBodiesIncluded': false,
        'conversationInitiativeModelJsonIncluded': false,
        'informationQuestionGuardMatchedTextIncluded': false,
        'personalityLearningCandidateBodiesIncluded': false,
        'personalityLearningEvidenceBodiesIncluded': false,
        'personalityLearningSubjectKeysIncluded': false,
        'personalityLearningModelProposalIncluded': false,
        'personalityLearningSemanticReviewBodiesIncluded': false,
        'selfExperienceSourceBodiesIncluded': false,
        'selfExperienceThoughtBodiesIncluded': false,
        'desireEventThoughtOrMessageBodiesIncluded': false,
      },
    };
    var attachmentPipeline = <String, Object?>{};

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
      final reasoningLanguageDiagnostics =
          await VisibleReasoningLanguageTelemetry.snapshot(db);
      final memoryRetrievalDiagnostics =
          await db.memoryRetrievalDiagnosticStats(now: now);
      final visionDiagnostics = await db.attachmentVisionDiagnosticStats();
      attachmentPipeline = await AttachmentPipelineTelemetry.snapshot(db);
      final chatTurnLease =
          await db.localLeaseDiagnostic('chat_turn_lease');
      final autonomousActions =
          await db.autonomousActionDiagnosticStats(now: now);
      final agentToolOutcomes = await db.agentToolOutcomeDiagnosticStats();
      final publicWebCandidates =
          await db.publicWebCandidateDiagnosticStats(now: now);
      final companionAlbum = await db.companionAlbumDiagnosticStats();
      final providerHealth = await db.providerHealthDiagnosticStats(now: now);
      final proactivePolicy =
          await db.proactivePolicyDiagnosticStats(now: now);
      final personalityTrials = await db.personalityTrialDiagnostics();
      final personalityLearning =
          await db.personalityLearningDiagnosticStats();
      final selfExperience =
          await db.selfExperienceDiagnosticStats(now: now);
      final desireEvents = await db.desireEventDiagnosticStats(now: now);
      final moeRepository = SqliteMoeRepository(() => db.database);
      final moeState = await moeRepository.loadState();
      final moePlan = const MoeDynamicsPolicy().expressionPlan(moeState);
      final moeExpressionEnabled =
          (await db.getSetting('moe_expression_enabled')) != '0';
      final moePromptTelemetry =
          await MoeExpressionPromptTelemetry.snapshot(db);
      final conversationInitiative =
          await ConversationInitiativeTelemetry.snapshot(db);
      final conversationInitiativeAblation =
          await ConversationInitiativeAblationTelemetry.snapshot(db);
      final dialogueExpression =
          await DialogueExpressionTelemetry.snapshot(db);
      conversationInitiative['contextResetAt'] = int.tryParse(
            await db.getSetting('conversation_context_reset_at') ?? '',
          ) ??
          0;
      conversationInitiative['contextResetCount'] = int.tryParse(
            await db.getSetting('conversation_context_reset_count') ?? '',
          ) ??
          0;
      final generationJob = await db.blockingGenerationJob();
      final failedGeneration = await db.failedGenerationNeedingAttention();
      final grounding = await GroundingEngine(db).capture(now: now);
      final desireSnapshot = await db.loadDesire();
      final desireThoughts = await db.activeThoughtMetadata(limit: 40);
      const adultRelationshipDriveEnabled = true;
      final desireCandidates = DesireCorePolicy.candidates(
        drives: desireSnapshot.drives,
        refractoryUntil: desireSnapshot.refractoryUntil,
        thoughts: desireThoughts,
        now: now,
        baselines: desireSnapshot.baselines,
        lastWildcardAt: desireSnapshot.lastWildcardAt,
        intimacyAllowed: adultRelationshipDriveEnabled,
      );
      final currentFatigue =
          desireSnapshot.drives[DriveKey.fatigue] ?? 0.0;
      final circadianFatigueFloor =
          DesireCorePolicy.circadianFatigueFloor(now);
      DesireCoreCandidate? restCandidate;
      DesireCoreCandidate? strongestNonRestCandidate;
      for (final candidate in desireCandidates) {
        if (candidate.drive == DriveKey.fatigue ||
            candidate.action == 'rest') {
          restCandidate ??= candidate;
        } else {
          strongestNonRestCandidate ??= candidate;
        }
      }
      final selectedDesireCandidate =
          desireCandidates.isEmpty ? null : desireCandidates.first;
      final strongDesireOverrideActive = restCandidate != null &&
          selectedDesireCandidate != null &&
          selectedDesireCandidate.drive != DriveKey.fatigue &&
          selectedDesireCandidate.action != 'rest';
      final fatigueOverrideCount = int.tryParse(
            await db.getSetting('circadian_fatigue_override_count') ?? '',
          ) ??
          0;
      final fatigueOverrideLastAt = int.tryParse(
            await db.getSetting('circadian_fatigue_override_last_at') ?? '',
          ) ??
          0;
      final fatigueOverrideLastDrive =
          await db.getSetting('circadian_fatigue_override_last_drive') ?? '';
      final fatigueOverrideLastCost = double.tryParse(
            await db.getSetting('circadian_fatigue_override_last_cost') ?? '',
          ) ??
          0.0;
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
      final backgroundErrorCount = int.tryParse(
            await db.getSetting('background_error_count') ?? '',
          ) ??
          0;
      final hasBackgroundError =
          (await db.getSetting('last_background_error') ?? '').isNotEmpty;
      final backgroundErrorCategory = hasBackgroundError
          ? (await db.getSetting('last_background_error_category')) ??
              'legacy_unclassified'
          : 'none';
      final backgroundErrorAt = int.tryParse(
            await db.getSetting('last_background_error_at') ?? '',
          ) ??
          0;
      final hasMaintenanceError =
          (await db.getSetting('last_long_running_maintenance_error') ?? '')
              .isNotEmpty;
      final maintenanceErrorCategory = hasMaintenanceError
          ? (await db.getSetting(
                'last_long_running_maintenance_error_category',
              )) ??
              'legacy_unclassified'
          : 'none';
      final maintenanceErrorAt = int.tryParse(
            await db.getSetting('last_long_running_maintenance_error_at') ?? '',
          ) ??
          0;
      final maintenanceSuccessAt = int.tryParse(
            await db.getSetting('last_long_running_maintenance_success_at') ?? '',
          ) ??
          0;
      final recoveryState =
          await db.getSetting('recovery_orchestrator_state') ?? 'never';
      final hasRecoveryError =
          (await db.getSetting('recovery_orchestrator_last_error') ?? '')
              .isNotEmpty;
      final recoveryErrorCategory = hasRecoveryError
          ? (await db.getSetting(
                'recovery_orchestrator_last_error_category',
              )) ??
              'legacy_unclassified'
          : 'none';
      final recoveryErrorAt = int.tryParse(
            await db.getSetting('recovery_orchestrator_last_error_at') ?? '',
          ) ??
          0;

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
        'visibleReasoningLanguage': reasoningLanguageDiagnostics,
        'memoryRetrieval': memoryRetrievalDia