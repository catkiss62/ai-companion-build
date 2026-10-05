import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/self/dream_store.dart';
import 'package:ai_companion_localfirst/core/self/dream_contract.dart';
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
      'dream understanding reaches the same final writer without extra planning, deep=$deep',
      () async {
        final root = await Directory.systemTemp.createTemp('dream-pipeline-');
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
        const sourceText = '不用一直赶目标，停下来看看也很好。';
        const understanding = '我可能也喜欢不急着完成目标的游玩节奏。';
        const reply = '「那我想先看看这里的风景，再决定下一步。」';
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
              expect(request.body, contains(understanding));
              expect(request.body, contains('当前自我理解'));
              return sse(reply);
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
          final sourceAt = now.subtract(const Duration(days: 1));
          await db.insertMessage(
            ChatMessage(
              id: 'dream-source',
              role: 'user',
              content: sourceText,
              createdAt: sourceAt,
            ),
          );
          final source = DreamSource(
            id: 'chat:dream-source',
            kind: 'user_text',
            text: sourceText,
            at: sourceAt.millisecondsSinceEpoch,
            fresh: true,
          );
          final state = DreamContract.apply(
            payload: {
              'changes': [
                {
                  'action': 'upsert',
                  'id': 'play.own_pace',
                  'domain': 'play',
                  'stance': 'tentative',
                  'understanding': understanding,
                  'choice': '允许在自己感兴趣的地方停留。',
                  'uncertainty': '未必适合所有游戏。',
                  'reason': '这次交流使我重新理解自己的游玩节奏。',
                  'basis': 'new_experience',
                  'evidence': [
                    {'id': source.id, 'quote': sourceText, 'role': 'support'},
                  ],
                },
              ],
            },
            state: {},
            sources: [source],
            now: now,
          )!;
          await db.setSetting(DreamStore.stateKey, jsonEncode(state));
          await db.setSetting('nsfw_route_turn_id', 'user');
          await db.tryAcquireLocalLease('chat_turn_lease');
          final job = await db.createGenerationTurn(
            user: ChatMessage(
              id: 'user',
              role: 'user',
              content: '那你自己想先做些什么？',
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
          expect(streamed.toString(), isNot(contains('当前自我理解')));
          expect(streamed.toString(), isNot(contains('user_quote')));
          expect(finals, 1);
          expect(plans, deep ? 1 : 0);
          expect(await db.getSetting(DreamStore.stateKey), jsonEncode(state));
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
