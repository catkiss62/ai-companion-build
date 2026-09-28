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
    'body': {'自然待机': {}, '左移重心': {'ParamBodyAngleX': -9, 'ParamBodyAngleZ': 5},
      '右移重心': {'ParamBodyAngleX': 9, 'ParamBodyAngleZ': -5},
      '兴奋踮起': {'ParamBodyAngleY': 9, 'ParamBodyAngleZ': 6},
      '俏皮侧身': {'ParamBodyAngleX': 8, 'ParamBodyAngleY': -5, 'ParamBodyAngleZ': -8}, '轻轻下压': {'ParamBodyAngleY': -8},
      '轻轻踮起': {'ParamBodyAngleY': 8}, '左摆': {'ParamBodyAngleZ': -8}, '右摆': {'ParamBodyAngleZ': 8}},
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
          '把四段当成一次连贯的表演：起意、强调、反应、收势。根据回复实际语气选择可见的转头、点头或身体动作；'
          '避免四段全选自然待机，也不要每段重复同一姿势。安静或严肃语境可克制；俏皮、兴奋时使用完整幅度。'
          '头和身方向有配合但不必同向；显式动作尽早执行。自然待机仍有本地重心和头身运动。', options);
      }
    }
    questions['face'] = JevChoiceQuestion('选择本次短时原装表情，情绪不明显时选无。', {for (final x in faces) x: x});
    questions['action'] = JevChoiceQuestion('选择与本轮明确动作或场景有关的原装动作；无关时选无。', {for (final x in actions) x: x});
    questions['emotion'] = JevChoiceQuestion(
      '选择对话结束后持续显示的聊天情绪。以实际回复语气为准；没有明显情绪选正常，不要为了变化而强选。',
      {'normal': '正常', for (final x in EmotionCatalog.labelsByKey.entries) x.key: x.value},
    );
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
      frames.add({'time': frame.toDouble(), 'duration': .32, 'parameters': targets});
      // A hip shift, wink or tongue is a gesture with a return, never a held latch.
      if (targets.keys.any((id) => const {'OUT','ParamEyeLOpen','ParamEyeROpen','ParamBodyAngleX'}.contains(id))) {
        final release = Map<String,double>.from(targets)
          ..removeWhere((id, _) => const {'OUT','ParamEyeLOpen','ParamEyeROpen',
            'ParamEyeLSmile','ParamEyeRSmile','ParamBodyAngleX'}.contains(id));
        frames.add({'time': frame + .55, 'duration': .25, 'parameters': release});
      }
    }
    return {'frames': frames,
      'face': faces.contains(answers['face']) && answers['face'] != '无' ? answers['face'] : '',
      'action': actions.contains(answers['action']) && answers['action'] != '无' ? answers['action'] : '',
      'emotion': answers['emotion'] == 'normal' || EmotionCatalog.labelsByKey.containsKey(answers['emotion'])
          ? CaicaiLive2DService.nativeEmotionId(answers['emotion']!) : ''};
  }
}
