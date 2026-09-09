import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known DeepSeek model IDs keep their stable choices', () {
    expect(
      DeepSeekModelProfile.fromApiName('deepseek-v4-pro'),
      DeepSeekModelProfile.pro,
    );
    expect(
      DeepSeekModelProfile.fromApiName('deepseek-v4-flash'),
      DeepSeekModelProfile.flash,
    );
    expect(DeepSeekModelProfile.fromApiName(null), DeepSeekModelProfile.flash);
  });

  test('unknown non-empty model ID is preserved instead of falling back', () {
    final profile = DeepSeekModelProfile.fromApiName(' provider/new-model ');

    expect(profile.isCustom, isTrue);
    expect(profile.apiName, 'provider/new-model');
    expect(profile.label, 'provider/new-model');
  });

  test('custom selector sentinel is never accepted as an API model', () {
    expect(
      DeepSeekModelProfile.fromApiName(DeepSeekModelProfile.custom.apiName),
      DeepSeekModelProfile.flash,
    );
    expect(DeepSeekModelProfile.values, contains(DeepSeekModelProfile.custom));
  });

  test('low reasoning effort is available for custom model APIs', () {
    expect(ReasoningEffort.fromApiName('low'), ReasoningEffort.low);
    expect(ReasoningEffort.low.apiName, 'low');
    expect(ReasoningEffort.values, contains(ReasoningEffort.low));
  });
}
