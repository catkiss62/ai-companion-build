import 'package:ai_companion_localfirst/core/models/rule_layer.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_group_editor_codec.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

RuleLayer _layer(String key, String content) => RuleLayer(
      key: key,
      title: key,
      content: content,
      loadPolicy: 'daily',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

void main() {
  test('placeholder sections may remain empty while sibling edits save', () {
    final group = RuleLayerGroup(
      key: '02',
      title: '日常',
      description: '',
      layers: [_layer('02_daily', ''), _layer('08_proactive_turn', '旧正文')],
    );
    final source = composeEditableRuleLayerGroup(group).replaceFirst(
      '旧正文',
      '新正文',
    );
    final parsed = parseEditableRuleLayerGroup(
      group,
      source,
      defaultEmptyKeys: const {'02_daily'},
    );
    expect(parsed['02_daily'], isEmpty);
    expect(parsed['08_proactive_turn'], '新正文');
  });

  test('default-empty placeholder can be cleared back to empty', () {
    final group = RuleLayerGroup(
      key: '02',
      title: '日常',
      description: '',
      layers: [_layer('02_daily', '用户临时填写的内容')],
    );
    final source = composeEditableRuleLayerGroup(group).replaceFirst(
      '用户临时填写的内容',
      '',
    );
    final parsed = parseEditableRuleLayerGroup(
      group,
      source,
      defaultEmptyKeys: const {'02_daily'},
    );
    expect(parsed['02_daily'], isEmpty);
  });

  test('substantive sections still reject accidental deletion', () {
    final group = RuleLayerGroup(
      key: '01',
      title: '身份',
      description: '',
      layers: [_layer('01_core', '不能误删')],
    );
    final source = composeEditableRuleLayerGroup(group).replaceFirst(
      '不能误删',
      '',
    );
    expect(
      () => parseEditableRuleLayerGroup(
        group,
        source,
        defaultEmptyKeys: const {},
      ),
      throwsFormatException,
    );
  });

  test('editor hides only known migrated placeholders that are empty', () {
    final emptyPlaceholder = _layer('02_daily', '');
    final userFilledPlaceholder = _layer('03_behavior', '用户恢复的正文');
    final unrelatedEmpty = _layer('custom_rule', '');
    final substantive = _layer('08_proactive_turn', '主动正文');
    final group = RuleLayerGroup(
      key: '02',
      title: '日常',
      description: '',
      layers: [
        emptyPlaceholder,
        userFilledPlaceholder,
        unrelatedEmpty,
        substantive,
      ],
    );

    final editable = editableRuleLayerGroup(group);
    expect(editable.layers.map((item) => item.key), [
      '03_behavior',
      'custom_rule',
      '08_proactive_turn',
    ]);
    expect(hiddenMigratedRuleLayerPlaceholderCount(group), 1);
    expect(group.layers, hasLength(4));
  });

  test('full export composition retains hidden stable placeholder markers', () {
    final group = RuleLayerGroup(
      key: '01',
      title: '身份',
      description: '',
      layers: [_layer('01_relationship', ''), _layer('01_core', '身份正文')],
    );

    final exported = composeEditableRuleLayerGroup(group);
    final edited = composeEditableRuleLayerGroup(editableRuleLayerGroup(group));
    expect(exported, contains('01_relationship'));
    expect(edited, isNot(contains('01_relationship')));
    expect(exported, contains('01_core'));
  });
}
