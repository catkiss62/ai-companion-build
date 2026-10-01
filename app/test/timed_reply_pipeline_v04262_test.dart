import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
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

  test('paused game: native timed tool -> second-channel reply -> commit -> activation', () async {
    final root = await Directory.systemTemp.createTemp('timed-reply-pipeline-');
    final paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    FlutterSecureStorage.setMockInitialValues({
      'deepseek_api_key': 'test', 'cedar_toy_token': 'ctai_v1_test',
      'chat_api_provider': 'aiwangyou_gemini',
      'aiwangyou_gemini_api_key': 'test-final',
      'aiwangyou_final_reply_endpoint': 'https://relay.invalid/v1/chat/completions',
    });
    final secure = SecureConfig.forTesting(const FlutterSecureStorage());
    final finalStarted = Completer<void>();
    final finalResponse = Completer<http.Response>();
    final cancellation = GenerationCancellationToken();
    Future<GenerationRunResult>? running;
    var planningCalls = 0;
    var finalCalls = 0;
    http.Response sse(Map<String, Object?> delta, String finish) =>
        http.Response.bytes(utf8.encode('data: ${jsonEncode({'choices': [
          {'delta': delta, 'finish_reason': finish}
        ]})}\n\ndata: [DONE]\n\n'), 200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'});
    final client = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      if (body['tools'] is List && (body['tools'] as List).isNotEmpty) {
        planningCalls++;
        return sse({'tool_calls': [
          {'index': 0, 'id': 'timed', 'type': 'function', 'function': {
            'name': 'cedar_toy_start_timed_play',
            'arguments': '{"game":"white_room","duration_text":"20分钟"}',
          }}
        ]}, 'tool_calls');
      }
      finalCalls++;
      if (!finalStarted.isCompleted) finalStarted.complete();
      return finalResponse.future;
    }), jsonClientFactory: () => MockClient((_) async => http.Response(
      jsonEncode({'choices': [{'message': {'content': '{}'}}]}), 200)));
    try {
      await db.setSetting('nsfw_route_turn_id', 'user');
      await db.setSetting('cedar_route_intent_v1', 'act_now');
      await db.setSetting('cedar_toy_enabled', '1');
      await db.setSetting('cedar_toy_autonomy_enabled', '1');
      final store = CedarToyActivityStore(db);
      await store.saveCatalog('white_room 白色房间，单人游戏');
      await store.recordGuide(gameId: 'white_room', guide: '单人白色房间。cmd 为游戏动作。');
      await store.pauseAndRelease();
      // Match the reported existing paused session selected by a fresh guide.
      await store.recordGuide(gameId: 'white_room', guide: '单人白色房间。cmd 为游戏动作。');
      expect((await store.load())!.phase, CedarActivityPhase.paused);
      await db.tryAcquireLocalLease('chat_turn_lease');
      final pending = await db.createGenerationTurn(
        user: ChatMessage(id: 'user', role: 'user', content: '你现在去白色房间玩20分钟',
            createdAt: DateTime.now()),
        assistantMessageId: 'reply', model: 'deepseek-flash', reasoningEffort: 'high');
      final runner = DurableGenerationRunner(db: db, client: client, secureConfig: secure);
      running = runner.run(pending, cancellationToken: cancellation);
      await finalStarted.future.timeout(const Duration(seconds: 15));
      final tasks = CedarTimedPlayTaskStore(db);
      expect(await tasks.active(), isNull);
      expect(await db.getSetting(CedarTimedPlayTaskStore.pendingKey), contains('20'));
      expect((await store.load())!.phase, CedarActivityPhase.paused);
      finalResponse.complete(sse({'content': '好，我去白色房间玩20分钟，结束后回来告诉你。'}, 'stop'));
      final result = await running.timeout(const Duration(seconds: 15));
      expect(result.status, 'completed', reason: '${result.error}');
      expect(await db.messageById('reply'), isNotNull);
      expect((await tasks.active())?['minutes'], 20);
      expect((await store.load())!.phase, isNot(CedarActivityPhase.paused));
      expect(planningCalls, 1);
      expect(finalCalls, 1);
    } finally {
      cancellation.cancel();
      if (!finalResponse.isCompleted) {
        finalResponse.complete(sse({'content': '测试结束'}, 'stop'));
      }
      if (running != null) {
        try { await running.timeout(const Duration(seconds: 5)); } catch (_) {}
      }
      client.close();
      await db.releaseLocalLease('chat_turn_lease');
      // Allow optional post-commit shadow work to finish its local reads.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await db.closeForTesting();
      PathProviderPlatform.instance = paths;
      await root.delete(recursive: true);
    }
  });
}
