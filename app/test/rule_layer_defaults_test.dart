import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_defaults.dart';

void main() {
  test('ships six feature layers plus relationship and personality foundations', () {
    const expectedKeys = <String>{
      '01_core',
      '01_relationship',
      '02_daily',
      '03_behavior',
      '03_personality_seed',
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
  });

  test('novel word-count rules are not in the companion defaults', () {
    final all = defaultRuleLayers.map((e) => e.content).join('\n');
    expect(all.contains('每轮正文输出必须≥600字'), isFalse);
    expect(all.contains('第三人称有限视角叙事，全程锁定'), isFalse);
  });
}
