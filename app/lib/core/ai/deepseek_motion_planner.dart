import 'dart:convert';
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
      '左歪头': {'AngleZ': -23}, '右歪头': {'AngleZ': 23},
      '探头打量': {'AngleX': 18, 'AngleY': -10, 'AngleZ': -16},
      '扬头得意': {'AngleY': 23, 'AngleZ': 15}},
    'body': {'自然': {}, '左侧身': {'PositionX': -12, 'PositionZ': -8},
      '右侧身': {'PositionX': 12, 'PositionZ': 8}, '轻沉': {'PositionY': -10},
      '轻提': {'PositionY': 10},
      '好奇探身': {'PositionX': -8, 'PositionZ': 7, 'PositionY': -6},
      '左摆重心': {'PositionX': -14, 'PositionY': -6, 'PositionZ': 12},
      '右摆重心': {'PositionX': 14, 'PositionY': -6, 'PositionZ': -12},
      '轻快舒展': {'PositionX': 6, 'PositionY': 13, 'PositionZ': -7}},
    'lean': {'自然': {}, '贴近屏幕': {'LeanInput': -30}, '站回原位': {'LeanInput': 0}},
    'gaze': {'自然': {}, '看左': {'ParamEyeBallX': -.7}, '看右': {'ParamEyeBallX': .7},
      '看上': {'ParamEyeBallY': .6}, '看下': {'ParamEyeBallY': -.6}},
    'eyes': {'自主眨眼': {}, '左笑眼wink': {'ParamEyeLOpen': 0, 'LEyeSquint': 1},
      '右笑眼wink': {'ParamEyeROpen': 0, 'REyeSquint': 1}},
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
  static const intensities = {'轻巧': .8, '鲜明': 1.0, '夸张': 1.12};
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
    'lean': '有意凑近对方看清、贴近逗弄或说悄悄话，拉近距离后站回原位；由整轮lean_use安排',
  };
  static String boundedText(String text, int limit) => text.length <= limit ? text
      : '${text.substring(0, limit ~/ 2)}〔中段略〕${text.substring(text.length - limit ~/ 2)}';

  static void _presets(Map<String, JevChoiceQuestion> q, String prefix, String context,
      {bool optional = false}) {
    final speech = prefix.startsWith('speech');
    final meanings = {'face': {for (final e in eyes.entries) if (!speech || e.key != '嫌弃眼') e.key: e.value}, 'effect': effects, 'wink': winks};
    final directions = <String, String>{
      'face': '只判断本段是否适合四种特殊眼型之一，不在这里选择类型。'
        '圈圈眼用于呆住、脑袋空白或装傻，><眼用于绷不住的开心、窘迫或撒娇抗议；'
        '${speech ? '语音期间不使用眼嘴绑定的嫌弃眼特效，普通嫌弃情绪仍可使用。' : '嫌弃眼可用于轻微无语吐槽；'}'
        '爱心眼允许轻微含蓄的心动、被撩到或着迷，普通开心、关心或礼貌温柔本身不足以使用爱心眼。'
        '按实际语气，轻微、中等或强烈的自然反应都可使用，不必等情绪强烈；中性或不相符时不用。',
      'effect': '只判断本段是否适合附加效果之一，不在这里选择类型。'
        '黑脸用于阴沉无语，落泪用于难过委屈或感动，脸红用于害羞脸热，加载用于思考卡壳，'
        '兔牙用于憨憨搞怪，大钢盆用于明确戴盆搞怪，流冷汗用于尴尬慌张。'
        '轻微、中等或强烈的自然反应都可使用，不必等情绪强烈；中性或无关时不用，不为增加频率强选。',
      'wink': '只判断本段是否适合有意眨眼示意、心照不宣、调侃中的明确强调点或文字描写wink。'
        '普通俏皮、开心、关心、得意或庆祝不自动等于需要眨眼；中性、无关或不合实际语气时不用。'
        '已有完整wink时不必再用四拍眼睛动作重复强调。',
    };
    for (final entry in meanings.entries) {
      q['$prefix${entry.key}_use'] = JevChoiceQuestion(
        '$context：${directions[entry.key]}'
        '这是独立附加层，可与19种情绪、五官、身体和手势组合；已有其他层不是不用的理由。'
        '特殊眼型之间互斥、不能同时wink，其他脸部参数仍可表达不同语气，爱心眼并不固定嘴巴和眉毛。'
        '普通形态和小豆丁使用同样的资格，只看本段语义。',
        const {'yes': '有相符的自然反应，使用此附加层。', 'no': '中性或无相符反应，不使用此层。'}, optional: optional);
      q['$prefix${entry.key}'] = JevChoiceQuestion(
        '$context 假设使用此层，选择与实际回复最贴合的类型和程度；这里只判断类型，不判断用不用。'
        '是否播放由独立_use题决定，不因存在类型题而必须播放，也不自动选最夸张的类型。',
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
        if (c.key == 'lean') continue;
        final options = {for (final e in c.value.entries)
          if (e.value.keys.every(parameters.containsKey)) e.key: '${e.key}，参数目标 ${jsonEncode(e.value)}'};
        if (options.length > 1) q['f${i}_${c.key}'] = JevChoiceQuestion(
          'DeepSeek四拍第${i + 1}拍，依次起意、强调、反应、收势。根据回复语义选择${c.key}，'
          '遵循state.performance_direction。普通对话也要有明确可见的头身表达，不因参数范围大而保守。'
          '${c.key == 'head' || c.key == 'body' ? '多拍时让头身至少有两次自然变化，不要四拍保持同一歪头和探身；头与身体可以错向，按语气选择侧身、重心或舒展，不为凑动作强行使用。' : ''}'
          '前倾仍只由整轮独立语义题决定。', options);
      }
      q['f${i}_intensity'] = JevChoiceQuestion('第${i + 1}拍头身与整模位移幅度：默认鲜明；重要语气可连续强调，后续收势。',
        const {'轻巧': '基准80%，明确安静语境', '鲜明': '基准100%，普通对话默认', '夸张': '基准112%，语义强调'});
      q['f${i}_root'] = JevChoiceQuestion('第${i + 1}拍整模轻移／以独立小腿支点倾斜，按语义配合头身。',
        {for (final key in roots.keys) key: key});
    }
    q['tempo'] = const JevChoiceQuestion('选择连贯四拍节奏。', {'舒展': '每拍1.1秒', '自然': '每拍0.95秒', '明快': '每拍0.82秒'});
    q['emotion'] = JevChoiceQuestion('回复结束后持续的情绪，平直时选normal。',
      {'normal': '自然', ...EmotionCatalog.labelsByKey});
    _presets(q, '', '本轮回复');
    final spans = SpeechPerformancePlan.candidates(spokenText);
    if (parameters.containsKey('LeanInput')) {
      q['lean_use'] = const JevChoiceQuestion(
        '这轮是否适合用短暂前倾拉近与对方的距离？明确要求靠近、贴近看清、耳语，或带亲近意味的逗弄、'
        '挑衅、撒娇、想看看对方反应，都可以选yes；不要求台词写出靠近。俏皮、开心、关心、害羞、'
        '吐槽或解释这些情绪标签单独不足以触发，但与贴近意图同时存在时不能据此否决yes。'
        '平直叙述、普通说明或没有贴近意味的互动选no。整轮最多一次连续前倾，完成后回正。',
        {'yes': '适合短暂凑近表达', 'no': '这轮没有贴近意味'});
      q['lean_moment'] = JevChoiceQuestion(
        '仅假设lean_use为yes，选择一次前倾最合适的时机；是否使用完全由lean_use决定。'
        '有实际朗读计划时只放在一个语音段，不在开场重复。',
        spans.isEmpty ? const {'f0': '起意拍', 'f1': '强调拍', 'f2': '反应拍'} :
          {for (var i = 0; i < spans.length; i++) 'speech$i': 'speech_stage第${i + 1}段'});
    }
    for (var i = 0; i < spans.length; i++) {
      q['speech${i}_emotion'] = JevChoiceQuestion('参照speech_stage第${i + 1}段实际朗读文字选择临时情绪；不为变化强选。',
        {'keep': '延续', 'normal': '自然', ...EmotionCatalog.labelsByKey}, optional: true);
      q['speech${i}_delivery'] = JevChoiceQuestion('参照speech_stage第${i + 1}段选择语气动作，发生在真实音频阶段。',
        {for (final e in deliveries.entries) if (e.key != 'lean') e.key: e.value}, optional: true);
      _presets(q, 'speech${i}_', 'speech_stage第${i + 1}段', optional: true);
    }
    final answers = await gateway.chooseMany(state: {
      'avatar': 'deepseek-avatar', 'catalog': catalog,
      'user': boundedText(user, 2000), 'reply': boundedText(reply, 4000), 'emotion': emotion,
      'parameter_contract': parameters,
      'performance_direction': '普通对话也应有看得见的头身表达，四拍至少两次符合语义的姿态变化，不要全选自然。'
        '转头25、俯仰24、歪头23，避免每拍反向甩头，不因范围大而一直保守。'
        '前倾可在带亲近意味的逗弄、撒娇或观察反应时自然使用，情绪标签不构成否决条件；'
        '不因单纯俏皮就必用，也不计入姿态变化数量；只由整轮lean_use决定，'
        'lean_moment安排一次连续前倾，完整到-30后回0。实际朗读时仅在选中的一个语音段出现。'
        '其他头身动作保持表达，嘴部只在没有真实语音时生效。',
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
            'delivery': speechDelivery(answers, i, supportsLean: parameters.containsKey('LeanInput')),
            ...preset(answers, 'speech${i}_')},
    ]};
  }
  static bool validEmotion(String? value) => value == 'normal' || EmotionCatalog.labelsByKey.containsKey(value);
  static Map<String, String> preset(Map<String, String> a, String p) {
    final selected = a['${p}face'];
    final allowed = !(p.startsWith('speech') && selected == '嫌弃眼');
    final face = allowed && a['${p}face_use'] == 'yes' && eyes.containsKey(a['${p}face']) ? a['${p}face']! : '';
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
    final moment = answers['lean_moment'] ?? '';
    final leanStart = answers['lean_use'] == 'yes' && const ['f0','f1','f2'].contains(moment)
        ? int.parse(moment.substring(1)) : -1;
    final frames = <Map<String, Object?>>[];
    final overlay = preset(answers, '');
    final explicitEyes = overlay['face']!.isNotEmpty || overlay['wink']!.isNotEmpty;
    for (var i = 0; i < 4; i++) {
      final intensity = intensities[answers['f${i}_intensity']] ?? 1.0;
      final values = <String, double>{};
      for (final c in channels.entries) {
        if (c.key == 'lean' || (c.key == 'eyes' && explicitEyes)) continue;
        final selected = c.value[answers['f${i}_${c.key}']];
        if (selected == null) continue;
        for (final e in selected.entries) {
          values[e.key] = e.value * (c.key == 'head' || c.key == 'body' ? intensity : 1);
        }
      }
      if (leanStart >= 0 && i >= leanStart) values['LeanInput'] = i < 3 ? -30 : 0;
      final root = {for (final e in (roots[answers['f${i}_root']] ?? const <String, double>{}).entries)
        e.key: e.value * intensity};
      if (root.isNotEmpty) {
        for (final id in ['PositionX', 'PositionZ']) {
          if (values.containsKey(id)) values[id] = values[id]! * .75;
        }
      }
      final targets = bounded(values, parameters);
      frames.add({'time': i * interval, 'duration': interval * .34,
        'parameters': targets, 'root': root});
      // Match Caicai: facial accents release inside a beat; body travel continues.
      if (targets.keys.any((id) => const {'TongueOut', 'ParamEyeLOpen', 'ParamEyeROpen'}.contains(id))) {
        final release = Map<String, double>.from(targets)..removeWhere((id, _) =>
          const {'TongueOut', 'ParamEyeLOpen', 'ParamEyeROpen', 'LEyeSquint', 'REyeSquint'}.contains(id));
        frames.add({'time': (i + .60) * interval, 'duration': interval * .30,
          'parameters': release, 'root': root});
      }
    }
    return {'catalog': catalog, 'frames': frames,
      ...preset(answers, ''),
      'emotion': validEmotion(answers['emotion']) ? CaicaiLive2DService.nativeEmotionId(answers['emotion']!) : ''};
  }
  static String speechDelivery(Map<String, String> answers, int index, {bool supportsLean = true}) {
    if (supportsLean && answers['lean_use'] == 'yes' && answers['lean_moment'] == 'speech$index') return 'lean';
    final chosen = answers['speech${index}_delivery'];
    return chosen != 'lean' && deliveries.containsKey(chosen) ? chosen! : 'hold';
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
      {'time': 0.0, 'duration': delivery == 'lean' ? .7 : .42, 'parameters': bounded(targets, parameters)},
      {'time': delivery == 'lean' ? 1.35 : .8, 'duration': delivery == 'lean' ? .8 : .5,
        'parameters': delivery == 'lean' ? bounded({'LeanInput': 0}, parameters) : const <String, double>{}},
    ];
  }
}
