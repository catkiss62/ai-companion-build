import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/reflection/deep_reflection_store.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final deep in [false, true]) {
    test('discussion uses existing final writer once, deep=$deep', () async {
      final root = await Directory.systemTemp.createTemp(
        'reflection-pipeline-',
      );
      final paths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(root.path);
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      FlutterSecureStorage.setMockInitialValues({
        'deepseek_api_key': 'test',
        'chat_api_provider': 'aiwangyou_gemini',
        'aiwangyou_gemini_api_key': 'test-final',
        'aiwangyou_final_reply_endpoint':
            'https://relay.invalid/v1/chat/completions',
      });
      final secure = SecureConfig.forTesting(const FlutterSecureStorage());
      final cancellation = GenerationCancellationToken();
      var finals = 0;
      var plans = 0;
      final streamed = StringBuffer();
      const question = '没有解释清楚就先保留判断，可以吗？';
      const reply = '「可以先保留不确定，我暂时能接受这个理解。」';
      final sidecar =
          '<reflection_state>${jsonEncode({'id': 'dr:test', 'action': 'settle', 'related': true, 'resume': false, 'view': '保留不确定是可接受的暂时理解', 'remaining': '', 'progress': '用户指出可以暂时不下结论', 'user_quote': '保留不确定', 'reply_quote': '可以先保留不确定'})}</reflection_state>';
      http.Response sse(String text) => http.Response.bytes(
        utf8.encode(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': text},
                'finish_reason': 'stop',
              },
            ],
          })}\n\ndata: [DONE]\n\n',
        ),
        200,
        headers: {'content-type': 'text/event-stream; charset=utf-8'},
      );
      final client = DeepSeekClient(
        streamClientFactory: () => MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if ((body['tools'] as List?)?.isNotEmpty == true) {
            plans++;
            return sse('现有上下文足够，无需工具。');
          }
          if (request.url.host == 'relay.invalid') {
            finals++;
            expect(request.body, contains(question));
            expect(request.body, contains('reflection_state'));
            return sse('$reply$sidecar');
          }
          return sse('{}');
        }),
        jsonClientFactory: () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '{}'},
                },
              ],
            }),
            200,
          ),
        ),
      );
      try {
        final now = DateTime.now();
        await db.setSetting(
          DeepReflectionStore.stateKey,
          jsonEncode({
            'topic': {
              'id': 'dr:test',
              'phase': 'offered',
              'revision': 0,
              'reset': '',
              'question': question,
              'prior_view': '需要理解所有原因',
              'tension': '有时没有唯一解释',
              'why_user': '想知道用户怎样处理不确定',
              'remaining': question,
              'created_at': now.millisecondsSinceEpoch,
              'updated_at': now.millisecondsSinceEpoch,
            },
            'history': [],
          }),
        );
        await db.setSetting('nsfw_route_turn_id', 'user');
        await db.tryAcquireLocalLease('chat_turn_lease');
        final job = await db.createGenerationTurn(
          user: ChatMessage(
            id: 'user',
            role: 'user',
            content: '可以保留不确定，不一定要马上回答清楚',
            createdAt: now,
          ),
          assistantMessageId: 'reply',
          model: 'deepseek-flash',
          reasoningEffort: 'high',
          deepThinking: deep,
        );
        final result =
            await DurableGenerationRunner(
                  db: db,
                  client: client,
                  secureConfig: secure,
                )
                .run(
                  job,
                  cancellationToken: cancellation,
                  onDelta: (delta) => streamed.write(delta.content),
                )
                .timeout(const Duration(seconds: 20));
        expect(result.status, 'completed', reason: '${result.error}');
        expect((await db.messageById('reply'))!.content, reply);
        expect(streamed.toString(), isNot(contains('reflection_state')));
        expect(streamed.toString(), isNot(contains('user_quote')));
        expect(finals, 1);
        expect(plans, deep ? 1 : 0);
        final topic =
            DeepReflectionStore.decode(
                  await db.getSetting(DeepReflectionStore.stateKey) ?? '',
                )['topic']
                as Map;
        expect(topic['phase'], 'settled');
        expect(topic['progress'], '用户指出可以暂时不下结论');
      } finally {
        cancellation.cancel();
        client.close();
        await db.releaseLocalLease('chat_turn_lease');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await db.closeForTesting();
        PathProviderPlatform.instance = paths;
        await root.delete(recursive: true);
      }
    });
  }
}
