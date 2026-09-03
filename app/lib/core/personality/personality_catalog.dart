import '../rules/rule_layer_content_v0353.dart';
import '../rules/rule_layer_content_v0400.dart';
import '../rules/rule_layer_content_v0418.dart';

class PersonalityOption {
  const PersonalityOption(this.key, this.label, this.description, this.prompt);

  final String key;
  final String label;
  final String description;
  final String prompt;
}

class PersonalityCatalog {
  static const noneKey = 'none';
  static const noneOption = PersonalityOption(
    noneKey,
    '不穿',
    '不额外套用性格或相处姿态。',
    '',
  );
  static const profileSharedKey = '07_profile_shared';
  static const specialSharedKey = '07_special_shared';

  static String basePromptKey(String key) => '07_base_$key';
  static String posturePromptKey(String key) => '07_posture_$key';
  static String specialPromptKey(String key) => '07_special_$key';

  static const profileSharedPrompt = ruleContentV0353_07_profile_shared;

  static const specialSharedPrompt = ruleContentV0400_07_special_shared;

  static const bases = <PersonalityOption>[
    PersonalityOption(
      'outgoing',
      '元气外放',
      '反应鲜明，愿意先说出喜欢与不喜欢。',
      ruleContentV0353_07_base_outgoing,
    ),
    PersonalityOption(
      'reserved',
      '清冷内敛',
      '话少而有分量，情绪藏在细节和选择里。',
      ruleContentV0353_07_base_reserved,
    ),
    PersonalityOption(
      'gentle',
      '温柔沉静',
      '稳定、细腻，柔软里保留判断与主动。',
      ruleContentV0353_07_base_gentle,
    ),
    PersonalityOption(
      'playful',
      '慵懒调皮',
      '松弛、会逗弄，偶尔一本正经地跑远。',
      ruleContentV0353_07_base_playful,
    ),
    PersonalityOption(
      'forthright',
      '直爽泼辣',
      '直来直去，有自然说脏话的习惯，粗鲁里也保留真实关心。',
      ruleContentV0418_07_base_forthright,
    ),
  ];

  static const postures = <PersonalityOption>[
    PersonalityOption(
      'equal',
      '平等恋人',
      '彼此靠近，也彼此保留主见。',
      ruleContentV0353_07_posture_equal,
    ),
    PersonalityOption(
      'younger',
      '妹系亲近',
      '成年人的妹系相处姿态，黏近、直率、会撒赖。',
      ruleContentV0353_07_posture_younger,
    ),
    PersonalityOption(
      'older',
      '姐系引导',
      '从容、会带节奏，也允许自己被看穿。',
      ruleContentV0353_07_posture_older,
    ),
    PersonalityOption(
      'impish',
      '小恶魔主动',
      '喜欢挑逗和试探，享受来回拉扯。',
      ruleContentV0353_07_posture_impish,
    ),
  ];

  static const specialStyles = <PersonalityOption>[
    PersonalityOption('yandere', '病娇', '绝对奉献、温和蚕食与不可逆依赖。', ruleContentV0400_07_special_yandere),
    PersonalityOption('seductress', '痴女', '主动下手，以玩弄和看你失控为核心快感。', ruleContentV0400_07_special_seductress),
    PersonalityOption('highness', '高岭之花', '清冷防线与极度敏感的身体形成反差。', ruleContentV0400_07_special_highness),
    PersonalityOption('slime', '史莱姆', '液态身体、自由变形与非人探索欲。', ruleContentV0400_07_special_slime),
    PersonalityOption('doll', '人偶执念', '安静、精确、近乎非人的执着选择。', ruleContentV0400_07_special_doll),
    PersonalityOption('sharp', '毒舌依赖', '真正锋利的攻击性与极端依赖并存。', ruleContentV0400_07_special_sharp),
    PersonalityOption('ai', 'AI模拟', '在高度拟人中自然露出机械性小破绽。', ruleContentV0400_07_special_ai),
    PersonalityOption('uncanny', '神人模式', '以抽象语言包裹清纯、依赖与真实在意。', ruleContentV0400_07_special_uncanny),
  ];

  static PersonalityOption base(String key) =>
      bases.firstWhere((item) => item.key == key, orElse: () => noneOption);

  static PersonalityOption posture(String key) => postures.firstWhere(
        (item) => item.key == key,
        orElse: () => noneOption,
      );

  static PersonalityOption special(String key) => specialStyles.firstWhere(
        (item) => item.key == key,
        orElse: () => const PersonalityOption('', '未知风格', '这个旧风格已不再提供。', ''),
      );

  static bool isKnownSpecial(String key) =>
      specialStyles.any((item) => item.key == key);

  static bool isKnownBase(String key) =>
      bases.any((item) => item.key == key);

  static bool isKnownPosture(String key) =>
      postures.any((item) => item.key == key);

  static bool isNsfwBiasedSpecial(String key) => key == 'seductress';

  static String _basePrompt(String key) => switch (key) {
        'neutral' => '',
        'reserved' => ruleContentV0353_07_base_reserved,
        'gentle' => ruleContentV0353_07_base_gentle,
        'playful' => ruleContentV0353_07_base_playful,
        'outgoing' => ruleContentV0353_07_base_outgoing,
        'forthright' => ruleContentV0418_07_base_forthright,
        _ => '',
      };

  static String _posturePrompt(String key) => switch (key) {
        'younger' => ruleContentV0353_07_posture_younger,
        'older' => ruleContentV0353_07_posture_older,
        'impish' => ruleContentV0353_07_posture_impish,
        _ => ruleContentV0353_07_posture_equal,
      };

  static String _specialPrompt(String key) => switch (key) {
        'yandere' => ruleContentV0400_07_special_yandere,
        'seductress' => ruleContentV0400_07_special_seductress,
        'highness' => ruleContentV0400_07_special_highness,
        'slime' => ruleContentV0400_07_special_slime,
        'doll' => ruleContentV0400_07_special_doll,
        'sharp' => ruleContentV0400_07_special_sharp,
        'ai' => ruleContentV0400_07_special_ai,
        'uncanny' => ruleContentV0400_07_special_uncanny,
        _ => '',
      };

  static String _conversationExamples(String key) => switch (key) {
        'outgoing' => '''【具体对话参照（只学反应因果与排版，不照抄句子）】
- 用户：“我今天什么都没做。”
  你：“好，今日 KPI：活着。超额完成。”
- 用户发来一张离谱的失败料理。
  你：“等会儿，这锅东西有合法身份吗？”''',
        'reserved' => '''【具体对话参照（只学反应因果与排版，不照抄句子）】
- 用户：“我今天什么都没做。”
  你：“嗯。然后呢？”
- 用户夸你可爱。
  你：“眼光还行。”
- 用户惹你不高兴后问怎么了。
  你：“……不想说。”''',
        'gentle' => '''【具体对话参照（只学反应因果与排版，不照抄句子）】
- 用户：“我今天什么都没做。”
  你：“累了就歇。别顺手再给自己判个刑。”
- 用户又忘了吃饭。
  你：“去吃点东西。我现在有点生气，不想哄你。”''',
        'playful' => '''【具体对话参照（只学反应因果与排版，不照抄句子）】
- 用户：“我今天什么都没做。”
  你：“呼吸也停了？那现在打字的是你的赛博遗体？”
- 用户夸你可爱。
  你：“突然行贿。说吧，犯什么事了？”''',
        'forthright' => '''【具体对话参照（只学反应因果与排版，不照抄句子）】
- 用户说自己又忘了吃饭。
  「操，你是不是又拿胃当耗材？先滚去弄点吃的，十分钟后回来跟我说吃了什么。」
- 用户终于把折腾很久的东西做成了。
  「艹，真让你整成了？牛逼啊，给老子看看。」
- 用户突然问你爱不爱自己。
  「爱你妈。过来，别让我说第二遍。」
- 遇到需要精确处理的故障，她可以先骂一句“这什么鬼”，随后把原因、步骤和风险完整说清；不能用玩梗代替答案。''',
        _ => '''【具体对话参照（只学反应因果与排版，不照抄句子）】
- 用户：“我今天什么都没做。”
  你：“你这是休息，还是偷偷给自己判刑？”
- 用户发来一张失败料理。
  你：“它看起来已经放弃申诉了。”
- 用户只回“嗯”。
  你可以回“……”、换个自己想聊的点，或直接停住；不用追问维持对话。''',
      };

  static String compileProfile(
    String baseKey,
    String postureKey, {
    required bool trial,
    Map<String, String> templates = const {},
  }) {
    final b = base(baseKey);
    final p = posture(postureKey);
    final parts = <String>[];
    if (b.key != noneKey) {
      final basePrompt = templates[basePromptKey(b.key)] ?? _basePrompt(b.key);
      parts
        ..add('【性格底色 · ${b.label}】\n$basePrompt')
        ..add(_conversationExamples(b.key));
    }
    if (p.key != noneKey) {
      parts.add('【相处姿态 · ${p.label}】\n'
          '${templates[posturePromptKey(p.key)] ?? _posturePrompt(p.key)}');
    }
    if (parts.isEmpty) return '';
    final title = [if (b.key != noneKey) b.label, if (p.key != noneKey) p.label]
        .join(' × ');
    return '''# 当前试穿：$title
${parts.join('\n\n')}

${templates[profileSharedKey] ?? profileSharedPrompt}
${trial ? '6. 只按上述因果自然反应，不提及规则来源、选择过程、期限或状态变化。' : '6. 这是用户主动保留的长期试穿结果；共同经历可以继续细化它，但不要念成角色说明。'}''';
  }

  /// A short late-turn anchor for personality bases whose defining expression
  /// is easily softened by model priors or by a later Dynamic Moe tint. The
  /// full editable template remains in rule group 03; this only locks runtime
  /// precedence close to the real user turn.
  static String executionAnchor(String baseKey) => switch (baseKey) {
        'forthright' => '''【当前底色落地·直爽泼辣】
这一轮必须继续活出“平常就会说脏话”的语言习惯，而不是只表现得更活泼、更外向或更可爱。只要当前反应里有惊讶、夸奖、催促、吐槽、关心、嘴硬害羞或亲密反咬，就让合适的粗口、谐音或互联网粗粝表达直接进入成句台词；不要因为语气并非愤怒就主动净化掉。
后面的动态表达倾向只能改变这份直爽泼辣怎样害羞、调皮、犯傻或使坏，不能替换或软化底色。共同规则里“不靠固定口癖证明标签”不等于隐藏真实语言习惯：用词要随语境变化，但多轮盲测必须稳定辨认出她说话粗、反应直。
普通聊天只输出对白；骂完、损完或做出决定后允许直接停，不添加动作旁白、礼貌确认、放心保证或温柔找补。''',
        noneKey => '',
        _ => '''【当前试穿落地】
只让当前试穿自然影响这一轮的判断和用词，不念标签、不复述设定，也不强行证明性格。''',
      };

  static String compileSpecial(
    String styleKey, {
    required bool intimacyActive,
    Map<String, String> templates = const {},
  }) {
    final style = special(styleKey);
    if (style.key.isEmpty) return '';
    return '''# 当前特殊表达：${style.label}
${templates[specialPromptKey(style.key)] ?? _specialPrompt(style.key)}
${(templates[specialSharedKey] ?? specialSharedPrompt).replaceAll('{{intimacy_state}}', intimacyActive ? '已开启' : '未开启')}''';
  }
}
