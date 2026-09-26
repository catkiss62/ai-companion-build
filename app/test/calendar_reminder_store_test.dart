import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion_localfirst/core/phone/calendar_reminder_store.dart';

void main() {
  test('annual leap-day event belongs only to a real February 29', () {
    const reminder = CalendarReminder(
      id: 'leap', title: '闰日', year: 2024, month: 2, day: 29,
      yearly: true,
    );
    expect(reminder.occursOn(DateTime(2028, 2, 29)), isTrue);
    expect(reminder.occursOn(DateTime(2027, 2, 28)), isFalse);
    expect(reminder.occursOn(DateTime(2027, 3, 1)), isFalse);
    expect(reminder.timed, isFalse);
    expect(reminder.toJson().containsKey('hour'), isFalse);
  });

  test('one-time timed event does not repeat the following year', () {
    const reminder = CalendarReminder(
      id: 'once', title: '约定', year: 2026, month: 9, day: 26,
      yearly: false, hour: 14, minute: 30,
    );
    expect(reminder.occursOn(DateTime(2026, 9, 26)), isTrue);
    expect(reminder.occursOn(DateTime(2027, 9, 26)), isFalse);
    expect(CalendarReminder.fromJson(reminder.toJson()).timed, isTrue);
  });
}
