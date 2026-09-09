import 'package:ai_companion_localfirst/core/ai/message_language_variant_service.dart';
import 'package:ai_companion_localfirst/core/models/chat_language_variant.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/chat_segment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatMessage sourceMessage() => ChatMessage(
        id: 'assistant-1',
        role: 'assistant',
        content: '（轻轻抬眼）\n\n「我在这里。」',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        segments: const <ChatSegment>[
          ChatSegment(kind: ChatSegmentKind.action, text: '轻轻抬眼'),
          ChatSegment(kind: ChatSegmentKind.dialogue, text: '我在这里。'),
        ],
      );

  test('one selected language is generated once and then reused from cache',
      () async {
    final store = _MemoryVariantStore(sourceMessage());
    final gateway = _FakeVariantGateway();
    final service = MessageLanguageVariantService(
      store: store,
      gateway: gateway,
      apiKeyLoader: () async => 'key',
      endpointLoader: () async => 'https://example.test/chat/completions',
    );

    final first = await service.ensure(
      message: sourceMessage(),
      language: ChatLanguage.japanese,
    );
    final second = await service.ensure(
      message: sourceMessage(),
      language: ChatLanguage.japanese,
    );

    expect(first.language, ChatLanguage.japanese);
    expect(first.segments.map((item) => item.kind),
        sourceMessage().segments.map((item) => item.kind));
    expect(second.content, first.content);
    expect(gateway.calls, 1);
    expect(gateway.targets, <ChatLanguage>[ChatLanguage.japanese]);
    expect(store.saves, 1);
  });

  test('concurrent taps share one target-language request', () async {
    final store = _MemoryVariantStore(sourceMessage());
    final gateway = _FakeVariantGateway(delay: const Duration(milliseconds: 1));
    final service = MessageLanguageVariantService(
      store: store,
      gateway: gateway,
      apiKeyLoader: () async => 'key',
      endpointLoader: () async => 'https://example.test/chat/completions',
    );

    await Future.wait([
      service.ensure(
        message: sourceMessage(),
        language: ChatLanguage.english,
      ),
      service.ensure(
        message: sourceMessage(),
        language: ChatLanguage.english,
      ),
    ]);

    expect(gateway.calls, 1);
    expect(store.saves, 1);
  });

  test('missing credentials never writes a fake variant', () async {
    final store = _MemoryVariantStore(sourceMessage());
    final gateway = _FakeVariantGateway();
    final service = MessageLanguageVariantService(
      store: store,
      gateway: gateway,
      apiKeyLoader: () async => '',
      endpointLoader: () async => 'https://example.test/chat/completions',
    );

    await expectLater(
      service.ensure(
        message: sourceMessage(),
        language: ChatLanguage.english,
      ),
      throwsA(isA<MessageLanguageVariantException>()),
    );
    expect(gateway.calls, 0);
    expect(store.saves, 0);
  });
}

class _MemoryVariantStore implements MessageLanguageVariantStore {
  _MemoryVariantStore(this.message);
  ChatMessage message;
  int saves = 0;

  @override
  Future<ChatMessage?> loadMessage(String messageId) async =>
      message.id == messageId ? message : null;

  @override
  Future<void> saveVariant(ChatLanguageVariant variant) async {
    saves++;
    message = message.copyWith(
      languageVariants: <ChatLanguage, ChatLanguageVariant>{
        ...message.languageVariants,
        variant.language: variant,
      },
    );
  }
}

class _FakeVariantGateway implements MessageLanguageVariantGateway {
  _FakeVariantGateway({this.delay = Duration.zero});
  final Duration delay;
  int calls = 0;
  final List<ChatLanguage> targets = <ChatLanguage>[];

  @override
  Future<List<ChatSegment>> translate({
    required String apiKey,
    required String endpoint,
    required List<ChatSegment> source,
    required ChatLanguage target,
  }) async {
    calls++;
    targets.add(target);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return source
        .map((item) => ChatSegment(
              kind: item.kind,
              text: '${target.key}:${item.text}',
            ))
        .toList(growable: false);
  }
}
