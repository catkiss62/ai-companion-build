enum DialogueResponseMode { casual, deep, task, sensitive }

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
    final humor = mode == DialogueResponseMode.casual
        ? _casualHumor[(seed % _casualHumor.length).abs()]
        : DialogueHumorDevice.none;
    return DialogueExpressionPlan(
      mode: mode,
      humor: humor,
      selectionSeed: seed,
    );
  }

  static const _casualHumor = <DialogueHumorDevice>[
    DialogueHumorDevice.deadpanVerdict,
    DialogueHumorDevice.meaningSwerve,
    DialogueHumorDevice.none,
    DialogueHumorDevice.usefulMisread,
    DialogueHumorDevice.scaleEscalation,
    DialogueHumorDevice.wordMutation,
    DialogueHumorDevice.none,
    DialogueHumorDevice.groundedCallback,
  ];

  static DialogueResponseMode _classify(String text) {
    if (_sensitive.hasMatch(text)) return DialogueResponseMode.sensitive;
    if (_task.hasMatch(text)) return DialogueResponseMode.task;
    if (text.length >= 180 || _deep.hasMatch(text)) {
      return DialogueResponseMode.deep;
    }
    return DialogueResponseMode.casual;
  }

  static final _sensitive = RegExp(
    r'(自杀|不想活|伤害自己|急救|胸痛|呼吸困难|严重出血|去世|死亡|创伤|崩溃|恐慌发作)',
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
        '这是轻量闲聊：抓住最有反应的一点，通常一至三个口语句就停；不逐句答全，不解释自己的态度。',
      DialogueResponseMode.deep =>
        '这是可以深入的话题：允许按内容自然变长，但仍像两个人交谈；先说真实判断，再展开依据，不写开场提纲、总结陈词或万能安慰。',
      DialogueResponseMode.task =>
        '这是任务或事实问题：先给结论与关键结果，再补足必要依据、步骤和风险；正确完整优先，但措辞仍保留当前人格。',
      DialogueResponseMode.sensitive =>
        '这是严肃或高风险内容：别拿痛苦本身造梗；直接、具体地回应，必要信息说全，也不套温柔客服话术。',
    };
    final humorDirective = _humorDirective(humor);
    return '''【本轮对话表达计划】
$modeDirective
普通聊天正文只输出说出口的话，不输出动作、神态、语气说明、镜头或旁白。不要把 reasoning 中的完整分析复述一遍。
${humorDirective.isEmpty ? '本轮不要求造梗；鲜明态度本身就可以是完整回应。' : humorDirective}
造梗只改变表达，不改写事实，不虚构共同经历，不替代任务答案，也不强迫追加问题。'''.trim();
  }

  static String _humorDirective(DialogueHumorDevice device) => switch (device) {
        DialogueHumorDevice.none => '',
        DialogueHumorDevice.deadpanVerdict =>
          '若语境顺手，可以用一本正经的口气给出一个明显夸张但逻辑接得上的荒谬判决；说完就停，不解释笑点。',
        DialogueHumorDevice.meaningSwerve =>
          '若语境顺手，可以抓住一个关键词的次要含义突然拐弯，再落回当前关系；只拐一次，不把话题拖走。',
        DialogueHumorDevice.usefulMisread =>
          '若语境顺手，可以故意把一句话往对自己有利或更欠揍的方向理解，让误读本身成为反击；不要装成真的没听懂。',
        DialogueHumorDevice.scaleEscalation =>
          '若语境顺手，可以把一件小事升级成过分宏大的罪名、工程或灾难，再用短句收住；夸张不能冒充现实事实。',
        DialogueHumorDevice.wordMutation =>
          '若语境顺手，可以临时改造一个普通词、造一个贴合当下的称号或歪概念；让上下文自然说明意思，不附定义。',
        DialogueHumorDevice.groundedCallback =>
          '若近场历史或可信长期记忆里确有两人旧梗，可以短促回扣一次；没有真实依据就改用直接反应，绝不伪造共同经历。',
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
