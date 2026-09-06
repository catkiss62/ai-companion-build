import 'package:ai_companion_localfirst/core/autonomy/ai_interest_evidence_policy.dart';
import 'package:flutter_test/flutter_test.dart';

AiInterestEvidenceObservation observation({
  required String source,
  required DateTime at,
  int polarity = 1,
  double weight = 0.8,
}) {
  final policy = const AiInterestEvidencePolicy();
  return AiInterestEvidenceObservation(
    sourceKind: source,
    polarity: polarity,
    weight: weight,
    localDay: policy.localDayKey(at),
    occurredAt: at,
  );
}

void main() {
  const policy = AiInterestEvidencePolicy();
  final dayOne = DateTime(2026, 9, 6, 9);
  final dayTwo = DateTime(2026, 9, 7, 9);

  test('one pipeline cluster or one local date cannot establish interest', () {
    final aggregate = policy.aggregate(
      <AiInterestEvidenceObservation>[
        observation(
          source: AiInterestEvidenceSource.autonomousWebVerified.key,
          at: dayOne,
        ),
        observation(
          source: AiInterestEvidenceSource.autonomousShare.key,
          at: dayOne.add(const Duration(hours: 3)),
        ),
      ],
      now: dayOne.add(const Duration(hours: 4)),
    );

    expect(aggregate.status, AiInterestStatus.forming);
    expect(aggregate.autonomousDayCount, 1);
    expect(aggregate.supportCount, 2);
  });

  test('independent autonomous terminal outcomes across dates establish', () {
    final aggregate = policy.aggregate(
      <AiInterestEvidenceObservation>[
        observation(
          source: AiInterestEvidenceSource.autonomousWebVerified.key,
          at: dayOne,
        ),
        observation(
          source: AiInterestEvidenceSource.autonomousWebVerified.key,
          at: dayTwo,
        ),
      ],
      now: dayTwo,
    );

    expect(aggregate.status, AiInterestStatus.established);
    expect(aggregate.autonomousDayCount, 2);
    expect(aggregate.confidence, greaterThanOrEqualTo(0.68));
  });

  test('user feedback refines but cannot satisfy autonomous-day gate', () {
    final aggregate = policy.aggregate(
      <AiInterestEvidenceObservation>[
        observation(
          source: AiInterestEvidenceSource.autonomousWebVerified.key,
          at: dayOne,
        ),
        observation(
          source: AiInterestEvidenceSource.userFeedbackPositive.key,
          at: dayTwo,
          weight: 0.9,
        ),
      ],
      now: dayTwo,
    );

    expect(aggregate.status, AiInterestStatus.forming);
    expect(aggregate.autonomousDayCount, 1);
    expect(
      policy.canCreateCandidate(
        AiInterestEvidenceSource.userFeedbackPositive.key,
        1,
      ),
      isFalse,
    );
  });

  test('explicit negative feedback can contradict accumulated support', () {
    final aggregate = policy.aggregate(
      <AiInterestEvidenceObservation>[
        observation(
          source: AiInterestEvidenceSource.autonomousWebVerified.key,
          at: dayOne,
          weight: 0.7,
        ),
        observation(
          source: AiInterestEvidenceSource.userFeedbackNegative.key,
          at: dayTwo,
          polarity: -1,
          weight: 1,
        ),
      ],
      now: dayTwo,
    );

    expect(aggregate.status, AiInterestStatus.contradicted);
    expect(aggregate.counterCount, 1);
  });

  test('freshness decays without changing the evidence body', () {
    final fresh = policy.aggregate(
      <AiInterestEvidenceObservation>[
        observation(
          source: AiInterestEvidenceSource.autonomousWebVerified.key,
          at: dayOne,
        ),
      ],
      now: dayOne,
    );
    final stale = policy.aggregate(
      <AiInterestEvidenceObservation>[
        observation(
          source: AiInterestEvidenceSource.autonomousWebVerified.key,
          at: dayOne,
        ),
      ],
      now: dayOne.add(const Duration(days: 61)),
    );

    expect(fresh.freshness, 1);
    expect(stale.freshness, 0);
  });

  test('only the four audited terminal source kinds are eligible', () {
    expect(policy.isEligibleSource('autonomous_web_verified'), isTrue);
    expect(policy.isEligibleSource('autonomous_share'), isTrue);
    expect(policy.isEligibleSource('user_feedback_positive'), isTrue);
    expect(policy.isEligibleSource('user_feedback_negative'), isTrue);
    expect(policy.isEligibleSource('diary'), isFalse);
    expect(policy.isEligibleSource('roleplay'), isFalse);
    expect(policy.isEligibleSource('model_self_report'), isFalse);
    expect(policy.isEligibleSource('user_turn_search'), isFalse);
  });
}
