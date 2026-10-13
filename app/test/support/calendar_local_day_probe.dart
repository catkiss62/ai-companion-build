import 'dart:convert';
import 'dart:io';

import '../../lib/core/phone/simulated_phone_policy.dart';

// Separate VM process: TZ must be set before Dart caches the local timezone.
void main() {
  final zone = Platform.environment['TZ'];
  final dates = switch (zone) {
    'America/New_York' => [DateTime(2026, 3, 9), DateTime(2026, 11, 2)],
    'Europe/Berlin' => [DateTime(2026, 3, 30), DateTime(2026, 10, 26)],
    'Australia/Lord_Howe' => [DateTime(2026, 10, 5), DateTime(2026, 4, 6)],
    _ => [DateTime(2026, 3, 9), DateTime(2026, 11, 2)],
  };
  final probes = [...dates, DateTime(2026, 1, 1), DateTime(2024, 3, 1)];
  stdout.writeln(jsonEncode({
    'zone': zone,
    'days': [for (final date in probes) {
      'date': SimulatedPhonePolicy.localDay(date),
      'previous': SimulatedPhonePolicy.previousLocalDay(date),
      'offsetMinutes': date.timeZoneOffset.inMinutes,
      'previousOffsetMinutes': DateTime(date.year, date.month, date.day - 1).timeZoneOffset.inMinutes,
      'hoursBetweenMidnights': date.difference(DateTime(date.year, date.month, date.day - 1)).inMinutes / 60,
    }],
    'utcInputPrevious': SimulatedPhonePolicy.previousLocalDay(DateTime.utc(2026, 3, 9, 1)),
  }));
}
