import 'dart:convert';
import 'dart:math' as math;

/// A short-lived causal trace, not a memory or a new fact about the user.
class MoodEvent {
  const MoodEvent({
    required this.id,
    required this.kind,
    required this.at,
    this.level = 'mild',
    this.source = 'conversation',
    this.replyId = '',
    this.targetId = '',
  });
  final String id, kind, level, source, replyId, targetId;
  final DateTime at;
  bool get relational => kind == 'hurt' || kind == 'boundary';
  bool get negative => relational || kind == 'disappointment';
  double get magnitude => switch (level) {
    'strong' => .22,
    'clear' => .12,
    _ => .045,
  };
  double get halfLifeMinutes => negative
      ? (level == 'strong'
            ? 100
            : level == 'clear'
            ? 45
            : 15)
      : (kind == 'playful' ? 25 : 45);
  double weight(DateTime now) {
    final minutes = now.difference(at).inMilliseconds / 60000;
    if (minutes < 0 || minutes >= halfLifeMinutes * 6) return 0;
    return magnitude * math.pow(.5, minutes / halfLifeMinutes);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'at': at.millisecondsSinceEpoch,
    'level': level,
    'source': source,
    'replyId': replyId,
    'targetId': targetId,
  };
  static const kinds = {
    'none',
    'playful',
    'connection',
    'discovery',
    'progress',
    'disappointment',
    'hurt',
    'boundary',
    'repair',
    'clarified',
  };
  static MoodEvent? decode(Object? value) {
    if (value is! Map ||
        !kinds.contains(value['kind']) ||
        value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        value['at'] is! int)
      return null;
    return MoodEvent(
      id: value['id'] as String,
      kind: value['kind'] as String,
      at: DateTime.fromMillisecondsSinceEpoch(value['at'] as int),
      level: const {'mild', 'clear', 'strong'}.contains(value['level'])
          ? value['level'] as String
          : 'mild',
      source: value['source'] as String? ?? 'conversation',
      replyId: value['replyId'] as String? ?? '',
      targetId: value['targetId'] as String? ?? '',
    );
  }

  static List<MoodEvent> decodeList(String? raw) {
    try {
      final decoded = jsonDecode(raw ?? '[]');
      if (decoded is! List) return [];
      return decoded.map(decode).whereType<MoodEvent>().take(96).toList();
    } catch (_) {
      return [];
    }
  }
}

class MoodSnapshot {
  const MoodSnapshot({
    required this.valence,
    required this.activation,
    this.causes = const [],
    this.resting = false,
    this.weatherAvailable = false,
  });
  final double valence, activation;
  final List<MoodEvent> causes;
  final bool resting, weatherAvailable;
  String get label => valence < .43
      ? (activation > .48 ? '有些不快' : '有些低落')
      : valence > .65
      ? (activation > .48 ? '兴致较好' : '轻松愉快')
      : activation > .50
      ? '有些起兴'
      : '平和';
  Map<String, Object?> diagnostic() => {
    'label': label,
    'valence': valence,
    'activation': activation,
    'resting': resting,
    'weatherBackgroundAvailable': weatherAvailable,
    'causes': causes.map((e) => e.toJson()).toList(),
  };
}

/// Recomputed from bounded events: reads do not tick, accumulate or reward
/// themselves. Removing a cancelled/regenerated turn also removes its effect.
class MoodPolicy {
  static MoodSnapshot evaluate(
    Iterable<MoodEvent> input,
    DateTime now, {
    double fatigue = 0,
    double stress = 0,
    bool weatherAvailable = false,
  }) {
    final unique = <String, MoodEvent>{for (final e in input) e.id: e};
    final events = unique.values.where((e) => !e.at.isAfter(now)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final resolved = <String, MoodEvent>{};
    for (final event in events) {
      if (event.targetId.isNotEmpty &&
          (event.kind == 'repair' || event.kind == 'clarified')) {
        final target = unique[event.targetId];
        if (target != null && target.negative && !target.at.isAfter(event.at)) {
          resolved[event.targetId] = event;
        }
      }
    }
    double positive = 0, negative = 0, activation = .35;
    final active = <MoodEvent>[];
    for (final event in events) {
      if (const {'none', 'repair', 'clarified'}.contains(event.kind)) continue;
      var weight = event.weight(now);
      final repair = resolved[event.id];
      if (repair != null) {
        // Clarifying a mistaken reading removes the injury; actual repair
        // leaves a small short-lived residue, not a forced instant smile.
        weight *= repair.kind == 'clarified'
            ? 0
            : .2 * math.pow(.5, now.difference(repair.at).inMinutes / 10);
      }
      if (weight < .008) continue;
      active.add(event);
      if (event.negative) {
        negative += weight;
        activation += weight * (event.relational ? .45 : -.35);
      } else {
        positive += weight;
        activation += weight * (event.kind == 'connection' ? -.15 : .6);
      }
    }
    // Saturation makes repeated tiny events unable to pin either extreme.
    double bounded(double value) => .3 * (1 - math.exp(-value / .3));
    final valence = (.55 + bounded(positive) - bounded(negative))
        .clamp(.25, .85)
        .toDouble();
    // Existing body state is a background, never another fatigue deduction.
    activation += stress.clamp(0, 1) * .05 - fatigue.clamp(0, 1) * .09;
    active.sort((a, b) => b.weight(now).compareTo(a.weight(now)));
    return MoodSnapshot(
      valence: valence,
      activation: activation.clamp(.15, .78).toDouble(),
      causes: active.take(3).toList(),
      resting: fatigue >= .66,
      weatherAvailable: weatherAvailable,
    );
  }
}
