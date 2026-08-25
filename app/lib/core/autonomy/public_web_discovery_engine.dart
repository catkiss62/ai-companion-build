import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../desire/desire_engine.dart';
import '../models/autonomous_action.dart';
import '../models/desire_state.dart';
import '../models/public_web_candidate.dart';
import '../platform/android_bridge.dart';
import '../storage/secure_config.dart';
import 'autonomous_action_coordinator.dart';
import 'layered_public_web_provider.dart';
import 'public_web_discovery_policy.dart';
import 'wikimedia_public_web_provider.dart';

/// First scheduled autonomous tool provider.
///
/// It runs only after the existing Desire heartbeat has produced a snapshot,
/// uses fixed public-knowledge topics so no user/Thought text leaves the app,
/// and stores untrusted results only in the candidate pool. It never sends a
/// message; proactive delivery remains a separate Gate.
class PublicWebDiscoveryEngine {
  PublicWebDiscoveryEngine({
    required this.db,
    required this.desire,
    required this.android,
    SecureConfig? secureConfig,
    PublicWebProvider? provider,
  })  : secureConfig = secureConfig ?? SecureConfig.instance,
        _providerOverride = provider;

  final AppDatabase db;
  final DesireEngine desire;
  final AndroidBridge android;
  final SecureConfig secureConfig;
  final PublicWebProvider? _providerOverride;
  final Uuid _uuid = Uuid();

  late final AutonomousActionCoordinator coordinator =
      AutonomousActionCoordinator(db);

  Future<PublicWebDiscoveryDecision> maybeDiscover({
    required DesireSnapshot snapshot,
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    if ((await db.getSetting('public_web_discovery_enabled')) == '0') {
      return const PublicWebDiscoveryDecision(state: 'disabled');
    }
    final thoughts = await db.activeThoughts(limit: 24);
    final intents = desire.previewCandidates(
      snapshot,
      thoughts,
      now: instant,
      intimacyAllowed: false,
    );
    DesireIntent? sourceIntent;
    for (final intent in intents) {
      if (PublicWebDiscoveryPolicy.eligible(intent)) {
        sourceIntent = intent;
        break;
      }
    }
    if (sourceIntent == null) {
      return const PublicWebDiscoveryDecision(state: 'no_eligible_intent');
    }

    final topic = PublicWebDiscoveryPolicy.topicFor(
      intent: sourceIntent,
      now: instant,
    );
    final provider = _providerOverride ?? await _configuredProvider();
    final toolIntent = PublicWebDiscoveryPolicy.toToolIntent(sourceIntent);
    var screenInteractive = true;
    var deviceLocked = false;
    try {
      final status = await android.capabilityStatus();
      screenInteractive = status.screenInteractive;
      deviceLocked = status.deviceLocked;
    } catch (_) {
      // Public-web eligibility deliberately does not depend on screen state.
    }

    final requestResult = await coordinator.requestFromDesire(
      intent: toolIntent,
      tool: AutonomousToolKind.publicWeb,
      dedupeMaterial:
          '${provider.providerKey}|${topic.interestKey}|${PublicWebDiscoveryPolicy.dedupeWindow(instant)}',
      providerAvailable: true,
      screenInteractive: screenInteractive,
      deviceLocked: deviceLocked,
      sensitiveSurface: false,
      budgetLimit: PublicWebDiscoveryPolicy.dailyLimit,
      budgetWindow: PublicWebDiscoveryPolicy.budgetWindow,
      now: instant,
    );
    if (!requestResult.decision.allowed || !requestResult.recorded) {
      await _recordRuntime(
        at: instant,
        outcome: requestResult.recorded
            ? 'gate_${requestResult.decision.reason.key}'
            : 'request_not_recorded',
      );
      return PublicWebDiscoveryDecision(
        state: 'blocked',
        gateReason: requestResult.decision.reason.key,
      );
    }

    final runToken = _uuid.v4();
    final run = await coordinator.claim(
      id: requestResult.request.id,
      runToken: runToken,
      now: instant,
    );
    if (run == null) {
      await _recordRuntime(at: instant, outcome: 'claim_lost');
      return const PublicWebDiscoveryDecision(state: 'claim_lost');
    }

    final result = await provider.discover(
      query: topic.query,
      driveKey: run.driveKey,
      intentAction: run.intentAction,
      interestKey: topic.interestKey,
      now: instant,
    );
    await _recordCompactionTelemetry(result, instant);
    if (!result.succeeded) {
      final completed = await coordinator.completeWithoutSatisfaction(
        run: run,
        runToken: runToken,
        status: AutonomousActionStatus.failed,
        outcome: AutonomousOutcomeKind.providerFailure,
        now: DateTime.now(),
      );
      if (completed) {
        await _recordRuntime(
          at: instant,
          outcome: 'provider_failure',
          error: result.failureReason,
        );
      }
      return PublicWebDiscoveryDecision(
        state: completed ? 'provider_failure' : 'ownership_lost',
      );
    }
    if (result.candidates.isEmpty) {
      final completed = await coordinator.completeWithoutSatisfaction(
        run: run,
        runToken: runToken,
        status: AutonomousActionStatus.noResult,
        outcome: AutonomousOutcomeKind.noUsefulResult,
        now: DateTime.now(),
      );
      if (completed) {
        await _recordRuntime(at: instant, outcome: 'no_result');
      }
      return PublicWebDiscoveryDecision(
        state: completed ? 'no_result' : 'ownership_lost',
      );
    }

    final stored = await coordinator.completePublicWebSuccess(
      run: run,
      runToken: runToken,
      candidates: result.candidates,
      now: DateTime.now(),
    );
    if (stored > 0) {
      await _recordRuntime(
        at: instant,
        outcome: 'candidate_stored',
        success: true,
      );
      return PublicWebDiscoveryDecision(
        state: 'candidate_stored',
        storedCount: stored,
      );
    }
    // A user generation may have started while HTTP was in flight. The
    // success transaction then refuses the result; close the still-owned run
    // without satisfying Desire so it cannot remain permanently `running`.
    final cancelled = await coordinator.completeWithoutSatisfaction(
      run: run,
      runToken: runToken,
      status: AutonomousActionStatus.cancelled,
      outcome: AutonomousOutcomeKind.cancelled,
      now: DateTime.now(),
    );
    if (cancelled) {
      await _recordRuntime(at: instant, outcome: 'cancelled_before_commit');
      return const PublicWebDiscoveryDecision(
        state: 'cancelled_before_commit',
      );
    }
    await _recordRuntime(at: instant, outcome: 'duplicate_or_ownership_lost');
    return const PublicWebDiscoveryDecision(
      state: 'duplicate_or_ownership_lost',
    );
  }

  Future<PublicWebProvider> _configuredProvider() async {
    final agnesEnabled =
        (await db.getSetting('agnes_web_compaction_enabled')) != '0';
    return LayeredPublicWebProvider(
      tavilyApiKey: await secureConfig.readTavilyApiKey() ?? '',
      agnesApiKey: await secureConfig.readAgnesApiKey() ?? '',
      agnesEndpoint: await secureConfig.readAgnesEndpoint(),
      agnesModel: await secureConfig.readAgnesModel(),
      agnesEnabled: agnesEnabled,
      extraSources: await db.getSetting('public_web_extra_sources') ?? '',
    );
  }

  Future<void> _recordCompactionTelemetry(
    PublicWebProviderResult result,
    DateTime at,
  ) async {
    if (!result.compactionAttempted || !await db.brainWorkAllowed()) return;
    await db.setSetting(
      'agnes_compaction_last_attempt_at',
      at.millisecondsSinceEpoch.toString(),
    );
    await db.setSetting(
      'agnes_compaction_last_outcome',
      result.compactionSucceeded ? 'success' : 'failed',
    );
    await db.setSetting(
      'agnes_compaction_last_input_count',
      '${result.compactionInputCount}',
    );
    await db.setSetting(
      'agnes_compaction_last_output_count',
      '${result.compactionOutputCount}',
    );
    await db.setSetting(
      'agnes_compaction_last_error',
      result.compactionFailureReason,
    );
    if (result.compactionSucceeded) {
      await db.setSetting(
        'agnes_compaction_last_success_at',
        at.millisecondsSinceEpoch.toString(),
      );
    }
  }

  Future<void> _recordRuntime({
    required DateTime at,
    required String outcome,
    String error = '',
    bool success = false,
  }) async {
    if (!await db.brainWorkAllowed()) return;
    await db.setSetting(
      'last_public_web_discovery_at',
      at.millisecondsSinceEpoch.toString(),
    );
    await db.setSetting('last_public_web_discovery_outcome', outcome);
    await db.setSetting('last_public_web_discovery_error', error);
    if (success) {
      await db.setSetting(
        'last_public_web_discovery_success_at',
        at.millisecondsSinceEpoch.toString(),
      );
    }
  }
}
