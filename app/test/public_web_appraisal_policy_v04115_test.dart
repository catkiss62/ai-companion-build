import 'package:ai_companion_localfirst/core/autonomy/public_web_appraisal_policy.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/public_web_candidate.dart';
import 'package:flutter_test/flutter_test.dart';

DesireIntent intent(DriveKey drive, {String action = 'discover_interest'}) =>
    DesireIntent(
      drive: drive,
      score: 0.72,
      reason: 'private reason',
      wantAction: action,
    );

PublicWebCandidateDraft candidate(int index) => PublicWebCandidateDraft(
      fingerprint: index.toString().padLeft(64, '0'),
      title: 'title $index',
      summary: 'summary $index',
      url: 'https://example.com/$index',
      sourceDomain: 'example.com',
      provider: 'test',
      language: 'zh',
      driveKey: 'curiosity',
      intentAction: 'discover_interest',
      interestKey: 'fixed:$index',
      discoveredAt: DateTime.utc(2026, 9, 1),
      expiresAt: DateTime.utc(2026, 9, 15),
    );

void main() {
  final candidates = [candidate(1), candidate(2), candidate(3)];

  test('curiosity keeps and verifies without forcing a share', () {
    final result = PublicWebAppraisalPolicy.appraise(
      candidates: candidates,
      sourceIntent: intent(DriveKey.curiosity),
    );
    expect(result.map((item) => item.appraisalState), [
      PublicWebAppraisalPolicy.hold,
      PublicWebAppraisalPolicy.verify,
      PublicWebAppraisalPolicy.discard,
    ]);
  });

  test('reflection remains private while social may nominate one share', () {
    final reflection = PublicWebAppraisalPolicy.appraise(
      candidates: candidates,
      sourceIntent: intent(DriveKey.reflection),
    );
    expect(
      reflection.any(
        (item) => item.appraisalState == PublicWebAppraisalPolicy.shareCandidate,
      ),
      isFalse,
    );

    final social = PublicWebAppraisalPolicy.appraise(
      candidates: candidates,
      sourceIntent: intent(DriveKey.social),
    );
    expect(social.first.appraisalState, PublicWebAppraisalPolicy.shareCandidate);
    expect(
      social.where(
        (item) => item.appraisalState == PublicWebAppraisalPolicy.shareCandidate,
      ),
      hasLength(1),
    );
  });

  test('wildcard curiosity can nominate one share candidate', () {
    final result = PublicWebAppraisalPolicy.appraise(
      candidates: candidates,
      sourceIntent: intent(DriveKey.curiosity, action: 'wildcard_share'),
    );
    expect(result.first.appraisalState, PublicWebAppraisalPolicy.shareCandidate);
  });

  test('social excess may nominate one otherwise private discovery', () {
    final reflection = PublicWebAppraisalPolicy.appraise(
      candidates: candidates,
      sourceIntent: intent(DriveKey.reflection),
      socialExcess: 0.13,
    );
    expect(
      reflection.first.appraisalState,
      PublicWebAppraisalPolicy.shareCandidate,
    );
    expect(
      reflection.where(
        (item) => item.appraisalState == PublicWebAppraisalPolicy.shareCandidate,
      ),
      hasLength(1),
    );
  });
}
