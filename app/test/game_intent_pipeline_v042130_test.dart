import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_localfirst/core/agent/turn_task_intent.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
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
  _Paths(this.path); final String path;
  @override Future<String?> getApplicationSupportPath()async=>path;
  @override Future<String?> getTemporaryPath()async=>path;
}
class _Game extends CedarToyClient {
  _Game():super(token:'ctai_v1_fixture');
  int writes=0;
  @override Future<McpToolOutcome> getGuide(String game,{GenerationCancellationToken? cancellationToken}) async =>
    const McpToolOutcome(content:[McpContentBlock(kind:McpContentKind.text,
      text:'solo 单人。cmd command: status drinks guests serve')],isError:false);

  @override Future<McpToolOutcome> play(String game,String action,Map<String,Object?> params,
      {GenerationCancellationToken? cancellationToken})async {
    expect(game,'bar');expect(action,'cmd');expect(params['command'],'serve cloud pour:plum_liqueur');
    writes++;
    return const McpToolOutcome(content:[],isError:false,structuredContent:{
      'text':'已递给客人，当前目标完成。','next_actor':'finished'});
  }
}
http.Response _sse(Map<String,Object?> delta,{String? finish='stop'})=>http.Response.bytes(
  utf8.encode('data: ${jsonEncode({'choices':[{'delta':delta,'finish_reason':finish}]})}\n\ndata: [DONE]\n\n'),
  200,headers:{'content-type':'text/event-stream; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  for(final second in [false,true]) {
    for(final scenario in ['conflict_timer','resume_step','future','chat','guide_retry','truncated_plan','done_only']) {
      test('real ${second?'second':'first'} channel reconciles game intent: $scenario',()async {
        final files=await Directory.systemTemp.createTemp('game-intent374-');
        final paths=PathProviderPlatform.instance;PathProviderPlatform.instance=_Paths(files.path);
        final db=await AppDatabase.createForTesting(databaseFactoryFfi);
        const channel=MethodChannel('ai_companion/system');
        final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel,(_)async=>null);
        FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'fixture','cedar_toy_token':'ctai_v1_fixture',
          'chat_api_provider':second?'aiwangyou_gemini':'deepseek','aiwangyou_gemini_api_key':'fixture-final',
          'aiwangyou_final_reply_endpoint':'https://relay.invalid/v1/chat/completions',
          'aiwangyou_final_reply_model':'fixture-final'});
        final game=_Game(),cancellation=GenerationCancellationToken();
        var reviews=0,plans=0;
        final client=DeepSeekClient(streamClientFactory:()=>MockClient((request)async {
          final body=jsonDecode(request.body) as Map;
          final names=[for(final t in body['tools'] as List? ?? [])((t as Map)['function'] as Map)['name']];
          if(names.any((n)=>n!='agent_request')) {
            plans++;
            if(const {'conflict_timer','resume_step','guide_retry','truncated_plan','done_only'}.contains(scenario)) {
              final name=scenario=='conflict_timer'?'cedar_toy_start_timed_play':
                scenario=='guide_retry' && plans==2?'cedar_toy_get_guide':'cedar_toy_play';
              expect(names,contains(name));
              final args=scenario=='conflict_timer'
                ? <String,Object?>{'game':'bar','duration_text':'半小时'}
                : <String,Object?>{'game':'bar','action':'cmd','params_json':jsonEncode({
                    'command':'serve cloud pour:plum_liqueur'}),'participation_mode':'solo'};
              if(name=='cedar_toy_get_guide') {args.clear();args['game']='bar';}
              return _sse({'tool_calls':[{'index':0,'id':'call-$plans','type':'function',
                'function':{'name':name,'arguments':jsonEncode(args)}}]},finish:scenario=='truncated_plan'?'length':scenario=='done_only'?null:'tool_calls');
            }
          }
          return _sse({'content':'「好，按当前情况来。」'});
        }),jsonClientFactory:()=>MockClient((request)async {
          final body=jsonDecode(request.body) as Map;
          final review=jsonEncode(body['messages']).contains('游戏入口与动作判断互相矛盾');
          if(review)reviews++;
          final answer=review ? {'task_game':scenario=='conflict_timer'?'resume':'none',
            'task_game_target':scenario=='conflict_timer'?'g0':'none',
            'task_duration':scenario=='conflict_timer'?'d0':'none'} : {};
          return http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode(answer)}}]}),200);
        }));
        try {
          await db.setSettingsAtomically({'cedar_toy_enabled':'1','cedar_toy_autonomy_enabled':'1'});
          final activity=CedarToyActivityStore(db);
          await activity.saveCatalog('bar·空杯俱乐部，单人酒馆游戏·tester');
          await activity.savePlayProtocol('play(game, action, params)');
          final session=await activity.recordGuide(gameId:'bar',guide:scenario=='guide_retry'?'solo 单人。先取得完整指南。':'solo 单人。cmd command: status drinks guests serve');
          await activity.pause();
          final text=switch(scenario) {
            'conflict_timer'=>'现在去空杯俱乐部玩半小时。',
            'resume_step'=>'恢复空杯俱乐部，继续把客人招呼好。',
            'guide_retry' || 'truncated_plan' || 'done_only'=>'去空杯俱乐部把客人招呼好。',
            'future'=>'今天别去空杯俱乐部，明天有空再玩。',
            _=>'空杯俱乐部这个名字真好听。',
          };
          await db.tryAcquireLocalLease('chat_turn_lease');
          final job=await db.createGenerationTurn(user:ChatMessage(id:'u',role:'user',content:text,createdAt:DateTime.now()),
            assistantMessageId:'a',model:'deepseek-flash',reasoningEffort:'high');
          final source=(await ConversationSourceStore.captureMessage(await db.database,'u'))!;
          final key='${source.contentHash}:${source.revision}';
          final intent=const {'resume_step','guide_retry','truncated_plan','done_only'}.contains(scenario)
            ? TurnTaskIntent(available:true,gameAction:scenario=='resume_step'?'resume':'play',gameId:'bar',sessionId:session.id)
            : const TurnTaskIntent(available:true);
          await db.setSettingsAtomically({'nsfw_route_turn_id':'u','nsfw_route_source_key_v2':key,
            'cedar_route_intent_v1':scenario=='chat'?'chat':'act_now','cedar_route_certain_v1':'1',
            'route_task_intent_v1':jsonEncode({'turn_id':'u','source_key':key,'intent':intent.toJson()})});
          final result=await DurableGenerationRunner(db:db,client:client,
            secureConfig:SecureConfig.forTesting(const FlutterSecureStorage()),cedarClientFactory:(_)=>game)
            .run(job,cancellationToken:cancellation).timeout(const Duration(seconds:30));
          if(scenario=='truncated_plan') {
            expect(game.writes,0);expect(result.status,isNot('completed'));return;
          }
          expect(result.status,'completed',reason:result.error?.toString());
          expect(reviews,scenario=='conflict_timer' || scenario=='future'?1:0);
          expect(game.writes,const {'resume_step','guide_retry','done_only'}.contains(scenario)?1:0);
          final timer=await CedarTimedPlayTaskStore(db).active();
          if(scenario=='conflict_timer') {expect(timer?['minutes'],30);expect(plans,1);}
          else {expect(timer,isNull);if(!const {'resume_step','guide_retry','done_only'}.contains(scenario))expect(plans,0);
            if(scenario=='guide_retry')expect(plans,3);}
        } finally {
          cancellation.cancel();client.close();await db.releaseLocalLease('chat_turn_lease');await db.closeForTesting();
          messenger.setMockMethodCallHandler(channel,null);PathProviderPlatform.instance=paths;await files.delete(recursive:true);
        }
      });
    }
  }
}
