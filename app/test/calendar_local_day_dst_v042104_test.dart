import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <String, ({List<String> previous, List<int> offsets, List<int> beforeOffsets, List<double> hours, String utcPrevious})>{
    'America/New_York': (previous: ['2026-03-08', '2026-11-01'], offsets: [-240, -300], beforeOffsets: [-300, -240], hours: [23, 25], utcPrevious: '2026-03-07'),
    'Europe/Berlin': (previous: ['2026-03-29', '2026-10-25'], offsets: [120, 60], beforeOffsets: [60, 120], hours: [23, 25], utcPrevious: '2026-03-08'),
    'Australia/Lord_Howe': (previous: ['2026-10-04', '2026-04-05'], offsets: [660, 630], beforeOffsets: [630, 660], hours: [23.5, 24.5], utcPrevious: '2026-03-08'),
    'UTC': (previous: ['2026-03-08', '2026-11-01'], offsets: [0, 0], beforeOffsets: [0, 0], hours: [24, 24], utcPrevious: '2026-03-08'),
    'Asia/Shanghai': (previous: ['2026-03-08', '2026-11-01'], offsets: [480, 480], beforeOffsets: [480, 480], hours: [24, 24], utcPrevious: '2026-03-08'),
  };
  for (final entry in cases.entries) {
    test('production previousLocalDay uses actual process timezone ${entry.key}', () async {
      final child = await Process.run('dart', ['test/support/calendar_local_day_probe.dart'],
        workingDirectory: Directory.current.path, environment: {'TZ': entry.key})
        .timeout(const Duration(seconds: 20));
      expect(child.exitCode, 0, reason: '${child.stderr}');
      final result = jsonDecode(child.stdout as String) as Map;
      expect(result['zone'], entry.key);
      final days = (result['days'] as List).cast<Map>();
      for (var i = 0; i < 2; i++) {
        expect(days[i]['offsetMinutes'], entry.value.offsets[i], reason: 'TZ must really affect DateTime');
        expect(days[i]['previousOffsetMinutes'], entry.value.beforeOffsets[i]);
        expect(days[i]['hoursBetweenMidnights'], entry.value.hours[i]);
        expect(days[i]['previous'], entry.value.previous[i]);
      }
      expect(days[2]['previous'], '2025-12-31');
      expect(days[3]['previous'], '2024-02-29');
      expect(result['utcInputPrevious'], entry.value.utcPrevious);
    });
  }
}
