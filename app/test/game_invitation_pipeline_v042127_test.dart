import 'package:ai_companion_localfirst/core/agent/turn_task_intent.dart';
import 'package:ai_companion_localfirst/core/agent/semantic_tool_route.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
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

class _Game extends CedarToyClient {
  _Game():super(token:'ctai_v1_test');
  int plays=0;
  @override Future<McpToolOutcome> play(String game,String action,Map<String,Object?> params,
    {GenerationCancellationToken? cancellationToken})async{
    expect(game,'white_room');expect(action,'start');plays++;
    return const McpToolOutcome(isError:false,
      content:[McpContentBlock(kind:McpContentKind.text,text:'已进入白房间')],
      structuredContent:{'status':'playing','next_actor':'companion','participation_mode':'solo'});
  }
  @override Future<McpToolOutcome> getGuide(String game,{GenerationCancellationToken? cancellationToken})async=>
    const McpToolOutcome(isError:false,content:[McpContentBlock(kind:McpContentKind.text,
      text:'单人自由叙事。start 开始，explore 探索。')]);
  @override Future<McpToolOutcome> listGames({GenerationCancellationToken? cancellationToken})async=>
    const McpToolOutcome(isError:false,content:[McpContentBlock(kind:McpContentKind.text,
      text:'white_room·自由叙事，单人·test')]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  for(final accepts in [true,false]) {
  test('present invitation supports a voluntary decision through cached JEV ambiguity: accepts=$accepts', () async {
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
    final game=_Game();
    var planningCalls = 0;
    var finalCalls = 0;
    http.Response sse(Map<String, Object?> delta, String finish) =>
        http.Response.bytes(utf8.encode('data: ${jsonEncode({'choices': [
          {'delta': delta, 'finish_reason': finish}
        ]})}\n\ndata: [DONE]\n\n'), 200,
            headers: {'content-type': 'text/event-stream; charset=utf-8'});
    final client = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      if (body['tools'] is List && (body['tools'] as List).any((t) => ((t as Map)['function'] as Map)['name'] != 'agent_request')) {
        planningCalls++;
        if(!accepts) return sse({'content':'这次我不想去玩，想休息。'},'stop');
        return sse({'tool_calls': [
          {'index': 0, 'id': 'timed', 'type': 'function', 'function': {
            'name': planningCalls==1?'cedar_toy_play':'cedar_toy_start_timed_play',
            'arguments': jsonEncode(planningCalls==1?{'game':'white_room','action':'start','params_json':'{}',
              'participation_mode':'solo','invitation_approved':false}:
              {'game':'white_room','duration_text':'半小时'}),
          }}
        ]}, 'tool_calls');
      }
      if (request.url.host == 'relay.invalid') {
        finalCalls++;
        if (!finalStarted.isCompleted) finalStarted.complete();
        return finalResponse.future;
      }
      // Optional post-turn judging stays on DeepSeek and is not a second
      // visible reply. It must not hold or activate the staged game task.
      return sse({'content': '{}'}, 'stop');
    }), jsonClientFactory: () => MockClient((_) async => http.Response(
      jsonEncode({'choices': [{'message': {'content': '{}'}}]}), 200)));
    try {
      await db.setSetting('nsfw_route_turn_id', 'user');
      await db.setSetting('cedar_route_intent_v1', 'act_now');
      await db.setSetting('cedar_toy_enabled', '1');
      await db.setSetting('cedar_toy_autonomy_enabled', '1');
      final store = CedarToyActivityStore(db);
      await store.saveCatalog('white_room·自由叙事，单人游戏·test');
      final session=await store.recordGuide(gameId:'white_room',guide:'单人自由叙事。start 开始，explore 探索。');
      await db.tryAcquireLocalLease('chat_turn_lease');
      final pending = await db.createGenerationTurn(
        user: ChatMessage(id: 'user', role: 'user', content: '可以啊，我来围观你，你现在想不想玩？要不要去玩半小时？',
            createdAt: DateTime.now()),
        assistantMessageId: 'reply', model: 'deepseek-flash', reasoningEffort: 'high');
      final source=(await ConversationSourceStore.captureMessage(await db.database,'user'))!;
      final sourceKey='${source.contentHash}:${source.revision}';
      await db.setSetting('nsfw_route_source_key_v2',sourceKey);
      await db.setSetting('cedar_route_intent_v1','accept');
      await db.setSetting('cedar_route_certain_v1','1');
      await db.setSetting('route_task_intent_v1',jsonEncode({'turn_id':'user','source_key':sourceKey,
        'intent':TurnTaskIntent(available:true,gameAction:'play',gameId:'white_room',sessionId:session.id,
          durationText:'半小时',minutes:30,unresolvedFields:const {'task_game'}).toJson()}));
      await db.setSetting('route_tool_intent_v1',jsonEncode({'turn_id':'user','source_key':sourceKey,
        'route':const SemanticToolRoute(available:true).toJson()}));
      final runner = DurableGenerationRunner(db: db, client: client, secureConfig: secure,
        cedarClientFactory:(_)=>game);
      running = runner.run(pending, cancellationToken: cancellation);
      await finalStarted.future.timeout(const Duration(seconds: 15));
      final tasks = CedarTimedPlayTaskStore(db);
      expect(await tasks.active(), isNull);
      if(accepts) expect(await db.getSetting(CedarTimedPlayTaskStore.pendingKey), contains('30'));
      else expect(await db.getSetting(CedarTimedPlayTaskStore.pendingKey), anyOf(isNull,isEmpty));
      expect(game.plays,accepts?1:0);
      finalResponse.complete(sse({'content': accepts?'好，我去白房间玩半小时，结束后回来告诉你。':'我现在想休息，先不去玩。'}, 'stop'));
      final result = await running.timeout(const Duration(seconds: 15));
      expect(result.status, 'completed', reason: '${result.error}');
      expect(await db.messageById('reply'), isNotNull);
      if(accepts) {
        expect((await tasks.active())?['minutes'],30);
        expect((await store.load())!.phase,isNot(CedarActivityPhase.paused));
      } else {
        expect(await tasks.active(),isNull);expect(game.plays,0);
        expect((await db.messageById('reply'))!.content,contains('想休息'));
      }
      expect(planningCalls, 2);
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
}
