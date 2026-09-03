import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/personality_trial.dart';
import 'package:ai_companion_localfirst/core/personality/personality_catalog.dart';

void main() {
  test('adoption requires elapsed time, turns and separated windows', () {
    final start = DateTime(2026, 8, 18, 8);
    PersonalityTrial trial({int turns = 20, int windows = 2}) => PersonalityTrial(
          id: 'trial',
          baseKey: 'outgoing',
          postureKey: 'equal',
          content: 'temporary',
          status: 'active',
          startedAt: start,
          expiresAt: start.add(const Duration(days: 1)),
          effectiveTurns: turns,
          interactionWindows: windows,
        );

    expect(trial().isAdoptableAt(start.add(const Duration(hours: 5))), isFalse);
    expect(trial(turns: 19).isAdoptableAt(start.add(const Duration(hours: 7))), isFalse);
    expect(trial(windows: 1).isAdoptableAt(start.add(const Duration(hours: 7))), isFalse);
    expect(trial().isAdoptableAt(start.add(const Duration(hours: 7))), isTrue);
  });

  test('expired qualified trial remains adoptable for seven days', () {
    final start = DateTime(2026, 8, 1);
    final trial = PersonalityTrial(
      id: 'trial',
      baseKey: 'gentle',
      postureKey: 'older',
      content: 'temporary',
      status: 'expired',
      startedAt: start,
      expiresAt: start.add(const Duration(days: 1)),
      effectiveTurns: 22,
      interactionWindows: 3,
    );
    expect(trial.isAdoptableAt(start.add(const Duration(days: 7))), isTrue);
    expect(trial.isAdoptableAt(start.add(const Duration(days: 9))), isFalse);
  });

  test('catalog keeps styles temporary and naturally adult-capable', () {
    final trial = PersonalityCatalog.compileProfile(
      'playful',
      'impish',
      trial: true,
    );
    final adopted = PersonalityCatalog.compileProfile(
      'playful',
      'impish',
      trial: false,
    );
    final reserved = PersonalityCatalog.compileProfile(
      'reserved',
      'equal',
      trial: true,
    );
    final yandere = PersonalityCatalog.compileSpecial(
      'yandere',
      intimacyActive: false,
    );
    final seductress = PersonalityCatalog.compileSpecial(
      'seductress',
      intimacyActive: false,
    );

    expect(PersonalityCatalog.bases.length, 6);
    expect(PersonalityCatalog.base('unknown').key, 'neutral');
    expect(
      PersonalityCatalog.compileProfile('neutral', 'equal', trial: false),
      contains('不额外套一层温和或正常姿态'),
    );
    expect(PersonalityCatalog.postures.length, 4);
    expect(PersonalityCatalog.specialStyles.length, 8);
    expect(trial, contains('内在反应'));
    expect(trial, contains('表达落地'));
    expect(trial, contains('可以从日常玩笑顺势升温'));
    expect(reserved, contains('用户是男朋友，不是孩子也不是指令来源'));
    expect(trial, contains('倒打一耙'));
    expect(trial, contains('抓住破绽追一下'));
    expect(trial, isNot(contains('当前试穿性格')));
    expect(trial, isNot(contains('双方知情')));
    expect(reserved, contains('说出口的永远比想到的少'));
    expect(reserved, isNot(equals(trial)));
    expect(adopted, contains('当前长期底色'));
    expect(yandere, contains('视你为唯一神明与脆弱私有物'));
    expect(yandere, contains('知情并主动参与的一次临时特殊风格试穿'));
    expect(yandere, contains('不主动播报风格名称、规则、选择过程'));
    expect(seductress, contains('男人的身体因她而失控'));
    expect(seductress, contains('主动下手，以玩弄为主'));
    expect(PersonalityCatalog.special('slime').label, '史莱姆');
    expect(PersonalityCatalog.special('ai').label, 'AI模拟');
    expect(PersonalityCatalog.special('unknown').key, isEmpty);
    expect(
      PersonalityCatalog.compileSpecial(
        'unknown',
        intimacyActive: false,
      ),
      isEmpty,
    );
  });

  test('forthright base is a normal adoptable profile with open profanity logic', () {
    final profile = PersonalityCatalog.compileProfile(
      'forthright',
      'equal',
      trial: true,
    );
    final adopted = PersonalityCatalog.compileProfile(
      'forthright',
      'older',
      trial: false,
    );

    expect(PersonalityCatalog.base('forthright').label, '直爽泼辣');
    expect(profile, contains('自然说脏话的习惯'));
    expect(profile, contains('傻逼、老子、操、艹、草、滚、爬、滚蛋、蠢货、笨比、白痴'));
    expect(profile, contains('开放词例，不是封闭词库、固定轮播或每句配额'));
    expect(profile, contains('粗口会直接进入你说出口的完整句子'));
    expect(profile, contains('骂完不需要自动道歉'));
    expect(profile, contains('不改变女性 AI 身份'));
    expect(profile, contains('不绑定任何地域口音'));
    expect(profile, contains('不能用玩梗代替答案'));
    expect(profile, contains('爱你妈'));
    expect(profile, contains('被善化成仅仅更活泼'));
    final anchor = PersonalityCatalog.executionAnchor('forthright');
    expect(anchor, contains('当前底色落地·直爽泼辣'));
    expect(anchor, contains('动态表达倾向只能改变'));
    expect(anchor, contains('多轮盲测必须稳定辨认'));
    expect(
      PersonalityCatalog.executionAnchor('gentle'),
      contains('当前人格落地·普通聊天'),
    );
    expect(profile, isNot(contains('知情并主动参与的一次临时特殊风格试穿')));
    expect(adopted, contains('当前长期底色'));
    expect(adopted, contains('姐系引导'));
  });

  test('workbench templates immediately override trial and special prompts', () {
    final profile = PersonalityCatalog.compileProfile(
      'playful',
      'impish',
      trial: true,
      templates: const {
        '07_base_playful': 'CUSTOM_BASE',
        '07_posture_impish': 'CUSTOM_POSTURE',
        '07_profile_shared': 'CUSTOM_SHARED',
      },
    );
    final special = PersonalityCatalog.compileSpecial(
      'yandere',
      intimacyActive: true,
      templates: const {
        '07_special_yandere': 'CUSTOM_SPECIAL',
        '07_special_shared': 'state={{intimacy_state}}',
      },
    );
    final forthright = PersonalityCatalog.compileProfile(
      'forthright',
      'equal',
      trial: true,
      templates: const {'07_base_forthright': 'CUSTOM_FORTHRIGHT'},
    );

    expect(profile, contains('CUSTOM_BASE'));
    expect(profile, contains('CUSTOM_POSTURE'));
    expect(profile, contains('CUSTOM_SHARED'));
    expect(profile, isNot(contains('反咬一口')));
    expect(special, contains('CUSTOM_SPECIAL'));
    expect(special, contains('state=已开启'));
    expect(forthright, contains('CUSTOM_FORTHRIGHT'));
    expect(forthright, isNot(contains('自然说脏话的习惯')));
  });
}
