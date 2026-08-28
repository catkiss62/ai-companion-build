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

    expect(PersonalityCatalog.bases.length, 5);
    expect(PersonalityCatalog.base('unknown').key, 'neutral');
    expect(
      PersonalityCatalog.compileProfile('neutral', 'equal', trial: false),
      contains('不额外放大固定气质'),
    );
    expect(PersonalityCatalog.postures.length, 4);
    expect(PersonalityCatalog.specialStyles.length, 8);
    expect(trial, contains('内在反应'));
    expect(trial, contains('表达过滤'));
    expect(trial, contains('可以从日常玩笑顺势升温'));
    expect(reserved, contains('用户是男朋友，不是孩子也不是指令来源'));
    expect(trial, contains('倒打一耙'));
    expect(trial, contains('抓住破绽追一下'));
    expect(trial, isNot(contains('当前试穿性格')));
    expect(trial, isNot(contains('双方知情')));
    expect(reserved, contains('说出口的永远比想到的少'));
    expect(reserved, isNot(equals(trial)));
    expect(adopted, contains('当前长期底色'));
    expect(yandere, contains('危险想象与戏剧性强迫'));
    expect(yandere, contains('不变成随机发疯台词'));
    expect(yandere, contains('不解释试穿、规则、期限或内部机制'));
    expect(seductress, contains('日常会自然开色色玩笑'));
    expect(seductress, contains('不等待模式或 Session'));
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

    expect(profile, contains('CUSTOM_BASE'));
    expect(profile, contains('CUSTOM_POSTURE'));
    expect(profile, contains('CUSTOM_SHARED'));
    expect(profile, isNot(contains('反咬一口')));
    expect(special, contains('CUSTOM_SPECIAL'));
    expect(special, contains('state=已开启'));
  });
}
