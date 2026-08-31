import 'package:ai_companion_localfirst/core/desire/thought_feed_policy.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:flutter_test/flutter_test.dart';

CompanionThought thought({
  required double strength,
  required int fedCount,
  String kind = 'flit',
  String source = 'presence/phone_activity',
}) {
  final now = DateTime.utc(2026, 8, 31, 1);
  return CompanionThought(
    id: 'awareness',
    text: 'coarse phone activity',
    driveKey: 'curiosity',
    kind: kind,
    strength: strength,
    bornAt: now,
    updatedAt: now,
    fedCount: fedCount,
    source: source,
    lifecycleState: kind == 'fixation' ? 'fixation' : 'active',
  );
}

void main() {
  test('repeated phone awareness refreshes but never becomes fixation', () {
    var current = thought(strength: 0.34, fedCount: 0);
    for (var i = 0; i < 121; i++) {
      final next = ThoughtFeedPolicy.merge(
        existing: current,
        source: 'presence/phone_activity',
        incomingStrength: 0.43,
      );
      current = thought(
        strength: next.strength,
        fedCount: next.fedCount,
        kind: next.kind,
      );
    }
    expect(current.kind, 'flit');
    expect(current.lifecycleState, 'active');
    expect(current.fedCount, 1);
    expect(current.strength, lessThanOrEqualTo(0.42));
  });

  test('legacy awareness fixation is demoted on the next real refresh', () {
    final next = ThoughtFeedPolicy.merge(
      existing: thought(strength: 0.91, fedCount: 19, kind: 'fixation'),
      source: 'perception/awareness',
      incomingStrength: 0.30,
    );
    expect(next.kind, 'flit');
    expect(next.lifecycleState, 'active');
    expect(next.fedCount, 1);
    expect(next.strength, lessThanOrEqualTo(0.42));
  });

  test('durable repeated evidence retains normal fixation semantics', () {
    var current = thought(
      strength: 0.40,
      fedCount: 1,
      source: 'self_drive/memory',
    );
    final next = ThoughtFeedPolicy.merge(
      existing: current,
      source: 'self_drive/memory',
      incomingStrength: 0.40,
    );
    current = thought(
      strength: next.strength,
      fedCount: next.fedCount,
      kind: next.kind,
      source: 'self_drive/memory',
    );
    final fixation = ThoughtFeedPolicy.merge(
      existing: current,
      source: 'self_drive/memory',
      incomingStrength: 0.40,
    );
    expect(fixation.kind, 'fixation');
    expect(fixation.fedCount, 3);
  });
}
