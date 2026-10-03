import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
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
    test(
      'real reply pipeline: deep=$deep plans only when enabled, Gemini writes once',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'deep-web-pipeline-',
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
        var plans = 0;
        var finals = 0;
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
              expect(request.url.host, isNot('relay.invalid'));
              return sse('现有上下文足够，无需工具。');
            }
            if (request.url.host == 'relay.invalid') {
              finals++;
              return sse('「嗯，我在听。」');
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
          await db.setSetting('nsfw_route_turn_id', 'user');
          await db.tryAcquireLocalLease('chat_turn_lease');
          final job = await db.createGenerationTurn(
            user: ChatMessage(
              id: 'user',
              role: 'user',
              content: '今天心情不错',
              createdAt: DateTime.now(),
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
                  .run(job, cancellationToken: cancellation)
                  .timeout(const Duration(seconds: 20));
          expect(result.status, 'completed', reason: '${result.error}');
          expect(plans, deep ? 1 : 0);
          expect(finals, 1);
          expect(
            (await db.messageById('reply'))!.content,
            isNot(contains('无需工具')),
          );
        } finally {
          cancellation.cancel();
          client.close();
          await db.releaseLocalLease('chat_turn_lease');
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await db.closeForTesting();
          PathProviderPlatform.instance = paths;
          await root.delete(recursive: true);
        }
      },
    );
  }
}
