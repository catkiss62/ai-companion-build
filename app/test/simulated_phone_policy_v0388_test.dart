import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';
import 'package:ai_companion_localfirst/core/phone/simulated_phone_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('master switch blocks every producer except tarot', () {
    for (final app in SimulatedPhoneAppKind.values) {
      final allowed = SimulatedPhonePolicy.updatesAllowed(
        phoneEnabled: false,
        app: app,
      );
      expect(allowed, app == SimulatedPhoneAppKind.tarot);
    }
    for (final app in SimulatedPhoneAppKind.values) {
      expect(
        SimulatedPhonePolicy.updatesAllowed(phoneEnabled: true, app: app),
        isTrue,
      );
    }
  });

  test('local day and previous day use calendar boundaries', () {
    final now = DateTime(2026, 8, 26, 0, 3);
    expect(SimulatedPhonePolicy.localDay(now), '2026-08-26');
    expect(SimulatedPhonePolicy.previousLocalDay(now), '2026-08-25');
  });

  test('daily selection is stable and salt can separate two tarot cards', () {
    final first = SimulatedPhonePolicy.stableIndex(
      '2026-08-26',
      12,
      salt: 101,
    );
    expect(
      SimulatedPhonePolicy.stableIndex('2026-08-26', 12, salt: 101),
      first,
    );
    expect(first, inInclusiveRange(0, 11));
    expect(
      SimulatedPhonePolicy.stableIndex('2026-08-26', 12, salt: 307),
      inInclusiveRange(0, 11),
    );
  });

  test('wish requires drive strength, recurrence and a concrete object', () {
    final now = DateTime(2026, 8, 26, 12);
    final desire = DesireSnapshot(
      drives: {...DesireSnapshot.defaultDrives(), DriveKey.curiosity: 0.72},
      baselines: DesireSnapshot.defaultBaselines(),
    );
    CompanionThought thought({
      int fedCount = 2,
      String topicKey = 'public-web:whale-art',
      double strength = 0.70,
      DateTime? lastSatisfiedAt,
    }) =>
        CompanionThought(
          id: 'thought-1',
          text: 'private body must never be rendered by phone policy',
          driveKey: DriveKey.curiosity.name,
          kind: 'thread',
          strength: strength,
          bornAt: now,
          updatedAt: now,
          fedCount: fedCount,
          topicKey: topicKey,
          lastSatisfiedAt: lastSatisfiedAt,
        );

    expect(
      SimulatedPhonePolicy.wishEligible(
        thought: thought(),
        desire: desire,
      ),
      isTrue,
    );
    expect(
      SimulatedPhonePolicy.wishEligible(
        thought: thought(fedCount: 0),
        desire: desire,
      ),
      isFalse,
    );
    expect(
      SimulatedPhonePolicy.wishEligible(
        thought: thought(topicKey: ''),
        desire: desire,
      ),
      isFalse,
    );
    expect(
      SimulatedPhonePolicy.wishEligible(
        thought: thought(strength: 0.30),
        desire: desire,
      ),
      isFalse,
    );
    expect(
      SimulatedPhonePolicy.wishEligible(
        thought: thought(lastSatisfiedAt: now),
        desire: desire,
      ),
      isFalse,
    );
  });

  test('wish presentation never exposes the private thought body', () {
    for (final drive in DriveKey.values) {
      final text = SimulatedPhonePolicy.wishText(drive.name);
      expect(text, isNotEmpty);
      expect(text, isNot(contains('private body')));
    }
  });
}
