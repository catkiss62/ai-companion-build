import 'dart:math' as math;
import '../tts/spoken_text_index.dart';
import 'caicai_preset_catalog.dart';
import 'jev_decision_gateway.dart';

class SpeechPerformanceSpan {
  const SpeechPerformanceSpan(this.text, this.start, this.end);
  final String text;
  final int start, end;
}

/// Semantic candidates, not mandatory gestures. At most fifty-six optional
/// questions share the existing speaking-motion request.
class SpeechPerformancePlan {
  static const deliveries = <String, String>{
    'hold': '平直叙述或安静倾听，维持自然待机；本段没有独立语气/姿态重点。',
    'nod': '认同、肯定、应允或温柔回应：轻点头，配合身体轻沉和回看。',
    'tilt': '好奇、疑问、思考或带笑打量：侧头配合身体轻倾，不反复摆动。',
    'avert': '迟疑、害羞、回想或故作不在意：短暂移开视线，轻低头后回看。',
    'emphasize': '提醒、强调、认真解释或打趣的重音：抬头、眉眼和身体轻提。',
  };

  static void addPresetQuestions(Map<String, JevChoiceQuestion> questions, int i) {
    final prefix = 'speech${i}_';
    final context = '参照speech_stage.spans第${i + 1}段text。';
    questions['${prefix}face_use'] = JevChoiceQuestion(
      '${context}是否有适合七种原装叠加表情的自然反应？心动/着迷、赌气/抗议、害羞、财迷、无语、惊喜期待、有泪意都可以，轻微也可；普通开心或关心不自动等于爱心眼。与情绪、手势、wink、道具独立，不因已有其他层而不用。',
      const {'yes': '有相符反应，使用叠加表情', 'no': '中性或无相符反应，不使用'}, optional: true);
    questions['${prefix}face'] = JevChoiceQuestion(
      '${context}假设要用七种表情，选择最贴合本段的一种；这里只选类型，用不用由face_use独立决定。',
      {for(final name in CaicaiPresetCatalog.overlayFaces) name: CaicaiPresetCatalog.faceMeanings[name]!}, optional: true);
    questions['${prefix}wink_use'] = JevChoiceQuestion(
      '${context}是否有意给对方眨眼示意、心照不宣、明确调侃强调点或文字描写wink？普通俏皮、开心、得意或关心不自动需要眨眼，可用其他层表达。与七种表情/情绪/道具独立判断。',
      const {'yes': '有适合有意眨眼的示意或强调', 'no': '本段不需要眨眼预设'}, optional: true);
    questions['${prefix}wink'] = JevChoiceQuestion(
      '${context}假设要wink，按本段实际程度选类型；不自动选最夸张。用不用由wink_use决定。',
      {for(final name in CaicaiPresetCatalog.winks) name: CaicaiPresetCatalog.faceMeanings[name]!}, optional: true);
    questions['${prefix}action'] = JevChoiceQuestion(
      '${context}选择与本段明确动作或场景有关的原装动作/道具，无关选无；可与七种表情、情绪和兼容wink叠加。',
      const {'无': '无相关动作或道具', '2奶茶': '拿奶茶/喝饮料', '2插手': '叉腰/插手站姿',
        '2比耶': '比耶、庆祝或展示胜利手势', '2点单': '点单、选餐或指点菜单',
        '2菜单': '拿菜单或展示可选内容', '2餐盘左': '左侧托盘/端餐', '2餐盘右': '右侧托盘/端餐'}, optional: true);
  }

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
          'delivery': answers['speech${i}_delivery'],
          'face': answers['speech${i}_face_use'] == 'yes' && CaicaiPresetCatalog.overlayFaces.contains(answers['speech${i}_face'])
              ? answers['speech${i}_face'] : '',
          'wink': answers['speech${i}_wink_use'] == 'yes' && CaicaiPresetCatalog.winks.contains(answers['speech${i}_wink'])
              ? answers['speech${i}_wink'] : '',
          'action': CaicaiPresetCatalog.actions.contains(answers['speech${i}_action']) && answers['speech${i}_action'] != '无'
              ? answers['speech${i}_action'] : ''},
  ];

  static List<Map<String, Object?>> frames(String delivery,
      Map<String, dynamic> parameters) {
    final targets = switch (delivery) {
      'nod' => {'ParamAngleY2': -10.0, 'ParamBodyAngleY': -1.8, 'ParamEyeBallY': -.1},
      'tilt' => {'ParamAngleZ': 8.0, 'ParamAngleZ2': 8.0, 'ParamBodyAngleZ': 1.5, 'ParamBodyAngleX': -1.0},
      'avert' => {'ParamEyeBallX': .35, 'ParamEyeBallY': -.25, 'ParamAngleY2': -6.0, 'ParamBodyAngleZ': -.8},
      'emphasize' => {'ParamAngleY2': 7.0, 'ParamBrowLY': .25, 'ParamBrowRY': .25, 'ParamBodyAngleY': 1.8},
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
