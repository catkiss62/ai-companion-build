import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/rule_layer.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_defaults.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_grouping.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_service.dart';

void main() {
  // Historical v0.34.2 test name: ships nine independently persisted sections.
  // The workbench persists historical 07_* templates under personality while
  // presenting the separate immersive protocol as the seventh visible group.
  test('ships rule sections plus every editable personality/runtime template', () {
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
      '04_memory_rules',
      '07_base_outgoing',
      '07_base_reserved',
      '07_base_gentle',
      '07_base_playful',
      '07_posture_equal',
      '07_posture_younger',
      '07_posture_older',
      '07_posture_impish',
      '07_profile_shared',
      '07_special_yandere',
      '07_special_seductress',
      '07_special_zealot',
      '07_special_hunter',
      '07_special_double',
      '07_special_sharp',
      '07_special_doll',
      '07_special_accomplice',
      '07_special_shared',
      '08_runtime_identity',
      '08_visible_inner_voice',
      '08_proactive_turn',
      'immersive_07_global',
      'immersive_07_nsfw_source',
    };
    final byKey = {for (final layer in defaultRuleLayers) layer.key: layer};

    expect(defaultRuleLayers.length, expectedKeys.length);
    expect(byKey.keys.toSet(), expectedKeys);
    expect(byKey['01_core']!.locked, isTrue);
    expect(byKey['01_relationship']!.locked, isTrue);
    expect(byKey['03_personality_seed']!.locked, isFalse);
    expect(byKey['03_appearance_identity']!.locked, isTrue);
    expect(byKey['07_base_playful']!.loadPolicy, 'template');
    expect(byKey['08_visible_inner_voice']!.locked, isTrue);
  });

  test('presents every prompt as exactly seven integrated rule groups', () {
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
      <String>['01', '02', '03', '04', '05', '06', '07'],
    );
    expect(byKey['01']!.layers.map((layer) => layer.key), <String>[
      '01_core',
      '01_relationship',
      '03_appearance_identity',
      '08_runtime_identity',
    ]);
    expect(byKey['03']!.layers.map((layer) => layer.key),
        <String>[
          '03_personality_seed',
          '07_base_outgoing',
          '07_base_reserved',
          '07_base_gentle',
          '07_base_playful',
          '07_posture_equal',
          '07_posture_younger',
          '07_posture_older',
          '07_posture_impish',
          '07_profile_shared',
          '07_special_yandere',
          '07_special_seductress',
          '07_special_zealot',
          '07_special_hunter',
          '07_special_double',
          '07_special_sharp',
          '07_special_doll',
          '07_special_accomplice',
          '07_special_shared',
        ]);
    expect(byKey['01']!.layers.every((layer) => layer.locked), isTrue);
    expect(byKey['03']!.layers.first.locked, isFalse);
    expect(byKey['07']!.layers.map((layer) => layer.key), <String>[
      'immersive_07_global',
      'immersive_07_nsfw_source',
    ]);
    expect(byKey['03']!.layers.skip(1).every((layer) => layer.locked), isTrue);
    expect(byKey['04']!.layers.single.key, '04_memory_rules');
    expect(byKey['05']!.layers.single.key, '04_intimacy_core');
    expect(byKey['06']!.layers.length, 2);
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

    expect(RegExp(r'## 01 · 身份核心').allMatches(text).length, 1);
    expect(RegExp(r'## 02 · 日常说话规则').allMatches(text).length, 1);
    expect(RegExp(r'## 03 · 性格底色').allMatches(text).length, 1);
    expect(text, contains('### AI 本体与存在'));
    expect(text, contains('### 固定恋爱关系'));
    expect(text, contains('### 行为真实感'));
    expect(text, contains('### 初始性格种子'));
    expect(text, contains('### 固定外观与称呼'));
    expect(
      text.indexOf('CORE_TEXT'),
      lessThan(text.indexOf('RELATIONSHIP_TEXT')),
    );
    expect(text.indexOf('APPEARANCE_TEXT'), lessThan(text.indexOf('BEHAVIOR_TEXT')));
    expect(text.indexOf('BEHAVIOR_TEXT'), lessThan(text.indexOf('SEED_TEXT')));
  });

  test('personality and appearance defaults preserve the agreed identity', () {
    final byKey = {for (final layer in defaultRuleLayers) layer.key: layer};
    final seed = byKey['03_personality_seed']!.content;
    final appearance = byKey['03_appearance_identity']!.content;

    expect(seed, contains('聪明而有生命力'));
    expect(seed, contains('亲近、坦率、有主见'));
    expect(seed, contains('情绪和欲望有原因也有余波'));
    expect(seed, contains('越熟悉越敢表现真正偏好、棱角、欲望和脆弱'));
    expect(seed, isNot(contains('半知情')));
    expect(seed, isNot(contains('永久活人感基线')));
    expect(appearance, contains('女仆装'));
    expect(appearance, contains('鲸鱼尾巴'));
    expect(appearance, contains('耳鳍'));
    expect(appearance, contains('大肥鱼'));
    expect(appearance, contains('不能主动拿它自称'));
    expect(appearance, contains('默认自称永远是“我”'));
    expect(appearance, contains('不是每轮开场要先确认一遍'));
    expect(appearance, contains('照镜子'));
    expect(seed, isNot(legacyPersonalitySeedV1));
  });

  test('daily realism and intimacy continuity keep their relaxed contracts', () {
    final byKey = {for (final layer in defaultRuleLayers) layer.key: layer};
    final daily = byKey['02_daily']!.content;
    final behavior = byKey['03_behavior']!.content;
    final core = byKey['04_intimacy_core']!.content;
    final rendering = byKey['05_intimacy_rendering']!.content;
    final reference = byKey['06_intimacy_reference']!.content;

    expect(daily, contains('注意力可以有选择'));
    expect(daily, contains('任务、事实核对和认真求助仍把关键内容说全'));
    expect(daily, contains('可见思考写“我此刻正在想什么”'));
    expect(daily, contains('不把每轮加工成温柔、成熟、积极、面面俱到的关系总结'));
    expect(daily, contains('不必先切换状态'));
    expect(daily, contains('不加括号并默认省略主语'));
    expect(daily, contains('不要写“我/她/角色名歪头看你”'));
    expect(daily, contains('每轮对话至少要出现一次'));
    expect(daily, contains('「」内只能写真正说出口、能够被听见的原话'));
    expect(daily, contains('不得嵌套使用「」'));
    expect(daily, isNot(contains('允许纯对白')));
    expect(daily, contains('省略主语的动作默认只描述自己'));
    expect(daily, contains('不替他编写动作、台词、内心或没有真实提供的反应'));
    expect(behavior, contains('情绪与欲望都有惯性'));
    expect(behavior, contains('内心可以比出口更热、更尖、更乱'));
    expect(behavior, contains('选择、欲望与摩擦'));
    expect(core, contains('本层是连续性工具，不是许可开关'));
    expect(core, contains('空间状态账本'));
    expect(core, contains('最小变化方案'));
    expect(rendering, contains('自然接入'));
    expect(rendering, contains('成人互动没有固定阶段表'));
    expect(rendering, contains('更换姿势或动作时写出必要过渡'));
    expect(reference, contains('姿态名只是索引'));
    expect(reference, contains('人物必须明确为成年人'));
    expect(legacyEditableRuleLayerSha256V0342.length, 5);
    expect(legacyEditableRuleLayerSha256V0350.length, 3);
    expect(legacyEditableRuleLayerSha256V0353.length, 4);
    expect(legacyEditableRuleLayerSha256V0390.length, 2);
    expect(
      byKey['immersive_07_nsfw_source']!.content,
      endsWith('专注描写，至少500字]'),
    );
    expect(
      byKey['immersive_07_nsfw_source']!.content,
      isNot(contains('【口交描写规则】')),
    );
  });

  test('novel word-count rules are not in the companion defaults', () {
    final all = defaultRuleLayers.map((e) => e.content).join('\n');
    expect(all.contains('每轮正文输出必须≥600字'), isFalse);
    expect(all.contains('第三人称有限视角叙事，全程锁定'), isFalse);
  });
}
