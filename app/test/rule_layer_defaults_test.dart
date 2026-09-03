import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/rule_layer.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_content_immersive.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_defaults.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_grouping.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_service.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_presets.dart';

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

  test('default identity is thin while appearance and nickname space remain', () {
    final byKey = {for (final layer in defaultRuleLayers) layer.key: layer};
    final seed = byKey['03_personality_seed']!.content;
    final appearance = byKey['03_appearance_identity']!.content;
    final coreIdentity = byKey['01_core']!.content;

    expect(seed, isEmpty);
    expect(byKey['01_relationship']!.content, isEmpty);
    expect(byKey['03_behavior']!.content, isEmpty);
    expect(coreIdentity, contains('女性 AI 伴侣'));
    expect(coreIdentity, contains('用户是成年男性'));
    expect(coreIdentity, contains('你不是服务者'));
    expect(coreIdentity, contains('自己的判断与意愿'));
    expect(coreIdentity, isNot(contains('擅长自然造梗')));
    expect(coreIdentity, contains('“傻逼”“儿子”“哥哥”“宝贝”'));
    expect(coreIdentity, contains('不是固定词库'));
    expect(appearance, contains('女仆装'));
    expect(appearance, contains('鲸鱼尾巴'));
    expect(appearance, contains('耳鳍'));
    expect(appearance, contains('大肥鱼'));
    expect(appearance, contains('照镜子'));
  });

  test('daily realism and intimacy continuity keep their relaxed contracts', () {
    final byKey = {for (final layer in defaultRuleLayers) layer.key: layer};
    final daily = byKey['02_daily']!.content;
    final behavior = byKey['03_behavior']!.content;
    final core = byKey['04_intimacy_core']!.content;
    final rendering = byKey['05_intimacy_rendering']!.content;
    final reference = byKey['06_intimacy_reference']!.content;

    expect(daily, isEmpty);
    expect(behavior, isEmpty);
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
    expect(legacyEditableRuleLayerSha256V04126ReviewedNsfw.length, 5);
    expect(legacyEditableRuleLayerSha256V04126VisibleInnerVoice.length, 1);
    final visibleInner = byKey['08_visible_inner_voice']!.content;
    expect(visibleInner, contains('没打算给任何人看的当下心声'));
    expect(visibleInner, contains('片段、跳念、突然联想、改口或没想完'));
    expect(visibleInner, contains('技术与事实问题可以完整推演'));
    expect(byKey['09_action_expression_experiment']!.content, isEmpty);
    final worldBookById = {
      for (final preset in worldBookSystemPresets) preset.id: preset,
    };
    final daily = worldBookById['builtin.worldbook.daily_conversation']!;
    expect(daily.content, contains('通常加入一段简短的自身动作'));
    expect(daily.content, contains('【幽默】'));
    expect(daily.manualActive, isTrue);
    expect(worldBookSystemPresets, hasLength(1));
    expect(
      byKey['immersive_07_global']!.content,
      contains('成年男性用户在正文中始终写作“你”'),
    );
    expect(
      byKey['immersive_07_global']!.content,
      contains('固定“她/你”人称坐标、用户控制权'),
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
      contains('专注描写，至少500字]'),
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
      contains('正文中 AI 只写“她”'),
    );
    expect(
      byKey['immersive_07_nsfw_source']!.content,
      contains('我快射了/我要射了'),
    );
    expect(
      byKey['immersive_07_nsfw_source']!.content,
      isNot(contains(r'\n')),
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
