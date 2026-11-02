import 'generation_cancellation.dart';
import 'jev_decision_gateway.dart';
import 'speech_performance_plan.dart' show SpeechPerformancePlan;
import '../emotion/emotion_contract.dart';
import '../../widgets/caicai_live2d_stage.dart';

/// The imported DeepSeek rig's own catalog. No Caicai parameter/preset aliases.
class DeepseekMotionPlanner {
  const DeepseekMotionPlanner({this.gateway = JevDecisionGateway.instance});
  final JevDecisionGateway gateway;
  static const catalog = 'deepseek-v2';
  static const channels = <String, Map<String, Map<String, double>>>{
    'head': {'自然': {}, '左转': {'AngleX': -25}, '右转': {'AngleX': 25},
      '低头': {'AngleY': -24}, '抬头': {'AngleY': 24},
      '左歪头': {'AngleZ': -23}, '右歪头': {'AngleZ': 23}},
    'body': {'自然': {}, '左侧身': {'PositionX': -12, 'PositionZ': -8},
      '右侧身': {'PositionX': 12, 'PositionZ': 8}, '轻沉': {'PositionY': -10},
      '轻提': {'PositionY': 10},
      '好奇探身': {'PositionX': -8, 'PositionZ': 7, 'PositionY': -6}},
    'lean': {'自然': {}, '贴近屏幕': {'LeanInput': -30}, '站回原位': {'LeanInput': 0}},
    'gaze': {'自然': {}, '看左': {'ParamEyeBallX': -.7}, '看右': {'ParamEyeBallX': .7},
      '看上': {'ParamEyeBallY': .6}, '看下': {'ParamEyeBallY': -.6}},
    'brows': {'自然': {}, '皱眉': {'ParamBrowLY': -.75, 'ParamBrowRY': -.75},
      '抬眉': {'BrowInnerUp': .85}, '眯笑': {'REyeSquint': .9, 'LEyeSquint': .9}},
    'mouth': {'自然': {}, '微笑': {'ParamMouthForm': 1}, '不高兴': {'ParamMouthForm': -1},
      '撅嘴': {'ParamMouthForm': -1, 'Mouthpucker': 1}, '鼓脸': {'CheeckPuff': .85},
      '歪嘴': {'MouthX': .8}, '吐舌': {'TongueOut': 1},
      '咧嘴': {'ParamMouthForm': .8, 'MouthPuckerWiden': .35},
      '微张露齿': {'MouthFunnel': .35}},
  };
  static const eyes = <String, String>{
    '圈圈眼': '双眼变成两个大而空白的O，呆住、脑袋空白或装傻的呆萌反应；不是旋转眩晕或蚊香眼',
    '爱心眼': '心动、着迷或被撩到；普通开心和关心不足以触发',
    '><眼': '双眼紧挤成><，被逗得绷不住、强烈开心、害羞窘迫或撒娇抗议；不是单眼wink',
    '嫌弃眼': '半垂眼、平直上眼皮的屑屑眼，像“就这？”“你认真的？”的无语吐槽或轻微嫌弃；不自动代表真正厌恶',
  };
  static const effects = <String, String>{
    '黑脸': '阴沉或无语到黑脸', '落泪': '难过、委屈或感动到有泪意',
    '脸红': '害羞或脸热', '加载': '思考、卡壳或处理信息的转圈',
    '兔牙': '憨憨兔牙的故意搞怪', '大钢盆': '明确提到经典钢盆帽或戴盆搞怪',
    '流冷汗': '尴尬、慌张或紧张到流冷汗',
  };
  static const winks = <String, String>{
    '左wink': '角色左眼wink，屏幕右侧眼睛',
    '右wink': '角色右眼wink，屏幕左侧眼睛',
    '吐舌wink': '角色左眼wink并吐舌头；不带比耶手势',
  };
  static const actions = <String, String>{
    '无': '没有相关手势', '狗尾草': '手持狗尾草，完整抬臂、持物、放下',
    '扶胸': '抬起手臂将手掌放在胸前，表达郑重或感动',
    '竖食指': '抬臂后食指朝上，用于提醒、解释或灵机一动',
  };
  static const roots = <String, Map<String, double>>{
    '自然': {}, '左轻移': {'x': -.055, 'tilt': 3},
    '右轻移': {'x': .055, 'tilt': -3},
    '左倾': {'tilt': 5}, '右倾': {'tilt': -5},
  };
  static const deliveries = <String, String>{
    'hold': '平直叙述，自然保持', 'nod': '认同、肯定或温柔回应，轻点头',
    'tilt': '好奇、疑问或带笑打量，轻侧头',
    'avert': '迟疑、害羞或回想，短暂移开视线',
    'emphasize': '认真解释、提醒或打趣的重音，轻抬头',
    'lean': '俏皮地凑近屏幕、逗弄或亲近对方，拉近距离后站回原位',
  };
  static String boundedText(String text, int limit) => text.length <= limit ? text
      : '${text.substring(0, limit ~/ 2)}〔中段略〕${text.substring(text.length - limit ~/ 2)}';

  static void _presets(Map<String, JevChoiceQuestion> q, String prefix, String context,
      {bool optional = false}) {
    for (final entry in {'face': eyes, 'effect': effects, 'wink': winks}.entries) {
      q['$prefix${entry.key}_use'] = JevChoiceQuestion(
        '$context 是否适合${entry.key}附加层？按实际语义决定；没有相符反应就不用。'
        '爱心眼只用于心动/着迷；wink需要有意眨眼示意，普通开心或关心不自动触发。'
        '圈圈眼是空白O眼的呆萌反应，与眩晕无关；><眼是双眼挤紧；嫌弃眼可用于轻微吐槽，不必上升为厌恶。特殊眼型互斥，也不能同时wink。',
        const {'yes': '有相符语义', 'no': '无相符语义'}, optional: optional);
      q['$prefix${entry.key}'] = JevChoiceQuestion('$context 假设使用此层，选择符合程度的类型；是否使用由独立_use题决定。',
        entry.value, optional: optional);
    }
    q['${prefix}action'] = JevChoiceQuestion('$context 选择相符手势，无关就选无；三组手势由本地互斥和收势。',
      actions, optional: optional);
  }

  Future<Map<String, Object?>?> plan({required String user, required String reply,
      required String emotion, required Map<String, dynamic> parameters,
      String spokenText = '', GenerationCancellationToken? cancellationToken}) async {
    if (parameters.isEmpty) return null;
    final q = <String, JevChoiceQuestion>{};
    for (var i = 0; i < 4; i++) {
      for (final c in channels.entries) {
        final options = {for (final e in c.value.entries)
          if (e.value.keys.every(parameters.containsKey)) e.key: e.key};
        if (options.length > 1) q['f${i}_${c.key}'] = JevChoiceQuestion(
          'DeepSeek四拍第${i + 1}拍，依次起意、强调、反应、收势。根据回复语义选择${c.key}；'
          '普通对话也应有看得见的头身表达，四拍至少两次符合语义的姿态变化，不要四拍全选自然。'
          '头转向可用25、俯仰24、歪头23，避免每拍反向甩头；不因范围大就一直保守。'
          'lean是独立前倾：俏皮、打趣、亲近或凑近打量时可选贴近屏幕，不要求台词明说靠近；'
          '强调/反应拍可连续保持LeanInput=-30，末拍本地收回0。正文无关时不强行前倾。'
          '头身可配合前倾，同时保持方向连贯。嘴部只在没有真实语音时生效。', options);
      }
      q['f${i}_root'] = JevChoiceQuestion('第${i + 1}拍整模轻移／以独立小腿支点倾斜，按语义配合头身。',
        {for (final key in roots.keys) key: key});
    }
    q['tempo'] = const JevChoiceQuestion('选择连贯四拍节奏。', {'舒展': '每拍1.1秒', '自然': '每拍0.95秒', '明快': '每拍0.82秒'});
    q['emotion'] = JevChoiceQuestion('回复结束后持续的情绪，平直时选normal。',
      {'normal': '自然', ...EmotionCatalog.labelsByKey});
    _presets(q, '', '本轮回复');
    final spans = SpeechPerformancePlan.candidates(spokenText);
    for (var i = 0; i < spans.length; i++) {
      q['speech${i}_emotion'] = JevChoiceQuestion('参照speech_stage第${i + 1}段实际朗读文字选择临时情绪；不为变化强选。',
        {'keep': '延续', 'normal': '自然', ...EmotionCatalog.labelsByKey}, optional: true);
      q['speech${i}_delivery'] = JevChoiceQuestion('参照speech_stage第${i + 1}段选择语气动作，发生在真实音频阶段。',
        deliveries, optional: true);
      _presets(q, 'speech${i}_', 'speech_stage第${i + 1}段', optional: true);
    }
    final answers = await gateway.chooseMany(state: {
      'avatar': 'deepseek-avatar', 'catalog': catalog,
      'user': boundedText(user, 2000), 'reply': boundedText(reply, 4000), 'emotion': emotion,
      'parameter_contract': parameters,
      if (spans.isNotEmpty) 'speech_stage': [for (var i = 0; i < spans.length; i++)
        {'index': i + 1, 'text': boundedText(spans[i].text, 500)}],
      'contract': 'One independent four-beat plan plus optional real-audio spans. No mouth opening, clothes, morph, physics outputs or arbitrary parameter IDs. Head/body inputs within authored -30..30; full front lean -30, return to 0 at the end. Root <=10deg/15%. Eye L/R are anatomical. No V-sign or Caicai props.',
    }, questions: q, usageLane: 'deepseek_avatar_speaking_motion', cancellationToken: cancellationToken);
    if (answers == null) return null;
    return {...buildPlan(answers, parameters), 'speech': [
      for (var i = 0; i < spans.length; i++)
        if (deliveries.containsKey(answers['speech${i}_delivery']) &&
            (answers['speech${i}_emotion'] == 'keep' || validEmotion(answers['speech${i}_emotion'])))
          {'start': spans[i].start, 'end': spans[i].end,
            'emotion': answers['speech${i}_emotion'] == 'keep' ? '' : answers['speech${i}_emotion'],
            'delivery': answers['speech${i}_delivery'], ...preset(answers, 'speech${i}_')},
    ]};
  }
  static bool validEmotion(String? value) => value == 'normal' || EmotionCatalog.labelsByKey.containsKey(value);
  static Map<String, String> preset(Map<String, String> a, String p) {
    final face = a['${p}face_use'] == 'yes' && eyes.containsKey(a['${p}face']) ? a['${p}face']! : '';
    return {'face': face,
      'effect': a['${p}effect_use'] == 'yes' && effects.containsKey(a['${p}effect']) ? a['${p}effect']! : '',
      'wink': face.isEmpty && a['${p}wink_use'] == 'yes' && winks.containsKey(a['${p}wink']) ? a['${p}wink']! : '',
      'action': actions.containsKey(a['${p}action']) && a['${p}action'] != '无' ? a['${p}action']! : ''};
  }
  static Map<String, double> bounded(Map<String, double> values, Map<String, dynamic> parameters) {
    final out = <String, double>{};
    for (final e in values.entries) {
      final meta = parameters[e.key];
      if (meta is! Map || meta['min'] is! num || meta['max'] is! num) continue;
      final min = (meta['min'] as num).toDouble(), max = (meta['max'] as num).toDouble();
      if (min.isFinite && max.isFinite && min <= max) out[e.key] = e.value.clamp(min, max).toDouble();
    }
    return out;
  }
  static Map<String, Object?> buildPlan(Map<String, String> answers, Map<String, dynamic> parameters) {
    final interval = answers['tempo'] == '舒展' ? 1.1 : answers['tempo'] == '明快' ? .82 : .95;
    final hasLean = List.generate(4, (i) => answers['f${i}_lean']).contains('贴近屏幕');
    return {'catalog': catalog, 'frames': [for (var i = 0; i < 4; i++)
      {'time': i * interval, 'duration': interval * .65,
        'parameters': bounded({for (final c in channels.entries)
          ...?c.value[answers['f${i}_${c.key}']],
          if (i == 3 && hasLean) 'LeanInput': 0}, parameters),
        'root': roots[answers['f${i}_root']] ?? const <String, double>{}}],
      ...preset(answers, ''),
      'emotion': validEmotion(answers['emotion']) ? CaicaiLive2DService.nativeEmotionId(answers['emotion']!) : ''};
  }
  static List<Map<String, Object?>> speechFrames(String delivery, Map<String, dynamic> parameters) {
    final targets = switch (delivery) {
      'nod' => {'AngleY': -10.0, 'PositionY': -5.0},
      'tilt' => {'AngleZ': 10.0, 'PositionZ': 5.0},
      'avert' => {'AngleX': -12.0, 'AngleY': -6.0, 'ParamEyeBallX': -.4},
      'emphasize' => {'AngleY': 10.0, 'BrowInnerUp': .7, 'PositionY': 5.0},
      'lean' => {'LeanInput': -30.0},
      _ => <String, double>{},
    };
    return targets.isEmpty ? const [] : [
      {'time': 0.0, 'duration': .42, 'parameters': bounded(targets, parameters)},
      {'time': delivery == 'lean' ? 1.2 : .8, 'duration': .5,
        'parameters': delivery == 'lean' ? bounded({'LeanInput': 0}, parameters) : const <String, double>{}},
    ];
  }
}
