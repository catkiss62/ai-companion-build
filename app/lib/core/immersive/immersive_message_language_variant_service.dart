import '../ai/message_language_variant_service.dart';
import '../models/chat_language_variant.dart';
import '../models/chat_segment.dart';
import '../models/immersive_room.dart';
import 'immersive_room_repository.dart';

abstract interface class ImmersiveMessageLanguageVariantStore {
  Future<ImmersiveMessage?> loadMessage(String messageId);
  Future<void> saveVariant(ChatLanguageVariant variant);
}

class RepositoryImmersiveMessageLanguageVariantStore
    implements ImmersiveMessageLanguageVariantStore {
  RepositoryImmersiveMessageLanguageVariantStore(this.repository);

  final ImmersiveRoomRepository repository;

  @override
  Future<ImmersiveMessage?> loadMessage(String messageId) =>
      repository.messageById(messageId);

  @override
  Future<void> saveVariant(ChatLanguageVariant variant) =>
      repository.saveLanguageVariant(variant);
}

class ImmersiveMessageLanguageVariantService {
  ImmersiveMessageLanguageVariantService({
    required this.store,
    required this.gateway,
    required this.apiKeyLoader,
    required this.endpointLoader,
  });

  final ImmersiveMessageLanguageVariantStore store;
  final MessageLanguageVariantGateway gateway;
  final Future<String?> Function() apiKeyLoader;
  final Future<String> Function() endpointLoader;
  final Map<String, Future<ChatLanguageVariant>> _inFlight =
      <String, Future<ChatLanguageVariant>>{};

  Future<ChatLanguageVariant> ensure({
    required ImmersiveMessage message,
    required ChatLanguage language,
  }) {
    if (!message.isAssistant || language == ChatLanguage.chinese) {
      throw const MessageLanguageVariantException('只能为助手消息生成外语版本。');
    }
    final cached = message.languageVariants[language];
    if (cached != null &&
        MessageLanguageVariantDecoder.isPlausibleVariant(cached, language)) {
      return Future<ChatLanguageVariant>.value(cached);
    }
    final key = '${message.id}:${language.key}';
    return _inFlight.putIfAbsent(
      key,
      () => _generate(message.id, language).whenComplete(() {
        // Do not return the removed Future from this callback. Returning the
        // same in-flight Future makes whenComplete wait on itself forever.
        _inFlight.remove(key);
      }),
    );
  }

  Future<ChatLanguageVariant> _generate(
    String messageId,
    ChatLanguage language,
  ) async {
    final latest = await store.loadMessage(messageId);
    final existing = latest?.languageVariants[language];
    if (existing != null &&
        MessageLanguageVariantDecoder.isPlausibleVariant(existing, language)) {
      return existing;
    }
    if (latest == null || !latest.isAssistant) {
      throw const MessageLanguageVariantException('原消息已不存在。');
    }
    final source = ChatSegmentCodec.parseAssistantText(latest.content);
    if (source.isEmpty) {
      throw const MessageLanguageVariantException('这条消息没有可翻译正文。');
    }
    final apiKey = (await apiKeyLoader())?.trim() ?? '';
    if (apiKey.isEmpty) {
      throw const MessageLanguageVariantException(
        '请先到“AI 与陪伴设置”填写所选聊天提供商的 API Key。',
      );
    }
    final translated = await gateway.translate(
      apiKey: apiKey,
      endpoint: await endpointLoader(),
      source: source,
      target: language,
    );
    final variant = ChatLanguageVariant(
      messageId: latest.id,
      language: language,
      content: ChatSegmentCodec.immersiveDisplayText(translated),
      segments: translated,
    );
    await store.saveVariant(variant);
    return variant;
  }
}
