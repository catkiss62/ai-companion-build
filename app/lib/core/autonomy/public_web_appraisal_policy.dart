import '../desire/desire_engine.dart';
import '../models/desire_state.dart';
import '../models/public_web_candidate.dart';

class PublicWebAppraisalPolicy {
  const PublicWebAppraisalPolicy._();

  static const discard = 'discard';
  static const hold = 'hold';
  static const verify = 'verify';
  static const shareCandidate = 'share_candidate';
  static const historyOnly = 'history_only';
  static const knowledgeCandidate = 'knowledge_candidate';

  static String routeModelScores({
    required DesireIntent sourceIntent,
    required double socialExcess,
    required String semanticState,
    required double interestScore,
    required double learningScore,
    required double shareScore,
  }) {
    if (semanticState == historyOnly) return historyOnly;
    final sociallyReady = sourceIntent.drive == DriveKey.social ||
        sourceIntent.wantAction == 'wildcard_share' ||
        socialExcess >= 0.10;
    if (shareScore >= 0.68 && sociallyReady) return shareCandidate;
    if (learningScore >= 0.62) return knowledgeCandidate;
    if (interestScore >= 0.55) return hold;
    return historyOnly;
  }

  /// Legacy deterministic routing retained for old fixtures and diagnostics.
  /// Runtime v0.41.39 uses DeepSeekPublicWebAppraiser after Extract + Agnes;
  /// a successful search alone never implies an outbound ping.
  static List<PublicWebCandidateDraft> appraise({
    required List<PublicWebCandidateDraft> candidates,
    required DesireIntent sourceIntent,
    double socialExcess = 0,
  }) {
    final result = <PublicWebCandidateDraft>[];
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final appraisal = switch (sourceIntent.drive) {
        DriveKey.social => index == 0
            ? shareCandidate
            : index == 1
                ? hold
                : discard,
        DriveKey.reflection => index == 0
            ? socialExcess >= 0.12
                ? shareCandidate
                : hold
            : index == 1
                ? verify
                : discard,
        _ => (sourceIntent.wantAction == 'wildcard_share' ||
                    socialExcess >= 0.14) &&
                index == 0
            ? shareCandidate
            : index == 0
                ? hold
                : index == 1
                    ? verify
                    : discard,
      };
      result.add(candidate.copyWith(appraisalState: appraisal));
    }
    return result;
  }
}
