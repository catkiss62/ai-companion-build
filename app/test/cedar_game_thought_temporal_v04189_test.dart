import 'package:ai_companion_localfirst/core/desire/cedar_game_thought_policy.dart';
import 'package:ai_companion_localfirst/core/desire/proactive_thought_readiness_policy.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:flutter_test/flutter_test.dart';

CompanionThought thought({
  required String id,
  required DateTime eventAt,
  int actionCount = 0,
  DateTime? lastActedAt,
  String? source,
}) =>
    CompanionThought(
      id: id,
      text: '一条真实 Cedar Outcome',
      driveKey: 'curiosity',
      kind: 'flit',
      strength: 0.72,
      bornAt: eventAt,
      updatedAt: eventAt.add(const Duration(days: 8)),
      source: source ??
          'mcp/cedar_game:fishing:play-${eventAt.microsecondsSinceEpoch}',
      lifecycleState: 'active',
      actionCount: actionCount,
      lastActedAt: lastActedAt,
      topicKey: 'cedar_game:fishing',
    );

void main() {
  final now = DateTime(2026, 9, 20, 6);

  test('Cedar evidence time comes from immutable event id, not updatedAt', () {
    final eventAt = now.subtract(const Duration(hours: 4));
    final value = thought(id: 'event', eventAt: eventAt);
    expect(CedarGameThoughtPolicy.evidenceAt(value), eventAt);
    expect(CedarGameThoughtPolicy.isRecent(value, now), isFalse);
  });

  test('different Cedar Outcomes never consolidate by shared game topic', () {
    final first = thought(
      id: 'first',
      eventAt: now.subtract(const Duration(minutes: 20)),
    );
    final second = thought(
      id: 'second',
      eventAt: now.subtract(const Duration(minutes: 10)),
    );
    final duplicate = thought(
      id: 'duplicate',
      eventAt: first.bornAt,
      source: first.source,
    );
    expect(
      CedarGameThoughtPolicy.canConsolidateByTopic(first, second),
      isFalse,
    );
    expect(
      CedarGameThoughtPolicy.canConsolidateByTopic(first, duplicate),
      isTrue,
    );
  });

  test('one Cedar Outcome can initiate at most one proactive share', () {
    final eventAt = now.subtract(const Duration(minutes: 20));
    expect(
      ProactiveThoughtReadinessPolicy.isReady(
        thought(id: 'fresh', eventAt: eventAt),
        now,
      ),
      isTrue,
    );
    expect(
      ProactiveThoughtReadinessPolicy.isReady(
        thought(
          id: 'already-shared',
          eventAt: eventAt,
          actionCount: 1,
          lastActedAt: eventAt.add(const Duration(minutes: 2)),
        ),
        now,
      ),
      isFalse,
    );
  });

  test('stale Cedar Outcome stays recallable but cannot initiate a share', () {
    final stale = thought(
      id: 'stale',
      eventAt: now.subtract(const Duration(hours: 49)),
    );
    expect(stale.canDriveIntentAt(now), isTrue);
    expect(ProactiveThoughtReadinessPolicy.isReady(stale, now), isFalse);
  });
}
