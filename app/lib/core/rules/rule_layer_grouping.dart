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
    '01 · 身份与关系',
    'AI 本体、存在方式、长期关系事实、自主性与边界。两个小节同属锁定的最高优先级基础。',
  ),
  '02': _RuleLayerGroupSpec(
    '02',
    '02 · 日常交流',
    '普通聊天的长度、口语、节奏与叙事克制。',
  ),
  '03': _RuleLayerGroupSpec(
    '03',
    '03 · 行为与初始性格',
    '行为真实感与固定外观常驻；初始性格是可编辑、可关闭、会被长期 AI Self 细化的种子。',
  ),
  '04': _RuleLayerGroupSpec(
    '04',
    '04 · 亲密关系核心',
    '只在明确的成年人亲密 Session 中决定状态、边界与连续性。',
  ),
  '05': _RuleLayerGroupSpec(
    '05',
    '05 · 亲密表现',
    '只在亲密 Session 中控制沉浸式表现方式。',
  ),
  '06': _RuleLayerGroupSpec(
    '06',
    '06 · 亲密参考资料',
    '只在亲密 Session 且检索到相关资料时按需加载。',
  ),
};

const _groupKeyByLayer = <String, String>{
  '01_core': '01',
  '01_relationship': '01',
  '02_daily': '02',
  '03_behavior': '03',
  '03_personality_seed': '03',
  '03_appearance_identity': '03',
  '04_intimacy_core': '04',
  '05_intimacy_rendering': '05',
  '06_intimacy_reference': '06',
};

const _sectionTitles = <String, String>{
  '01_core': 'AI 本体与存在',
  '01_relationship': '固定恋爱关系',
  '02_daily': '日常交流规则',
  '03_behavior': '行为真实感',
  '03_personality_seed': '初始性格种子',
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
    final groupKey = _groupKeyByLayer[layer.key] ?? 'custom:${layer.key}';
    if (!grouped.containsKey(groupKey)) {
      order.add(groupKey);
      grouped[groupKey] = <RuleLayer>[];
    }
    grouped[groupKey]!.add(layer);
  }

  return order.map((groupKey) {
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
