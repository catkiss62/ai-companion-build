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

  test('catalog keeps special styles temporary and reality bounded', () {
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

    expect(PersonalityCatalog.bases.length, 4);
    expect(PersonalityCatalog.postures.length, 4);
    expect(PersonalityCatalog.specialStyles.length, 8);
    expect(trial, contains('内在反应'));
    expect(trial, contains('表达过滤'));
    expect(trial, contains('可见思考默认用第一人称“我”'));
    expect(trial, contains('他是平等的男朋友'));
    expect(trial, contains('反咬一口'));
    expect(trial, contains('抓住破绽追一下'));
    expect(trial, isNot(contains('当前试穿性格')));
    expect(trial, isNot(contains('双方知情')));
    expect(reserved, contains('十成波澜收成两三成'));
    expect(reserved, isNot(equals(trial)));
    expect(adopted, contains('当前长期底色'));
    expect(yandere, contains('不能真实阻止退出'));
    expect(yandere, contains('不得写入长期人格'));
    expect(yandere, contains('不要向他说明风格层'));
    expect(seductress, contains('未开启'));
    expect(seductress, contains('露骨成人表达只在'));
  });
}
