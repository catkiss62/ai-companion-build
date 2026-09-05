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
    this.imageUrl = '',
    this.imageDomain = '',
    this.imageDescription = '',
    this.appraisalState = 'share_candidate',
    this.readState = 'snippet_only',
    this.semanticState = 'unappraised',
    this.keyPoints = const <String>[],
    this.uncertainties = const <String>[],
    this.topicTags = const <String>[],
    this.interestScore = 0,
    this.learningScore = 0,
    this.shareScore = 0,
    this.appraisalReason = '',
    this.contentSha256 = '',
    this.readAt,
    this.searchQuery = '',
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
  final String imageUrl;
  final String imageDomain;
  final String imageDescription;
  final String appraisalState;
  final String readState;
  final String semanticState;
  final List<String> keyPoints;
  final List<String> uncertainties;
  final List<String> topicTags;
  final double interestScore;
  final double learningScore;
  final double shareScore;
  final String appraisalReason;
  final String contentSha256;
  final DateTime? readAt;
  final String searchQuery;

  bool get isVerifiedRead => readState == 'verified';

  PublicWebCandidateDraft copyWith({
    String? summary,
    String? provider,
    String? appraisalState,
    String? readState,
    String? semanticState,
    List<String>? keyPoints,
    List<String>? uncertainties,
    List<String>? topicTags,
    double? interestScore,
    double? learningScore,
    double? shareScore,
    String? appraisalReason,
    String? contentSha256,
    DateTime? readAt,
    String? searchQuery,
  }) =>
      PublicWebCandidateDraft(
        fingerprint: fingerprint,
        title: title,
        summary: summary ?? this.summary,
        url: url,
        sourceDomain: sourceDomain,
        provider: provider ?? this.provider,
        language: language,
        driveKey: driveKey,
        intentAction: intentAction,
        interestKey: interestKey,
        discoveredAt: discoveredAt,
        expiresAt: expiresAt,
        safetyState: safetyState,
        imageUrl: imageUrl,
        imageDomain: imageDomain,
        imageDescription: imageDescription,
        appraisalState: appraisalState ?? this.appraisalState,
        readState: readState ?? this.readState,
        semanticState: semanticState ?? this.semanticState,
        keyPoints: keyPoints ?? this.keyPoints,
        uncertainties: uncertainties ?? this.uncertainties,
        topicTags: topicTags ?? this.topicTags,
        interestScore: interestScore ?? this.interestScore,
        learningScore: learningScore ?? this.learningScore,
        shareScore: shareScore ?? this.shareScore,
        appraisalReason: appraisalReason ?? this.appraisalReason,
        contentSha256: contentSha256 ?? this.contentSha256,
        readAt: readAt ?? this.readAt,
        searchQuery: searchQuery ?? this.searchQuery,
      );
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
    this.compactionEnabled = false,
    this.compactionConfigured = false,
    this.compactionSucceeded = false,
    this.compactionInputCount = 0,
    this.compactionOutputCount = 0,
    this.compactionFailureReason = '',
    this.primaryProvider = '',
    this.primaryFailureReason = '',
    this.fallbackProvider = '',
    this.fallbackEligible = false,
    this.fallbackAttempted = false,
    this.fallbackSucceeded = false,
    this.fallbackFailureReason = '',
    this.extractionAttempted = false,
    this.extractionSucceeded = false,
    this.extractionInputCount = 0,
    this.extractionOutputCount = 0,
    this.extractionFailureReason = '',
  });

  final List<PublicWebCandidateDraft> candidates;
  final String provider;
  final String failureReason;
  final bool compactionAttempted;
  final bool compactionEnabled;
  final bool compactionConfigured;
  final bool compactionSucceeded;
  final int compactionInputCount;
  final int compactionOutputCount;
  final String compactionFailureReason;
  final String primaryProvider;
  final String primaryFailureReason;
  final String fallbackProvider;
  final bool fallbackEligible;
  final bool fallbackAttempted;
  final bool fallbackSucceeded;
  final String fallbackFailureReason;
  final bool extractionAttempted;
  final bool extractionSucceeded;
  final int extractionInputCount;
  final int extractionOutputCount;
  final String extractionFailureReason;

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
