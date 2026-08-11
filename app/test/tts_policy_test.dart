import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/tts/tts_policy.dart';

void main() {
  test('proactive tts policy is conservative by default', () {
    expect(ProactiveTtsPolicy.fromSetting(null), ProactiveTtsPolicy.silent);
    expect(ProactiveTtsPolicy.fromSetting('unknown'), ProactiveTtsPolicy.silent);
  });

  test('proactive tts policy round-trips settings', () {
    for (final policy in ProactiveTtsPolicy.values) {
      expect(ProactiveTtsPolicy.fromSetting(policy.settingValue), policy);
    }
  });
}
