import 'package:ai_companion_localfirst/core/diagnostics/visible_reasoning_language_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reasoning language telemetry classifies shape without retaining text', () {
    expect(
      VisibleReasoningLanguageTelemetry.classify(''),
      VisibleReasoningLanguageStatus.empty,
    );
    expect(
      VisibleReasoningLanguageTelemetry.classify(
        '先看他这句话真正碰到我的地方，再决定怎么回。',
      ),
      VisibleReasoningLanguageStatus.chineseFirst,
    );
    expect(
      VisibleReasoningLanguageTelemetry.classify(
        '先检查 API response 和 tool result，再自然回答他。',
      ),
      VisibleReasoningLanguageStatus.chineseFirst,
    );
    expect(
      VisibleReasoningLanguageTelemetry.classify(
        'I should inspect the user request and then produce a concise answer.',
      ),
      VisibleReasoningLanguageStatus.mainlyEnglish,
    );
  });
}
