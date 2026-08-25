class PublicWebCandidateDraft {
  const PublicWebCandidateDraft({
    required this.fingerprint,
    required this.title,
    required this.summary,
    required this.url,
    required this.sourceDomain,
    required this.provider,
    required this.language,
    required this.driveKey,
    required this.intentAction,
    required this.interestKey,
    required this.discoveredAt,
    required this.expiresAt,
    this.safetyState = 'untrusted_public',
  });

  final String fingerprint;
  final String title;
  final String summary;
  final String url;
  final String sourceDomain;
  final String provider;
  final String language;
  final String driveKey;
  final String intentAction;
  final String interestKey;
  final DateTime discoveredAt;
  final DateTime expiresAt;
  final String safetyState;
}

class PublicWebContextItem {
  const PublicWebContextItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.url,
    required this.sourceDomain,
    required this.provider,
    required this.discoveredAt,
    required this.safetyState,
  });

  final String id;
  final String title;
  final String summary;
  final String url;
  final String sourceDomain;
  final String provider;
  final DateTime discoveredAt;
  final String safetyState;
}

class PublicWebProviderResult {
  const PublicWebProviderResult({
    required this.candidates,
    required this.provider,
    this.failureReason = '',
    this.compactionAttempted = false,
    this.compactionSucceeded = false,
    this.compactionInputCount = 0,
    this.compactionOutputCount = 0,
    this.compactionFailureReason = '',
  });

  final List<PublicWebCandidateDraft> candidates;
  final String provider;
  final String failureReason;
  final bool compactionAttempted;
  final bool compactionSucceeded;
  final int compactionInputCount;
  final int compactionOutputCount;
  final String compactionFailureReason;

  bool get succeeded => failureReason.isEmpty;
}

class PublicWebDiscoveryDecision {
  const PublicWebDiscoveryDecision({
    required this.state,
    this.gateReason = '',
    this.storedCount = 0,
  });

  final String state;
  final String gateReason;
  final int storedCount;
}


class PublicWebShareCandidate {
  const PublicWebShareCandidate({
    required this.id,
    required this.driveKey,
    required this.lifecycleState,
    required this.discoveredAt,
  });

  final String id;
  final String driveKey;
  final String lifecycleState;
  final DateTime discoveredAt;
}
