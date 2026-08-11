import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/rules/rule_layer_defaults.dart';

void main() {
  test('ships six distinct rule layers', () {
    expect(defaultRuleLayers.length, 6);
    expect(defaultRuleLayers.map((e) => e.key).toSet().length, 6);
    expect(defaultRuleLayers.first.key, '01_core');
    expect(defaultRuleLayers.first.locked, isTrue);
  });

  test('novel word-count rules are not in the companion defaults', () {
    final all = defaultRuleLayers.map((e) => e.content).join('\n');
    expect(all.contains('每轮正文输出必须≥600字'), isFalse);
    expect(all.contains('第三人称有限视角叙事，全程锁定'), isFalse);
  });
}
