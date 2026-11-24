import 'dart:math';
import 'dart:typed_data';

import '../ai/generation_cancellation.dart';
import '../memory/local_semantic_index.dart';

typedef _Passage = ({int turn, String source, String text, String url});
typedef _Hit = ({_Passage passage, double score});

/// Vectors live only in the open work conversation. Search candidates always
/// come from a fresh reading of that thread, including pre-index task files.
class CommissionHistorySearch {
  CommissionHistorySearch({LocalSemanticIndex? encoder})
    : encoder = encoder ?? LocalSemanticIndex();
  final LocalSemanticIndex encoder;
  final _vectors = <String, Float32List>{};

  void clear() => _vectors.clear();

  Iterable<_Passage> _passages(List<Map<String, dynamic>> rows) sync* {
    for (var i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      final fields = [
        ('用户', row['goal'], ''),
        ('交付', row['answer'], ''),
        for (final e in (row['evidence'] as List? ?? []).whereType<Map>())
          if (e['repository'] is String && e['readme_excerpt'] is String)
            (
              'README · ${e['repository']}',
              e['readme_excerpt'],
              e['url']?.toString() ?? '',
            ),
      ];
      for (final (source, value, url) in fields) {
        if (value is! String || value.trim().isEmpty) continue;
        final points = value.runes.toList();
        for (var start = 0; start < points.length; start += 320) {
          final end = min(start + 360, points.length);
          yield (
            turn: i + 1,
            source: source,
            text: String.fromCharCodes(points, start, end),
            url: url,
          );
          if (end == points.length) break;
        }
      }
    }
  }

  static Set<String> _terms(String text) {
    final terms = <String>{};
    for (final m in RegExp(
      r'[a-z0-9_./-]+|[\u3400-\u9fff]+',
    ).allMatches(text.toLowerCase())) {
      final word = m[0]!;
      if (word.codeUnitAt(0) < 128 || word.length == 1) {
        terms.add(word);
      } else {
        for (var i = 1; i < word.length; i++) {
          terms.add(word.substring(i - 1, i + 1));
        }
      }
    }
    return terms;
  }

  Future<Map<String, Object?>> search(
    String query,
    List<Map<String, dynamic>> rows,
    GenerationCancellationToken cancel, {
    int? turn,
  }) async {
    final passages = _passages(rows).toList();
    final live = passages.map((p) => p.text).toSet();
    _vectors.removeWhere((key, _) => !live.contains(key));
    final terms = _terms(query);
    final candidates = <_Hit>[];
    for (final p in passages) {
      if (turn != null && p.turn != turn) continue;
      final text = '${p.source} ${p.text}'.toLowerCase();
      final overlap = terms.where(text.contains).length / max(1, terms.length);
      candidates.add((
        passage: p,
        score: text.contains(query.toLowerCase()) ? 1 : overlap,
      ));
    }
    int rank(_Hit a, _Hit b) {
      final order = b.score.compareTo(a.score);
      return order == 0 ? b.passage.turn.compareTo(a.passage.turn) : order;
    }

    candidates.sort(rank);
    final clock = Stopwatch()..start();
    const budget = Duration(seconds: 3);
    Float32List? q;
    if (encoder.enabled && candidates.isNotEmpty) {
      try {
        cancel.throwIfCancelled();
        q = (await encoder.encodeBatch([query], budget)).single;
        final missing = candidates
            .map((e) => e.passage.text)
            .where((s) => !_vectors.containsKey(s))
            .toSet()
            .toList();
        for (var i = 0; i < missing.length && clock.elapsed < budget; i += 4) {
          cancel.throwIfCancelled();
          final batch = missing.sublist(i, min(i + 4, missing.length));
          final encoded = await encoder.encodeBatch(
            batch,
            budget - clock.elapsed,
          );
          cancel.throwIfCancelled();
          _vectors.addAll(Map.fromIterables(batch, encoded));
          while (_vectors.length > 1024) {
            _vectors.remove(_vectors.keys.first);
          }
        }
      } catch (_) {
        cancel.throwIfCancelled();
        // Exact text lookup still works when the local model is unavailable.
      }
    }
    // Short paraphrases in the bundled mean-pooled BGE model often score
    // around 0.5. Keep the best neighborhood above an absolute noise floor.
    final semantic = <String, double>{};
    var best = 0.0;
    if (q != null) {
      for (final text in candidates.map((c) => c.passage.text).toSet()) {
        final v = _vectors[text];
        if (v == null) continue;
        var similarity = 0.0;
        for (var i = 0; i < q.length; i++) {
          similarity += q[i] * v[i];
        }
        semantic[text] = similarity;
        best = max(best, similarity);
      }
    }
    final semanticFloor = max(.47, best - .03);
    final hits = <_Hit>[];
    for (final item in candidates) {
      final similarity = semantic[item.passage.text] ?? 0;
      if (item.score >= .35 || similarity >= semanticFloor || turn != null) {
        hits.add((passage: item.passage, score: max(item.score, similarity)));
      }
    }
    hits.sort(rank);
    final seen = <String>{};
    final selected = <_Passage>[];
    for (final h in hits) {
      if (seen.add(h.passage.text)) selected.add(h.passage);
      if (selected.length == 3) break;
    }
    // A later related correction can rank below the original exact wording.
    if (selected.isNotEmpty && turn == null) {
      final first = selected.first.turn;
      final revisions =
          hits
              .map((h) => h.passage)
              .where(
                (p) =>
                    p.turn > first &&
                    RegExp('改成|改为|更正|纠正|修订|订正|最终|作废|取消原').hasMatch(p.text),
              )
              .toList()
            ..sort((a, b) => b.turn.compareTo(a.turn));
      if (revisions.isNotEmpty && seen.add(revisions.first.text)) {
        selected.add(revisions.first);
      }
    }
    selected.sort((a, b) => a.turn.compareTo(b.turn));
    return {
      'matches': [
        for (final p in selected)
          {
            'turn': p.turn,
            'source': p.source,
            'excerpt': p.text,
            if (p.url.isNotEmpty) 'url': p.url,
          },
      ],
      'thread_turns': rows.length,
    };
  }
}
