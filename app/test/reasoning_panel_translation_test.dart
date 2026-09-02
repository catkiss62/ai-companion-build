import 'package:ai_companion_localfirst/core/ai/reasoning_translation_service.dart';
import 'package:ai_companion_localfirst/widgets/reasoning_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const english =
      'I need to understand the feeling behind his words before I choose what I actually want to say.';

  testWidgets('manual translation preserves original and reveals cached result',
      (tester) async {
    final service = ReasoningTranslationService(
      cache: _WidgetCache(),
      gateway: _WidgetGateway(),
      apiKeyLoader: () async => 'test-key',
      endpointLoader: () async => 'https://example.test/chat/completions',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReasoningPanel(
            reasoning: english,
            messageId: 'message-1',
            translationScope: ReasoningTranslationScope.chat,
            translationService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('THINKING'));
    await tester.pumpAndSettle();

    expect(find.text('翻译'), findsOneWidget);
    expect(find.text(english), findsOneWidget);
    await tester.tap(find.text('翻译'));
    await tester.pumpAndSettle();

    expect(find.text(english), findsOneWidget);
    expect(find.text('中文翻译'), findsOneWidget);
    expect(find.text('我需要先理解他话语背后的感受。'), findsOneWidget);
  });

  testWidgets('Chinese and streaming reasoning never show translation action',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ReasoningPanel(
                reasoning: '我正在想他为什么突然这么说，DeepSeek API 只是一个专业名词。',
                messageId: 'message-cn',
                translationScope: ReasoningTranslationScope.chat,
              ),
              ReasoningPanel(
                reasoning: english,
                streaming: true,
                messageId: 'streaming-message',
                translationScope: ReasoningTranslationScope.chat,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('翻译'), findsNothing);
    expect(find.text('THINKING'), findsNWidgets(2));
  });
}

class _WidgetCache implements ReasoningTranslationCache {
  ReasoningTranslationCacheEntry? value;

  @override
  Future<ReasoningTranslationCacheEntry?> load({
    required ReasoningTranslationScope scope,
    required String messageId,
    required String sourceSha256,
  }) async =>
      value?.sourceSha256 == sourceSha256 ? value : null;

  @override
  Future<void> save({
    required ReasoningTranslationScope scope,
    required String messageId,
    required String sourceSha256,
    required String translatedText,
    required String provider,
    required String model,
  }) async {
    value = ReasoningTranslationCacheEntry(
      sourceSha256: sourceSha256,
      translatedText: translatedText,
    );
  }
}

class _WidgetGateway implements ReasoningTranslationGateway {
  @override
  Future<String> translate({
    required String apiKey,
    required String endpoint,
    required String reasoning,
  }) async =>
      '我需要先理解他话语背后的感受。';
}
