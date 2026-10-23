import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_localfirst/core/agent/turn_task_intent.dart';
import 'package:ai_companion_localfirst/core/agent/semantic_tool_route.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
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
  _Paths(this.path);final String path;
  @override Future<String?> getApplicationSupportPath()async=>path;
  @override Future<String?> getTemporaryPath()async=>path;
}
const guide='单人游戏，action="status" 查询真实存档；action="cmd" 用command执行操作。slot存档槽1至5，当前slot=1。';
class _Game extends CedarToyClient {
  _Game():super(token:'ctai_v1_fixture');
  final actions=<String>[];
  @override Future<String> getPlayerPlayProtocol({GenerationCancellationToken? cancellationToken})async=>'';
  @override Future<McpToolOutcome> listGames({GenerationCancellationToken? cancellationToken})async=>
    const McpToolOutcome(isError:false,content:[McpContentBlock(kind:McpContentKind.text,text:'bar·酒馆经营，单人·fixture')]);
  @override Future<McpToolOutcome> getGuide(String game,{GenerationCancellationToken? cancellationToken})async=>
    const McpToolOutcome(isError:false,content:[McpContentBlock(kind:McpContentKind.text,text:guide)]);
  @override Future<McpToolOutcome> play(String game,String action,Map<String,Object?> params,
    {GenerationCancellationToken? cancellationToken})async {
    expect(game,'bar');expect(params['slot'],1);actions.add(action);
    if(action=='cmd')expect(params['command'],'new-valid-step');
    return McpToolOutcome(isError:false,content:[McpContentBlock(kind:McpContentKind.text,
      text:action=='status'?'同一槽的真实状态':'已完成新的一步')],
      structuredContent:{'next_actor':'companion','participation_mode':'solo'});
  }
}
http.Response _reply(Map<String,Object?> delta,{String finish='stop'})=>http.Response.bytes(
  utf8.encode('data: ${jsonEncode({'choices':[{'delta':delta,'finish_reason':finish}]})}\n\ndata: [DONE]\n\n'),200,
  headers:{'content-type':'text/event-stream; charset=utf-8'});
Map<String,Object?> _call(String name,Map<String,Object?> args)=>{'tool_calls':[{
  'index':0,'id':'call-$name','type':'function','function':{'name':name,'arguments':jsonEncode(args)}}]};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  for(final winner in ['play','resume']) {
    test('real $winner ambiguity registers a NEW task and reconciles the old unknown write before progressing',()async {
      final files=await Directory.systemTemp.createTemp('cedar373-');
      final previous=PathProviderPlatform.instance;PathProviderPlatform.instance=_Paths(files.path);
      final db=await AppDatabase.createForTesting(databaseFactoryFfi);
      const channel=MethodChannel('ai_companion/system');
      final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel,(c)async=>c.method=='runtimeProcessEpoch'?'fixture-runtime':null);
      FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'fixture','cedar_toy_token':'ctai_v1_fixture',
        'chat_api_provider':'aiwangyou_gemini','aiwangyou_gemini_api_key':'fixture-final',
        'aiwangyou_final_reply_endpoint':'https://relay.invalid/v1/chat/completions'});
      final game=_Game();final finalStarted=Completer<void>();final finalResponse=Completer<http.Response>();
      final cancellation=GenerationCancellationToken();var plans=0;
      final ai=DeepSeekClient(streamClientFactory:()=>MockClient((request)async{
        final body=jsonDecode(request.body) as Map;
        final names=[for(final t in body['tools'] as List? ?? [])((t as Map)['function'] as Map)['name']];
        if(names.any((n)=>n!='agent_request')) {
          plans++;
          if(plans==1)return _reply(_call('cedar_toy_list_games',{}),finish:'tool_calls');
          if(plans==2)return _reply(_call('cedar_toy_get_guide',{'game':'bar'}),finish:'tool_calls');
          return _reply(_call('cedar_toy_start_timed_play',{'game':'bar','duration_text':'半个小时'}),finish:'tool_calls');
        }
        if(request.url.host=='relay.invalid') {
          if(!finalStarted.isCompleted)finalStarted.complete();return finalResponse.future;
        }
        return _reply({'content':'{}'});
      }),jsonClientFactory:()=>MockClient((_)async=>http.Response(jsonEncode({'choices':[{'message':{'content':'{}'}}]}),200)));
      Future<GenerationRunResult>? running;
      try {
        final activity=CedarToyActivityStore(db);final tasks=CedarTimedPlayTaskStore(db);
        await activity.saveCatalog('bar·酒馆经营，单人·fixture');
        final session=await activity.recordGuide(gameId:'bar',guide:guide);
        await activity.pause();
        await db.setSetting('${CedarToyActivityStore.uncertainWritePrefix}bar',jsonEncode({
          'schema':1,'execution_id':'dead-runtime','state':'dispatching','action':'cmd',
          'params':{'slot':1,'command':'old-mutation-do-not-repeat'}}));
        await db.setSetting(CedarTimedPlayTaskStore.diagnosticKey,jsonEncode({
          'terminal':true,'game_id':'bar','session_id':session.id,'used_ms':1800000,'execution_id':'old-ended-task'}));
        await db.tryAcquireLocalLease('chat_turn_lease');
        const text='修好了，酒馆可以用了，去玩半个小时吧';
        final job=await db.createGenerationTurn(user:ChatMessage(id:'u',role:'user',content:text,createdAt:DateTime.now()),
          assistantMessageId:'a',model:'fixture-first',reasoningEffort:'high');
        final source=(await ConversationSourceStore.captureMessage(await db.database,'u'))!;
        final key='${source.contentHash}:${source.revision}';
        final questions=TurnTaskQuestionSet(userText:text,state:await activity.loadState(),works:const []);
        final target=questions.games.entries.firstWhere((e)=>e.value.id=='bar').key;
        final intent=questions.interpret({'task_game':winner,'task_game_target':target,'task_duration':'d0','task_creative':'none','cedar':'act_now'},
          details:{'task_game':JevChoiceDecision(choice:winner,
            probabilities:{'play':winner=='play' ? .42 : .39,'resume':winner=='resume' ? .42 : .39,'none':.16,'pause':.01,'pause_and_release':.01,'report':.01},ambiguous:true),
            'cedar':const JevChoiceDecision(choice:'act_now',probabilities:{'act_now':.65,'accept':.34,'chat':.01},ambiguous:false)});
        expect(intent.gameExecutionResolved,true);
        await db.setSetting('nsfw_route_turn_id','u');await db.setSetting('nsfw_route_source_key_v2',key);
        await db.setSetting('cedar_route_intent_v1','act_now');await db.setSetting('cedar_route_certain_v1','1');
        await db.setSetting('route_task_intent_v1',jsonEncode({'turn_id':'u','source_key':key,'intent':intent.toJson()}));
        await db.setSetting('route_tool_intent_v1',jsonEncode({'turn_id':'u','source_key':key,'route':const SemanticToolRoute(available:true).toJson()}));
        running=DurableGenerationRunner(db:db,client:ai,secureConfig:SecureConfig.forTesting(const FlutterSecureStorage()),cedarClientFactory:(_)=>game)
          .run(job,cancellationToken:cancellation);
        await finalStarted.future.timeout(const Duration(seconds:20));
        expect(await tasks.active(),isNull);expect(game.actions,isEmpty);
        expect(await db.getSetting(CedarTimedPlayTaskStore.pendingKey),contains('30'));
        finalResponse.complete(_reply({'content':'「已登记半小时任务，先核对旧操作，确认后继续。」'}));
        final result=await running.timeout(const Duration(seconds:20));
        expect(result.status,'completed',reason:result.error?.toString());
        expect((await tasks.active())!['id'],'cedar-task:u');expect((await tasks.active())!['minutes'],30);
        expect((await activity.loadSession('bar'))!.id,session.id);
        await db.releaseLocalLease('chat_turn_lease');
        final backgroundAi=DeepSeekClient(streamClientFactory:()=>MockClient((_)async=>_reply(_call('cedar_toy_play',{
          'game':'bar','action':'cmd','params_json':'{"slot":1,"command":"new-valid-step"}',
          'participation_mode':'solo','invitation_approved':false,'share_previous_outcome':false}),finish:'tool_calls')));
        try {
          final engine=CedarToyAutonomyEngine(db:db,ai:backgroundAi,secureConfig:SecureConfig.forTesting(const FlutterSecureStorage()),tokenReader:()async=>'ctai_v1_fixture',
            apiKeyReader:()async=>'fixture',endpointReader:()async=>DeepSeekClient.defaultEndpoint,clientFactory:(_)=>game);
          expect((await engine.continueDue(now:DateTime.now())).state,'write_reconciliation_scheduled');
          await activity.deferContinuation(gameId:'bar',delay:Duration.zero,now:DateTime.now().subtract(const Duration(seconds:1)));
          expect((await engine.continueDue(now:DateTime.now())).state,'write_reconciled');
          expect(game.actions,['status']);expect(await activity.unresolvedWrite('bar'),isNull);
          await activity.deferContinuation(gameId:'bar',delay:Duration.zero,now:DateTime.now().subtract(const Duration(seconds:1)));
          expect((await engine.continueDue(now:DateTime.now())).state,'played_one_step');
          expect(game.actions,['status','cmd']);expect((await tasks.active())!['progressCount'],1);
        } finally {backgroundAi.close();}
      } finally {
        cancellation.cancel();if(!finalResponse.isCompleted)finalResponse.complete(_reply({'content':'测试结束'}));
        if(running!=null){try{await running.timeout(const Duration(seconds:2));}catch(_){}}
        ai.close();await db.releaseLocalLease('chat_turn_lease');await db.closeForTesting();
        messenger.setMockMethodCallHandler(channel,null);PathProviderPlatform.instance=previous;await files.delete(recursive:true);
      }
    });
  }
}
