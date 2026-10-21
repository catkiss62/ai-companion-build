import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/ai/final_reply_control.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/ai/playful_self_judge.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';
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
  @override Future<String?> getApplicationSupportPath() async => path;
  @override Future<String?> getTemporaryPath() async => path;
}

http.Response _sse(String text) => http.Response.bytes(utf8.encode(
  'data: ${jsonEncode({'choices': [{'delta': {'content': text}, 'finish_reason': 'stop'}]})}\n\ndata: [DONE]\n\n'),
  200, headers: {'content-type': 'text/event-stream; charset=utf-8'});

/// Deliberately ignores close until headers arrive, like an uncooperative SDK.
class _LateTransport extends http.BaseClient {
  final started = Completer<void>();
  final response = Completer<http.StreamedResponse>();
  bool closed = false;
  @override Future<http.StreamedResponse> send(http.BaseRequest request) {
    started.complete();
    return response.future;
  }
  @override void close() { closed = true; }
  void finish() => response.complete(http.StreamedResponse(Stream.value(utf8.encode(
    'data: {"choices":[{"delta":{"content":"迟到的第二通道"},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n')), 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('manual choice aborts only the active second-channel transport before headers', () async {
    final transport = _LateTransport();
    final client = DeepSeekClient(streamClientFactory: () => transport);
    final control = FinalReplyControl();
    final wholeTurn = GenerationCancellationToken();
    final request = client.streamChat(apiKey: 'test',
      model: DeepSeekModelProfile.fromApiName('second-test'), effort: ReasoningEffort.high,
      messages: const [{'role': 'user', 'content': '测试'}],
      cancellationToken: control.secondChannelToken(wholeTurn)).toList();
    final assertion = expectLater(request, throwsA(isA<GenerationCancelledByUserException>()));
    await transport.started.future;
    expect(control.requestDeepSeek(), isTrue);
    await assertion.timeout(const Duration(seconds: 1));
    expect(transport.closed, isTrue);
    expect(wholeTurn.isCancelled, isFalse); // First-channel planning remains live.
    transport.finish();
    client.close();
  });
  for (final scenario in ['before_final', 'durable_before_final', 'legacy_job', 'headers_pending', 'retry_wait',
      'postprocessing', 'durable_choice', 'stop_after_choice', 'second_success', 'second_repair_failure', 'api_failure']) {
    test('production runner per-turn choice: $scenario', () async {
      final root = await Directory.systemTemp.createTemp('manual-reply-');
      final paths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(root.path);
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      FlutterSecureStorage.setMockInitialValues({
        'deepseek_api_key': 'test-first', 'chat_api_provider': 'aiwangyou_gemini',
        'aiwangyou_gemini_api_key': 'test-second',
        'aiwangyou_final_reply_endpoint': 'https://relay.invalid/v1/chat/completions',
        'aiwangyou_final_reply_model': 'second-custom',
      });
      final secure = SecureConfig.forTesting(const FlutterSecureStorage());
      final control = FinalReplyControl();
      final stop = GenerationCancellationToken();
      final late = _LateTransport();
      final firstFinalStarted = Completer<void>();
      final judgedSecond = Completer<void>();
      final allowJudgement = Completer<void>();
      final models = <String>[];
      final finalInputs = <List<dynamic>>[];
      var secondRequests = 0;
      var planningRequests = 0;
      var firstFinals = 0;
      final client = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final isSecond = request.url.host == 'relay.invalid';
        if (isSecond) {
          secondRequests++;
          models.add(body['model'] as String);
          finalInputs.add(body['messages'] as List);
          if (scenario == 'headers_pending' || scenario == 'stop_after_choice') {
            final raw = await late.send(request);
            return http.Response.fromStream(raw);
          }
          if (scenario == 'retry_wait') {
            // Request the choice after the 503 has entered the retry delay.
            Timer(const Duration(milliseconds: 50), control.requestDeepSeek);
            return http.Response('temporary', 503);
          }
          if (scenario == 'api_failure') return http.Response('unauthorized', 401);
          if (scenario == 'second_repair_failure' && secondRequests > 1) {
            return http.Response('repair unavailable', 400);
          }
          return _sse('「今天的风看起来很轻。」');
        }
        if ((body['tools'] as List?)?.isNotEmpty == true) {
          planningRequests++;
          return _sse('现有上下文足够。');
        }
        if (body.containsKey('max_tokens')) {
          expect(body['model'], 'first-configured'); // Bounded routing utility.
          return _sse('{}');
        }
        models.add(body['model'] as String);
        finalInputs.add(body['messages'] as List);
        firstFinals++;
        if (scenario == 'second_repair_failure') return http.Response('first repair unavailable', 500);
        if (!firstFinalStarted.isCompleted) firstFinalStarted.complete();
        if (scenario == 'stop_after_choice') {
          await stop.whenCancelled;
          return _sse('停止后不应提交');
        }
        return _sse('「我想先安静地看看窗外。」');
      }), jsonClientFactory: () => MockClient((_) async => http.Response(
        jsonEncode({'choices': [{'message': {'content': '{}'}, 'finish_reason': 'stop'}]}), 200)));
      final judge = PlayfulSelfJudge(client: client,
        jevGateway: JevDecisionGateway(enabledReader: () async => false),
        fallbackClassifier: (_, text) async {
          if ((scenario == 'postprocessing' || scenario == 'durable_choice') && text.contains('风')) {
            judgedSecond.complete();
            await allowJudgement.future;
          }
          return PlayfulSelfActivity.none;
        });
      try {
        await db.setSetting('deepseek_model', 'first-configured');
        await db.setSetting('nsfw_manual_override', 'off');
        if (scenario == 'second_repair_failure') {
          await db.insertMessage(ChatMessage(id: 'old', role: 'assistant',
            content: '「今天的风看起来很轻。」', createdAt: DateTime.now().subtract(const Duration(minutes: 1))));
        }
        await db.tryAcquireLocalLease('chat_turn_lease');
        final job = await db.createGenerationTurn(user: ChatMessage(id: 'user', role: 'user',
          content: '你想先做什么？', createdAt: DateTime.now()), assistantMessageId: 'reply',
          model: scenario == 'legacy_job' ? '' : 'first-configured', reasoningEffort: 'high');
        if (scenario == 'durable_before_final') {
          expect(await db.selectDeepSeekForGeneration(job.id), isTrue);
        }
        if (scenario == 'before_final' || scenario == 'legacy_job') {
          expect(control.requestDeepSeek(), isTrue);
          expect(control.requestDeepSeek(), isFalse);
        }
        final pending = DurableGenerationRunner(db: db, client: client, secureConfig: secure, selfJudge: judge)
          .run(job, cancellationToken: stop, replyControl: control);
        if (scenario == 'headers_pending' || scenario == 'stop_after_choice') {
          await late.started.future.timeout(const Duration(seconds: 10));
          expect(control.requestDeepSeek(), isTrue);
          expect(control.requestDeepSeek(), isFalse);
          await firstFinalStarted.future.timeout(const Duration(seconds: 2));
          if (scenario == 'stop_after_choice') stop.cancel();
        }
        if (scenario == 'postprocessing' || scenario == 'durable_choice') {
          await judgedSecond.future.timeout(const Duration(seconds: 10));
          if (scenario == 'durable_choice') {
            expect(await db.selectDeepSeekForGeneration(job.id), isTrue);
          } else {
            expect(control.requestDeepSeek(), isTrue);
          }
          allowJudgement.complete();
        }
        final result = await pending.timeout(const Duration(seconds: 15));
        if (scenario == 'headers_pending' || scenario == 'stop_after_choice') {
          late.finish(); // A late provider may complete after the first reply.
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        if (scenario == 'stop_after_choice') {
          expect(result.status, 'cancelled_by_user');
          expect(await db.messageById('reply'), isNull);
        } else {
          expect(result.status, 'completed', reason: '${result.error}');
          final secondWon = scenario == 'second_success' || scenario == 'second_repair_failure';
          expect(result.assistant!.model, secondWon ? 'second-custom' : 'first-configured');
          expect(result.assistant!.content, contains(secondWon ? '风' : '窗外'));
          final rows = await (await db.database).query('messages');
          expect(rows.where((r) => r['role'] == 'user'), hasLength(1));
          expect(rows.where((r) => r['role'] == 'assistant'),
            hasLength(scenario == 'second_repair_failure' ? 2 : 1));
          expect(await db.selectDeepSeekForGeneration(job.id), isFalse);
          expect(control.requestDeepSeek(), isFalse); // Committed result owns the turn.
          expect(await secure.readChatProvider(), isNotNull);
          expect((await secure.readChatProvider()).isGeminiRelay, isTrue);
          final route = jsonDecode((await db.getSetting('generation_final_route_v1'))!) as Map;
          expect(route['reason'], secondWon ? 'second_channel'
              : scenario == 'api_failure' ? 'api_failure_fallback' : 'manual_deepseek');
          expect(firstFinals, scenario == 'second_repair_failure' ? 1 : secondWon ? 0 : 1);
          if (const {'before_final', 'durable_before_final', 'legacy_job'}.contains(scenario)) {
            expect(secondRequests, 0);
          }
          if (scenario == 'retry_wait') expect(secondRequests, 1);
          if (finalInputs.length > 1 && scenario != 'second_repair_failure') {
            expect(finalInputs.last, finalInputs.first); // Same turn/context, no fake user.
          }
        }
        expect(planningRequests, lessThanOrEqualTo(1));
        expect(models, isNot(contains('deepseek-v4-pro')));
      } finally {
        stop.cancel(); client.close();
        if (!late.response.isCompleted) late.finish();
        if (!allowJudgement.isCompleted) allowJudgement.complete();
        await db.releaseLocalLease('chat_turn_lease');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await db.closeForTesting();
        PathProviderPlatform.instance = paths;
        await root.delete(recursive: true);
      }
    });
  }
}
