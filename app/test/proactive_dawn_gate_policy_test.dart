import 'package:ai_companion_localfirst/core/desire/proactive_dawn_gate_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen-off dawn removes long-idle acceleration without a count cap', () {
    final adjusted = ProactiveDawnGatePolicy.adjust(
      now: DateTime(2026, 9, 3, 7, 20),
      activityContext: 'screen_off',
      rawIdleBoost: 0.24,
    );

    expect(adjusted.active, isTrue);
    expect(adjusted.idleBoost, ProactiveDawnGatePolicy.maxIdleBoost);
    expect(adjusted.thresholdPenalty, greaterThan(0));
    expect(adjusted.suppressLongIdleRelief, isTrue);
  });

  test('dawn boundaries and screen-on contexts keep the ordinary gate', () {
    for (final instant in <DateTime>[
      DateTime(2026, 9, 3, 4, 59),
      DateTime(2026, 9, 3, 9),
    ]) {
      final adjusted = ProactiveDawnGatePolicy.adjust(
        now: instant,
        activityContext: 'screen_off',
        rawIdleBoost: 0.24,
      );
      expect(adjusted.active, isFalse);
      expect(adjusted.idleBoost, 0.24);
      expect(adjusted.thresholdPenalty, 0);
      expect(adjusted.suppressLongIdleRelief, isFalse);
    }

    final screenOn = ProactiveDawnGatePolicy.adjust(
      now: DateTime(2026, 9, 3, 7),
      activityContext: 'idle',
      rawIdleBoost: 0.24,
    );
    expect(screenOn.active, isFalse);
  });

  test('strong intent still has a score path through the adjusted gate', () {
    final adjusted = ProactiveDawnGatePolicy.adjust(
      now: DateTime(2026, 9, 3, 7),
      activityContext: 'screen_off',
      rawIdleBoost: 0.24,
    );
    const strongIntent = 0.92;
    const maximumPositiveJitter = 0.05;
    final gateScore = strongIntent + adjusted.idleBoost + maximumPositiveJitter;
    final threshold = 0.60 + adjusted.thresholdPenalty;

    expect(gateScore, greaterThan(threshold));
  });
}
