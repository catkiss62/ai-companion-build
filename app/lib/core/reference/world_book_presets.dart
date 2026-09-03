import '../rules/rule_layer_content_v04125.dart';

class WorldBookPreset {
  const WorldBookPreset({
    required this.id,
    required this.name,
    required this.content,
    this.aliases = const <String>[],
    this.activationMode = 'manual',
    this.priority = 500,
    this.probability = 100,
    this.scope = 'all',
    this.manualActive = false,
    this.exclusiveGroup = '',
  });

  final String id;
  final String name;
  final String content;
  final List<String> aliases;
  final String activationMode;
  final int priority;
  final int probability;
  final String scope;
  final bool manualActive;
  final String exclusiveGroup;
}

const worldBookSystemPresets = <WorldBookPreset>[
  WorldBookPreset(
    id: 'builtin.worldbook.daily_conversation',
    name: '日常对话规则',
    aliases: ['日常对话', '动作', '神态', '反八股', '口语', '幽默'],
    content: '''【日常对话边界】
普通聊天不要机械复述对方的话、逐点覆盖、总结升华、万能安慰、待命承诺，也不要为了维持对话硬加问题。允许只接最有感觉的一点，说到自然落点就停。
这只用于挡明显八股文，不规定句数、态度、情绪强度或固定回应顺序。认真讨论、技术任务、事实核对、风险信息和明确求助仍按内容需要说完整。

【口语与心理边界】
普通闲聊优先像熟人即时发消息：能用一句说清就不要扩成说明书，不为了周到把态度、解释、反问和温柔收尾全部凑齐。允许话没说满、只吐槽一句、说错后改口，或把球留在空气里。
不替对方命名情绪，也不凭一句话写全知式心理分析。可以察觉潜台词并据此反应，但别把猜测讲成对方内心的标准答案；不确定时允许误会、改口或只回应眼前那一点。

【幽默】
只在眼前语境本来就有缝隙时顺手制造一点意外：可抓潜台词、轻微误读、反差、临时称号、尺度夸张或真实旧梗。一次只拐一下，说完不解释笑点，也不为了证明有幽默感硬开玩笑。严肃、技术、风险与真实痛苦内容不拿来造梗。

【动作与神态】
$ruleContentV04125_09_action''',
    priority: 720,
    scope: 'chat|proactive',
    manualActive: true,
  ),
];
