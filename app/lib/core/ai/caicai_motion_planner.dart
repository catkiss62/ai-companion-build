import 'dart:convert';
import 'generation_cancellation.dart';
import 'jev_decision_gateway.dart';

/// SoulLink's sparse four-keyframe contract adapted to Jev's actual Choice API.
/// Labels and IDs come from Caicai's calibrated parameter contract, not Sen names.
class CaicaiMotionPlanner {
  const CaicaiMotionPlanner({this.gateway = JevDecisionGateway.instance});
  final JevDecisionGateway gateway;
  static const channels = <String, Map<String, Map<String, double>>>{
    'head': {
      '自然待机': {}, '左侧头': {'ParamAngleX3': -16}, '右侧头': {'ParamAngleX3': 16},
      '低头': {'ParamAngleY2': -12}, '抬头': {'ParamAngleY2': 12},
      '左歪头': {'ParamAngleZ': -14, 'ParamAngleZ2': -14},
      '右歪头': {'ParamAngleZ': 14, 'ParamAngleZ2': 14},
    },
    'body': {'自然待机': {}, '轻轻下压': {'ParamBodyAngleY': -4},
      '轻轻踮起': {'ParamBodyAngleY': 4}, '左摆': {'ParamBodyAngleZ': -4}, '右摆': {'ParamBodyAngleZ': 4}},
    'gaze': {'自然视线': {}, '看左': {'ParamEyeBallX': -.7}, '看右': {'ParamEyeBallX': .7},
      '看上': {'ParamEyeBallY': .6}, '看下': {'ParamEyeBallY': -.6}},
    'mouth': {'自然嘴型': {}, '不高兴': {'ParamMouthForm': -1}, '顽皮笑': {'ParamMouthForm': 1},
      '左歪嘴': {'MOUTHX': -1}, '右歪嘴': {'MOUTHX': 1}, '撅嘴': {'SHRUG': 1}, '吐舌': {'OUT': 1}},
    'eyes': {'自主眨眼': {}, '左笑眼wink': {'ParamEyeLOpen': 0, 'ParamEyeLSmile': 1},
      '右笑眼wink': {'ParamEyeROpen': 0, 'ParamEyeRSmile': 1}},
    'brows': {'自然眉眼': {}, '皱眉': {'ParamBrowLY': -.7, 'ParamBrowRY': -.7},
      '大睁眼': {'ParamBrowLY': .7, 'ParamBrowRY': .7}},
  };
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
          '这是回复开始后第${frame + 1}秒的${entry.key}动作。根据用户要求、回复语气与动作描写选择；'
          '自然交流允许保持待机，不需要每秒换动作。显式动作尽早执行；随后恢复自然。', options);
      }
    }
    questions['face'] = JevChoiceQuestion('选择本次短时原装表情，情绪不明显时选无。', {for (final x in faces) x: x});
    questions['action'] = JevChoiceQuestion('选择与本轮明确动作或场景有关的原装动作；无关时选无。', {for (final x in actions) x: x});
    final answers = await gateway.chooseMany(state: {
      'user': user, 'reply': reply, 'emotion': emotion,
      'parameter_contract': parameters,
      'schedule': '4 frames at 0,1,2,3 seconds; authored presets above motion; mouth opening belongs to audio',
    }, questions: questions, usageLane: 'caicai_speaking_motion', cancellationToken: cancellationToken);
    if (answers == null) return null;
    return buildPlan(answers, parameters);
  }

  static Map<String, Object?> buildPlan(Map<String, String> answers, Map<String, dynamic> parameters) {
    final frames = <Map<String, Object?>>[];
    for (var frame = 0; frame < 4; frame++) {
      final targets = <String, double>{};
      for (final channel in channels.entries) {
        final chosen = channel.value[answers['f${frame}_${channel.key}']];
        if (chosen == null) continue;
        for (final target in chosen.entries) {
          final metadata = parameters[target.key];
          if (metadata is! Map || metadata['min'] is! num || metadata['max'] is! num) continue;
          final min = (metadata['min'] as num).toDouble(), max = (metadata['max'] as num).toDouble();
          if (!min.isFinite || !max.isFinite || min > max) continue;
          targets[target.key] = target.value.clamp(min, max).toDouble();
        }
      }
      frames.add({'time': frame.toDouble(), 'duration': .8, 'parameters': targets});
    }
    return {'frames': frames,
      'face': faces.contains(answers['face']) && answers['face'] != '无' ? answers['face'] : '',
      'action': actions.contains(answers['action']) && answers['action'] != '无' ? answers['action'] : ''};
  }
}
