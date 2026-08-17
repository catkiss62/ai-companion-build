enum AutonomousToolKind {
  publicWeb,
  screenObservation,
  videoUnderstanding,
}

extension AutonomousToolKindKey on AutonomousToolKind {
  String get key => switch (this) {
        AutonomousToolKind.publicWeb => 'public_web',
        AutonomousToolKind.screenObservation => 'screen_observation',
        AutonomousToolKind.videoUnderstanding => 'video_understanding',
      };

  static AutonomousToolKind fromKey(String value) => switch (value) {
        'screen_observation' => AutonomousToolKind.screenObservation,
        'video_understanding' => AutonomousToolKind.videoUnderstanding,
        _ => AutonomousToolKind.publicWeb,
      };
}

enum AutonomousActionStatus {
  requested,
  running,
  blocked,
  deduplicated,
  succeeded,
  noResult,
  failed,
  cancelled,
}

extension AutonomousActionStatusKey on AutonomousActionStatus {
  String get key => switch (this) {
        AutonomousActionStatus.requested => 'requested',
        AutonomousActionStatus.running => 'running',
        AutonomousActionStatus.blocked => 'blocked',
        AutonomousActionStatus.deduplicated => 'deduplicated',
        AutonomousActionStatus.succeeded => 'succeeded',
        AutonomousActionStatus.noResult => 'no_result',
        AutonomousActionStatus.failed => 'failed',
        AutonomousActionStatus.cancelled => 'cancelled',
      };

  bool get isTerminal => switch (this) {
        AutonomousActionStatus.requested ||
        AutonomousActionStatus.running => false,
        _ => true,
      };
}

enum AutonomousGateReason {
  allowed,
  inactiveBrain,
  transferLocked,
  generationActive,
  screenLocked,
  screenNotInteractive,
  sensitiveSurface,
  providerUnavailable,
  budgetExhausted,
  duplicate,
}

extension AutonomousGateReasonKey on AutonomousGateReason {
  String get key => switch (this) {
        AutonomousGateReason.allowed => 'allowed',
        AutonomousGateReason.inactiveBrain => 'inactive_brain',
        AutonomousGateReason.transferLocked => 'transfer_locked',
        AutonomousGateReason.generationActive => 'generation_active',
        AutonomousGateReason.screenLocked => 'screen_locked',
        AutonomousGateReason.screenNotInteractive => 'screen_not_interactive',
        AutonomousGateReason.sensitiveSurface => 'sensitive_surface',
        AutonomousGateReason.providerUnavailable => 'provider_unavailable',
        AutonomousGateReason.budgetExhausted => 'budget_exhausted',
        AutonomousGateReason.duplicate => 'duplicate',
      };
}

enum AutonomousOutcomeKind {
  none,
  candidateStored,
  observationStored,
  noUsefulResult,
  providerFailure,
  cancelled,
}

extension AutonomousOutcomeKindKey on AutonomousOutcomeKind {
  String get key => switch (this) {
        AutonomousOutcomeKind.none => 'none',
        AutonomousOutcomeKind.candidateStored => 'candidate_stored',
        AutonomousOutcomeKind.observationStored => 'observation_stored',
        AutonomousOutcomeKind.noUsefulResult => 'no_useful_result',
        AutonomousOutcomeKind.providerFailure => 'provider_failure',
        AutonomousOutcomeKind.cancelled => 'cancelled',
      };
}

class AutonomousActionRequest {
  const AutonomousActionRequest({
    required this.id,
    required this.dedupeKey,
    required this.tool,
    required this.intentAction,
    required this.driveKey,
    required this.intentScore,
    required this.reasonSource,
    required this.requestedAt,
    this.thoughtId,
  });

  final String id;
  final String dedupeKey;
  final AutonomousToolKind tool;
  final String intentAction;
  final String driveKey;
  final double intentScore;
  final String reasonSource;
  final DateTime requestedAt;
  final String? thoughtId;
}

class AutonomousActionContext {
  const AutonomousActionContext({
    required this.activeBrain,
    required this.transferLocked,
    required this.generationActive,
    required this.screenInteractive,
    required this.deviceLocked,
    required this.sensitiveSurface,
    required this.providerAvailable,
    required this.duplicateActive,
    required this.budgetLimit,
    required this.budgetUsed,
  });

  final bool activeBrain;
  final bool transferLocked;
  final bool generationActive;
  final bool screenInteractive;
  final bool deviceLocked;
  final bool sensitiveSurface;
  final bool providerAvailable;
  final bool duplicateActive;
  final int? budgetLimit;
  final int budgetUsed;

  int? get budgetRemaining => budgetLimit == null
      ? null
      : (budgetLimit! - budgetUsed).clamp(0, budgetLimit!).toInt();
}

class AutonomousGateDecision {
  const AutonomousGateDecision({
    required this.allowed,
    required this.reason,
    this.budgetRemaining,
  });

  final bool allowed;
  final AutonomousGateReason reason;
  final int? budgetRemaining;
}

class AutonomousActionRequestResult {
  const AutonomousActionRequestResult({
    required this.request,
    required this.decision,
    required this.recorded,
  });

  final AutonomousActionRequest request;
  final AutonomousGateDecision decision;
  final bool recorded;
}

class AutonomousActionRun {
  const AutonomousActionRun({
    required this.id,
    required this.dedupeKey,
    required this.tool,
    required this.intentAction,
    required this.driveKey,
    required this.intentScore,
    required this.reasonSource,
    required this.status,
    required this.gateReason,
    required this.outcome,
    required this.requestedAt,
    required this.stateGeneration,
    required this.deviceId,
    required this.screenInteractive,
    required this.deviceLocked,
    this.thoughtId,
    this.runToken = '',
    this.attempt = 0,
    this.startedAt,
    this.finishedAt,
    this.latencyBucket = '',
    this.resultCount = 0,
    this.desireSatisfiedAt,
  });

  final String id;
  final String dedupeKey;
  final AutonomousToolKind tool;
  final String intentAction;
  final String driveKey;
  final double intentScore;
  final String reasonSource;
  final String? thoughtId;
  final AutonomousActionStatus status;
  final AutonomousGateReason gateReason;
  final AutonomousOutcomeKind outcome;
  final DateTime requestedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String runToken;
  final int attempt;
  final int stateGeneration;
  final String deviceId;
  final bool screenInteractive;
  final bool deviceLocked;
  final String latencyBucket;
  final int resultCount;
  final DateTime? desireSatisfiedAt;
}

String autonomousLatencyBucket(Duration elapsed) {
  if (elapsed < const Duration(seconds: 1)) return 'lt_1s';
  if (elapsed < const Duration(seconds: 5)) return '1_5s';
  if (elapsed < const Duration(seconds: 15)) return '5_15s';
  if (elapsed < const Duration(minutes: 1)) return '15_60s';
  return 'gte_60s';
}
