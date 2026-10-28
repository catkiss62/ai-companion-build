import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/chat_api_provider.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/ai/final_reply_control.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_client.dart';
import 'package:ai_companion_localfirst/core/ai/third_channel_config.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path); final String path;
  @override Future<String?> getApplicationSupportPath() async => path;
  @override Future<String?> getTemporaryPath() async => path;
}
http.Response _stream(String text, {bool tools = false}) => http.Response.bytes(utf8.encode(
  'data: ${jsonEncode({'choices': [{'delta': tools ? {'tool_calls': [
    {'index': 0, 'id': 'gateway-entry', 'type': 'function', 'function': {'name': 'agent_request',
      'arguments': jsonEncode({'goal': '查看已有系统能力', 'families': ['system']})}}]} : {'content': text},
    'finish_reason': tools ? 'tool_calls' : 'stop'}], 'usage': {'prompt_tokens': 10, 'completion_tokens': 5,
      'completion_tokens_details': {'reasoning_tokens': 2}, 'total_tokens': 17}})}\n\ndata: [DONE]\n\n'),
  200, headers: {'content-type': 'text/event-stream; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  for (final scenario in ['first_base', 'second_key_missing', 'manual_first', 'active_manual_first', 'tool_entry']) {
    test('durable App generation preserves $scenario routing and committed model provenance', () async {
      final directory = await Directory.systemTemp.createTemp('third-chat-149-');
      final paths = PathProviderPlatform.instance; PathProviderPlatform.instance = _Paths(directory.path);
      const bridge = MethodChannel('ai_companion/system');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(bridge, (call) async => call.method == 'runtimeProcessEpoch' ? 'fixture-process' : null);
      FlutterSecureStorage.setMockInitialValues({});
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      final secure = SecureConfig.forTesting(const FlutterSecureStorage());
      await secure.writeApiKey('first-fixture'); await secure.writeEndpoint('http://first.invalid/chat');
      await secure.writeThirdChannel(const ThirdChannelConfig(enabled: true, baseUrl: 'http://gateway.invalid/v1', apiKey: 'third-fixture'));
      if (scenario == 'second_key_missing') await secure.writeChatProvider(ChatApiProvider.aiWangYouGemini);
      var posts = 0, secondPosts = 0;
      final gatewayRequests = <Map>[];
      final entered = Completer<void>(), release = Completer<http.Response>();
      final control = FinalReplyControl();
      final client = DeepSeekClient(secureConfig: secure,
        thirdClientFactory: () => ThirdChannelClient(clientFactory: () => MockClient((request) async {
          if (request.url.path == '/health') return http.Response('{"status":"ok"}', 200);
          posts++; gatewayRequests.add(jsonDecode(request.body) as Map);
          if (scenario == 'active_manual_first') {
            if (!entered.isCompleted) entered.complete();
            return release.future;
          }
          return _stream('<emotion>正常</emotion>\n「我在听，继续聊。」', tools: scenario == 'tool_entry' && posts == 1);
        })), streamClientFactory: () => MockClient((request) async {
          if (request.url.host != 'first.invalid') secondPosts++;
          return _stream('<emotion>正常</emotion>\n「今天就慢慢聊。」');
        }), jsonClientFactory: () => MockClient((_) async => http.Response(jsonEncode({
          'choices': [{'message': {'content': '{}'}, 'finish_reason': 'stop'}]}), 200)));
      try {
        await db.setSettingsAtomically({'tts_enabled': '0', 'auto_tts': '0', 'emotion_sound_enabled': '0',
          'cedar_toy_enabled': '0', 'post_turn_queue_enabled': '0', 'daily_continuity_enabled': '0',
          'memory_fading_enabled': '0', 'memory_consolidation_enabled': '0', 'relationship_continuity_enabled': '0',
          'personality_learning_enabled': '0'});
        final job = await db.createGenerationTurn(user: ChatMessage(id: 'u', role: 'user', content: '继续聊吧', createdAt: DateTime.now()),
          assistantMessageId: 'a', model: 'deepseek-v4-flash', reasoningEffort: 'high', thinking: false);
        if (scenario == 'manual_first') await db.selectDeepSeekForGeneration(job.id);
        await db.tryAcquireLocalLease('chat_turn_lease');
        final running = DurableGenerationRunner(db: db, client: client, secureConfig: secure).run(job, replyControl: control);
        if (scenario == 'active_manual_first') {
          await entered.future.timeout(const Duration(seconds: 15));
          expect(control.requestDeepSeek(), true);
        }
        final result = await running.timeout(const Duration(seconds: 30));
        expect(result.status, 'completed', reason: '${result.error}');
        final assistant = (await db.messageById('a'))!;
        expect(secondPosts, 0);
        if (scenario == 'manual_first' || scenario == 'active_manual_first') {
          expect(posts, scenario == 'manual_first' ? 0 : 1);
          expect(assistant.content, contains('慢慢聊')); expect(assistant.model, 'deepseek-v4-flash');
        } else {
          expect(posts, greaterThanOrEqualTo(1)); expect(assistant.content, contains('我在听'));
          expect(assistant.model, ThirdChannelConfig.model);
          expect(jsonDecode((await db.getSetting('generation_final_route_v1'))!)['reason'], 'third_channel');
          if (scenario == 'tool_entry') {
            expect(posts, greaterThanOrEqualTo(2));
            expect((gatewayRequests[1]['messages'] as List).any((m) => m['role'] == 'tool' && m['tool_call_id'] == 'gateway-entry'), true);
          }
        }
      } finally {
        if (!release.isCompleted) release.complete(_stream('late discarded fixture'));
        client.close(); await db.releaseLocalLease('chat_turn_lease'); await db.closeForTesting();
        messenger.setMockMethodCallHandler(bridge, null); PathProviderPlatform.instance = paths;
        await directory.delete(recursive: true);
      }
    });
  }
}
