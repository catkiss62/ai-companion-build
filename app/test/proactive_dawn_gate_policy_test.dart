import 'package:ai_companion_localfirst/core/desire/proactive_dawn_gate_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all night contexts remove silence acceleration', () {
    for (final hour in [0, 3, 5, 8]) {
      for (final context in ['screen_off', 'idle', 'game']) {
        final result = ProactiveDawnGatePolicy.adjust(
          now: DateTime(2026, 10, 5, hour),
          activityContext: context,
          rawIdleBoost: .24,
        );
        expect(result.idleBoost, 0);
        expect(result.suppressLongIdleRelief, isTrue);
        expect(result.active, hour >= 5 && context == 'screen_off');
        expect(
          result.thresholdPenalty,
          hour >= 5 && context == 'screen_off' ? .10 : 0,
        );
      }
    }
  });
  test('09:00 and late evening keep ordinary daytime motivation', () {
    for (final hour in [9, 19, 21, 23]) {
      final result = ProactiveDawnGatePolicy.adjust(
        now: DateTime(2026, 10, 5, hour),
        activityContext: 'screen_off',
        rawIdleBoost: .24,
      );
      expect(result.idleBoost, .24);
      expect(result.suppressLongIdleRelief, isFalse);
      expect(result.thresholdPenalty, 0);
      expect(
        ProactiveNightContactCapPolicy.windowStart(DateTime(2026, 10, 5, hour)),
        isNull,
      );
    }
  });
  test(
    '00:00 through 08:59 shares two opportunities, including UTC clocks',
    () {
      for (final time in [
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 5, 8, 59),
        DateTime.utc(2026, 10, 5, 8, 59),
      ]) {
        final start = ProactiveNightContactCapPolicy.windowStart(time)!;
        expect(start.day, 5);
        expect(start.hour, 0);
        expect(start.isUtc, time.isUtc);
        expect(
          ProactiveNightContactCapPolicy.blocks(
            now: time,
            deliveredSinceWindowStart: 1,
          ),
          isFalse,
        );
        expect(
          ProactiveNightContactCapPolicy.blocks(
            now: time,
            deliveredSinceWindowStart: 2,
          ),
          isTrue,
        );
      }
    },
  );
  test('strong motivation can still pass the screen-off dawn gate', () {
    final result = ProactiveDawnGatePolicy.adjust(
      now: DateTime(2026, 10, 5, 7),
      activityContext: 'screen_off',
      rawIdleBoost: .24,
    );
    expect(.92 + result.idleBoost, greaterThan(.60 + result.thresholdPenalty));
  });
}
