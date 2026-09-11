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

  test('localized kind labels are repaired from authoritative source order', () {
    final source = sourceMessage().segments;
    final decoded = MessageLanguageVariantDecoder.decode(
      <String, Object?>{
        'segments': <Object?>[
          <String, Object?>{'kind': '動作', 'text': 'そっと顔を上げる'},
          <String, Object?>{'kind': '会話', 'text': 'ここにいるよ。'},
        ],
      },
      source,
      ChatLanguage.japanese,
    );

    expect(decoded.map((item) => item.kind), source.map((item) => item.kind));
    expect(decoded.last.text, 'ここにいるよ。');
  });

  test('english projection rejects Japanese or Chinese contamination', () {
    expect(
      () => MessageLanguageVariantDecoder.decode(
        <String, Object?>{
          'segments': <Object?>[
            <String, Object?>{'text': 'She looks up softly.'},
            <String, Object?>{'text': 'ここにいるよ。'},
          ],
        },
        sourceMessage().segments,
        ChatLanguage.english,
      ),
      throwsA(isA<MessageLanguageVariantException>()),
    );
  });

  test('a contaminated cached English projection is regenerated', () async {
    final source = sourceMessage();
    final contaminated = ChatLanguageVariant(
      messageId: source.id,
      language: ChatLanguage.english,
      content: 'ここにいるよ。',
      segments: const <ChatSegment>[
        ChatSegment(kind: ChatSegmentKind.action, text: 'そっと見上げる。'),
        ChatSegment(kind: ChatSegmentKind.dialogue, text: 'ここにいるよ。'),
      ],
    );
    final stored = source.copyWith(
      languageVariants: <ChatLanguage, ChatLanguageVariant>{
        ChatLanguage.english: contaminated,
      },
    );
    final store = _MemoryVariantStore(stored);
    final gateway = _FakeVariantGateway();
    final service = MessageLanguageVariantService(
      store: store,
      gateway: gateway,
      apiKeyLoader: () async => 'key',
      endpointLoader: () async => 'https://example.test/chat/completions',
    );

    final repaired = await service.ensure(
      message: stored,
      language: ChatLanguage.english,
    );

    expect(repaired.content, contains('English segment'));
    expect(gateway.calls, 1);
    expect(store.saves, 1);
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
    var index = 0;
    return source
        .map((item) => ChatSegment(
              kind: item.kind,
              text: target == ChatLanguage.english
                  ? 'English segment ${index++}.'
                  : '${target.key}:${item.text}',
            ))
        .toList(growable: false);
  }
}
