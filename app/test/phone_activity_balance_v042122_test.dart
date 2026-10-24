import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/presence/phone_activity_evidence.dart';
import 'package:ai_companion_localfirst/core/presence/presence_intelligence.dart';

void main() {
  PresenceMomentumResult step({double previous = 0, double minutes = 0,
    int switches = 0, int events = 0, bool reset = false, int idle = 60,
    bool interactive = true}) => PresenceMomentumPolicy.advance(
    previousScore: previous, elapsed: Duration(minutes: minutes.toInt()),
    input: PresenceMomentumInput(screenInteractive: interactive,
      evidence: PhoneActivityEvidence(reset: reset, reason: 'fixture',
        activeMinutes: minutes, switches: switches, accessibilityEvents: events),
      busyScore: .5, dominantActivityMinutes: 40, appSwitchesLast30Minutes: switches,
      newNotificationCount: 99, newAccessibilityCount: events,
      hasCurrentActivity: true, userIdleMinutes: idle));

  test('+365 usage, switching and UI rewards are each exactly half, including caps', () {
    expect(step(minutes: 4).impulse, closeTo(4 * .009 * .5, 1e-10));
    expect(step(switches: 7).impulse, closeTo(.025, 1e-10));
    expect(step(events: 6).impulse, closeTo(.025, 1e-10));
    expect(step(minutes: 60, switches: 100, events: 100).impulse,
      closeTo((.27 + .10 + .10) * .5, 1e-10));
  });
  test('switching and UI evidence retain separate +365 rewards', () {
    expect(step(minutes: 4, switches: 14, events: 12).impulse,
      closeTo(.118, 1e-10));
  });
  test('same old decay and threshold, with half rewards', () {
    final result = step(previous: .4, minutes: 4, events: 6);
    expect(result.score, greaterThan(.4));
    expect(result.shouldFeedThought, isTrue);
    expect(step(minutes: 4, events: 6).shouldFeedThought, isFalse);
    expect(step(previous: .8, minutes: 4, events: 12, idle: 2).shouldFeedThought, isFalse);
  });
  test('screen off, reset and notification counts never grant phone rewards', () {
    expect(step(minutes: 4, events: 12, interactive: false).impulse, 0);
    expect(step(minutes: 4, switches: 14, events: 12, reset: true).impulse, 0);
    expect(step().impulse, 0);
  });
}
