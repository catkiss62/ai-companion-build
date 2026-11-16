/// Rank fusion keeps lexical and semantic scales independent. Semantic admission
/// is deliberately modest; thresholds are versioned with the model and evaluated
/// against local fixtures rather than treated as calibrated probabilities.
class HybridMemoryRanking {
  static List<String> rank({
    required List<String> lexical,
    required Map<String, double> semantic,
    required int limit,
  }) {
    lexical = lexical.toSet().toList();
    final scores = <String, double>{};
    for (var i = 0; i < lexical.length; i++) {
      scores[lexical[i]] = 1 / (60 + i + 1);
    }
    final top = semantic.values.isEmpty
        ? 0.0
        : semantic.values.reduce((a, b) => a > b ? a : b);
    final accepted =
        semantic.entries
            .where((e) => e.value >= 0.50 && e.value >= top - 0.15)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    for (var i = 0; i < accepted.length; i++) {
      final e = accepted[i];
      scores[e.key] = (scores[e.key] ?? 0) + 1 / (60 + i + 1);
    }
    final ordered = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ordered.take(limit).map((e) => e.key).toList();
  }
}
