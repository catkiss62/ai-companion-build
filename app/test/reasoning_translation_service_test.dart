import 'package:ai_companion_localfirst/core/ai/reasoning_translation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReasoningTranslationPolicy', () {
    test('offers translation for English and English-dominant reasoning', () {
      expect(
        ReasoningTranslationPolicy.shouldOffer(
          'I need to think about what he meant and answer with the feeling that actually surfaced.',
        ),
        isTrue,
      );
      expect(
        ReasoningTranslationPolicy.shouldOffer(
          '先确认 API。The important part is that the response should remain emotionally honest and should not turn into a work log.',
        ),
        isTrue,
      );
    });

    test('does not offer for Chinese prose containing technical names', () {
      expect(
        ReasoningTranslationPolicy.shouldOffer(
          '我先确认 DeepSeek API、reasoning_content 和 Flutter 状态，再自然回应他。',
        ),
        isFalse,
      );
      expect(ReasoningTranslationPolicy.shouldOffer(''), isFalse);
    });
  });

  test('successful translation is cached by source hash', () async {
    final cache = _MemoryCache();
    final gateway = _FakeGateway('这是忠实的中文翻译。');
    final service = ReasoningTranslationService(
      cache: cache,
      gateway: gateway,
      apiKeyLoader: () async => 'test-key',
      endpointLoader: () async => 'https://example.test/chat/completions',
    );
    const source =
        'I should keep the exact meaning and preserve every important detail in this reasoning.';

    final first = await service.translate(
      scope: ReasoningTranslationScope.chat,
      messageId: 'm1',
      reasoning: source,
    );
    final second = await service.translate(
      scope: ReasoningTranslationScope.chat,
      messageId: 'm1',
      reasoning: source,
    );

    expect(first.translation, '这是忠实的中文翻译。');
    expect(first.fromCache, isFalse);
    expect(second.fromCache, isTrue);
    expect(gateway.calls, 1);
    expect(cache.saved, 1);
  });

  test('changed source misses the old cache entry', () async {
    final cache = _MemoryCache();
    final gateway = _FakeGateway('翻译');
    final service = ReasoningTranslationService(
      cache: cache,
      gateway: gateway,
      apiKeyLoader: () async => 'test-key',
      endpointLoader: () async => 'https://example.test/chat/completions',
    );

    await service.translate(
      scope: ReasoningTranslationScope.immersive,
      messageId: 'same-id',
      reasoning:
          'This is the first complete English reasoning paragraph for the room.',
    );
    await service.translate(
      scope: ReasoningTranslationScope.immersive,
      messageId: 'same-id',
      reasoning:
          'This is a changed English reasoning paragraph and must not reuse stale text.',
    );

    expect(gateway.calls, 2);
    expect(cache.saved, 2);
  });

  test('missing API key and gateway failure never write a fake cache', () async {
    final missingKeyCache = _MemoryCache();
    final missingKeyGateway = _FakeGateway('不会被调用');
    final missingKeyService = ReasoningTranslationService(
      cache: missingKeyCache,
      gateway: missingKeyGateway,
      apiKeyLoader: () async => '',
      endpointLoader: () async => 'https://example.test/chat/completions',
    );
    const source =
        'This English reasoning is long enough to request a manual translation.';

    await expectLater(
      missingKeyService.translate(
        scope: ReasoningTranslationScope.chat,
        messageId: 'missing-key',
        reasoning: source,
      ),
      throwsA(isA<ReasoningTranslationException>()),
    );
    expect(missingKeyGateway.calls, 0);
    expect(missingKeyCache.saved, 0);

    final failedCache = _MemoryCache();
    final failedGateway = _FakeGateway.failure(StateError('network failed'));
    final failedService = ReasoningTranslationService(
      cache: failedCache,
      gateway: failedGateway,
      apiKeyLoader: () async => 'test-key',
      endpointLoader: () async => 'https://example.test/chat/completions',
    );
    await expectLater(
      failedService.translate(
        scope: ReasoningTranslationScope.chat,
        messageId: 'failed',
        reasoning: source,
      ),
      throwsStateError,
    );
    expect(failedCache.saved, 0);
  });

  test('English output is rejected and never cached', () async {
    final cache = _MemoryCache();
    final service = ReasoningTranslationService(
      cache: cache,
      gateway: _FakeGateway('This was not translated at all.'),
      apiKeyLoader: () async => 'test-key',
      endpointLoader: () async => 'https://example.test/chat/completions',
    );
    await expectLater(
      service.translate(
        scope: ReasoningTranslationScope.chat,
        messageId: 'english-output',
        reasoning:
            'This complete English reasoning should produce a Chinese translation.',
      ),
      throwsA(isA<ReasoningTranslationException>()),
    );
    expect(cache.saved, 0);
  });
}

class _MemoryCache implements ReasoningTranslationCache {
  final Map<String, ReasoningTranslationCacheEntry> values =
      <String, ReasoningTranslationCacheEntry>{};
  int saved = 0;

  String _key(ReasoningTranslationScope scope, String messageId, String sha) =>
      '${scope.key}:$messageId:$sha';

  @override
  Future<ReasoningTranslationCacheEntry?> load({
    required ReasoningTranslationScope scope,
    required String messageId,
    required String sourceSha256,
  }) async =>
      values[_key(scope, messageId, sourceSha256)];

  @override
  Future<void> save({
    required ReasoningTranslationScope scope,
    required String messageId,
    required String sourceSha256,
    required String translatedText,
    required String provider,
    required String model,
  }) async {
    saved++;
    values[_key(scope, messageId, sourceSha256)] =
        ReasoningTranslationCacheEntry(
      sourceSha256: sourceSha256,
      translatedText: translatedText,
    );
  }
}

class _FakeGateway implements ReasoningTranslationGateway {
  _FakeGateway(this.output) : error = null;
  _FakeGateway.failure(this.error) : output = '';

  final String output;
  final Object? error;
  int calls = 0;

  @override
  Future<String> translate({
    required String apiKey,
    required String endpoint,
    required String reasoning,
  }) async {
    calls++;
    if (error != null) throw error!;
    return output;
  }
}
