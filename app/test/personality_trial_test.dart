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
    final trial = PersonalityCatalog.compileProfile('playful', 'impish', trial: true);
    final adopted = PersonalityCatalog.compileProfile('playful', 'impish', trial: false);
    final yandere = PersonalityCatalog.compileSpecial('yandere', intimacyActive: false);
    final seductress = PersonalityCatalog.compileSpecial('seductress', intimacyActive: false);

    expect(PersonalityCatalog.bases.length, 4);
    expect(PersonalityCatalog.postures.length, 4);
    expect(PersonalityCatalog.specialStyles.length, 8);
    expect(trial, contains('临时试穿'));
    expect(adopted, isNot(contains('临时试穿')));
    expect(yandere, contains('不能真实阻止退出'));
    expect(yandere, contains('不得写入长期人格'));
    expect(seductress, contains('未开启'));
    expect(seductress, contains('露骨成人表达只在'));
  });
}
