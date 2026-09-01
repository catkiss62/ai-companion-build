import 'package:ai_companion_localfirst/core/autonomy/public_web_discovery_policy.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:flutter_test/flutter_test.dart';

DesireIntent intent({
  DriveKey drive = DriveKey.curiosity,
  double score = 0.72,
  String action = 'explore_topic',
}) =>
    DesireIntent(
      drive: drive,
      score: score,
      reason: 'raw private Thought text must never become a query',
      wantAction: action,
      thoughtId: 'thought-private-1',
      reasonSource: 'thought',
    );

void main() {
  group('public web eligibility remains owned by Desire', () {
    test('only curiosity, reflection and social are eligible', () {
      expect(PublicWebDiscoveryPolicy.eligible(intent()), isTrue);
      expect(
        PublicWebDiscoveryPolicy.eligible(intent(drive: DriveKey.reflection)),
        isTrue,
      );
      expect(
        PublicWebDiscoveryPolicy.eligible(intent(drive: DriveKey.social)),
        isTrue,
      );
      expect(
        PublicWebDiscoveryPolicy.eligible(intent(drive: DriveKey.attachment)),
        isFalse,
      );
      expect(
        PublicWebDiscoveryPolicy.eligible(intent(drive: DriveKey.fatigue)),
        isFalse,
      );
    });

    test('normal and wildcard thresholds are deterministic', () {
      expect(PublicWebDiscoveryPolicy.eligible(intent(score: 0.599)), isFalse);
      expect(PublicWebDiscoveryPolicy.eligible(intent(score: 0.60)), isTrue);
      expect(
        PublicWebDiscoveryPolicy.eligible(
          intent(score: 0.579, action: 'wildcard_share'),
        ),
        isFalse,
      );
      expect(
        PublicWebDiscoveryPolicy.eligible(
          intent(score: 0.58, action: 'wildcard_share'),
        ),
        isTrue,
      );
    });

    test('tool intent preserves Desire provenance but uses a route action', () {
      final source = intent(drive: DriveKey.reflection);
      final routed = PublicWebDiscoveryPolicy.toToolIntent(source);
      expect(routed.drive, source.drive);
      expect(routed.score, source.score);
      expect(routed.reason, source.reason);
      expect(routed.thoughtId, source.thoughtId);
      expect(routed.reasonSource, source.reasonSource);
      expect(routed.wantAction, 'discover_interest');
    });
  });

  group('privacy-safe topic routing', () {
    test('query comes from a fixed public list, never raw Thought text', () {
      final source = intent();
      final first = PublicWebDiscoveryPolicy.topicFor(
        intent: source,
        now: DateTime.utc(2026, 8, 18, 3),
      );
      final second = PublicWebDiscoveryPolicy.topicFor(
        intent: source,
        now: DateTime.utc(2026, 8, 18, 3),
      );
      expect(first.query, second.query);
      expect(first.interestKey, second.interestKey);
      expect(first.query, isNot(contains('private')));
      expect(first.query, isNot(contains('Thought')));
      expect(first.interestKey, startsWith('curiosity:'));
      expect(first.searchMode, 'curiosity_explore');
      expect(first.domain, isNotEmpty);
    });

    test('reflection and social use separate search modes', () {
      final reflection = PublicWebDiscoveryPolicy.topicFor(
        intent: intent(drive: DriveKey.reflection),
        now: DateTime.utc(2026, 8, 18, 3),
      );
      final social = PublicWebDiscoveryPolicy.topicFor(
        intent: intent(drive: DriveKey.social),
        now: DateTime.utc(2026, 8, 18, 3),
      );
      expect(reflection.searchMode, 'reflection_understand');
      expect(social.searchMode, 'social_material');
      expect(reflection.domain, isNot(social.domain));
    });

    test('recent exact interests are skipped while the taxonomy has options', () {
      final first = PublicWebDiscoveryPolicy.topicFor(
        intent: intent(),
        now: DateTime.utc(2026, 8, 18, 3),
      );
      final next = PublicWebDiscoveryPolicy.topicFor(
        intent: intent(),
        now: DateTime.utc(2026, 8, 18, 3),
        recentInterestKeys: [first.interestKey],
      );
      expect(next.interestKey, isNot(first.interestKey));
      expect(next.searchMode, first.searchMode);
    });

    test('dedupe changes only at a six-hour UTC boundary', () {
      expect(
        PublicWebDiscoveryPolicy.dedupeWindow(DateTime.utc(2026, 8, 18, 1)),
        PublicWebDiscoveryPolicy.dedupeWindow(DateTime.utc(2026, 8, 18, 5)),
      );
      expect(
        PublicWebDiscoveryPolicy.dedupeWindow(DateTime.utc(2026, 8, 18, 5)),
        isNot(PublicWebDiscoveryPolicy.dedupeWindow(
          DateTime.utc(2026, 8, 18, 6),
        )),
      );
    });

    test('hard budget and retention constants remain bounded', () {
      expect(PublicWebDiscoveryPolicy.dailyLimit, 4);
      expect(PublicWebDiscoveryPolicy.budgetWindow, const Duration(hours: 24));
      expect(PublicWebDiscoveryPolicy.candidateTtl, const Duration(days: 14));
      expect(PublicWebDiscoveryPolicy.candidateCap, 240);
    });
  });
}
