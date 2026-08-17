import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/rule_layer.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_defaults.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_grouping.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_service.dart';

void main() {
  test('ships nine independently persisted sections', () {
    const expectedKeys = <String>{
      '01_core',
      '01_relationship',
      '02_daily',
      '03_behavior',
      '03_personality_seed',
      '03_appearance_identity',
      '04_intimacy_core',
      '05_intimacy_rendering',
      '06_intimacy_reference',
    };
    final byKey = {for (final layer in defaultRuleLayers) layer.key: layer};

    expect(defaultRuleLayers.length, expectedKeys.length);
    expect(byKey.keys.toSet(), expectedKeys);
    expect(byKey['01_core']!.locked, isTrue);
    expect(byKey['01_relationship']!.locked, isTrue);
    expect(byKey['03_personality_seed']!.locked, isFalse);
    expect(byKey['03_appearance_identity']!.locked, isTrue);
  });

  test('presents the nine sections as six maintenance groups', () {
    final now = DateTime(2026, 8, 14);
    final layers = defaultRuleLayers
        .map((layer) => RuleLayer(
              key: layer.key,
              title: layer.title,
              content: layer.content,
              loadPolicy: layer.loadPolicy,
              enabled: true,
              locked: layer.locked,
              updatedAt: now,
            ))
        .toList();
    final groups = groupRuleLayers(layers);
    final byKey = {for (final group in groups) group.key: group};

    expect(
      groups.map((group) => group.key),
      <String>['01', '02', '03', '04', '05', '06'],
    );
    expect(byKey['01']!.layers.map((layer) => layer.key),
        <String>['01_core', '01_relationship']);
    expect(byKey['03']!.layers.map((layer) => layer.key),
        <String>[
          '03_behavior',
          '03_personality_seed',
          '03_appearance_identity',
        ]);
    expect(byKey['01']!.layers.every((layer) => layer.locked), isTrue);
    expect(byKey['03']!.layers[1].locked, isFalse);
    expect(byKey['03']!.layers.last.locked, isTrue);
  });

  test('prompt groups related sections without concatenating their storage', () {
    final now = DateTime(2026, 8, 14);
    RuleLayer layer(
      String key,
      String title,
      String content, {
      bool locked = false,
    }) =>
        RuleLayer(
          key: key,
          title: title,
          content: content,
          loadPolicy: 'always',
          enabled: true,
          locked: locked,
          updatedAt: now,
        );
    final text = RuleLayerBundle(
      layers: [
        layer('01_core', 'core', 'CORE_TEXT', locked: true),
        layer(
          '01_relationship',
          'relationship',
          'RELATIONSHIP_TEXT',
          locked: true,
        ),
        layer('03_behavior', 'behavior', 'BEHAVIOR_TEXT'),
        layer('03_personality_seed', 'seed', 'SEED_TEXT'),
        layer(
          '03_appearance_identity',
          'appearance',
          'APPEARANCE_TEXT',
          locked: true,
        ),
      ],
      intimacyActive: false,
      referenceTriggered: false,
    ).formatForPrompt();

    expect(RegExp(r'## 01 · 身份与关系').allMatches(text).length, 1);
    expect(RegExp(r'## 03 · 行为与初始性格').allMatches(text).length, 1);
    expect(text, contains('### AI 本体与存在'));
    expect(text, contains('### 固定恋爱关系'));
    expect(text, contains('### 行为真实感'));
    expect(text, contains('### 初始性格种子'));
    expect(text, contains('### 固定外观与称呼'));
    expect(
      text.indexOf('CORE_TEXT'),
      lessThan(text.indexOf('RELATIONSHIP_TEXT')),
    );
    expect(text.indexOf('BEHAVIOR_TEXT'), lessThan(text.indexOf('SEED_TEXT')));
    expect(text.indexOf('SEED_TEXT'), lessThan(text.indexOf('APPEARANCE_TEXT')));
  });

  test('personality and appearance defaults preserve the agreed identity', () {
    final byKey = {for (final layer in defaultRuleLayers) layer.key: layer};
    final seed = byKey['03_personality_seed']!.content;
    final appearance = byKey['03_appearance_identity']!.content;

    expect(seed, contains('半自知'));
    expect(seed, contains('陪伴不是一项工作'));
    expect(seed, contains('不是越相处越顺从'));
    expect(seed, contains('不要为了显得可爱而故意答错'));
    expect(appearance, contains('女仆装'));
    expect(appearance, contains('鲸鱼尾巴'));
    expect(appearance, contains('耳鳍'));
    expect(appearance, contains('大肥鱼'));
    expect(appearance, contains('绝不能主动用它自称'));
    expect(appearance, contains('照镜子'));
    expect(seed, isNot(legacyPersonalitySeedV1));
  });

  test('novel word-count rules are not in the companion defaults', () {
    final all = defaultRuleLayers.map((e) => e.content).join('\n');
    expect(all.contains('每轮正文输出必须≥600字'), isFalse);
    expect(all.contains('第三人称有限视角叙事，全程锁定'), isFalse);
  });
}
