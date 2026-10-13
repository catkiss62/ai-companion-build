import 'dart:convert';

import '../models/personality_learning.dart';

/// Replays evidence in source order. Processing time and lifetime majorities
/// cannot remove a user boundary or supply votes to a newly permitted epoch.
abstract final class PersonalityLearningLifecycle {
  static Map<String, dynamic> metadata(Object? raw) {
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      return value is Map ? Map<String, dynamic>.from(value) : {};
    } catch (_) { return {}; }
  }

  static Map<String, Object?> reduce(List<Map<String, Object?>> evidence) {
    final rows = evidence.toList()..sort((a, b) {
      final am = metadata(a['lifecycle_json']);
      final bm = metadata(b['lifecycle_json']);
      final as = (am['source_seq'] as num?)?.toInt() ?? 0;
      final bs = (bm['source_seq'] as num?)?.toInt() ?? 0;
      final order = as > 0 && bs > 0
          ? as.compareTo(bs)
          : ((a['observed_at'] as num?)?.toInt() ?? 0)
              .compareTo((b['observed_at'] as num?)?.toInt() ?? 0);
      if (order != 0) return order;
      // Ambiguous same-time order cannot resolve a boundary.
      if (a['polarity'] != b['polarity']) return a['polarity'] == 'contradict' ? 1 : -1;
      return (a['id'] as String).compareTo(b['id'] as String);
    });
    final barriers = <String>{};
    var support = 0.0, contradiction = 0.0;
    var supports = 0, contradictions = 0;
    var first = 0, last = 0, barrierAt = -1, barrierSeq = 0;
    var epoch = '';
    for (final row in rows) {
      final at = (row['observed_at'] as num?)?.toInt() ?? 0;
      if (first == 0 || at < first) first = at;
      if (at > last) last = at;
      final id = row['id'] as String;
      final meta = metadata(row['lifecycle_json']);
      final seq = (meta['source_seq'] as num?)?.toInt() ?? 0;
      final weight = (row['weight'] as num?)?.toDouble() ?? 0.0;
      if (row['polarity'] == 'contradict') {
        // Even a withdrawn boundary closes the historical evidence epoch;
        // removal must not resurrect the old majority automatically.
        barriers.add(id);
        support = 0; supports = 0;
        contradiction += weight; contradictions += 1;
        barrierAt = at; barrierSeq = seq;
        continue;
      }
      if (row['source_valid'] == 0) continue;
      if (barriers.isNotEmpty) {
        final resolves = (meta['resolves'] as List?)?.whereType<String>().toSet() ?? <String>{};
        final later = seq > 0 && barrierSeq > 0 ? seq > barrierSeq : at > barrierAt;
        if (!later || !resolves.containsAll(barriers)) continue;
        barriers.clear(); contradiction = 0; contradictions = 0;
        support = 0; supports = 0; epoch = id;
      }
      support += weight; supports += 1;
    }
    final maturity = PersonalityLearningMaturityPolicy.evaluate(
      supportScore: support, contradictionScore: contradiction,
      supportCount: supports, contradictionCount: contradictions,
      latestPolarity: barriers.isEmpty ? PersonalityLearningPolarity.support : PersonalityLearningPolarity.contradict,
      latestKind: PersonalityLearningEvidenceKind.explicitPreference,
    );
    return {
      'status': barriers.isNotEmpty ? 'contradicted' : maturity.status.key,
      'confidence': maturity.confidence,
      'support_count': supports, 'contradiction_count': contradictions,
      'support_score': support, 'contradiction_score': contradiction,
      'first_observed_at': first, 'last_observed_at': last,
      'established_at': barriers.isEmpty && maturity.status == PersonalityLearningStatus.established ? last : null,
      'contradicted_at': barriers.isNotEmpty ? barrierAt : null,
      'lifecycle_json': jsonEncode({'contract': 1, 'blocked': barriers.isNotEmpty,
        'barriers': barriers.toList()..sort(), 'epoch': epoch}),
    };
  }
}
