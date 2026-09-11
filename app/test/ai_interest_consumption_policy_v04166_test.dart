import 'package:ai_companion_localfirst/core/autonomy/ai_interest_consumption_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 11, 12);

  AiInterestConsumptionCandidate candidate({
    String id = 'interest-a',
    String status = 'established',
    double confidence = 0.82,
    double freshness = 0.90,
    int version = 4,
    DateTime? lastEvidenceAt,
  }) =>
      AiInterestConsumptionCandidate(
        id: id,
        interestKey: 'curiosity:animals:whales',
        label: '鲸类睡眠',
        sourceDomain: 'example.org',
        status: status,
        confidence: confidence,
        freshness: freshness,
        version: version,
        lastEvidenceAt: lastEvidenceAt ?? now.subtract(const Duration(days: 2)),
      );

  AiInterestConsumptionEvent event({
    String candidateId = 'other-interest',
    String mode = 'exploit',
    String surface = 'public_web',
    String status = 'completed',
    Duration age = const Duration(hours: 7),
  }) =>
      AiInterestConsumptionEvent(
        candidateId: candidateId,
        mode: mode,
        surface: surface,
        status: status,
        createdAt: now.subtract(age),
      );

  test('only current established and fresh candidates are consumable', () {
    expect(
      AiInterestConsumptionPolicy.eligible(candidate(), now: now),
      isTrue,
    );
    for (final status in <String>['forming', 'contradicted', 'inactive']) {
      expect(
        AiInterestConsumptionPolicy.eligible(
          candidate(status: status),
          now: now,
        ),
        isFalse,
      );
    }
    expect(
      AiInterestConsumptionPolicy.eligible(
        candidate(confidence: 0.67),
        now: now,
      ),
      isFalse,
    );
    expect(
      AiInterestConsumptionPolicy.eligible(
        candidate(lastEvidenceAt: now.subtract(const Duration(days: 60))),
        now: now,
      ),
      isFalse,
    );
    expect(
      AiInterestConsumptionPolicy.eligible(candidate(version: 0), now: now),
      isFalse,
    );
  });

  test('weighted mode has bounded exploit adjacent and wildcard lanes', () {
    AiInterestConsumptionMode pick(double modeUnit) =>
        AiInterestConsumptionPolicy.select(
          candidates: <AiInterestConsumptionCandidate>[candidate()],
          recentEvents: const <AiInterestConsumptionEvent>[],
          surface: AiInterestConsumptionSurface.publicWeb,
          now: now,
          modeUnit: modeUnit,
          candidateUnit: 0,
        )!
            .mode;

    expect(pick(0.10), AiInterestConsumptionMode.exploit);
    expect(pick(0.70), AiInterestConsumptionMode.adjacent);
    expect(pick(0.95), AiInterestConsumptionMode.wildcard);
  });

  test('completed outcomes spend mode budgets but failures do not', () {
    final twoExploit = <AiInterestConsumptionEvent>[
      event(age: const Duration(hours: 7)),
      event(candidateId: 'other-b', age: const Duration(hours: 13)),
    ];
    final next = AiInterestConsumptionPolicy.select(
      candidates: <AiInterestConsumptionCandidate>[candidate()],
      recentEvents: twoExploit,
      surface: AiInterestConsumptionSurface.publicWeb,
      now: now,
      modeUnit: 0,
      candidateUnit: 0,
    );
    expect(next!.mode, AiInterestConsumptionMode.adjacent);

    final failed = AiInterestConsumptionPolicy.select(
      candidates: <AiInterestConsumptionCandidate>[candidate()],
      recentEvents: <AiInterestConsumptionEvent>[
        event(status: 'failed', age: const Duration(minutes: 5)),
      ],
      surface: AiInterestConsumptionSurface.publicWeb,
      now: now,
      modeUnit: 0,
      candidateUnit: 0,
    );
    expect(failed!.mode, AiInterestConsumptionMode.exploit);
  });

  test('candidate and surface cooldowns prevent repetitive habit loops', () {
    final sameCandidate = AiInterestConsumptionPolicy.select(
      candidates: <AiInterestConsumptionCandidate>[candidate()],
      recentEvents: <AiInterestConsumptionEvent>[
        event(candidateId: 'interest-a', age: const Duration(hours: 2)),
      ],
      surface: AiInterestConsumptionSurface.publicWeb,
      now: now,
      modeUnit: 0.7,
      candidateUnit: 0,
    );
    expect(sameCandidate, isNull);

    final proactiveFull = AiInterestConsumptionPolicy.select(
      candidates: <AiInterestConsumptionCandidate>[candidate()],
      recentEvents: <AiInterestConsumptionEvent>[
        event(surface: 'proactive', age: const Duration(hours: 13)),
        event(
          candidateId: 'other-b',
          mode: 'adjacent',
          surface: 'proactive',
          age: const Duration(hours: 14),
        ),
      ],
      surface: AiInterestConsumptionSurface.proactive,
      now: now,
      modeUnit: 0.95,
      candidateUnit: 0,
    );
    expect(proactiveFull, isNull);
  });

  test('commit-time check rejects a plan made stale by another success', () {
    final plan = AiInterestConsumptionPlan(
      candidate: candidate(),
      mode: AiInterestConsumptionMode.exploit,
      surface: AiInterestConsumptionSurface.publicWeb,
    );
    expect(
      AiInterestConsumptionPolicy.completionAllowed(
        plan: plan,
        recentEvents: const <AiInterestConsumptionEvent>[],
        now: now,
      ),
      isTrue,
    );
    expect(
      AiInterestConsumptionPolicy.completionAllowed(
        plan: plan,
        recentEvents: <AiInterestConsumptionEvent>[
          event(candidateId: 'interest-a', age: const Duration(minutes: 1)),
        ],
        now: now,
      ),
      isFalse,
    );
  });

  test('prompt hint remains a light preference instead of a hard persona', () {
    final plan = AiInterestConsumptionPolicy.select(
      candidates: <AiInterestConsumptionCandidate>[candidate()],
      recentEvents: const <AiInterestConsumptionEvent>[],
      surface: AiInterestConsumptionSurface.proactive,
      now: now,
      modeUnit: 0,
      candidateUnit: 0,
    )!;
    expect(plan.promptHint(), contains('轻量偏向'));
    expect(plan.promptHint(), contains('不是必须提及的人设标签'));
    expect(plan.toPlannerJson().keys, isNot(contains('interest_key')));
    expect(plan.toPlannerJson().keys, isNot(contains('candidate_version')));
  });
}
