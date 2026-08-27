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
        '先看 I should inspect the full response and decide how to answer it.',
      ),
      VisibleReasoningLanguageStatus.mixed,
    );
    expect(
      VisibleReasoningLanguageTelemetry.classify(
        'I should inspect the user request and then produce a concise answer.',
      ),
      VisibleReasoningLanguageStatus.mainlyEnglish,
    );
  });

  test('manual translation is offered only for English-dominant prose', () {
    expect(
      VisibleReasoningLanguageTelemetry.shouldOfferTranslation(
        '先检查 API response，再自然地用中文回答他。',
      ),
      isFalse,
    );
    expect(
      VisibleReasoningLanguageTelemetry.shouldOfferTranslation(
        'I should inspect what he meant and decide why this suddenly makes me feel shy.',
      ),
      isTrue,
    );
    expect(
      VisibleReasoningLanguageTelemetry.shouldOfferTranslation(
        '先停一下。 I should inspect the emotional cue and then decide how I actually feel about him.',
      ),
      isTrue,
    );
    expect(
      VisibleReasoningLanguageTelemetry.shouldOfferTranslation(
        '先核对这段代码：```dart\nfinal apiResponse = await client.send();\n```',
      ),
      isFalse,
    );
  });
}
