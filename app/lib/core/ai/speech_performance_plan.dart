import 'dart:math' as math;
import '../tts/spoken_text_index.dart';

class SpeechPerformanceSpan {
  const SpeechPerformanceSpan(this.text, this.start, this.end);
  final String text;
  final int start, end;
}

/// Semantic candidates, not mandatory gestures. At most sixteen new optional
/// questions share the existing speaking-motion request.
class SpeechPerformancePlan {
  static const deliveries = <String, String>{
    'hold': '自然说话，延续当前表达，不需要独立强调动作。',
    'nod': '短而轻地点头，随后回到当下情绪的自然姿态。',
    'tilt': '小幅侧头思考或打量，不反复摆动。',
    'avert': '短暂移开视线并轻微低头，随后自然回看。',
    'emphasize': '小幅抬头配合眉眼强调，不使用大幅整模动作。',
  };

  static List<SpeechPerformanceSpan> candidates(String spoken) {
    final total = SpokenTextIndex.normalize(spoken).length;
    if (total == 0) return const [];
    final clauses = RegExp(r'[^，,。！？!?；;\n]+[，,。！？!?；;\n]*')
        .allMatches(spoken).map((m) => m.group(0)!.trim())
        .where((s) => SpokenTextIndex.normalize(s).isNotEmpty).toList();
    if (clauses.isEmpty) return const [];
    final desired = total <= 45 ? math.min(2, clauses.length)
        : math.min(8, math.max(2, (total / 55).ceil()));
    final target = (total / desired).ceil();
    final groups = <String>[];
    var buffer = '';
    for (final clause in clauses) {
      if (buffer.isNotEmpty && groups.length < desired - 1 &&
          SpokenTextIndex.normalize(buffer + clause).length > target) {
        groups.add(buffer); buffer = '';
      }
      buffer += clause;
    }
    if (buffer.isNotEmpty) groups.add(buffer);
    // A long unpunctuated paragraph still covers its later words. Preserve
    // complete clauses whenever available, splitting only this special case.
    if (groups.length == 1 && desired > 1) {
      final text = groups.removeLast();
      final width = (text.length / desired).ceil();
      for (var i = 0; i < text.length; i += width) {
        groups.add(text.substring(i, math.min(text.length, i + width)));
      }
    }
    var position = 0;
    return [for (final text in groups.take(8))
      (() { final start = position; position += SpokenTextIndex.normalize(text).length;
        return SpeechPerformanceSpan(text, start, position); })()];
  }

  static List<Map<String, Object?>> decode(List<SpeechPerformanceSpan> spans,
      Map<String, String> answers, Set<String> emotions) => [
    for (var i = 0; i < spans.length; i++)
      if (deliveries.containsKey(answers['speech${i}_delivery']) &&
          (answers['speech${i}_emotion'] == 'keep' || emotions.contains(answers['speech${i}_emotion'])))
        {'start': spans[i].start, 'end': spans[i].end,
          'emotion': answers['speech${i}_emotion'] == 'keep' ? '' : answers['speech${i}_emotion'],
          'delivery': answers['speech${i}_delivery']},
  ];

  static List<Map<String, Object?>> frames(String delivery,
      Map<String, dynamic> parameters) {
    final targets = switch (delivery) {
      'nod' => {'ParamAngleY2': -10.0},
      'tilt' => {'ParamAngleZ': 8.0, 'ParamAngleZ2': 8.0},
      'avert' => {'ParamEyeBallX': .35, 'ParamEyeBallY': -.25, 'ParamAngleY2': -6.0},
      'emphasize' => {'ParamAngleY2': 7.0, 'ParamBrowLY': .25, 'ParamBrowRY': .25},
      _ => <String, double>{},
    };
    final safe = <String, double>{};
    for (final e in targets.entries) {
      final range = parameters[e.key];
      if (range is Map && range['min'] is num && range['max'] is num) {
        final low = (range['min'] as num).toDouble(), high = (range['max'] as num).toDouble();
        if (low.isFinite && high.isFinite && low <= high) safe[e.key] = e.value.clamp(low, high).toDouble();
      }
    }
    if (safe.isEmpty) return const [];
    return [{'time': 0.0, 'duration': .45, 'parameters': safe},
      {'time': .8, 'duration': .5, 'parameters': <String, double>{}}];
  }
}
