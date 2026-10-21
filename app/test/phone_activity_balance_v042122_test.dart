import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/presence/phone_activity_evidence.dart';
import 'package:ai_companion_localfirst/core/presence/presence_intelligence.dart';

void main() {
  PresenceMomentumResult step(double previous, int seconds, {
    bool active = true, bool events = false, bool switches = false,
    bool reset = false, int idle = 60,
  }) => PresenceMomentumPolicy.advance(
    previousScore: previous,
    elapsed: Duration(seconds: seconds),
    input: PresenceMomentumInput(
      screenInteractive: true,
      evidence: PhoneActivityEvidence(
        reset: reset, reason: 'test', activeMinutes: active ? seconds / 60 : 0,
        switches: switches ? seconds ~/ 15 : 0,
        accessibilityEvents: events ? seconds ~/ 5 : 0,
      ),
      busyScore: 0.5, dominantActivityMinutes: 40,
      appSwitchesLast30Minutes: 0, newNotificationCount: 99,
      newAccessibilityCount: 0, hasCurrentActivity: active, userIdleMinutes: idle,
    ),
  );
  PresenceMomentumResult simulate(int seconds, int total, {bool events = false, bool switches = false}) {
    var state = step(0, 0);
    for (var elapsed = 0; elapsed < total; elapsed += seconds) {
      state = step(state.score, seconds, events: events, switches: switches);
    }
    return state;
  }
  for (final events in [false, true]) {
    test('same 24 minutes, 90s and 4m cadence agree; UI events=$events', () {
      final quick = simulate(90, 24 * 60, events: events);
      final slow = simulate(240, 24 * 60, events: events);
      expect(quick.score, closeTo(slow.score, 0.000001));
      expect(quick.shouldFeedThought, slow.shouldFeedThought);
      expect(quick.shouldFeedThought, isTrue);
    });
  }
  test('switches and UI events share one supplement budget', () {
    final ui = step(0, 240, events: true);
    final both = step(0, 240, events: true, switches: true);
    expect(both.score, closeTo(ui.score, 0.000001));
    expect(both.impulse, closeTo(4 * (0.009 + 0.003), 0.000001));
  });
  test('passive UI changes alone remain below the contact thought threshold', () {
    var score = 0.0;
    for (var i = 0; i < 80; i++) {
      final result = step(score, 90, active: false, events: true);
      expect(result.shouldFeedThought, isFalse);
      score = result.score;
    }
    expect(score, lessThan(0.34));
  });
  test('notifications, reset, zero time and recent chat do not earn contact', () {
    expect(step(0, 240, active: false).impulse, 0);
    expect(step(0.8, 240, events: true, reset: true).impulse, 0);
    expect(step(0, 0, active: false, events: true).score, 0);
    expect(step(0.8, 240, events: true, idle: 2).shouldFeedThought, isFalse);
  });
}
