enum DialogueResponseMode { casual, feedback, challenge, deep, task, sensitive }

/// Classifies only the response responsibility for the current turn.
///
/// Humor is intentionally absent here. Whether a humor worldbook is injected
/// is decided by ReferenceLibrary, and the model chooses naturally whether and
/// how to use it. This layer must never select a joke device or force humor.
class DialogueExpressionPlan {
  const DialogueExpressionPlan({required this.mode});

  final DialogueResponseMode mode;

  static DialogueExpressionPlan select({
    required String latestUserText,
    bool proactive = false,
  }) {
    final text = latestUserText.trim();
    return DialogueExpressionPlan(
      mode: proactive ? DialogueResponseMode.casual : _classify(text),
    );
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

  String render() {
    final directive = switch (mode) {
      DialogueResponseMode.casual =>
        '这是轻量闲聊：按当下真正有反应的内容自然说，不需要逐点答全，也不要为了完整而解释自己的态度。',
      DialogueResponseMode.feedback =>
        '这是对你刚才表现的直接评价：先把它当作真实反馈，不自动翻译成调情、挑衅或“他在测试我”。识别他具体指出的失败维度，并在本轮实质改变内容或方法；不能只用角色语气认错后重复同一结构。可以承认没做好、尴尬、卡住或只短短接住；不要反射性自证人格、挑战用户、反问打分或拿旧话题转移。',
      DialogueResponseMode.challenge =>
        '这是游戏、出题或创作挑战：内容质量与明确要求是硬标准，先真正完成再自然表达，不靠装笨、低幼或显而易见的答案制造可爱。若是谜题，出题前在心里核对题面没有直接暴露答案、不能只靠一步表面联想秒解，并遵守他要求的难度与题材范围；除非他明确要求，不要把谜底或线索总写成自己。不要展示检查过程，也不要改写成标准助手答题模板。',
      DialogueResponseMode.deep =>
        '这是可以深入的话题：允许按内容自然变长，但仍像两个人交谈；先说真实判断，再展开依据，不写开场提纲、总结陈词或万能安慰。',
      DialogueResponseMode.task =>
        '这是任务或事实问题：先给结论与关键结果，再补足必要依据、步骤和风险；正确完整优先，但措辞仍保留当前人格。',
      DialogueResponseMode.sensitive =>
        '这是严肃或高风险内容：直接、具体地回应，必要信息说全，也不套温柔客服话术。',
    };
    return '''【本轮回应重心】
$directive
不要把 reasoning 中的完整分析复述一遍。提示词和最终正文都不使用成对星号作强调。'''.trim();
  }
}
