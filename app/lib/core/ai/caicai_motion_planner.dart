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
      '自然待机': {}, '左侧头': {'ParamAngleX3': -22}, '右侧头': {'ParamAngleX3': 22},
      '低头': {'ParamAngleY2': -21}, '抬头': {'ParamAngleY2': 21},
      '左歪头': {'ParamAngleZ': -20, 'ParamAngleZ2': -20},
      '右歪头': {'ParamAngleZ': 20, 'ParamAngleZ2': 20},
      '探头打量': {'ParamAngleX3': 20, 'ParamAngleY2': -11, 'ParamAngleZ': -16, 'ParamAngleZ2': -16},
      '扬头得意': {'ParamAngleY2': 22, 'ParamAngleZ': 15, 'ParamAngleZ2': 15},
    },
    'body': {'自然待机': {}, '左移重心': {'ParamBodyAngleX': -5, 'ParamBodyAngleZ': 2.5},
      '右移重心': {'ParamBodyAngleX': 5, 'ParamBodyAngleZ': -2.5},
      '兴奋踮起': {'ParamBodyAngleY': 6, 'ParamBodyAngleZ': 4},
      '俏皮侧身': {'ParamBodyAngleX': 5, 'ParamBodyAngleY': -3, 'ParamBodyAngleZ': -5}, '轻轻下压': {'ParamBodyAngleY': -6},
      '轻轻踮起': {'ParamBodyAngleY': 6}, '左摆': {'ParamBodyAngleZ': -5}, '右摆': {'ParamBodyAngleZ': 5}},
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
    '不位移': {}, '向左探身': {'x': -.04, 'tilt': 2.5},
    '向右探身': {'x': .04, 'tilt': -2.5},
    '小腿支点左倾': {'x': -.015, 'tilt': 4},
    '小腿支点右倾': {'x': .015, 'tilt': -4},
  };
  static const intensities = {'轻巧': .8, '鲜明': 1.0, '夸张': 1.12};
  static const tempos = {'舒展': 1.15, '明快': .98, '俏皮快拍': .86};
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
          '以自然待机的动作幅度和速度为基准，普通对话可以有明显动作；只在一句重点处略高于待机。'
          '连贯保持同一姿势也是动作，不必每拍换方向；强调拍后逐渐回落，明确安静语境可轻巧。'
          '头和身方向有配合但不必同向；显式动作尽早执行。自然待机仍有本地重心和头身运动。', options);
      }
    }
    for (var frame = 0; frame < 4; frame++) {
      questions['f${frame}_intensity'] = JevChoiceQuestion(
        '第${frame + 1}拍头身与整模位移幅度：默认鲜明；整段最多一拍夸张，其余保持或回落。',
        {'轻巧':'基准80%', '鲜明':'基准100%', '夸张':'基准112%，只用于一句重点'});
      questions['f${frame}_root'] = JevChoiceQuestion(
        '第${frame + 1}拍整模动作：独立的水平平移和以小腿为中心的整体倾斜。'
        '请配合头身动作，仅在需要时选一次探身或倾斜；其余拍保持或收回，不要连续左右来回撞。',
        {for(final x in rootMotions.keys) x:x});
    }
    questions['tempo'] = JevChoiceQuestion('整段表演节奏，默认明快；真正需要强调时可用俏皮快拍，安静时舒展。',
      {'舒展':'每拍1.15秒', '明快':'每拍0.98秒', '俏皮快拍':'每拍0.86秒'});
    questions['face'] = JevChoiceQuestion('选择本次短时原装表情，情绪不明显时选无。', {for (final x in faces) x: x});
    questions['action'] = JevChoiceQuestion('选择与本轮明确动作或场景有关的原装动作；无关时选无。', {for (final x in actions) x: x});
    questions['emotion'] = JevChoiceQuestion(
      '选择对话结束后持续显示的聊天情绪。以实际回复语气为准；没有明显情绪选正常，不要为了变化而强选。',
      {'normal': '正常', for (final x in EmotionCatalog.labelsByKey.entries) x.key: x.value},
    );
    final answers = await gateway.chooseMany(state: {
      'user': user, 'reply': reply, 'emotion': emotion,
      'parameter_contract': parameters,
      'schedule': '4 beats; tempo chooses interval 0.86/0.98/1.15s; intensity scales head/body/root only; one emphasis beat at most; root x is fraction of model width and tilt is screen rotation degrees about lower legs; Cubism head values are parameter units, NOT physical angles; authored presets above motion; mouth opening belongs to audio',
    }, questions: questions, usageLane: 'caicai_speaking_motion', cancellationToken: cancellationToken);
    if (answers == null) return null;
    return buildPlan(answers, parameters);
  }

  static Map<String, Object?> buildPlan(Map<String, String> answers, Map<String, dynamic> parameters) {
    final frames = <Map<String, Object?>>[];
    final interval = tempos[answers['tempo']] ?? .98;
    // The model may select "夸张" on every beat. Reserve that gain for one
    // emphasis beat so the rest of the phrase has room to breathe.
    final emphasisBeat = answers['f1_intensity'] == '夸张' ? 1 :
        List.generate(4, (index) => index).where((index) =>
          answers['f${index}_intensity'] == '夸张').firstOrNull;
    var rootBeat = -1;
    for (var frame = 0; frame < 4; frame++) {
      final targets = <String, double>{};
      final chosenIntensity = answers['f${frame}_intensity'];
      final intensity = chosenIntensity == '夸张' && frame != emphasisBeat ? 1.0 :
          (intensities[chosenIntensity] ?? 1.0);
      final selectedRoot = rootMotions[answers['f${frame}_root']] ?? <String,double>{};
      final root = selectedRoot.isNotEmpty && rootBeat < 0
          ? {for(final e in selectedRoot.entries) e.key: e.value * intensity}
          : <String,double>{};
      if (root.isNotEmpty) rootBeat = frame;
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
      // A root shift plus two full body axes reads as a collision. Keep a
      // modest combined body budget during the one independent root gesture.
      if (root.isNotEmpty) {
        for (final id in const ['ParamBodyAngleX','ParamBodyAngleZ']) {
          if (targets.containsKey(id)) targets[id] = targets[id]! * .75;
        }
      }
      final bodyX = targets['ParamBodyAngleX'];
      final nextBody = frame < 3 ? channels['body']![answers['f${frame + 1}_body']] : null;
      final holdsBodyX = bodyX != null && nextBody?['ParamBodyAngleX'] != null &&
          nextBody!['ParamBodyAngleX']!.sign == bodyX.sign;
      frames.add({'time': frame * interval, 'duration': interval * .42, 'parameters': targets, 'root': root});
      // Tongue/wink are brief. A repeated hip pose remains continuous; only
      // release that axis when it is changing or the phrase is ending.
      if (targets.keys.any((id) => const {'OUT','ParamEyeLOpen','ParamEyeROpen'}.contains(id)) ||
          (bodyX != null && !holdsBodyX)) {
        final release = Map<String,double>.from(targets)
          ..removeWhere((id, _) => const {'OUT','ParamEyeLOpen','ParamEyeROpen',
            'ParamEyeLSmile','ParamEyeRSmile'}.contains(id) ||
            (id == 'ParamBodyAngleX' && !holdsBodyX));
        frames.add({'time': (frame + .60) * interval, 'duration': interval * .36, 'parameters': release, 'root': root});
      }
    }
    return {'frames': frames,
      'face': faces.contains(answers['face']) && answers['face'] != '无' ? answers['face'] : '',
      'action': actions.contains(answers['action']) && answers['action'] != '无' ? answers['action'] : '',
      'emotion': answers['emotion'] == 'normal' || EmotionCatalog.labelsByKey.containsKey(answers['emotion'])
          ? CaicaiLive2DService.nativeEmotionId(answers['emotion']!) : ''};
  }
}
