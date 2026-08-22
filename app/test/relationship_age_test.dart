import 'package:ai_companion_localfirst/core/relationship/relationship_age.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first local calendar day is relationship day one', () {
    final age = RelationshipAge(
      startedAt: DateTime(2026, 8, 22, 23, 59),
      now: DateTime(2026, 8, 22, 23, 59, 59),
    );
    expect(age.elapsedCalendarDays, 0);
    expect(age.dayNumber, 1);
  });

  test('crossing local midnight advances the relationship day', () {
    final age = RelationshipAge(
      startedAt: DateTime(2026, 8, 22, 23, 59),
      now: DateTime(2026, 8, 23, 0, 1),
    );
    expect(age.elapsedCalendarDays, 1);
    expect(age.dayNumber, 2);
  });

  test('time before stored start never produces day zero or negative days', () {
    final age = RelationshipAge(
      startedAt: DateTime(2026, 8, 23),
      now: DateTime(2026, 8, 22),
    );
    expect(age.elapsedCalendarDays, 0);
    expect(age.dayNumber, 1);
  });
}
