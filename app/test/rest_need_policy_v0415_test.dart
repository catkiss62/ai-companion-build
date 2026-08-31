import 'package:ai_companion_localfirst/core/emotion/rest_need_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rest need enters once and remains continuous inside hysteresis', () {
    final entered = RestNeedPolicy.evaluate(
      fatigue: .68,
      stress: .2,
      currentlyActive: false,
    );
    expect(entered.active, isTrue);
    expect(entered.resolve, isFalse);

    final sustained = RestNeedPolicy.evaluate(
      fatigue: .58,
      stress: .2,
      currentlyActive: true,
    );
    expect(sustained.active, isTrue);
    expect(sustained.resolve, isFalse);
  });

  test('morning recovery crosses the lower threshold and resolves', () {
    final recovered = RestNeedPolicy.evaluate(
      fatigue: .40,
      stress: .30,
      currentlyActive: true,
    );
    expect(recovered.active, isFalse);
    expect(recovered.resolve, isTrue);
  });

  test('stress can create the same rest episode without message-count input', () {
    final stressed = RestNeedPolicy.evaluate(
      fatigue: .30,
      stress: .86,
      currentlyActive: false,
    );
    expect(stressed.active, isTrue);
    expect(stressed.causeCode, 'drive_stress_high');
    expect(stressed.intensity, closeTo(.86, .001));
  });
}
