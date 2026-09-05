import '../database/app_database.dart';
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
  }) : secureConfig = secureConfig ?? SecureConfig.instance;

  final AppDatabase db;
  final DesireEngine desire;
  final SecureConfig secureConfig;
  final bool refreshBeforeShare;

  Future<PublicWebShareStageResult> stageNextCandidate({
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    final claimed = await db.claimNextPublicWebCandidateForSharing(now: instant);
    if (claimed == null) {
      return const PublicWebShareStageResult(state: 'none');
    }
    if (refreshBeforeShare) {
      final refreshed = await _refreshClaimedCandidate(claimed, instant);
      if (!refreshed) {
        return PublicWebShareStageResult(
          state: 'refresh_declined',
          candidateId: claimed.id,
        );
      }
    }
    final source = PublicWebSharePolicy.source(claimed.id);
    final topicKey = PublicWebSharePolicy.topicKey(claimed.id);
    try {
      await desire.feedThought(
        text: PublicWebSharePolicy.thoughtText,
        drive: PublicWebSharePolicy.driveFromKey(claimed.driveKey),
        incomingStrength: 0.62,
        source: source,
        topicKey: topicKey,
      );
      final thought = await db.thoughtBySource(source);
      if (thought == null) {
        await db.completePublicWebCandidateShareStage(
          claimed.id,
          ready: false,
          outcome: 'thought_missing',
          now: instant,
        );
        return PublicWebShareStageResult(
          state: 'thought_missing',
          candidateId: claimed.id,
        );
      }
      final completed = await db.completePublicWebCandidateShareStage(
        claimed.id,
        ready: true,
        outcome: 'thought_created',
        now: instant,
      );
      if (!completed) {
        return PublicWebShareStageResult(
          state: 'ownership_lost',
          candidateId: claimed.id,
          thoughtId: thought.id,
        );
      }
      return PublicWebShareStageResult(
        state: PublicWebSharePolicy.readyLifecycle,
        candidateId: claimed.id,
        thoughtId: thought.id,
      );
    } catch (_) {
      await db.completePublicWebCandidateShareStage(
        claimed.id,
        ready: false,
        outcome: 'thought_error',
        now: instant,
      );
      return PublicWebShareStageResult(
        state: 'thought_error',
        candidateId: claimed.id,
      );
    }
  }

  Future<bool> _refreshClaimedCandidate(
    PublicWebShareCandidate claimed,
    DateTime instant,
  ) async {
    final original = await db.publicWebCandidateForRefresh(claimed.id);
    if (original == null) return false;
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
    await db.recordProviderHealthEvent(ProviderHealthEvent(
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
    await db.recordProviderHealthEvent(ProviderHealthEvent(
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
      apiKey: await secureConfig.readApiKey() ?? '',
      endpoint: await secureConfig.readEndpoint(),
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
    await db.recordProviderHealthEvent(ProviderHealthEvent(
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
      claimed.id,
      current,
      eligible: eligible,
      now: instant,
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

  Future<void> markShared(String candidateId, {DateTime? now}) =>
      db.markPublicWebCandidateShareOutcome(
        candidateId,
        outcome: PublicWebSharePolicy.sharedLifecycle,
        now: now,
      );

  Future<void> markDeclined(String candidateId, {DateTime? now}) =>
      db.markPublicWebCandidateShareOutcome(
        candidateId,
        outcome: PublicWebSharePolicy.declinedLifecycle,
        now: now,
      );
}
