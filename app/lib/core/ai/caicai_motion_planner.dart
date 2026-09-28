import 'dart:convert';
import 'generation_cancellation.dart';
import 'jev_decision_gateway.dart';
import '../emotion/emotion_contract.dart';
import '../../widgets/caicai_live2d_stage.dart';

/// SoulLink's sparse four-keyframe contract adapted to Jev's actual Choice API.
/// Labels and IDs come from Caicai's calibrated parameter contract, not Sen names.
class CaicaiMotionPlanner {
  const CaicaiMotionPlanner({this.gateway = JevDecisionGateway.instance});
  final JevDecisionGateway gateway;
  static const channels = <String, Map<String, Map<String, double>>>{
    'head': {
      '自然待机': {}, '左侧头': {'ParamAngleX3': -27}, '右侧头': {'ParamAngleX3': 27},
      '低头': {'ParamAngleY2': -24}, '抬头': {'ParamAngleY2': 24},
      '左歪头': {'ParamAngleZ': -24, 'ParamAngleZ2': -24},
      '右歪头': {'ParamAngleZ': 24, 'ParamAngleZ2': 24},
      '探头打量': {'ParamAngleX3': 23, 'ParamAngleY2': -12, 'ParamAngleZ': -18, 'ParamAngleZ2': -18},
      '扬头得意': {'ParamAngleY2': 25, 'ParamAngleZ': 16, 'ParamAngleZ2': 16},
    },
    'body': {'自然待机': {}, '左移重心': {'ParamBodyAngleX': -18, 'ParamBodyAngleZ': 5},
      '右移重心': {'ParamBodyAngleX': 18, 'ParamBodyAngleZ': -5},
      '兴奋踮起': {'ParamBodyAngleY': 18, 'ParamBodyAngleZ': 14},
      '俏皮侧身': {'ParamBodyAngleX': 16, 'ParamBodyAngleY': -5, 'ParamBodyAngleZ': -16}, '轻轻下压': {'ParamBodyAngleY': -16},
      '轻轻踮起': {'ParamBodyAngleY': 16}, '左摆': {'ParamBodyAngleZ': -16}, '右摆': {'ParamBodyAngleZ': 16}},
    'gaze': {'自然视线': {}, '看左': {'ParamEyeBallX': -.7}, '看右': {'ParamEyeBallX': .7},
      '看上': {'ParamEyeBallY': .6}, '看下': {'ParamEyeBallY': -.6}},
    'mouth': {'自然嘴型': {}, '不高兴': {'ParamMouthForm': -1}, '顽皮笑': {'ParamMouthForm': 1},
      '左歪嘴': {'MOUTHX': -1}, '右歪嘴': {'MOUTHX': 1}, '撅嘴': {'SHRUG': 1}, '吐舌': {'OUT': 1}},
    'eyes': {'自主眨眼': {}, '左笑眼wink': {'ParamEyeLOpen': 0, 'ParamEyeLSmile': 1},
      '右笑眼wink': {'ParamEyeROpen': 0, 'ParamEyeRSmile': 1}},
    'brows': {'自然眉眼': {}, '皱眉': {'ParamBrowLY': -.7, 'ParamBrowRY': -.7},
      '大睁眼': {'ParamBrowLY': .7, 'ParamBrowRY': .7}},
  };
  static const rootMotions = <String, Map<String, double>>{
    '不位移': {}, '向左探身': {'x': -.10, 'tilt': 3},
    '向右探身': {'x': .10, 'tilt': -3},
    '小腿支点左倾': {'x': -.025, 'tilt': 7},
    '小腿支点右倾': {'x': .025, 'tilt': -7},
  };
  static const intensities = {'轻巧': .65, '鲜明': 1.0, '夸张': 1.2};
  static const tempos = {'舒展': 1.0, '明快': .78, '俏皮快拍': .62};
  static const faces = ['无','1爱心','1生气','1红脸','1钱钱','1黑脸','1星星眼','1流泪'];
  static const actions = ['无','2奶茶','2插手','2比耶','2点单','2菜单','2餐盘左','2餐盘右'];

  Future<Map<String, Object?>?> plan({required String user, required String reply,
      required String emotion, required Map<String, dynamic> parameters,
      GenerationCancellationToken? cancellationToken}) async {
    if (parameters.isEmpty) return null;
    final questions = <String, JevChoiceQuestion>{};
    for (var frame = 0; frame < 4; frame++) {
      for (final entry in channels.entries) {
        final options = <String, String>{};
        for (final option in entry.value.entries) {
          if (option.value.keys.every(parameters.containsKey)) {
            options[option.key] = '${option.key}，参数目标 ${jsonEncode(option.value)}';
          }
        }
        if (options.length > 1) questions['f${frame}_${entry.key}'] = JevChoiceQuestion(
          '这是四拍表演的第${frame + 1}拍${entry.key}动作。根据用户要求、回复语气与动作描写选择；'
          '把四段当成一次连贯的表演：起意、强调、反应、收势。根据回复实际语气选择可见的转头、点头或身体动作；'
          '这是夸张的虚拟主播表演，不必模拟真人的克制；普通对话也用鲜明动作。参数由本地限幅，不要因范围数字大而保守。'
          '避免四拍全选自然待机；强调拍用完整幅度，反应拍可换方向，收势拍回落。明确安静语境才选轻巧。'
          '头和身方向有配合但不必同向；显式动作尽早执行。自然待机仍有本地重心和头身运动。', options);
      }
    }
    for (var frame = 0; frame < 4; frame++) {
      questions['f${frame}_intensity'] = JevChoiceQuestion(
        '第${frame + 1}拍头身与整模位移幅度：默认鲜明，强调/俏皮用夸张；轻巧只用于有意收敛。',
        {'轻巧':'基准65%', '鲜明':'基准100%', '夸张':'基准120%，本地限制到模型范围'});
      questions['f${frame}_root'] = JevChoiceQuestion(
        '第${frame + 1}拍整模动作：独立的水平平移和以小腿为中心的整体倾斜。'
        '请配合头身动作，探身看向一侧、俏皮倾身、换重心都可用；四拍不必全动，收势可以不位移。',
        {for(final x in rootMotions.keys) x:x});
    }
    questions['tempo'] = JevChoiceQuestion('整段表演节奏，默认明快；兴奋或俏皮可快拍，安静时舒展。',
      {'舒展':'每拍1秒', '明快':'每拍0.78秒', '俏皮快拍':'每拍0.62秒'});
    questions['face'] = JevChoiceQuestion('选择本次短时原装表情，情绪不明显时选无。', {for (final x in faces) x: x});
    questions['action'] = JevChoiceQuestion('选择与本轮明确动作或场景有关的原装动作；无关时选无。', {for (final x in actions) x: x});
    questions['emotion'] = JevChoiceQuestion(
      '选择对话结束后持续显示的聊天情绪。以实际回复语气为准；没有明显情绪选正常，不要为了变化而强选。',
      {'normal': '正常', for (final x in EmotionCatalog.labelsByKey.entries) x.key: x.value},
    );
    final answers = await gateway.chooseMany(state: {
      'user': user, 'reply': reply, 'emotion': emotion,
      'parameter_contract': parameters,
      'schedule': '4 beats; tempo chooses interval 0.62/0.78/1s; intensity scales head/body/root only; root x is fraction of model width and tilt is screen rotation degrees about lower legs; Cubism head values are parameter units, NOT physical angles; authored presets above motion; mouth opening belongs to audio',
    }, questions: questions, usageLane: 'caicai_speaking_motion', cancellationToken: cancellationToken);
    if (answers == null) return null;
    return buildPlan(answers, parameters);
  }

  static Map<String, Object?> buildPlan(Map<String, String> answers, Map<String, dynamic> parameters) {
    final frames = <Map<String, Object?>>[];
    final interval = tempos[answers['tempo']] ?? .78;
    for (var frame = 0; frame < 4; frame++) {
      final targets = <String, double>{};
      final intensity = intensities[answers['f${frame}_intensity']] ?? 1.0;
      for (final channel in channels.entries) {
        final chosen = channel.value[answers['f${frame}_${channel.key}']];
        if (chosen == null) continue;
        for (final target in chosen.entries) {
          final metadata = parameters[target.key];
          if (metadata is! Map || metadata['min'] is! num || metadata['max'] is! num) continue;
          final min = (metadata['min'] as num).toDouble(), max = (metadata['max'] as num).toDouble();
          if (!min.isFinite || !max.isFinite || min > max) continue;
          final gain = channel.key == 'head' || channel.key == 'body' ? intensity : 1.0;
          targets[target.key] = (target.value * gain).clamp(min, max).toDouble();
        }
      }
      final root = {for(final e in (rootMotions[answers['f${frame}_root']] ?? <String,double>{}).entries)
        e.key: e.value * intensity};
      frames.add({'time': frame * interval, 'duration': interval * .28, 'parameters': targets, 'root': root});
      // A hip shift, wink or tongue is a gesture with a return, never a held latch.
      if (targets.keys.any((id) => const {'OUT','ParamEyeLOpen','ParamEyeROpen','ParamBodyAngleX'}.contains(id))) {
        final release = Map<String,double>.from(targets)
          ..removeWhere((id, _) => const {'OUT','ParamEyeLOpen','ParamEyeROpen',
            'ParamEyeLSmile','ParamEyeRSmile','ParamBodyAngleX'}.contains(id));
        frames.add({'time': (frame + .55) * interval, 'duration': interval * .25, 'parameters': release, 'root': root});
      }
    }
    return {'frames': frames,
      'face': faces.contains(answers['face']) && answers['face'] != '无' ? answers['face'] : '',
      'action': actions.contains(answers['action']) && answers['action'] != '无' ? answers['action'] : '',
      'emotion': answers['emotion'] == 'normal' || EmotionCatalog.labelsByKey.containsKey(answers['emotion'])
          ? CaicaiLive2DService.nativeEmotionId(answers['emotion']!) : ''};
  }
}
