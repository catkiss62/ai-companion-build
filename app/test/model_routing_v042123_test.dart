import 'dart:async';
import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/first_channel_model.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/ai/reasoning_translation_service.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/memory/memory_query_expander.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/self/dream_engine.dart';
import 'package:ai_companion_localfirst/core/self/dream_store.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

http.Response _json(String content, {String finish = 'stop'}) => http.Response(
  jsonEncode({'choices': [{'message': {'content': content}, 'finish_reason': finish}]}),
  200, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'test'});
  });
  tearDown(() async => db.closeForTesting());

  for (final choice in ['primary', 'legacy', 'empty']) {
    test('memory gateway sends the resolved $choice model to HTTP', () async {
      await db.setSetting('deepseek_model', choice == 'primary' ? ' first-custom ' : '');
      await db.setSetting('model', choice == 'empty' ? '' : 'legacy-custom');
      final expected = choice == 'primary' ? 'first-custom'
          : choice == 'legacy' ? 'legacy-custom' : DeepSeekModelProfile.flash.apiName;
      final client = DeepSeekClient(client: MockClient((request) async {
        expect((jsonDecode(request.body) as Map)['model'], expected);
        return _json('{"queries":["充电器"]}');
      }));
      try {
        expect(await MemoryQueryExpander(client).expand('充电设备', apiKey: 'test',
          endpoint: 'https://api.deepseek.com/chat/completions',
          model: await FirstChannelModel.read(db)), ['充电器']);
      } finally { client.close(); }
    });
  }

  test('translation cache model matches the actual custom-model payload', () async {
    await db.setSetting('deepseek_model', 'translation-custom');
    final client = DeepSeekClient(client: MockClient((request) async {
      expect((jsonDecode(request.body) as Map)['model'], 'translation-custom');
      return _json('{"translation":"我先考虑这句话。"}');
    }));
    try {
      final service = ReasoningTranslationService(cache: DatabaseReasoningTranslationCache(db),
        gateway: DeepSeekReasoningTranslationGateway(client: client),
        apiKeyLoader: () async => 'test', endpointLoader: () async => 'https://api.deepseek.com/chat/completions',
        modelLoader: () => FirstChannelModel.read(db));
      await service.translate(scope: ReasoningTranslationScope.chat, messageId: 'reply',
        reasoning: 'I want to consider this sentence before replying to it.');
      final row = (await (await db.database).query('reasoning_translations')).single;
      expect(row['model'], 'translation-custom');
    } finally { client.close(); }
  });

  for (final work in ['work-custom', '']) {
    test('dream HTTP uses work model or first-channel fallback: $work', () async {
      await db.setSetting('deepseek_model', 'first-custom');
      await db.setSetting('creative_work_model', work);
      await db.insertMessage(ChatMessage(id: 'source', role: 'user',
        content: '不用一直赶目标，停下来看看也很好。', createdAt: DateTime.now().subtract(const Duration(hours: 2))));
      var calls = 0;
      final engine = DreamEngine(db,
        secureConfig: SecureConfig.forTesting(const FlutterSecureStorage()),
        clientFactory: (abort) => DeepSeekClient(abortWhen: abort, jsonClientFactory: () => MockClient((request) async {
          calls++;
          final body = jsonDecode(request.body) as Map;
          expect(body['model'], work.isEmpty ? 'first-custom' : work);
          expect(body['max_tokens'], 6000);
          expect(body['thinking'], {'type': 'enabled'});
          return _json('{"changes":[]}');
        })));
      expect(await engine.maybeDream(manual: true), isTrue);
      expect(calls, 1);
      expect(await engine.maybeDream(manual: true), isFalse); // Success-day gate retained.
      expect(calls, 1);
    });
  }

  for (final category in ['http_error', 'timeout', 'connection_error', 'output_limit',
      'abnormal_finish', 'empty_body', 'invalid_json', 'runtime_interrupted']) {
    test('dream records body-free $category without committing insight/day', () async {
      await db.setSetting('creative_work_model', 'work-diagnostic');
      await db.insertMessage(ChatMessage(id: 'source', role: 'user',
        content: '不用一直赶目标，停下来看看也很好。', createdAt: DateTime.now().subtract(const Duration(hours: 2))));
      final engine = DreamEngine(db,
        secureConfig: SecureConfig.forTesting(const FlutterSecureStorage()),
        clientFactory: (abort) => DeepSeekClient(abortWhen: abort, jsonClientFactory: () => MockClient((request) async {
          expect((jsonDecode(request.body) as Map)['model'], 'work-diagnostic');
          switch (category) {
            case 'http_error': return http.Response('PRIVATE_PROVIDER_BODY', 502);
            case 'timeout': throw TimeoutException('PRIVATE_TIMEOUT');
            case 'connection_error': throw http.ClientException('PRIVATE_CONNECTION');
            case 'runtime_interrupted': throw const GenerationSuspendedByRuntimeGateException();
            case 'output_limit': return _json('{"changes":[]}', finish: 'length');
            case 'abnormal_finish': return _json('{"changes":[]}', finish: 'content_filter');
            case 'empty_body': return _json('');
            default: return _json('PRIVATE_INVALID_JSON');
          }
        })));
      expect(await engine.maybeDream(manual: true), isFalse);
      final raw = (await db.getSetting(DreamStore.diagnosticKey))!;
      final diagnostic = jsonDecode(raw) as Map;
      expect(diagnostic['model'], 'work-diagnostic');
      expect(diagnostic['failure_category'], category);
      expect(diagnostic['content_included'], isFalse);
      expect(raw, isNot(contains('PRIVATE_')));
      expect(await db.getSetting(DreamStore.stateKey), anyOf(isNull, isEmpty));
      final attempt = jsonDecode((await db.getSetting(DreamStore.attemptKey))!) as Map;
      expect(attempt['count'], 1);
      expect((attempt['retry_at'] as num).toInt(), greaterThan(DateTime.now().millisecondsSinceEpoch));
    });
  }
}
