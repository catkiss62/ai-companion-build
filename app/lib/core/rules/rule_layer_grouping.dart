import '../models/rule_layer.dart';

class RuleLayerGroup {
  const RuleLayerGroup({
    required this.key,
    required this.title,
    required this.description,
    required this.layers,
  });

  final String key;
  final String title;
  final String description;
  final List<RuleLayer> layers;

  bool get hasMultipleSections => layers.length > 1;
}

class _RuleLayerGroupSpec {
  const _RuleLayerGroupSpec(this.key, this.title, this.description);

  final String key;
  final String title;
  final String description;
}

const _groupSpecs = <String, _RuleLayerGroupSpec>{
  '01': _RuleLayerGroupSpec(
    '01',
    '01 · 身份核心',
    'AI 本体、关系事实、固定外观与最上层身份边界。',
  ),
  '02': _RuleLayerGroupSpec(
    '02',
    '02 · 日常说话规则',
    '普通聊天、行为真实感、可见思考与主动开口方式。',
  ),
  '03': _RuleLayerGroupSpec(
    '03',
    '03 · 性格底色',
    '长期性格种子、四个底色、四个相处姿态、八个特殊风格与共同约束。',
  ),
  '04': _RuleLayerGroupSpec(
    '04',
    '04 · 记忆规则',
    '长期记忆、AI Self、关系事实、推断与原始思考的写入边界。',
  ),
  '05': _RuleLayerGroupSpec(
    '05',
    '05 · NSFW 状态机',
    '只在明确的成年人亲密 Session 中决定状态、空间、边界与退出。',
  ),
  '06': _RuleLayerGroupSpec(
    '06',
    '06 · NSFW 渲染',
    '亲密 Session 的表达、动作连续性与按需参考资料。',
  ),
};

const _groupKeyByLayer = <String, String>{
  // Historical v0.34.2 evidence: '03_appearance_identity': '03'.
  // Prompt Workbench intentionally moves appearance into 01 · 身份核心.
  '01_core': '01',
  '01_relationship': '01',
  '02_daily': '02',
  '03_behavior': '02',
  '03_personality_seed': '03',
  '03_personality_expression': '03',
  '03_appearance_identity': '01',
  '04_memory_rules': '04',
  '04_intimacy_core': '05',
  '05_intimacy_rendering': '06',
  '06_intimacy_reference': '06',
  '08_runtime_identity': '01',
  '08_visible_inner_voice': '02',
  '08_proactive_turn': '02',
};

const _sectionTitles = <String, String>{
  '01_core': 'AI 本体与存在',
  '01_relationship': '固定恋爱关系',
  '02_daily': '日常交流规则',
  '03_behavior': '行为真实感',
  '03_personality_seed': '初始性格种子',
  '03_personality_expression': '当前表达底色与相处姿态',
  '03_appearance_identity': '固定外观与称呼',
  '04_intimacy_core': '亲密关系核心',
  '05_intimacy_rendering': '亲密表现规则',
  '06_intimacy_reference': '亲密参考资料',
};

String ruleLayerSectionTitle(RuleLayer layer) =>
    _sectionTitles[layer.key] ?? layer.title;

List<RuleLayerGroup> groupRuleLayers(Iterable<RuleLayer> layers) {
  final order = <String>[];
  final grouped = <String, List<RuleLayer>>{};
  for (final layer in layers) {
    final groupKey = _groupKeyByLayer[layer.key] ??
        (layer.key.startsWith('07_') ? '03' : 'custom:${layer.key}');
    if (!grouped.containsKey(groupKey)) {
      order.add(groupKey);
      grouped[groupKey] = <RuleLayer>[];
    }
    grouped[groupKey]!.add(layer);
  }

  final sortedOrder = [...order]..sort((a, b) {
      final ai = int.tryParse(a);
      final bi = int.tryParse(b);
      if (ai != null && bi != null) return ai.compareTo(bi);
      if (ai != null) return -1;
      if (bi != null) return 1;
      return order.indexOf(a).compareTo(order.indexOf(b));
    });
  return sortedOrder.map((groupKey) {
    final members = List<RuleLayer>.unmodifiable(grouped[groupKey]!);
    final spec = _groupSpecs[groupKey];
    return RuleLayerGroup(
      key: spec?.key ?? groupKey,
      title: spec?.title ?? members.first.title,
      description: spec?.description ?? '自定义规则层',
      layers: members,
    );
  }).toList(growable: false);
}
