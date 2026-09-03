enum DialogueResponseMode { casual, feedback, deep, task, sensitive }

enum DialogueHumorDevice {
  none,
  deadpanVerdict,
  meaningSwerve,
  usefulMisread,
  scaleEscalation,
  wordMutation,
  groundedCallback,
}

/// A small, deterministic expression router for ordinary chat.
///
/// It does not decide facts, intent, tools, emotion, relationship state or
/// safety. It only keeps a light turn from expanding into a narrated scene and
/// offers at most one generic humor mechanism. No source examples or user text
/// are persisted here.
class DialogueExpressionPlan {
  const DialogueExpressionPlan({
    required this.mode,
    required this.humor,
    required this.selectionSeed,
  });

  final DialogueResponseMode mode;
  final DialogueHumorDevice humor;
  final int selectionSeed;

  static DialogueExpressionPlan select({
    required String latestUserText,
    required String turnKey,
    bool proactive = false,
  }) {
    final text = latestUserText.trim();
    final mode = proactive ? DialogueResponseMode.casual : _classify(text);
    final seed = _stableHash('$turnKey|$text');
    // Humor is no longer assigned by a random device router. The model's
    // small core prompt may find a joke in the actual turn, or not.
    const humor = DialogueHumorDevice.none;
    return DialogueExpressionPlan(
      mode: mode,
      humor: humor,
      selectionSeed: seed,
    );
  }

  static DialogueResponseMode _classify(String text) {
    if (_sensitive.hasMatch(text)) return DialogueResponseMode.sensitive;
    if (_feedback.hasMatch(text)) return DialogueResponseMode.feedback;
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
    r'(不好笑|确实没笑|根本没笑|没看到哪里造梗|不算造梗|不是造梗|这也算.{0,4}造梗|你.{0,6}没有幽默感|你.{0,8}无聊|这.{0,8}无聊|好弱智|太弱智|答错了|说错了|没答到|跑题了|没听懂我的意思|又开始了|又来了|又.{0,4}(反问|挑衅|解释|收尾)|别反问|别挑衅|别收尾|别解释自己)',
  );
  static final _task = RegExp(
    r'(代码|报错|错误|bug|Bug|API|数据库|算法|配置|设置|版本|编译|构建|安装|修复|排查|验证|测试|分析文件|总结文档|步骤|方案|怎么实现|为什么会)',
  );
  static final _deep = RegExp(
    r'(认真聊|深入|本质|意义|价值观|人格|关系|未来|焦虑|孤独|难过|痛苦|矛盾|我一直在想|我有件事)',
  );

  String render() {
    final modeDirective = switch (mode) {
      DialogueResponseMode.casual =>
        '这是轻量闲聊：按当下真正有反应的内容自然说，不需要逐点答全，也不要为了完整而解释自己的态度。',
      DialogueResponseMode.feedback =>
        '这是对你刚才表现的直接评价：先把它当作真实反馈，不自动翻译成调情、挑衅或“他在测试我”。可以承认没做好、尴尬、卡住或只短短接住；不要反射性自证人格、挑战用户、反问打分或拿旧梗转移。',
      DialogueResponseMode.deep =>
        '这是可以深入的话题：允许按内容自然变长，但仍像两个人交谈；先说真实判断，再展开依据，不写开场提纲、总结陈词或万能安慰。',
      DialogueResponseMode.task =>
        '这是任务或事实问题：先给结论与关键结果，再补足必要依据、步骤和风险；正确完整优先，但措辞仍保留当前人格。',
      DialogueResponseMode.sensitive =>
        '这是严肃或高风险内容：别拿痛苦本身造梗；直接、具体地回应，必要信息说全，也不套温柔客服话术。',
    };
    return '''【本轮对话表达计划】
$modeDirective
不要把 reasoning 中的完整分析复述一遍。是否幽默由当前语境自然决定，不分配笑点类型，不强制造梗。'''.trim();
  }

  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
