import 'package:ai_companion_localfirst/core/desire/proactive_outcome_fit_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deferred can never teach a positive delivery time', () {
    expect(
      ProactiveOutcomeFitPolicy.timing(
        outcome: 'deferred',
        proposed: 0.5,
        responseLatencySeconds: 60,
      ),
      -0.60,
    );
    expect(
      ProactiveOutcomeFitPolicy.topic(outcome: 'deferred', proposed: 0.5),
      0.15,
    );
  });

  test('three-hour and very late replies cannot reinforce timing', () {
    expect(
      ProactiveOutcomeFitPolicy.timing(
        outcome: 'engaged',
        proposed: 0.8,
        responseLatencySeconds: 3 * 3600 + 35 * 60,
      ),
      -0.15,
    );
    expect(
      ProactiveOutcomeFitPolicy.timing(
        outcome: 'acknowledged',
        proposed: 0.8,
        responseLatencySeconds: 7 * 3600,
      ),
      -0.35,
    );
  });

  test('quick engaged replies preserve bounded positive evidence', () {
    expect(
      ProactiveOutcomeFitPolicy.timing(
        outcome: 'engaged',
        proposed: 0.55,
        responseLatencySeconds: 10 * 60,
      ),
      0.55,
    );
    expect(
      ProactiveOutcomeFitPolicy.timing(
        outcome: 'engaged',
        proposed: 0.35,
        responseLatencySeconds: null,
      ),
      0.35,
    );
  });
}
