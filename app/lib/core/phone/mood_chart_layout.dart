class MoodChartSample {
  const MoodChartSample({
    required this.sourceIndex,
    required this.localDay,
    required this.createdAt,
    required this.value,
  });

  final int sourceIndex;
  final String localDay;
  final DateTime createdAt;
  final double value;
}

class MoodChartPointLayout {
  const MoodChartPointLayout({
    required this.sample,
    required this.dayIndex,
    required this.dayFraction,
  });

  final MoodChartSample sample;
  final int dayIndex;

  /// Position inside seven equal-width day slots. Day 0 occupies [0, 1),
  /// day 6 occupies [6, 7). Multiple samples stay inside their own day slot.
  final double dayFraction;
}

class MoodChartWindowLayout {
  const MoodChartWindowLayout({
    required this.labels,
    required this.points,
  });

  final List<String> labels;
  final List<MoodChartPointLayout> points;
}

abstract final class MoodChartLayout {
  static MoodChartWindowLayout build({
    required DateTime now,
    required List<MoodChartSample> samples,
  }) {
    final today = _dateOnly(now.toLocal());
    final firstDay = today.subtract(const Duration(days: 6));
    final labels = List<String>.generate(7, (index) {
      final day = firstDay.add(Duration(days: index));
      return '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
    }, growable: false);
    final byDay = <int, List<MoodChartSample>>{};
    for (final sample in samples) {
      final parsed = DateTime.tryParse(sample.localDay);
      if (parsed == null) continue;
      final day = _dateOnly(parsed.toLocal());
      final dayIndex = day.difference(firstDay).inDays;
      if (dayIndex < 0 || dayIndex > 6) continue;
      byDay.putIfAbsent(dayIndex, () => []).add(sample);
    }
    final points = <MoodChartPointLayout>[];
    for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
      final daySamples = byDay[dayIndex] ?? const <MoodChartSample>[];
      final ordered = [...daySamples]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (var index = 0; index < ordered.length; index++) {
        final offset = ordered.length == 1
            ? 0.0
            : -0.24 + (0.48 * index / (ordered.length - 1));
        points.add(
          MoodChartPointLayout(
            sample: ordered[index],
            dayIndex: dayIndex,
            dayFraction: dayIndex + 0.5 + offset,
          ),
        );
      }
    }
    return MoodChartWindowLayout(
      labels: List.unmodifiable(labels),
      points: List.unmodifiable(points),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
}
