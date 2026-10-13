import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/agent/turn_execution_store.dart';
import 'package:ai_companion_localfirst/core/agent/turn_task_intent.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter/services.dart';
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

http.Response _response(Map<String, Object?> delta, {String finish = 'stop'}) =>
  http.Response.bytes(utf8.encode('data: ${jsonEncode({'choices': [
    {'delta': delta, 'finish_reason': finish} ]})}\n\ndata: [DONE]\n\n'), 200,
    headers: {'content-type': 'text/event-stream; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const channel = MethodChannel('ai_companion/system');
  for (final scenario in ['commission', 'stop', 'fallback_stop']) {
    final fallback = scenario == 'fallback_stop';
    final creativeAction = scenario == 'commission' ? 'commission' : 'stop';
    test('real runner preserves each authorized task through $scenario planning', () async {
      final files = await Directory.systemTemp.createTemp('mixed-goal-runner-');
      final originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(files.path);
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'fixture-only',
        'cedar_toy_token': 'ctai_v1_test', 'chat_api_provider': 'deepseek'});
      final secure = SecureConfig.forTesting(const FlutterSecureStorage());
      final cancellation = GenerationCancellationToken();
      var planningCalls = 0;
      var finalSawBothGoalsSatisfied = false;
      late String workId;
      final userText = fallback ? '请停止制作那个小灯作品。' : creativeAction == 'commission'
        ? '暂停白色房间，把小灯作品改成蓝色。' : '暂停白色房间，那个小灯作品也先别做了。';
      final client = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if ((body['tools'] as List?)?.isNotEmpty == true) {
          planningCalls++;
          final name = 'creative_work_$creativeAction';
          expect(jsonEncode(body['tools']), contains(name));
          expect(planningCalls, 1, reason: 'one remaining creative goal needs one proposal');
          return _response({'tool_calls': [{'index': 0, 'id': 'creative-call', 'type': 'function',
            'function': {'name': name, 'arguments': jsonEncode({
              'work_id': workId, 'request_quote': userText, if (creativeAction == 'commission') ...{
                'target_kind': 'existing', 'brief': '把小灯改成蓝色'}})}}]},
            finish: 'tool_calls');
        }
        final prompt = jsonEncode(body['messages']);
        if (prompt.contains('本轮明确任务目标均有相应真实执行证据')) finalSawBothGoalsSatisfied = true;
        if (prompt.contains('Classify only the actual ASSISTANT_REPLY')) return _response({'content': '{}'});
        return _response({'content': fallback ? '「好，那个小灯作品先不做了。」' : creativeAction == 'commission'
          ? '「白色房间先停下了，小灯的修改也交给后台了，做好再给你看。」'
          : '「好，白色房间和小灯制作都先停下。」'});
      }), jsonClientFactory: () => MockClient((_) async => http.Response(
        jsonEncode({'choices': [{'message': {'content': '{}'}}]}), 200)));
      try {
        await db.setSetting('cedar_toy_enabled', '1');
        await db.setSetting('cedar_toy_autonomy_enabled', '1');
        final activity = CedarToyActivityStore(db);
        await activity.saveCatalog('white_room·白色房间，单人游戏·tester');
        final session = await activity.recordGuide(gameId: 'white_room', guide: '单人白色房间，cmd操作。');
        final works = CreativeStore(db);
        final originalWork = await works.commission(deepThinking: true, requestId: 'old-request',
          messageId: 'old-card', brief: '小灯', requestQuote: '小灯', latestText: '做一盏小灯');
        workId = originalWork['id'] as String;
        if (creativeAction == 'commission') await works.stop(workId);
        await db.tryAcquireLocalLease('chat_turn_lease');
        final job = await db.createGenerationTurn(user: ChatMessage(id: 'user', role: 'user',
          content: userText, createdAt: DateTime.now()), assistantMessageId: 'reply',
          model: 'deepseek-flash', reasoningEffort: 'high', deepThinking: true);
        final source = (await ConversationSourceStore.captureMessage(await db.database, 'user'))!;
        final sourceKey = '${source.contentHash}:${source.revision}';
        final intent = fallback ? const TurnTaskIntent() : TurnTaskIntent(available: true, gameAction: 'pause',
          gameId: session.gameId, sessionId: session.id, creativeAction: creativeAction,
          workId: workId, requestId: originalWork['request_id'] as String, workTargetKind: 'existing');
        await db.setSetting('nsfw_route_turn_id', 'user');
        await db.setSetting('nsfw_route_source_key_v2', sourceKey);
        await db.setSetting('cedar_route_intent_v1', 'chat');
        await db.setSetting('route_task_intent_v1', jsonEncode({
          'turn_id': 'user', 'source_key': sourceKey, 'intent': intent.toJson()}));
        // The routing decision and model response are fixed inputs; both
        // local effects, original ownership, loop and final commit are real.
        final result = await DurableGenerationRunner(db: db, client: client, secureConfig: secure)
          .run(job, cancellationToken: cancellation).timeout(const Duration(seconds: 20));
        expect(result.status, 'completed', reason: result.error?.toString());
        expect(await db.messageById('reply'), isNotNull);
        expect(planningCalls, 1);
        expect(finalSawBothGoalsSatisfied, isTrue);
        final game = (await activity.loadState()).sessions['white_room']!;
        final gameReceipt = await TurnExecutionStore(db).readEffect('user', TurnEffectSlot.cedarControl);
        if (fallback) {
          expect(game.phase, session.phase);
          expect(gameReceipt, isNull);
        } else {
          expect(game.phase, CedarActivityPhase.paused);
          expect(gameReceipt?.committed, isTrue);
        }
        final creativeSlot = creativeAction == 'commission'
          ? TurnEffectSlot.creativeCommission : TurnEffectSlot.creativeControl;
        expect((await TurnExecutionStore(db).readEffect('user', creativeSlot))?.committed, isTrue);
        final work = await works.get(workId);
        expect(work['status'], creativeAction == 'commission' ? 'queued' : 'paused');
        expect(work['request_id'], creativeAction == 'commission'
          ? turnEffectId('user', TurnEffectSlot.creativeCommission) : 'old-request');
        expect(await works.list(), hasLength(1));
        expect(await CedarTimedPlayTaskStore(db).active(), isNull);
        expect(await db.getSetting('agent_v2_last_tool_calls'), fallback ? '1' : '2');
      } finally {
        cancellation.cancel();
        client.close();
        await db.releaseLocalLease('chat_turn_lease');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await db.closeForTesting();
        messenger.setMockMethodCallHandler(channel, null);
        PathProviderPlatform.instance = originalPaths;
        await files.delete(recursive: true);
      }
    });
  }
}
