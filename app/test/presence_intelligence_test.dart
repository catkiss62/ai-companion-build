import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/presence/presence_intelligence.dart';

void main() {
  test('one weak phone event is not enough to create a presence thought', () {
    final result = PresenceMomentumPolicy.advance(
      previousScore: 0,
      elapsed: Duration.zero,
      input: const PresenceMomentumInput(
        screenInteractive: true,
        busyScore: 0.35,
        dominantActivityMinutes: 3,
        appSwitchesLast30Minutes: 1,
        newNotificationCount: 0,
        newAccessibilityCount: 1,
        hasCurrentActivity: true,
        userIdleMinutes: 30,
      ),
    );

    expect(result.score, lessThan(0.20));
    expect(result.shouldFeedThought, isFalse);
  });

  test('repeated coarse activity accumulates gradually', () {
    var score = 0.0;
    PresenceMomentumResult? latest;
    for (var i = 0; i < 4; i++) {
      latest = PresenceMomentumPolicy.advance(
        previousScore: score,
        elapsed: const Duration(minutes: 2),
        input: const PresenceMomentumInput(
          screenInteractive: true,
          busyScore: 0.52,
          dominantActivityMinutes: 8,
          appSwitchesLast30Minutes: 4,
          newNotificationCount: 1,
          newAccessibilityCount: 3,
          hasCurrentActivity: true,
          userIdleMinutes: 25,
        ),
      );
      score = latest.score;
    }

    expect(latest, isNotNull);
    expect(latest!.score, greaterThanOrEqualTo(0.20));
    expect(latest.shouldFeedThought, isTrue);
    expect(latest.signalClass, anyOf('active_use', 'sustained_use'));
  });

  test('screen off does not inject new phone-activity pressure', () {
    final result = PresenceMomentumPolicy.advance(
      previousScore: 0.60,
      elapsed: const Duration(minutes: 20),
      input: const PresenceMomentumInput(
        screenInteractive: false,
        busyScore: 0.12,
        dominantActivityMinutes: 40,
        appSwitchesLast30Minutes: 20,
        newNotificationCount: 8,
        newAccessibilityCount: 20,
        hasCurrentActivity: true,
        userIdleMinutes: 120,
      ),
    );

    expect(result.impulse, 0);
    expect(result.score, lessThan(0.60));
    expect(result.signalClass, 'screen_off');
    expect(result.shouldFeedThought, isFalse);
  });

  test('recent direct chat suppresses presence thought even with strong activity', () {
    final result = PresenceMomentumPolicy.advance(
      previousScore: 0.35,
      elapsed: const Duration(minutes: 2),
      input: const PresenceMomentumInput(
        screenInteractive: true,
        busyScore: 0.68,
        dominantActivityMinutes: 35,
        appSwitchesLast30Minutes: 14,
        newNotificationCount: 6,
        newAccessibilityCount: 15,
        hasCurrentActivity: true,
        userIdleMinutes: 2,
      ),
    );

    expect(result.score, greaterThan(0.35));
    expect(result.shouldFeedThought, isFalse);
  });
}
