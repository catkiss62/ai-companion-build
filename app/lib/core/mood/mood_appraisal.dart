import '../ai/jev_decision_gateway.dart';
import 'mood_state.dart';

/// Optional independent questions in the EXISTING pre-reply Jev batch.
/// Confidence only gates evidence; it never becomes emotional intensity.
class MoodAppraisal {
  static const questions = <String, JevChoiceQuestion>{
    'mood_event': JevChoiceQuestion(
      'Judge the latest REAL user participation in the recent exchange, not keywords. '
      'The assistant may have invited teasing: reciprocal jokes, mock anger, embarrassment '
      'and Q-form play are NOT relationship injury. Criticism of a wrong answer, differing '
      'opinions, brief replies, going offline, declining and asking her to stop are NOT injury. '
      'Quotes, fictional roles and hypothetical scenes are none. Previous assistant claims '
      'of being hurt alone cannot prove injury. Use pending_cause only to interpret genuine '
      'repair/clarification of that specific incident; a new unrelated topic is not repair. '
      'Uncertain harm is none; clear present harm can count once.',
      {
        'none': 'Ordinary or ambiguous; no grounded lasting mood change.',
        'playful':
            'Enjoyable reciprocal play, amusement or shared playful pride.',
        'connection':
            'A real moment of mutual understanding, warmth or reassurance.',
        'discovery':
            'An engaging new idea or shared discovery genuinely raises interest.',
        'disappointment':
            'Concrete mild letdown unrelated to punishing lack of attention.',
        'hurt':
            'Clear sincere personally hurtful treatment of her, not banter, task criticism or fiction.',
        'boundary':
            'Clear intentional continuation across a specific sincerely expressed boundary, not mock resistance.',
        'repair':
            'Addresses pending_cause with genuine reconciliation; does not imply instant happiness.',
        'clarified':
            'Specifically clarifies pending_cause was misunderstood, e.g. reciprocal play rather than actual harm.',
      },
      optional: true,
      resolve: resolveEvent,
    ),
    'mood_impact': JevChoiceQuestion(
      'Independently estimate actual emotional impact of this real exchange, NOT confidence '
      'in the category. Most turns are none or mild. Strong needs a genuinely significant '
      'event, not vivid wording, heat level, flirtation or assistant dramatization.',
      {
        'none': 'No clear impact.',
        'mild': 'Small local ripple.',
        'clear': 'Meaningful but moderate impact.',
        'strong': 'Clearly substantial real impact.',
      },
      optional: true,
      resolve: resolveImpact,
    ),
  };
  static String resolveEvent(Map<String, double> probabilities) {
    const positive = {'playful', 'connection', 'discovery'};
    const injury = {'hurt', 'boundary'};
    const recovery = {'repair', 'clarified'};
    final groups = <String, double>{};
    for (final e in probabilities.entries) {
      final key = positive.contains(e.key)
          ? 'positive'
          : injury.contains(e.key)
          ? 'injury'
          : recovery.contains(e.key)
          ? 'recovery'
          : e.key;
      groups[key] = (groups[key] ?? 0) + e.value;
    }
    final ranked = groups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty || ranked.first.key == 'none') return 'none';
    final group = ranked.first;
    final negative = group.key == 'injury' || group.key == 'disappointment';
    final gate = negative
        ? .82
        : group.key == 'recovery'
        ? .75
        : .62;
    final margin = ranked.length > 1 ? group.value - ranked[1].value : 0.0;
    if (group.value < gate ||
        (ranked.length > 1 && margin < (negative ? .25 : .15)))
      return 'none';
    if (negative &&
        probabilities.length != questions['mood_event']!.options.length)
      return 'none';
    final choices =
        probabilities.entries
            .where(
              (e) => switch (group.key) {
                'positive' => positive.contains(e.key),
                'injury' => injury.contains(e.key),
                'recovery' => recovery.contains(e.key),
                _ => e.key == group.key,
              },
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    // Ambiguous repair/clarification softens first; only clear correction
    // completely withdraws the mistaken interpretation.
    if (group.key == 'recovery' && (probabilities['clarified'] ?? 0) < .75)
      return 'repair';
    return choices.first.key;
  }

  static String resolveImpact(Map<String, double> probabilities) {
    const levels = ['mild', 'clear', 'strong'];
    final impact = levels.fold<double>(
      0,
      (v, key) => v + (probabilities[key] ?? 0),
    );
    if (impact < .65 || impact - (probabilities['none'] ?? 0) < .15)
      return 'none';
    final ranked = levels.where(probabilities.containsKey).toList()
      ..sort((a, b) => probabilities[b]!.compareTo(probabilities[a]!));
    if (ranked.isEmpty) return 'none';
    final best = probabilities[ranked.first]!;
    // Uncertainty between adjacent degrees keeps the gentler degree; it
    // does NOT erase a well established event (the old heat-system mistake).
    final near =
        ranked.where((key) => best - probabilities[key]! <= .10 + 1e-9).toList()
          ..sort((a, b) => levels.indexOf(a).compareTo(levels.indexOf(b)));
    final selected = near.first;
    return selected == 'strong' && best < .8 ? 'clear' : selected;
  }

  static MoodEvent? event({
    required Map<String, String>? answers,
    required String userId,
    required DateTime at,
    String targetId = '',
  }) {
    final kind = answers?['mood_event'];
    final level = answers?['mood_impact'];
    if (kind == null ||
        kind == 'none' ||
        !MoodEvent.kinds.contains(kind) ||
        !const {'mild', 'clear', 'strong'}.contains(level))
      return null;
    if (const {'hurt', 'boundary'}.contains(kind) &&
        (level == 'mild' ||
            const {
              'light',
              'mutual',
              'strong',
            }.contains(answers?['interaction'])))
      return null;
    if (const {'repair', 'clarified'}.contains(kind) && targetId.isEmpty)
      return null;
    return MoodEvent(
      id: 'user:$userId',
      kind: kind,
      level: level!,
      at: at,
      targetId: const {'repair', 'clarified'}.contains(kind) ? targetId : '',
    );
  }
}
