import 'dart:convert';
import 'generation_cancellation.dart';
import 'speech_performance_plan.dart';
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
      '自然待机': {}, '左侧头': {'ParamAngleX3': -25}, '右侧头': {'ParamAngleX3': 25},
      '低头': {'ParamAngleY2': -24}, '抬头': {'ParamAngleY2': 24},
      '左歪头': {'ParamAngleZ': -23, 'ParamAngleZ2': -23},
      '右歪头': {'ParamAngleZ': 23, 'ParamAngleZ2': 23},
      '探头打量': {'ParamAngleX3': 23, 'ParamAngleY2': -12, 'ParamAngleZ': -18, 'ParamAngleZ2': -18},
      '扬头得意': {'ParamAngleY2': 25, 'ParamAngleZ': 16, 'ParamAngleZ2': 16},
    },
    'body': {'自然待机': {}, '左移重心': {'ParamBodyAngleX': -4, 'ParamBodyAngleZ': 2},
      '右移重心': {'ParamBodyAngleX': 4, 'ParamBodyAngleZ': -2},
      '兴奋踮起': {'ParamBodyAngleY': 7, 'ParamBodyAngleZ': 3.5},
      '俏皮侧身': {'ParamBodyAngleX': 4, 'ParamBodyAngleY': -4, 'ParamBodyAngleZ': -3.5}, '轻轻下压': {'ParamBodyAngleY': -7},
      '轻轻踮起': {'ParamBodyAngleY': 7}, '左摆': {'ParamBodyAngleZ': -4}, '右摆': {'ParamBodyAngleZ': 4}},
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
    '不位移': {}, '向左探身': {'x': -.038, 'tilt': 3},
    '向右探身': {'x': .038, 'tilt': -3},
    '小腿支点左倾': {'x': -.015, 'tilt': 5},
    '小腿支点右倾': {'x': .015, 'tilt': -5},
  };
  static const intensities = {'轻巧': .8, '鲜明': 1.0, '夸张': 1.12};
  static const tempos = {'舒展': 1.10, '明快': .95, '俏皮快拍': .82};
  static const faces = ['无','1爱心','1生气','1红脸','1钱钱','1黑脸','1星星眼','1流泪',
    'wink','wink吐舌','比耶wink吐舌'];
  static const faceMeanings = <String, String>{
    '无': '不使用额外原装表情。',
    '1爱心': '爱心眼：心动、被撩到、看得入迷，或带一点迷恋意味的喜欢；轻微、含蓄的反应也可以使用，不要求强烈情绪或告白。普通开心、日常关心和礼貌温柔本身不足以使用；如果其中带有心动或着迷，也可以使用。',
    '1生气': '气鼓鼓、佯怒或抗议；轻轻赌气和认真生气都可，按本轮语气判断。',
    '1红脸': '害羞、浪漫或难为情；轻微脸热也可自然表达，不必等到强烈害羞。',
    '1钱钱': '财迷式的开心、对钱或收益的兴奋；不把一般开心当作财迷。',
    '1黑脸': '无语、被噎住或阴沉；轻度无奈也可，不把普通平静当作黑脸。',
    '1星星眼': '惊喜、赞叹、好奇的期待；小小的兴奋也可自然表达。',
    '1流泪': '难过、委屈或感动到想哭；需要有泪意，不把所有低落都演成哭。',
    'wink': '轻度：轻巧眨眼、俏皮或默契。',
    'wink吐舌': '中度：眨眼加吐舌，更淘气。',
    '比耶wink吐舌': '程度更强：比耶加吐舌加眨眼，更夸张的得意、庆祝或卖萌。',
  };
  static const overlayFaces = ['1爱心','1生气','1红脸','1钱钱','1黑脸','1星星眼','1流泪'];
  static const winks = ['wink','wink吐舌','比耶wink吐舌'];
  static const actions = ['无','2奶茶','2插手','2比耶','2点单','2菜单','2餐盘左','2餐盘右'];

  Future<Map<String, Object?>?> plan({required String user, required String reply,
      required String emotion, required Map<String, dynamic> parameters,
      String spokenText = '',
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
          '这是生动的虚拟主播表演，普通对话也要有明确的可见头身动作，不要因为参数范围大而保守。'
          '四拍中安排至少两次与语义相符的姿势变化，不要四拍都选自然待机或保持相同姿势；'
          '可以有强调、反应和收势，避免每拍左右交替撞击。明确安静语境才选轻巧。'
          '头和身方向有配合但不必同向；显式动作尽早执行。自然待机仍有本地重心和头身运动。', options);
      }
    }
    for (var frame = 0; frame < 4; frame++) {
      questions['f${frame}_intensity'] = JevChoiceQuestion(
        '第${frame + 1}拍头身与整模位移幅度：默认鲜明；重要语气可连续强调，后续收势。',
        {'轻巧':'基准80%', '鲜明':'基准100%', '夸张':'基准112%，可用于语义强调'});
      questions['f${frame}_root'] = JevChoiceQuestion(
        '第${frame + 1}拍整模动作：独立的水平平移和以小腿为中心的整体倾斜。'
        '请配合头身动作，可在不同拍选择探身、倾斜和回位；不要每拍左右交替撞击。',
        {for(final x in rootMotions.keys) x:x});
    }
    questions['tempo'] = JevChoiceQuestion('整段表演节奏，默认明快；兴奋或俏皮可用快拍，安静时舒展。',
      {'舒展':'每拍1.10秒', '明快':'每拍0.95秒', '俏皮快拍':'每拍0.82秒'});
    questions['face_use'] = JevChoiceQuestion(
      '只判断本轮是否适合使用七种原装叠加表情中的一种，不在这里选择具体类型。'
      '七种含义：心动或着迷的爱心眼、气鼓鼓或抗议、害羞脸热、财迷、无语、惊喜期待、难过委屈或感动到有泪意。'
      '爱心眼允许轻微含蓄的心动、被撩到或着迷；普通开心、日常关心和礼貌温柔本身不足以使用爱心眼。'
      '依据实际回复语气与动作描写，轻微、中等或强烈的自然反应都可使用，不必等情绪强烈；'
      '但中性或没有相符反应时不用，不为增加频率而强选，也不要把轻微情绪自动夸张。'
      '这是独立附加层，可与19种情绪、五官、wink和道具同时使用；已有其他层不是不用的理由。'
      '普通形态和小豆丁使用同样的资格，只看本轮语义。',
      {'yes': '有相符的自然反应，使用七种叠加表情中的一种。', 'no': '中性或没有相符反应，不使用七种叠加表情。'});
    questions['face'] = JevChoiceQuestion(
      '假设本轮要使用七种叠加表情，从七种中选与实际回复最贴合的一种；这里只判断类型，不判断用不用。'
      '按实际语义选择，不因为有该类型题就必须播放；是否播放由独立的face_use判断决定。',
      {for (final name in overlayFaces) name: faceMeanings[name]!});
    questions['wink_use'] = JevChoiceQuestion(
      '只判断本轮是否适合使用wink家族，不在这里选择具体类型。'
      '轻巧俏皮、默契、淘气、得意或庆祝时都可自然使用；不要求强烈情绪，不设次数或频率。'
      '中性、无关或不合实际语气时不用。可与七种叠加表情、19种情绪和道具同时使用；'
      '已有其他层不是不用的理由。普通形态和小豆丁使用同样的资格，只看本轮语义。',
      {'yes': '本轮有适合眨眼类预设的俏皮或默契等反应。', 'no': '本轮不适合眨眼类预设。'});
    questions['wink'] = JevChoiceQuestion(
      '假设本轮要使用wink家族，从三种中选择符合实际语气和程度的一种；这里只判断类型，不判断用不用。'
      '不因候选有更夸张的预设就自动选强度最高的；是否播放由独立的wink_use判断决定。'
      'wink、wink吐舌、比耶wink吐舌是完整原装预设，后者自带比耶手势；'
      '已有完整wink时不必再用四拍眼睛动作重复强调。',
      {for (final name in winks) name: faceMeanings[name]!});
    questions['action'] = JevChoiceQuestion('选择与本轮明确动作或场景有关的原装动作；无关时选无。', {for (final x in actions) x: x});
    questions['emotion'] = JevChoiceQuestion(
      '选择对话结束后持续显示的聊天情绪。以实际回复语气为准；没有明显情绪选正常，不要为了变化而强选。',
      {'normal': '正常', for (final x in EmotionCatalog.labelsByKey.entries) x.key: x.value},
    );
    final speech = SpeechPerformancePlan.candidates(spokenText);
    for (var i = 0; i < speech.length; i++) {
      questions['speech${i}_emotion'] = JevChoiceQuestion(
        '实际朗读的第${i + 1}段：${speech[i].text}。选择该段的临时表演情绪；'
        '允许延续，同一情绪不必切回正常。不要为变化而强选；与原先四拍是不同播放阶段。',
        {'keep': '延续本轮已有情绪', 'normal': '自然平静', for (final e in EmotionCatalog.labelsByKey.entries) e.key: e.value},
        optional: true);
      questions['speech${i}_delivery'] = JevChoiceQuestion(
        '实际朗读的第${i + 1}段：${speech[i].text}。选择适合本段的小幅表达动作，'
        '无独立强调可以自然说话；无需每段都做动作。回程由本地处理，不用再安排回落段。',
        SpeechPerformancePlan.deliveries, optional: true);
    }
    final answers = await gateway.chooseMany(state: {
      'user': user, 'reply': reply, 'emotion': emotion,
      'parameter_contract': parameters,
      if (speech.isNotEmpty) 'speech_stage': {
        'spokenText': spokenText,
        'note': 'Extra speech-stage cues begin at real audio playback, AFTER the existing immediate four beats. Do not change the original four-beat performance to fill speech duration.',
      },
      'schedule': '4 beats; tempo chooses interval 0.82/0.95/1.10s; choose visible semantic pose changes on multiple beats; intensity scales head/body/root only; each beat can have its own emphasis and root action; root x is fraction of model width and tilt is screen rotation degrees about lower legs; Cubism head values are parameter units, NOT physical angles; authored presets above motion; mouth opening belongs to audio',
    }, questions: questions, usageLane: 'caicai_speaking_motion', cancellationToken: cancellationToken);
    if (answers == null) return null;
    return {...buildPlan(answers, parameters),
      'speech': SpeechPerformancePlan.decode(speech, answers, {'normal', ...EmotionCatalog.labelsByKey.keys})};
  }

  static Map<String, Object?> buildPlan(Map<String, String> answers, Map<String, dynamic> parameters) {
    final frames = <Map<String, Object?>>[];
    final interval = tempos[answers['tempo']] ?? .95;
    for (var frame = 0; frame < 4; frame++) {
      final targets = <String, double>{};
      final intensity = intensities[answers['f${frame}_intensity']] ?? 1.0;
      final selectedRoot = rootMotions[answers['f${frame}_root']] ?? <String,double>{};
      final root = {for(final e in selectedRoot.entries) e.key: e.value * intensity};
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
      frames.add({'time': frame * interval, 'duration': interval * .34, 'parameters': targets, 'root': root});
      // Only facial cues release within a beat. Body X must travel smoothly
      // across adjacent beats instead of snapping back to idle each time.
      if (targets.keys.any((id) => const {'OUT','ParamEyeLOpen','ParamEyeROpen'}.contains(id))) {
        final release = Map<String,double>.from(targets)
          ..removeWhere((id, _) => const {'OUT','ParamEyeLOpen','ParamEyeROpen',
            'ParamEyeLSmile','ParamEyeRSmile'}.contains(id));
        frames.add({'time': (frame + .60) * interval, 'duration': interval * .30, 'parameters': release, 'root': root});
      }
    }
    return {'frames': frames,
      // Type questions always have a winner, even for neutral replies. Only an
      // explicit valid use decision may enable it; missing gates fail closed.
      'face': answers['face_use'] == 'yes' && overlayFaces.contains(answers['face']) ? answers['face'] : '',
      'wink': answers['wink_use'] == 'yes' && winks.contains(answers['wink']) ? answers['wink'] : '',
      'action': actions.contains(answers['action']) && answers['action'] != '无' ? answers['action'] : '',
      'emotion': answers['emotion'] == 'normal' || EmotionCatalog.labelsByKey.containsKey(answers['emotion'])
          ? CaicaiLive2DService.nativeEmotionId(answers['emotion']!) : ''};
  }
}
