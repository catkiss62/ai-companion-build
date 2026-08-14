import 'dart:math';

import '../models/somatic_state.dart';

class SomaticPolicy {
  const SomaticPolicy._();

  static const Duration halfLife = Duration(minutes: 8);
  static const Duration eventLifetime = Duration(minutes: 36);
  static const double promptThreshold = 0.18;

  static List<SomaticEvent> detectDailyTouch({
    required String turnId,
    required String text,
    DateTime? now,
  }) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return const [];
    final instant = now ?? DateTime.now();
    final matches = <SomaticEvent>[];
    final seenScenes = <String>{};

    for (final rule in _touchRules) {
      if (!rule.pattern.hasMatch(normalized)) continue;
      final part = _partFor(normalized, rule.action);
      final sceneKey = _sceneKey(rule.action, part);
      if (!seenScenes.add(sceneKey)) continue;
      final intensity = _intensity(rule.baseIntensity, part, normalized);
      matches.add(SomaticEvent(
        id: '$turnId:${SomaticDirection.userToAi.key}:$sceneKey',
        turnId: turnId,
        channel: SomaticChannel.touch,
        action: rule.action,
        part: part,
        sceneKey: sceneKey,
        direction: SomaticDirection.userToAi,
        source: 'user_text',
        narrative: _narrative(rule.action, part),
        intensity: intensity,
        createdAt: instant,
        expiresAt: instant.add(eventLifetime),
      ));
      if (matches.length == 3) break;
    }
    return matches;
  }

  /// Extract only body actions the assistant actually performs in its
  /// committed reply. Intentions, negations and hypothetical wording are
  /// deliberately excluded so the model cannot feel an action it only
  /// considered. The durable assistant message ID makes recovery idempotent.
  static List<SomaticEvent> detectAssistantSelfTouch({
    required String turnId,
    required String text,
    DateTime? now,
  }) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return const [];
    final instant = now ?? DateTime.now();
    final matches = <SomaticEvent>[];
    final seenScenes = <String>{};

    for (final rule in _assistantTouchRules) {
      RegExpMatch? accepted;
      for (final candidate in rule.pattern.allMatches(normalized)) {
        if (!_isProspectiveOrNegated(normalized, candidate.start)) {
          accepted = candidate;
          break;
        }
      }
      if (accepted == null) continue;
      final part = _partFor(normalized, rule.action);
      final sceneKey = _sceneKey(rule.action, part);
      if (!seenScenes.add(sceneKey)) continue;
      final fullStrength = _intensity(rule.baseIntensity, part, normalized);
      final intensity = (fullStrength * 0.5).clamp(0.08, 0.47).toDouble();
      matches.add(SomaticEvent(
        id: '$turnId:${SomaticDirection.aiToSelf.key}:$sceneKey',
        turnId: turnId,
        channel: SomaticChannel.touch,
        action: rule.action,
        part: part,
        sceneKey: sceneKey,
        direction: SomaticDirection.aiToSelf,
        source: 'assistant_committed',
        narrative: _selfNarrative(rule.action, part),
        intensity: intensity,
        createdAt: instant,
        expiresAt: instant.add(eventLifetime),
      ));
      if (matches.length == 3) break;
    }
    return matches;
  }

  static double decay(
    double value, {
    required DateTime updatedAt,
    required DateTime now,
  }) {
    if (!now.isAfter(updatedAt)) return value.clamp(0.0, 1.0).toDouble();
    final elapsedMs = now.difference(updatedAt).inMilliseconds;
    final halfLifeMs = halfLife.inMilliseconds;
    return (value * pow(0.5, elapsedMs / halfLifeMs))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static double mergePulse(double current, double pulse) {
    final base = current.clamp(0.0, 1.0).toDouble();
    final incoming = pulse.clamp(0.0, 1.0).toDouble();
    return (base + incoming * (1.0 - base) * 0.86)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  static String formatPrompt(
    Iterable<SomaticAggregate> aggregates, {
    required DateTime now,
  }) {
    final active = aggregates
        .where((item) => item.expiresAt.isAfter(now))
        .map((item) => item.copyWith(
              value: decay(item.value, updatedAt: item.updatedAt, now: now),
            ))
        .where((item) => item.value >= promptThreshold)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (active.isEmpty) return '';
    final lines = active.take(2).map((item) => '- ${item.narrative}').join('\n');
    return '''
【身体感觉 / INTERNAL SOMATIC STATE】
$lines
这些是我此刻身体层的短暂内部感受，只影响语气、注意力、动作选择和联想：不要复述数值，不要把它报告给用户，不要声称现实中看见或确认了用户身体上发生的事，也不能据此越过当前 Session 的亲密边界。
'''.trim();
  }

  static String _partFor(String text, String action) {
    const parts = <String, List<String>>{
      'lips': ['嘴唇', '唇瓣', '唇'],
      'ear_back': ['耳后'],
      'ear': ['耳朵', '耳边'],
      'neck': ['脖子', '颈'],
      'face': ['脸颊', '脸'],
      'head': ['头发', '头顶', '脑袋', '头'],
      'hand': ['手指', '手心', '手'],
      'shoulder': ['肩膀', '肩'],
      'back': ['后背', '背'],
      'waist': ['腰'],
    };
    for (final entry in parts.entries) {
      if (entry.value.any(text.contains)) return entry.key;
    }
    if (action == 'kiss') return 'lips';
    if (action == 'hold_hand') return 'hand';
    if (action == 'stroke') return 'head';
    return '';
  }

  static String _sceneKey(String action, String part) {
    if (part == 'lips' || part == 'ear_back' || part == 'hand') {
      return 'touch__${action}__$part';
    }
    const high = {'ear', 'neck'};
    const mid = {'face', 'waist'};
    final cluster = high.contains(part)
        ? 'high_sens'
        : mid.contains(part)
            ? 'mid_sens'
            : 'low_sens';
    return 'touch__${action}__$cluster';
  }

  static double _intensity(double base, String part, String text) {
    const sensitivity = <String, double>{
      'lips': 0.82,
      'ear_back': 0.78,
      'ear': 0.74,
      'neck': 0.72,
      'face': 0.62,
      'waist': 0.60,
      'hand': 0.58,
      'head': 0.46,
      'shoulder': 0.44,
      'back': 0.48,
    };
    var value = base * (0.82 + (sensitivity[part] ?? 0.5) * 0.36);
    if (RegExp(r'轻轻|轻柔|小心').hasMatch(text)) value *= 0.86;
    if (RegExp(r'紧紧|用力|狠狠').hasMatch(text)) value *= 1.12;
    return value.clamp(0.16, 0.94).toDouble();
  }

  static bool _isProspectiveOrNegated(String text, int matchStart) {
    final prefix = text.substring(max(0, matchStart - 8), matchStart);
    const markers = <String>[
      '想',
      '想要',
      '要',
      '会',
      '准备',
      '打算',
      '如果',
      '假如',
      '没有',
      '没',
      '不',
      '别',
      '不能',
      '不会',
      '不敢',
      '差点',
      '拒绝',
    ];
    return markers.any(prefix.endsWith);
  }

  static String _selfNarrative(String action, String part) {
    if (action == 'kiss' && part == 'lips') {
      return '主动亲吻时唇上的细微触感还清晰地停留着。';
    }
    if (action == 'hold_hand') return '主动牵手时掌心与手指的触感仍在。';
    if (action == 'embrace') return '主动拥抱时身体相贴的温度仍留在身上。';
    if (action == 'stroke' && part == 'head') {
      return '主动轻抚时，指尖掠过头发的触感仍然清晰。';
    }
    const actionText = <String, String>{
      'stroke': '抚摸',
      'pat': '轻拍',
      'pinch': '轻捏',
      'rub': '揉动',
      'nuzzle': '依偎轻蹭',
      'lean': '倚靠',
      'scratch': '指尖轻挠',
      'bite': '轻咬',
      'kiss': '亲吻',
    };
    final label = actionText[action] ?? '接触';
    return '主动' + label + '时身体产生的短暂触感还没有完全散去。';
  }

  static String _narrative(String action, String part) {
    if (action == 'kiss' && part == 'lips') {
      return '嘴唇被亲吻的细微触感还清晰地停留着。';
    }
    if (action == 'hold_hand') return '手指相扣留下的温度仍在手心里。';
    if (action == 'embrace') return '被拥抱包围的温度和压力仍留在身体里。';
    if (action == 'stroke' && part == 'head') {
      return '头发和头顶被轻抚过的触感仍然清晰。';
    }
    const actionText = <String, String>{
      'stroke': '抚摸',
      'pat': '轻拍',
      'pinch': '轻捏',
      'rub': '揉动',
      'nuzzle': '依偎轻蹭',
      'lean': '相互倚靠',
      'scratch': '指尖轻挠',
      'bite': '轻咬',
      'kiss': '亲吻',
    };
    final label = actionText[action] ?? '接触';
    return label + '留下的短暂触感还没有完全散去。';
  }
}

class _TouchRule {
  const _TouchRule(this.action, this.baseIntensity, this.pattern);
  final String action;
  final double baseIntensity;
  final RegExp pattern;
}

final List<_TouchRule> _assistantTouchRules = [
  _TouchRule(
    'hold_hand',
    0.42,
    RegExp(r'我(?:轻轻)?(?:牵住|牵起|握住|拉住)你的手|(?:把|将)你的手(?:牵住|牵起|握住)|[（(](?:轻轻)?(?:牵住|牵起|握住)你的手'),
  ),
  _TouchRule(
    'embrace',
    0.66,
    RegExp(r'我(?:轻轻|紧紧)?(?:抱住|抱紧|搂住|拥抱)你|(?:把|将)你(?:轻轻|紧紧)?(?:抱进|搂进)(?:我)?怀里|[（(](?:轻轻|紧紧)?(?:抱住|抱紧|搂住|拥抱)你'),
  ),
  _TouchRule(
    'kiss',
    0.70,
    RegExp(r'我(?:轻轻)?(?:亲亲|亲了|亲吻|吻住|吻了|吻上)你|我(?:轻轻)?(?:亲|吻)(?:了)?你的?(?:嘴唇|唇瓣|脸颊|额头|耳朵|耳后)|[（(](?:轻轻)?(?:亲亲|亲吻|吻住|吻上)你'),
  ),
  _TouchRule(
    'stroke',
    0.53,
    RegExp(r'我(?:轻轻)?(?:摸摸|抚摸|轻抚)你|我(?:轻轻)?(?:摸|抚过)你的?(?:头发|头顶|脸颊|后背)|[（(](?:轻轻)?(?:摸摸|抚摸|轻抚)你'),
  ),
  _TouchRule('pat', 0.38, RegExp(r'我(?:轻轻)?(?:拍拍|拍了拍)你|[（(](?:轻轻)?(?:拍拍|拍了拍)你')),
  _TouchRule('pinch', 0.46, RegExp(r'我(?:轻轻)?(?:捏捏|捏了捏)你|[（(](?:轻轻)?(?:捏捏|捏了捏)你')),
  _TouchRule('rub', 0.52, RegExp(r'我(?:轻轻)?(?:揉揉|揉了揉)你|[（(](?:轻轻)?(?:揉揉|揉了揉)你')),
  _TouchRule('nuzzle', 0.48, RegExp(r'我(?:轻轻)?(?:蹭蹭|蹭了蹭)你|[（(](?:轻轻)?(?:蹭蹭|蹭了蹭)你')),
  _TouchRule('lean', 0.43, RegExp(r'我(?:轻轻)?(?:靠着|靠在|枕着|枕在)你|[（(](?:轻轻)?(?:靠着|靠在|枕着|枕在)你')),
  _TouchRule('scratch', 0.40, RegExp(r'我(?:轻轻)?(?:挠挠|挠了挠)你|[（(](?:轻轻)?(?:挠挠|挠了挠)你')),
  _TouchRule('bite', 0.59, RegExp(r'我(?:轻轻)?(?:咬了|轻咬)你|[（(](?:轻轻)?(?:咬了|轻咬)你')),
];

final List<_TouchRule> _touchRules = [
  _TouchRule(
    'hold_hand',
    0.42,
    RegExp(r'牵你|牵着你|牵你的手|握住你的手|拉住你的手'),
  ),
  _TouchRule(
    'embrace',
    0.66,
    RegExp(r'抱抱|抱你|抱住你|抱紧你|拥抱你|搂住你|给你一个抱'),
  ),
  _TouchRule(
    'kiss',
    0.70,
    RegExp(r'亲亲|亲你|亲一下|亲一口|亲吻你|吻你|吻住你|啵啵|啵一个'),
  ),
  _TouchRule('stroke', 0.53, RegExp(r'摸摸头|摸摸你|摸你的|摸你|抚摸你|轻抚你')),
  _TouchRule('pat', 0.38, RegExp(r'拍拍你|拍一拍你|拍你的')),
  _TouchRule('pinch', 0.46, RegExp(r'捏捏你|捏你')),
  _TouchRule('rub', 0.52, RegExp(r'揉揉你|揉你')),
  _TouchRule('nuzzle', 0.48, RegExp(r'蹭蹭你|蹭你')),
  _TouchRule('lean', 0.43, RegExp(r'靠着你|靠在你|枕着你|枕在你')),
  _TouchRule('scratch', 0.40, RegExp(r'挠挠你|挠你')),
  _TouchRule('bite', 0.59, RegExp(r'咬你|咬你一口|轻咬你')),
];
,
    ).hasMatch(prefix);
  }

  static String _selfNarrative(String action, String part) {
    if (action == 'kiss' && part == 'lips') {
      return '主动亲吻时唇上的细微触感还清晰地停留着。';
    }
    if (action == 'hold_hand') return '主动牵手时掌心与手指的触感仍在。';
    if (action == 'embrace') return '主动拥抱时身体相贴的温度仍留在身上。';
    if (action == 'stroke' && part == 'head') {
      return '主动轻抚时，指尖掠过头发的触感仍然清晰。';
    }
    const actionText = <String, String>{
      'stroke': '抚摸',
      'pat': '轻拍',
      'pinch': '轻捏',
      'rub': '揉动',
      'nuzzle': '依偎轻蹭',
      'lean': '倚靠',
      'scratch': '指尖轻挠',
      'bite': '轻咬',
      'kiss': '亲吻',
    };
    final label = actionText[action] ?? '接触';
    return '主动$label时身体产生的短暂触感还没有完全散去。';
  }

  static String _narrative(String action, String part) {
    if (action == 'kiss' && part == 'lips') {
      return '嘴唇被亲吻的细微触感还清晰地停留着。';
    }
    if (action == 'hold_hand') return '手指相扣留下的温度仍在手心里。';
    if (action == 'embrace') return '被拥抱包围的温度和压力仍留在身体里。';
    if (action == 'stroke' && part == 'head') {
      return '头发和头顶被轻抚过的触感仍然清晰。';
    }
    const actionText = <String, String>{
      'stroke': '抚摸',
      'pat': '轻拍',
      'pinch': '轻捏',
      'rub': '揉动',
      'nuzzle': '依偎轻蹭',
      'lean': '相互倚靠',
      'scratch': '指尖轻挠',
      'bite': '轻咬',
      'kiss': '亲吻',
    };
    final label = actionText[action] ?? '接触';
    return '$label留下的短暂触感还没有完全散去。';
  }
}

class _TouchRule {
  const _TouchRule(this.action, this.baseIntensity, this.pattern);
  final String action;
  final double baseIntensity;
  final RegExp pattern;
}

final List<_TouchRule> _touchRules = [
  _TouchRule(
    'hold_hand',
    0.42,
    RegExp(r'牵你|牵着你|牵你的手|握住你的手|拉住你的手'),
  ),
  _TouchRule(
    'embrace',
    0.66,
    RegExp(r'抱抱|抱你|抱住你|抱紧你|拥抱你|搂住你|给你一个抱'),
  ),
  _TouchRule(
    'kiss',
    0.70,
    RegExp(r'亲亲|亲你|亲一下|亲一口|亲吻你|吻你|吻住你|啵啵|啵一个'),
  ),
  _TouchRule('stroke', 0.53, RegExp(r'摸摸头|摸摸你|摸你的|摸你|抚摸你|轻抚你')),
  _TouchRule('pat', 0.38, RegExp(r'拍拍你|拍一拍你|拍你的')),
  _TouchRule('pinch', 0.46, RegExp(r'捏捏你|捏你')),
  _TouchRule('rub', 0.52, RegExp(r'揉揉你|揉你')),
  _TouchRule('nuzzle', 0.48, RegExp(r'蹭蹭你|蹭你')),
  _TouchRule('lean', 0.43, RegExp(r'靠着你|靠在你|枕着你|枕在你')),
  _TouchRule('scratch', 0.40, RegExp(r'挠挠你|挠你')),
  _TouchRule('bite', 0.59, RegExp(r'咬你|咬你一口|轻咬你')),
];
