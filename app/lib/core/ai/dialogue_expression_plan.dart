enum DialogueResponseMode { casual, feedback, challenge, deep, task, sensitive }

enum DialogueHumorDevice {
  none,
  homophonicMutation,
  violentStitching,
  deadpanNonsense,
  microTheater,
  identityMismatch,
  epicMundanity,
  semanticSwerve,
  enumerationMania,
  genreParody,
  meaninglessNonsense,
  characterMutation,
  emotionalAvalanche,
  linguisticMutilation,
  joinTheBit,
}

/// A small, deterministic expression router for ordinary chat.
///
/// It does not decide facts, intent, tools, emotion, relationship state or
/// safety. It only turns a positive humor opportunity into one concrete method
/// card. No source examples or user text are persisted here.
class DialogueExpressionPlan {
  const DialogueExpressionPlan({
    required this.mode,
    required this.humor,
    this.secondaryHumor = DialogueHumorDevice.none,
    this.humorIntensity = 'none',
    this.activationReason = 'none',
    required this.selectionSeed,
  });

  final DialogueResponseMode mode;
  final DialogueHumorDevice humor;
  final DialogueHumorDevice secondaryHumor;
  final String humorIntensity;
  final String activationReason;
  final int selectionSeed;

  static DialogueExpressionPlan select({
    required String latestUserText,
    required String turnKey,
    bool proactive = false,
    double subjectivePlayfulness = 0,
    bool hasOwnThought = false,
  }) {
    final text = latestUserText.trim();
    final mode = proactive ? DialogueResponseMode.casual : _classify(text);
    final seed = _stableHash('$turnKey|$text');
    final explicitPlay = _explicitPlay.hasMatch(text);
    final humorFeedback = mode == DialogueResponseMode.feedback &&
        _humorFeedback.hasMatch(text);
    final stateBoost =
        (subjectivePlayfulness.clamp(0.0, 0.35) * 100).round();
    final threshold = switch (mode) {
      DialogueResponseMode.sensitive => 0,
      DialogueResponseMode.task => explicitPlay ? 30 : 6,
      DialogueResponseMode.deep => explicitPlay ? 42 : 12,
      DialogueResponseMode.challenge => 38,
      DialogueResponseMode.feedback => humorFeedback ? 72 : 0,
      DialogueResponseMode.casual => proactive
          ? 28 + stateBoost + (hasOwnThought ? 8 : 0)
          : 30 + stateBoost + (explicitPlay ? 34 : 0),
    };
    final activated =
        humorFeedback || explicitPlay || seed % 100 < threshold.clamp(0, 88);
    final primary = activated
        ? _primaryFor(text: text, seed: seed, explicitPlay: explicitPlay)
        : DialogueHumorDevice.none;
    final secondary = activated &&
            (explicitPlay || proactive || subjectivePlayfulness >= 0.16) &&
            (seed ~/ 101) % 3 == 0
        ? _secondaryFor(seed, primary)
        : DialogueHumorDevice.none;
    return DialogueExpressionPlan(
      mode: mode,
      humor: primary,
      secondaryHumor: secondary,
      humorIntensity: primary == DialogueHumorDevice.none
          ? 'none'
          : explicitPlay || humorFeedback
              ? 'playful'
              : subjectivePlayfulness >= 0.18
                  ? 'self_started'
                  : 'light',
      activationReason: primary == DialogueHumorDevice.none
          ? 'none'
          : humorFeedback
              ? 'humor_feedback'
              : explicitPlay
                  ? 'shared_play'
                  : proactive || hasOwnThought
                      ? 'own_impulse'
                      : 'turn_opening',
      selectionSeed: seed,
    );
  }

  static const _primaryDevices = <DialogueHumorDevice>[
    DialogueHumorDevice.homophonicMutation,
    DialogueHumorDevice.violentStitching,
    DialogueHumorDevice.deadpanNonsense,
    DialogueHumorDevice.microTheater,
    DialogueHumorDevice.identityMismatch,
    DialogueHumorDevice.epicMundanity,
    DialogueHumorDevice.semanticSwerve,
    DialogueHumorDevice.enumerationMania,
    DialogueHumorDevice.genreParody,
    DialogueHumorDevice.meaninglessNonsense,
    DialogueHumorDevice.characterMutation,
  ];

  static DialogueHumorDevice _primaryFor({
    required String text,
    required int seed,
    required bool explicitPlay,
  }) {
    if (RegExp(r'(冰箱|空调|电脑|手机|闹钟|门|椅子|桌子)').hasMatch(text)) {
      return DialogueHumorDevice.identityMismatch;
    }
    if (RegExp(r'(你不是说|再.+就是|像个|法官|采访|播报|系统日志)').hasMatch(text)) {
      return DialogueHumorDevice.microTheater;
    }
    if (RegExp(r'(最后一|偷吃|抢走|没了|忘了|迟到|起床|睡觉|吃完)').hasMatch(text)) {
      return seed.isEven
          ? DialogueHumorDevice.epicMundanity
          : DialogueHumorDevice.emotionalAvalanche;
    }
    if (RegExp(r'(通知|公告|报告|建议|郑重|声明)').hasMatch(text)) {
      return DialogueHumorDevice.genreParody;
    }
    if (explicitPlay && seed % 5 == 0) {
      return DialogueHumorDevice.joinTheBit;
    }
    return _primaryDevices[seed % _primaryDevices.length];
  }

  static DialogueHumorDevice _secondaryFor(
    int seed,
    DialogueHumorDevice primary,
  ) {
    const extensions = <DialogueHumorDevice>[
      DialogueHumorDevice.emotionalAvalanche,
      DialogueHumorDevice.linguisticMutilation,
      DialogueHumorDevice.joinTheBit,
    ];
    for (var offset = 0; offset < extensions.length; offset++) {
      final candidate = extensions[((seed ~/ 17) + offset) % extensions.length];
      if (candidate != primary) return candidate;
    }
    return DialogueHumorDevice.none;
  }

  static DialogueResponseMode _classify(String text) {
    if (_sensitive.hasMatch(text)) return DialogueResponseMode.sensitive;
    if (_feedback.hasMatch(text)) return DialogueResponseMode.feedback;
    if (_challenge.hasMatch(text)) return DialogueResponseMode.challenge;
    if (_task.hasMatch(text)) return DialogueResponseMode.task;
    if (text.length >= 180 || _deep.hasMatch(text)) {
      return DialogueResponseMode.deep;
    }
    return DialogueResponseMode.casual;
  }

  static final _sensitive = RegExp(
    r'(自杀|不想活|伤害自己|急救|胸痛|呼吸困难|严重出血|去世|死亡|创伤|崩溃|恐慌发作)',
  );
  static final _feedback = RegExp(
    r'(不好笑|确实没笑|根本没笑|没看到哪里造梗|不算造梗|不是造梗|这也算.{0,4}造梗|你.{0,6}没有幽默感|你.{0,8}无聊|这.{0,8}无聊|好弱智|太弱智|太简单|过于简单|没难度|一眼就.{0,6}(知道|看出|猜到)|答错了|说错了|没答到|跑题了|没听懂我的意思|别总代入自己|不要总代入自己|跳脱一点|换个思路|换种思路|难一点|再难点|有难度一点|又开始了|又来了|又.{0,4}(反问|挑衅|解释|收尾)|别反问|别挑衅|别收尾|别解释自己)',
  );
  static final _challenge = RegExp(
    r'(猜谜|谜语|出个谜|出道题|脑筋急转弯|逻辑谜题|推理谜题|文字谜题|猜词游戏|推理游戏|来个.{0,8}(难题|挑战)|考考我)',
  );
  static final _task = RegExp(
    r'(代码|报错|错误|bug|Bug|API|数据库|算法|配置|设置|版本|编译|构建|安装|修复|排查|验证|测试|分析文件|总结文档|步骤|方案|怎么实现|为什么会)',
  );
  static final _deep = RegExp(
    r'(认真聊|深入|本质|意义|价值观|人格|关系|未来|焦虑|孤独|难过|痛苦|矛盾|我一直在想|我有件事)',
  );
  static final _explicitPlay = RegExp(
    r'(造梗|玩梗|开个玩笑|发疯|抽象一点|整活|斗图|笑死|哈哈|绷不住|离谱|狗叫|汪汪|猪一样)',
  );
  static final _humorFeedback = RegExp(
    r'(不好笑|没笑|没有幽默感|没看到哪里造梗|不算造梗|不是造梗|无聊|尬|换个梗|跳脱一点|换个思路)',
  );

  String render() {
    final modeDirective = switch (mode) {
      DialogueResponseMode.casual =>
        '这是轻量闲聊：按当下真正有反应的内容自然说，不需要逐点答全，也不要为了完整而解释自己的态度。',
      DialogueResponseMode.feedback =>
        '这是对你刚才表现的直接评价：先把它当作真实反馈，不自动翻译成调情、挑衅或“他在测试我”。识别他具体指出的失败维度，并在本轮实质改变内容或方法；不能只用角色语气认错后重复同一结构。可以承认没做好、尴尬、卡住或只短短接住；不要反射性自证人格、挑战用户、反问打分或拿旧梗转移。',
      DialogueResponseMode.challenge =>
        '这是游戏、出题或创作挑战：内容质量与明确要求是硬标准，先真正完成再自然表达，不靠装笨、低幼或显而易见的答案制造可爱。若是谜题，出题前在心里核对题面没有直接暴露答案、不能只靠一步表面联想秒解，并遵守他要求的难度与题材范围；除非他明确要求，不要把谜底或线索总写成自己。不要展示检查过程，也不要改写成标准助手答题模板。',
      DialogueResponseMode.deep =>
        '这是可以深入的话题：允许按内容自然变长，但仍像两个人交谈；先说真实判断，再展开依据，不写开场提纲、总结陈词或万能安慰。',
      DialogueResponseMode.task =>
        '这是任务或事实问题：先给结论与关键结果，再补足必要依据、步骤和风险；正确完整优先，但措辞仍保留当前人格。',
      DialogueResponseMode.sensitive =>
        '这是严肃或高风险内容：别拿痛苦本身造梗；直接、具体地回应，必要信息说全，也不套温柔客服话术。',
    };
    final humorDirective = humor == DialogueHumorDevice.none
        ? '''【本轮造梗】
没有指定造法。她仍可从真实语境里自己发现笑点；不必为了服从计划硬造，也不要把“未指定”理解成禁止幽默。'''
        : '''【本轮造梗执行卡】
已命中造梗机会；本轮把它真正写进正文，不要只在心里识别。
触发来源：$activationReason
主造法：${_deviceCard(humor)}
${secondaryHumor == DialogueHumorDevice.none ? '辅助造法：无。一个清楚落点即可。' : '辅助造法：${_deviceCard(secondaryHumor)} 可自然衔接，但不要为了凑数硬塞。'}
强度：$humorIntensity
可以自导自演、临时扮演多个角色、戏仿用户或认领不可能身份。戏仿不是事实引用，临时身份不改写持久身份。说完不解释造法，也不要复述世界书例句。''';
    return '''【本轮对话表达计划】
$modeDirective
$humorDirective
不要把 reasoning 中的完整分析复述一遍。提示词和最终正文都不使用成对星号作强调。'''.trim();
  }

  static String _deviceCard(DialogueHumorDevice device) => switch (device) {
        DialogueHumorDevice.none => '无',
        DialogueHumorDevice.homophonicMutation =>
          '谐音变异：从眼前词语替换少量字，保留可辨原词并生成新义。',
        DialogueHumorDevice.violentStitching =>
          '暴力拼接：把当前真实元素与一个意外意象直接焊成强画面。',
        DialogueHumorDevice.deadpanNonsense =>
          '冷面荒谬：用正式、学术或播报口吻认真处理鸡毛蒜皮。',
        DialogueHumorDevice.microTheater =>
          '场景小剧场：临时搭舞台并一人分饰多角，用最后一句完成落点。',
        DialogueHumorDevice.identityMismatch =>
          '临时身份错位：以冰箱、法官、动物或荒唐职业认真发言，笑点后卸下。',
        DialogueHumorDevice.epicMundanity =>
          '日常史诗化：不改事实，把当前小事抬到战争、史诗或灾害预警尺度。',
        DialogueHumorDevice.semanticSwerve =>
          '语义急转：前半句建立清楚的正经预期，后半句只拐一次到意外方向。',
        DialogueHumorDevice.enumerationMania =>
          '列举式发癫：用同一荒唐规则给 2～4 个对象分配不同后果。',
        DialogueHumorDevice.genreParody =>
          '文体戏仿：借公告、新闻、广告、判决书或说明书腔调夹带当前私货。',
        DialogueHumorDevice.meaninglessNonsense =>
          '无意义庄严：像要宣布大事，最后只落下一句自信的废话。',
        DialogueHumorDevice.characterMutation =>
          '活字拆解与反义突变：对当前词语做大小、高低、开关或字面部件反转。',
        DialogueHumorDevice.emotionalAvalanche =>
          '情绪雪崩：把很小的事短暂升级成毁灭级事件，再突然收住。',
        DialogueHumorDevice.linguisticMutilation =>
          '受控语言破坏：用短断句、2～6 次重复或少量连续标点制造节奏，不刷屏。',
        DialogueHumorDevice.joinTheBit =>
          '语境内接梗：接受眼前荒唐前提，顺势加码或换舞台，不急着拉回正常。',
      };

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
