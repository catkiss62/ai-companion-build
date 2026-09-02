import 'package:ai_companion_localfirst/core/phone/mood_chart_layout.dart';
import 'package:ai_companion_localfirst/features/phone/simulated_phone_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mood chart always exposes seven natural-day slots', () {
    final layout = MoodChartLayout.build(
      now: DateTime(2026, 9, 8, 20),
      samples: const [],
    );

    expect(layout.labels, [
      '09-02',
      '09-03',
      '09-04',
      '09-05',
      '09-06',
      '09-07',
      '09-08',
    ]);
    expect(layout.points, isEmpty);
  });

  test('same-day samples stay separated inside their natural-day slot', () {
    final layout = MoodChartLayout.build(
      now: DateTime(2026, 9, 8, 20),
      samples: [
        MoodChartSample(
          sourceIndex: 0,
          localDay: '2026-09-07',
          createdAt: DateTime(2026, 9, 7, 9),
          value: 45,
        ),
        MoodChartSample(
          sourceIndex: 1,
          localDay: '2026-09-07',
          createdAt: DateTime(2026, 9, 7, 18),
          value: 72,
        ),
        MoodChartSample(
          sourceIndex: 2,
          localDay: '2026-09-08',
          createdAt: DateTime(2026, 9, 8, 12),
          value: 60,
        ),
        MoodChartSample(
          sourceIndex: 3,
          localDay: '2026-08-31',
          createdAt: DateTime(2026, 8, 31, 12),
          value: 10,
        ),
      ],
    );

    expect(layout.points, hasLength(3));
    expect(layout.points[0].dayIndex, 5);
    expect(layout.points[1].dayIndex, 5);
    expect(layout.points[0].dayFraction, lessThan(layout.points[1].dayFraction));
    expect(layout.points[0].dayFraction, inInclusiveRange(5.0, 6.0));
    expect(layout.points[1].dayFraction, inInclusiveRange(5.0, 6.0));
    expect(layout.points[2].dayIndex, 6);
    expect(layout.points[2].dayFraction, inInclusiveRange(6.0, 7.0));
  });

  testWidgets('chart claims the available card width without a child',
      (tester) async {
    final layout = MoodChartLayout.build(
      now: DateTime(2026, 9, 8, 20),
      samples: [
        MoodChartSample(
          sourceIndex: 0,
          localDay: '2026-09-08',
          createdAt: DateTime(2026, 9, 8, 12),
          value: 60,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 224,
                  child: MoodChart(
                    layout: layout,
                    selected: null,
                    onSelected: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(CustomPaint)).width, 360);
  });
}
