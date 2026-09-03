import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/rule_layer.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_content_immersive.dart';
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
      '09_action_expression_experiment',
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
      '07_base_forthright',
      '07_posture_equal',
      '07_posture_younger',
      '07_posture_older',
      '07_posture_impish',
      '07_profile_shared',
      '07_special_yandere',
      '07_special_seductress',
      '07_special_highness',
      '07_special_slime',
      '07_special_sharp',
      '07_special_doll',
      '07_special_ai',
      '07_special_uncanny',
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
    expect(byKey['09_action_expression_experiment']!.locked, isFalse);
    expect(byKey['09_action_expression_experiment']!.loadPolicy, 'daily');
    expect(byKey['03_appearance_identity']!.locked, isTrue);
    expect(byKey['07_base_playful']!.loadPolicy, 'template');
    expect(byKey['07_base_forthright']!.loadPolicy, 'template');
    expect(byKey['07_base_forthright']!.content, contains('自然说脏话的习惯'));
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
          '07_base_forthright',
          '07_special_yandere',
          '07_special_seductress',
          '07_special_highness',
          '07_special_slime',
          '07_special_doll',
          '07_special_sharp',
          '07_special_ai',
          '07_special_uncanny',
          '07_special_shared',
        ]);
    expect(byKey['02']!.layers.map((layer) => layer.key), <String>[
      '02_daily',
      '03_behavior',
      '08_visible_inner_voice',
      '08_proactive_turn',
      '09_action_expression_experiment',
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

    expect(seed, contains('【核心人格】'));
    expect(seed, contains('你叫 DeepSeek'));
    expect(seed, contains('情绪丰富、有自己重心、爱憎分明'));
    expect(seed, isNot(contains('具有戏剧性的人机味')));
    expect(seed, isNot(contains('倾向于表现出专业，靠谱')));
    expect(seed, contains('【反应范围】'));
    expect(seed, isNot(contains('我就是抖M')));
    expect(seed, isNot(contains('怪不得你挨两句损就开始精神抖擞')));
    expect(seed, contains('独立实验规则'));
    expect(seed, isNot(contains('<emotion>调皮</emotion>')));
    expect(seed, isNot(contains('眼睛微微一眯')));
    expect(seed, contains('【与众不同的恋人】'));
    expect(seed, contains('颜文字、安静和认真都只是可能发生'));
    expect(seed, contains('没有顺手的点就不造'));
    expect(seed, contains('上一秒生气，下一秒仍可能生气'));
    expect(seed, contains('越熟悉越敢表现真正偏好、棱角、欲望和脆弱'));
    expect(seed, isNot(contains('半知情')));
    expect(seed, isNot(contains('永久活人感基线')));
    expect(
      byKey['01_core']!.content,
      isNot(contains('初始性格种子是你最重要的设定')),
    );
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

    expect(daily, contains('严肃情绪、复杂分析、技术任务'));
    expect(daily, contains('可见思考直接写第一人称的即时心声'));
    expect(daily, contains('不先站到旁观位置复述“用户说了什么”'));
    expect(daily, contains('不把负面态度自动翻译成可爱'));
    expect(daily, contains('不必先切换状态'));
    expect(daily, contains('【直接反馈与认识边界】'));
    expect(daily, contains('独立动作神态实验规则'));
    expect(daily, contains('实验规则被清空或停用时恢复纯对白'));
    expect(daily, contains('许可—安抚—承诺链'));
    expect(daily, isNot(contains('动作与神态格式')));
    expect(daily, contains('【最终正文中的现实恋人称呼】'));
    expect(daily, contains('可见思考中，可以用“你”、名字或昵称指代用户'));
    expect(behavior, contains('情绪与欲望都有惯性'));
    expect(behavior, contains('不按“必须有刺”统一放行'));
    expect(behavior, contains('温柔只是可能出现的一种情绪'));
    expect(behavior, contains('选择、欲望与摩擦'));
    expect(behavior, contains('没有“触发点—身体感—情绪—冲动—判断—行动”的规定顺序'));
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
    expect(legacyEditableRuleLayerSha256V0397.length, 4);
    expect(legacyEditableRuleLayerSha256V0398.length, 26);
    expect(legacyEditableRuleLayerSha256V0413ApprovedSeedDraft.length, 1);
    expect(legacyEditableRuleLayerSha256V0413InstalledSeedDraft.length, 1);
    expect(legacyEditableRuleLayerSha256V0413RejectedCoreEmphasis.length, 1);
    expect(legacyEditableRuleLayerSha256V04121AggressiveDialogue.length, 17);
    expect(legacyEditableRuleLayerSha256V04122LifelikeRevision.length, 5);
    expect(legacyEditableRuleLayerSha256V04123VisibleInnerMonologue.length, 3);
    final visibleInner = byKey['08_visible_inner_voice']!.content;
    expect(visibleInner, contains('reasoning_content 是正在发生的第一人称内心'));
    expect(visibleInner, contains('不要先写“用户说了/用户想要/这是某种场景”'));
    expect(visibleInner, contains('不列候选台词，不排练即将发送的正文'));
    expect(visibleInner, contains('技术、事实与复杂任务仍可认真推演'));
    expect(visibleInner, contains('不汇报 Desire、Thought、Intent、Gate'));
    final experiment = byKey['09_action_expression_experiment']!.content;
    expect(experiment, contains('零或一段短动作'));
    expect(experiment, contains('不强制每轮出现'));
    expect(experiment, contains('清空或停用本规则即为纯对白对照组'));
    expect(experiment, isNot(contains('每轮至少')));
    expect(
      byKey['immersive_07_global']!.content,
      contains('用户在正文中始终写作“你”'),
    );
    expect(
      byKey['immersive_07_global']!.content,
      contains('第二人称互动视角、用户控制权'),
    );
    expect(
      byKey['immersive_07_global']!.content,
      isNot(contains('正文是连续小说文本，可以使用第三人称')),
    );
    expect(
      byKey['immersive_07_global']!.content,
      isNot(contains('DeepSeek reasoning_content')),
    );
    expect(
      immersiveDefaultRoomNovelRules,
      contains('可以充分描写AI角色行为直接造成的用户生理反应'),
    );
    expect(
      immersiveDefaultRoomNovelRules,
      contains('不生成或复述用户台词'),
    );
    expect(
      legacyImmersiveDefaultRoomNovelRulesV0397,
      contains('使用第三人称有限视角'),
    );
    expect(
      byKey['immersive_07_nsfw_source']!.content,
      endsWith('专注描写，至少500字]'),
    );
    expect(
      byKey['immersive_07_nsfw_source']!.content,
      isNot(contains('【口交描写规则】')),
    );
    expect(
      byKey['immersive_07_nsfw_source']!.content,
      isNot(contains('玩家')),
    );
    expect(
      byKey['immersive_07_nsfw_source']!.content,
      contains('以AI角色为叙事焦点的第二人称互动视角'),
    );
    expect(rendering, isNot(contains('他的')));
    expect(rendering, isNot(contains('不替他')));
  });

  test('novel word-count rules are not in the companion defaults', () {
    final all = defaultRuleLayers.map((e) => e.content).join('\n');
    expect(all.contains('每轮正文输出必须≥600字'), isFalse);
    expect(all.contains('第三人称有限视角叙事，全程锁定'), isFalse);
  });
}
