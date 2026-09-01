import '../desire/desire_engine.dart';
import '../models/desire_state.dart';
import '../models/public_web_candidate.dart';

class PublicWebAppraisalPolicy {
  const PublicWebAppraisalPolicy._();

  static const discard = 'discard';
  static const hold = 'hold';
  static const verify = 'verify';
  static const shareCandidate = 'share_candidate';

  /// Appraisal is intentionally conservative and content-independent. Search
  /// results are still untrusted at this point; the current Desire decides
  /// whether they are merely kept, need verification, or may become one share
  /// candidate. A successful search therefore does not imply an outbound ping.
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
