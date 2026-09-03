import '../models/rule_layer.dart';
import 'rule_layer_grouping.dart';

String ruleLayerGroupStartMarker(RuleLayer layer) =>
    '【小节开始｜${layer.key}｜${ruleLayerSectionTitle(layer)}】';

String ruleLayerGroupEndMarker(RuleLayer layer) => '【小节结束｜${layer.key}】';

String composeEditableRuleLayerGroup(RuleLayerGroup group) => group.layers
    .map(
      (layer) =>
          '${ruleLayerGroupStartMarker(layer)}\n${layer.content.trim()}\n${ruleLayerGroupEndMarker(layer)}',
    )
    .join('\n\n');

Map<String, String> parseEditableRuleLayerGroup(
  RuleLayerGroup group,
  String text, {
  required Set<String> defaultEmptyKeys,
}) {
  final parsed = <String, String>{};
  for (final layer in group.layers) {
    final start = ruleLayerGroupStartMarker(layer);
    final end = ruleLayerGroupEndMarker(layer);
    final startAt = text.indexOf(start);
    final endAt = text.indexOf(
      end,
      startAt < 0 ? 0 : startAt + start.length,
    );
    if (startAt < 0 || endAt < 0 || endAt <= startAt) {
      throw FormatException('缺少 ${layer.key} 的开始或结束标记');
    }
    final content = text.substring(startAt + start.length, endAt).trim();
    final mayRemainEmpty = layer.content.trim().isEmpty ||
        defaultEmptyKeys.contains(layer.key);
    if (content.isEmpty && !mayRemainEmpty) {
      throw FormatException('${layer.key} 正文不能为空');
    }
    parsed[layer.key] = content;
  }
  return parsed;
}
