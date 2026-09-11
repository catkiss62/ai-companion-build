import 'package:ai_companion_localfirst/core/ai/message_language_variant_service.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_message_language_variant_service.dart';
import 'package:ai_companion_localfirst/core/models/chat_language_variant.dart';
import 'package:ai_companion_localfirst/core/models/chat_segment.dart';
import 'package:ai_companion_localfirst/core/models/immersive_room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ImmersiveMessage sourceMessage() => ImmersiveMessage(
        id: 'immersive-assistant-1',
        roomId: 'room-1',
        role: 'assistant',
        content: '（轻轻抬眼）\n\n「我在这里。」',
        reasoningContent: '先回应眼前的场景。',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      );

  test('immersive foreign projection is generated once and cached', () async {
    final store = _MemoryImmersiveStore(sourceMessage());
    final gateway = _FakeGateway();
    final service = ImmersiveMessageLanguageVariantService(
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

    expect(first.content, second.content);
    expect(first.segments.map((item) => item.kind), <ChatSegmentKind>[
      ChatSegmentKind.action,
      ChatSegmentKind.dialogue,
    ]);
    expect(gateway.calls, 1);
    expect(store.saves, 1);
  });

  test('concurrent immersive language requests share one translation', () async {
    final store = _MemoryImmersiveStore(sourceMessage());
    final gateway = _FakeGateway(delay: const Duration(milliseconds: 1));
    final service = ImmersiveMessageLanguageVariantService(
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

  test('database row restores both language projections and reasoning', () {
    final message = ImmersiveMessage.fromDb(<String, Object?>{
      'id': 'immersive-assistant-1',
      'room_id': 'room-1',
      'role': 'assistant',
      'content': '「我在这里。」',
      'reasoning_content': '先回应。',
      'created_at': 1,
      'ja_content': '「ここにいるよ。」',
      'ja_segments_json':
          '[{"kind":"dialogue","text":"ここにいるよ。"}]',
      'en_content': '“I am here.”',
      'en_segments_json':
          '[{"kind":"dialogue","text":"I am here."}]',
    });

    expect(message.reasoningContent, '先回应。');
    expect(message.contentFor(ChatLanguage.japanese), '「ここにいるよ。」');
    expect(message.contentFor(ChatLanguage.english), '“I am here.”');
    expect(
      message.segmentsFor(ChatLanguage.japanese).single.kind,
      ChatSegmentKind.dialogue,
    );
  });

  test('schema-59 immersive rows remain Chinese-only after migration', () {
    final message = ImmersiveMessage.fromDb(<String, Object?>{
      'id': 'legacy-immersive-assistant',
      'room_id': 'room-1',
      'role': 'assistant',
      'content': '「旧消息仍然在。」',
      'reasoning_content': '',
      'created_at': 1,
    });

    expect(message.contentFor(ChatLanguage.chinese), '「旧消息仍然在。」');
    expect(message.languageVariants, isEmpty);
  });

  test('missing key never saves a fake immersive projection', () async {
    final store = _MemoryImmersiveStore(sourceMessage());
    final gateway = _FakeGateway();
    final service = ImmersiveMessageLanguageVariantService(
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

class _MemoryImmersiveStore implements ImmersiveMessageLanguageVariantStore {
  _MemoryImmersiveStore(this.message);

  ImmersiveMessage message;
  int saves = 0;

  @override
  Future<ImmersiveMessage?> loadMessage(String messageId) async =>
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

class _FakeGateway implements MessageLanguageVariantGateway {
  _FakeGateway({this.delay = Duration.zero});

  final Duration delay;
  int calls = 0;

  @override
  Future<List<ChatSegment>> translate({
    required String apiKey,
    required String endpoint,
    required List<ChatSegment> source,
    required ChatLanguage target,
  }) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    var index = 0;
    return source
        .map(
          (segment) => ChatSegment(
            kind: segment.kind,
            text: target == ChatLanguage.english
                ? 'English segment ${index++}.'
                : '${target.key}:${segment.text}',
          ),
        )
        .toList(growable: false);
  }
}
