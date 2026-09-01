import 'package:ai_companion_localfirst/core/perception/screen_off_contact_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one screen-off session opens at most one bounded contact window', () {
    final offAt = DateTime(2026, 9, 2, 12);
    final first = ScreenOffContactPolicy.evaluate(
      now: DateTime(2026, 9, 2, 13, 29),
      screenOffAt: offAt,
      lastPulsedSessionKey: '',
      currentFatigue: 0.16,
    );
    expect(first.eligible, isFalse);
    expect(first.reason, 'minimum_silence_not_reached');

    final opened = ScreenOffContactPolicy.evaluate(
      now: DateTime(2026, 9, 2, 13, 30),
      screenOffAt: offAt,
      lastPulsedSessionKey: '',
      currentFatigue: 0.16,
    );
    expect(opened.eligible, isTrue);
    expect(opened.socialPulse, closeTo(0.010, 1e-9));

    final duplicate = ScreenOffContactPolicy.evaluate(
      now: DateTime(2026, 9, 2, 16),
      screenOffAt: offAt,
      lastPulsedSessionKey: opened.sessionKey,
      currentFatigue: 0.16,
    );
    expect(duplicate.eligible, isFalse);
    expect(duplicate.reason, 'same_screen_off_session');
  });

  test('late-night fatigue sharply reduces but does not invert the pulse', () {
    final offAt = DateTime(2026, 9, 2, 20);
    final evening = ScreenOffContactPolicy.evaluate(
      now: DateTime(2026, 9, 2, 22),
      screenOffAt: offAt,
      lastPulsedSessionKey: '',
      currentFatigue: 0.16,
    );
    final deepNight = ScreenOffContactPolicy.evaluate(
      now: DateTime(2026, 9, 3, 1),
      screenOffAt: offAt,
      lastPulsedSessionKey: '',
      currentFatigue: 0.16,
    );

    expect(evening.eligible, isTrue);
    expect(evening.socialPulse, lessThan(0.007));
    expect(deepNight.socialPulse, lessThan(0.001));
    expect(deepNight.socialPulse, greaterThan(0));
  });
}
