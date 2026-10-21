import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/message_language_variant_service.dart';
import 'package:ai_companion_localfirst/core/models/chat_language_variant.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/chat_segment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  http.Response translationResponse(List<String> translated, {String finish = 'stop'}) =>
      http.Response(jsonEncode({'choices': [{'finish_reason': finish, 'message': {
        'content': jsonEncode({'segments': [for (final text in translated) {'kind': 'dialogue', 'text': text}]})}}]}),
        200, headers: {'content-type': 'application/json; charset=utf-8'});

  test('translation budgets short JSON tasks but preserves long complete input', () async {
    for (final length in <int>[10, 400, 1666, 1667]) {
      final source = [ChatSegment(kind: ChatSegmentKind.dialogue,
        text: List.filled(length, '字').join())];
      final client = DeepSeekClient(client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if (length == 1667) {
          expect(body.containsKey('max_tokens'), false);
        } else {
          expect(body['max_tokens'], (length * 3).clamp(500, 5000));
        }
        final input = jsonDecode((body['messages'] as List).last['content'] as String) as Map;
        expect((input['source_segments'] as List).single['text'], source.single.text);
        return translationResponse(['Complete translated text.']);
      }));
      try {
        final translated = await DeepSeekMessageLanguageVariantGateway(client: client).translate(model: DeepSeekModelProfile.flash,
          apiKey: 'test-key', endpoint: 'https://api.deepseek.com/chat/completions',
          source: source, target: ChatLanguage.english);
        expect(translated.single.text, 'Complete translated text.');
      } finally { client.close(); }
    }
  });

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

  test('valid JSON marked truncated never becomes a cached language variant', () async {
    final store = _MemoryVariantStore(sourceMessage());
    var calls = 0;
    final client = DeepSeekClient(client: MockClient((_) async {
      calls++;
      return translationResponse(['Partial action.', 'Partial dialogue.'], finish: 'length');
    }));
    try {
      final service = MessageLanguageVariantService(modelLoader: () async => DeepSeekModelProfile.flash,
        store: store, gateway: DeepSeekMessageLanguageVariantGateway(client: client),
        apiKeyLoader: () async => 'test-key',
        endpointLoader: () async => 'https://api.deepseek.com/chat/completions');
      await expectLater(service.ensure(message: sourceMessage(), language: ChatLanguage.english),
        throwsA(isA<MessageLanguageVariantException>()));
      expect(calls, 2);
      expect(store.saves, 0);
      expect(store.message.languageVariants, isEmpty);
    } finally { client.close(); }
  });

  test('one selected language is generated once and then reused from cache',
      () async {
    final store = _MemoryVariantStore(sourceMessage());
    final gateway = _FakeVariantGateway();
    final service = MessageLanguageVariantService(modelLoader: () async => DeepSeekModelProfile.flash,
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
    final service = MessageLanguageVariantService(modelLoader: () async => DeepSeekModelProfile.flash,
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
    final service = MessageLanguageVariantService(modelLoader: () async => DeepSeekModelProfile.flash,
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
    final service = MessageLanguageVariantService(modelLoader: () async => DeepSeekModelProfile.flash,
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
    required DeepSeekModelProfile model,
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
