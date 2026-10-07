import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion_localfirst/core/phone/calendar_reminder_store.dart';

void main() {
  test('daily and selected weekdays schedule the next local occurrence', () {
    const daily = CalendarReminder(id:'daily',title:'每日',year:2026,month:10,day:8,
        yearly:false,recurrence:'daily',hour:9,minute:15);
    expect(daily.nextOccurrence(DateTime(2026,10,8,9,14)),DateTime(2026,10,8,9,15));
    expect(daily.nextOccurrence(DateTime(2026,10,8,9,15)),DateTime(2026,10,9,9,15));
    const weekly = CalendarReminder(id:'weekly',title:'星期',year:2026,month:10,day:8,
        yearly:false,recurrence:'weekly',weekdays:[1,5],hour:8,minute:0);
    expect(weekly.nextOccurrence(DateTime(2026,10,8,20)),DateTime(2026,10,9,8));
    expect(weekly.nextOccurrence(DateTime(2026,10,9,8)),DateTime(2026,10,12,8));
    expect(weekly.withEnabled(false).nextOccurrence(DateTime(2026,10,8)),isNull);
    expect(weekly.withEnabled(false).occursOn(DateTime(2026,10,9)),isFalse);
    final restored=CalendarReminder.fromJson(weekly.toJson());
    expect(restored.weekdays,[1,5]);expect(restored.repeat,'weekly');
    expect(restored.occurrenceTime('weekly:${DateTime(2026,10,9,8).millisecondsSinceEpoch}'),DateTime(2026,10,9,8));
  });
  test('legacy annual JSON and next leap day survive recurrence upgrade', () {
    final old=CalendarReminder.fromJson({'id':'old','title':'生日','year':2024,'month':2,'day':29,
      'yearly':true,'hour':9,'minute':0});
    expect(old.repeat,'yearly');expect(old.enabled,isTrue);
    expect(old.nextOccurrence(DateTime(2026,10,8)),DateTime(2028,2,29,9));
    expect(CalendarReminder.fromJson(old.toJson()).repeat,'yearly');
  });
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
  test('old alarm occurrences cannot follow a changed time or deleted identity', () {
    const reminder = CalendarReminder(id: 'id:with:colon', title: '事项',
        year: 2026, month: 10, day: 1, yearly: false, hour: 14, minute: 30);
    final due = DateTime(2026, 10, 1, 14, 30);
    expect(reminder.occurrenceTime('id:with:colon:${due.millisecondsSinceEpoch}'), due);
    expect(reminder.occurrenceTime('id:with:colon:${due.add(const Duration(minutes: 1)).millisecondsSinceEpoch}'), isNull);
    expect(reminder.occurrenceTime('different:${due.millisecondsSinceEpoch}'), isNull);
    expect(reminder.occurrenceTime('id:with:colon:invalid'), isNull);
  });

}
