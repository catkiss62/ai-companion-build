import '../ai/first_channel_model.dart';
import '../ai/deepseek_client.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../diagnostics/provider_health.dart';
import '../desire/desire_engine.dart';
import '../models/desire_state.dart';
import '../models/public_web_candidate.dart';
import '../models/thought.dart';
import '../storage/secure_config.dart';
import 'layered_public_web_provider.dart';
import 'public_web_appraisal_policy.dart';
import 'public_web_deepseek_appraiser.dart';
import 'public_web_share_policy.dart';
import 'public_web_share_contract.dart';
import 'public_web_read_service.dart';

class PublicWebShareStageResult {
  const PublicWebShareStageResult({
    required this.state,
    this.candidateId,
    this.thoughtId,
    this.candidateSource = 'none',
  });

  final String state;
  final String? candidateId;
  final String? thoughtId;
  final String candidateSource;

  bool get ready =>
      state == PublicWebSharePolicy.readyLifecycle &&
      candidateId != null &&
      thoughtId != null;
}

/// Bridges one untrusted web candidate into the existing Thought/Desire path.
///
/// It never sends a message. ProactiveEngine remains the only outbound writer
/// and must still pass its ordinary rhythm, device, Grounding and frequency
/// gates before the persona may share or return WAIT.
class PublicWebShareCoordinator {
  PublicWebShareCoordinator({
    required this.db,
    required this.desire,
    SecureConfig? secureConfig,
    this.refreshBeforeShare = false,
    this.ai,
    this.reader,
  }) : secureConfig = secureConfig ?? SecureConfig.instance;

  final AppDatabase db;
  final DesireEngine desire;
  final SecureConfig secureConfig;
  final bool refreshBeforeShare;
  final DeepSeekClient? ai;
  final WebCandidateReader? reader;

  Future<PublicWebShareStageResult> stageNextCandidate({
    DateTime? now,
    BrainWorkFence? workFence,
  }) async {
    final instant = now ?? DateTime.now();
    // Diagnostics may enter without the proactive lease; they still retain one
    // original reset/brain capability for the entire asynchronous stage.
    final fence = workFence ?? await db.captureBrainWorkFence(settingKeys: const [
      'conversation_context_reset_at', 'conversation_context_reset_count',
    ]);
    if (fence == null) return const PublicWebShareStageResult(state: 'ownership_lost');
    final claimed = await db.claimNextPublicWebCandidateForSharing(
      now: instant, workFence: fence);
    if (claimed == null) return const PublicWebShareStageResult(state: 'none');
    try {
      if (refreshBeforeShare && !await _refreshClaimedCandidate(claimed, instant)) {
        // The refresh can have declined the owned candidate, or lost ownership.
        // Releasing only this token cannot undo another worker's progress.
        await db.abortPublicWebShareStage(claimed, outcome: 'refresh_declined');
        return PublicWebShareStageResult(state: 'refresh_declined', candidateId: claimed.id);
      }
      final thought = await db.finishPublicWebShareStage(claimed);
      return PublicWebShareStageResult(
        state: thought == null ? 'ownership_lost' : PublicWebSharePolicy.readyLifecycle,
        candidateId: claimed.id, thoughtId: thought?.id);
    } catch (_) {
      await db.abortPublicWebShareStage(claimed, outcome: 'stage_error');
      return PublicWebShareStageResult(state: 'stage_error', candidateId: claimed.id);
    }
  }

  Future<bool> _refreshClaimedCandidate(
    PublicWebShareStageLease claimed,
    DateTime instant,
  ) async {
    final original = await db.publicWebCandidateForRefresh(claimed.id);
    if (original == null) return false;
    if (reader != null) {
      final refreshed = await reader!(original,
        original.searchQuery.isEmpty ? original.title : original.searchQuery, null);
      final eligible = refreshed.isVerifiedRead && refreshed.semanticState == 'valid' &&
          refreshed.shareScore >= 0.68 &&
          refreshed.appraisalState == PublicWebAppraisalPolicy.shareCandidate;
      return await db.completePublicWebShareRefresh(claimed,
        refreshed: refreshed, eligible: eligible) && eligible;
    }
    final healthEvents = <ProviderHealthEvent>[];
    final provider = LayeredPublicWebProvider(
      tavilyApiKey: await secureConfig.readTavilyApiKey() ?? '',
      agnesApiKey: await secureConfig.readAgnesApiKey() ?? '',
      agnesEndpoint: await secureConfig.readAgnesEndpoint(),
      agnesModel: await secureConfig.readAgnesModel(),
      agnesEnabled:
          (await db.getSetting('agnes_web_compaction_enabled')) != '0',
      extraSources: await db.getSetting('public_web_extra_sources') ?? '',
    );
    final rereadStarted = DateTime.now();
    final reread = await provider.rereadCandidate(
      candidate: original,
      query: original.searchQuery.isEmpty ? original.title : original.searchQuery,
      now: instant,
    );
    final rereadElapsed = DateTime.now().difference(rereadStarted);
    final extracted = reread.readState == 'extracted' ||
        reread.readState == 'summary_failed' ||
        reread.readState == 'verified';
    healthEvents.add(ProviderHealthEvent(
      lane: 'extraction',
      context: 'share_refresh',
      primaryProvider: 'tavily',
      primaryOutcome: extracted ? 'success' : 'no_result',
      primaryErrorCategory:
          extracted ? 'none' : ProviderHealth.errorCategory(reread.appraisalReason),
      finalProvider: extracted ? 'tavily' : 'none',
      finalOutcome: extracted ? 'success' : 'no_result',
      resultCount: extracted ? 1 : 0,
      latencyBucket: ProviderHealth.latencyBucket(rereadElapsed),
      createdAt: instant,
    ));
    final compacted = reread.isVerifiedRead;
    final compactionNotConfigured =
        reread.appraisalReason == 'agnes_not_configured';
    healthEvents.add(ProviderHealthEvent(
      lane: 'compaction',
      context: 'share_refresh',
      primaryProvider: 'agnes',
      primaryOutcome: compacted
          ? 'success'
          : compactionNotConfigured
              ? 'not_configured'
              : extracted
                  ? 'failed'
                  : 'not_called',
      primaryErrorCategory: compacted
          ? 'none'
          : ProviderHealth.errorCategory(reread.appraisalReason),
      finalProvider: compacted ? 'agnes' : 'none',
      finalOutcome: compacted
          ? 'success'
          : compactionNotConfigured
              ? 'not_configured'
              : extracted
                  ? 'failed'
                  : 'not_called',
      resultCount: compacted ? 1 : 0,
      latencyBucket: ProviderHealth.latencyBucket(rereadElapsed),
      createdAt: instant,
    ));
    final drive = DriveKey.values.firstWhere(
      (item) => item.name == original.driveKey,
      orElse: () => DriveKey.curiosity,
    );
    final appraiser = DeepSeekPublicWebAppraiser(
      model: await FirstChannelModel.read(db),
      apiKey: await secureConfig.readApiKey() ?? '',
      endpoint: await secureConfig.readEndpoint(),
      client: ai,
    );
    final appraisalStarted = DateTime.now();
    final appraised = await appraiser.appraise(
      query: original.searchQuery.isEmpty ? original.title : original.searchQuery,
      candidates: <PublicWebCandidateDraft>[reread],
      sourceIntent: DesireIntent(
        drive: drive,
        score: 1,
        reason: 'share_time_source_refresh',
        wantAction: 'wildcard_share',
        reasonSource: 'public_web_candidate',
      ),
      socialExcess: 0.2,
    );
    final current = appraised.single;
    final appraisalCalled = reread.isVerifiedRead;
    final appraisalFailed = appraisalCalled &&
        (current.appraisalReason == 'deepseek_failure' ||
        current.appraisalReason == 'deepseek_not_configured' ||
        current.appraisalReason == 'invalid_items' ||
        current.appraisalReason == 'empty_items');
    healthEvents.add(ProviderHealthEvent(
      lane: 'appraisal',
      context: 'share_refresh',
      primaryProvider: 'deepseek',
      primaryOutcome: !appraisalCalled
          ? 'not_called'
          : appraisalFailed
              ? 'failed'
              : 'success',
      primaryErrorCategory: appraisalFailed ? 'invalid_response' : 'none',
      finalProvider:
          appraisalCalled && !appraisalFailed ? 'deepseek' : 'none',
      finalOutcome: !appraisalCalled
          ? 'not_called'
          : appraisalFailed
              ? 'failed'
              : 'success',
      resultCount: appraisalCalled && !appraisalFailed ? 1 : 0,
      latencyBucket: ProviderHealth.latencyBucket(
        DateTime.now().difference(appraisalStarted),
      ),
      createdAt: instant,
    ));
    final eligible = current.isVerifiedRead &&
        current.semanticState == 'valid' &&
        current.shareScore >= 0.68 &&
        current.appraisalState == PublicWebAppraisalPolicy.shareCandidate;
    return db.completePublicWebShareRefresh(
      claimed,
      refreshed: current,
      eligible: eligible,
      providerHealthEvents: healthEvents,
    ).then((owned) => owned && eligible);
  }

  Future<PublicWebShareStageResult> _readyStage(
    PublicWebShareCandidate candidate, {
    required String candidateSource,
  }) async {
    final thought = await db.thoughtBySource(
      PublicWebSharePolicy.source(candidate.id),
    );
    if (thought == null || !PublicWebSharePolicy.isCandidateThought(thought)) {
      return PublicWebShareStageResult(
        state: 'stale_ready',
        candidateId: candidate.id,
        candidateSource: candidateSource,
      );
    }
    return PublicWebShareStageResult(
      state: PublicWebSharePolicy.readyLifecycle,
      candidateId: candidate.id,
      thoughtId: thought.id,
      candidateSource: candidateSource,
    );
  }

  Future<PublicWebShareStageResult> seedDiagnosticCandidate({
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    // A repeated tap must not leave synthetic candidates or orphan Thoughts.
    // Real ready candidates are preserved and tested before a fixture is made.
    await db.clearDiagnosticPublicWebShareFixture();
    final existing = await db.activeReadyPublicWebShareCandidate(now: instant);
    if (existing != null) {
      return _readyStage(
        existing,
        candidateSource: PublicWebShareTestPolicy.existingReadySource,
      );
    }

    await db.seedDiagnosticPublicWebShareCandidate(now: instant);
    final staged = await stageNextCandidate(now: instant);
    if (staged.ready) {
      return PublicWebShareStageResult(
        state: staged.state,
        candidateId: staged.candidateId,
        thoughtId: staged.thoughtId,
        candidateSource: PublicWebShareTestPolicy.diagnosticSeededSource,
      );
    }

    // A background heartbeat may win the tiny no-ready -> fixture claim race.
    // Reuse that real winner and remove the unclaimed synthetic fixture.
    final raced = await db.activeReadyPublicWebShareCandidate(now: instant);
    if (raced != null) {
      await db.clearDiagnosticPublicWebShareFixture();
      return _readyStage(
        raced,
        candidateSource: PublicWebShareTestPolicy.existingReadySource,
      );
    }
    return PublicWebShareStageResult(
      state: staged.state,
      candidateId: staged.candidateId,
      thoughtId: staged.thoughtId,
      candidateSource: PublicWebShareTestPolicy.diagnosticSeededSource,
    );
  }

  String? candidateIdForThought(CompanionThought? thought) =>
      PublicWebSharePolicy.isCandidateThought(thought)
          ? PublicWebSharePolicy.candidateIdFromTopic(thought!.topicKey)
          : null;

  Future<bool> markDeclined(ExpectedPublicWebShare expected, {
    required BrainWorkFence workFence, DateTime? now,
  }) => db.declinePublicWebShareIfCurrent(expected, workFence: workFence, now: now);
}
