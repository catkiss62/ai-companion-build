import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_localfirst/core/agent/agent_task_loop.dart';
import 'package:ai_companion_localfirst/core/agent/agent_progress_tracker.dart';
import 'package:ai_companion_localfirst/core/agent/agent_runtime_diagnostic.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/semantic_tool_route.dart';
import 'package:ai_companion_localfirst/core/agent/turn_task_intent.dart';
import 'package:ai_companion_localfirst/core/agent/turn_execution_contract.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/grounding/operational_claim_grounding_guard.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/agent/turn_execution_store.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_task_presentation.dart';
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
http.Response reply(Map<String,Object?> delta,{String finish='stop'})=>http.Response.bytes(
  utf8.encode('data: ${jsonEncode({'choices':[{'delta':delta,'finish_reason':finish}]})}\n\ndata: [DONE]\n\n'),200,
  headers:{'content-type':'text/event-stream; charset=utf-8'});
Map<String,Object?> call(String name,Map<String,Object?> args)=>{'tool_calls':[{
  'index':0,'id':'call-$name','type':'function','function':{'name':name,'arguments':jsonEncode(args)}}]};

class _ReadGame extends CedarToyClient {
  _ReadGame() : super(token: 'ctai_v1_fixture');
  var reads = 0;
  @override Future<McpToolOutcome> play(String game, String action, Map<String, Object?> params,
      {GenerationCancellationToken? cancellationToken}) async {
    expect(game, 'bar'); expect(action, 'cmd'); expect(params['command'], 'status');
    reads++;
    return const McpToolOutcome(content: [], isError: false, structuredContent: {
      'slot': 4, 'balance': 0, 'inventory': [], 'next_actor': 'companion', 'participation_mode': 'solo'});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  test('ordinary and deep limits are shared by all entry paths',(){
    expect(AgentTaskLoopPolicy.roundLimit(false),20);expect(AgentTaskLoopPolicy.callLimit(false),40);
    expect(AgentTaskLoopPolicy.roundLimit(true),30);expect(AgentTaskLoopPolicy.callLimit(true),60);
    expect(AgentTaskLoopPolicy.allowedCalls(planningRounds:4,toolCalls:2),2);
    expect(AgentTaskLoopPolicy.allowedCalls(planningRounds:19,toolCalls:39),1);
    expect(AgentTaskLoopPolicy.allowedCalls(planningRounds:20,toolCalls:2),0);
  });
  test('only repeated evidence stalls; new results and negative evidence make progress',(){
    final tracker=AgentProgressTracker();
    AgentToolResult result(String text,AgentToolStatus status)=>AgentToolResult(toolId:'memory.search',status:status,
      displayText:'',promptData:text);
    final first=result('No result for A',AgentToolStatus.noResult);
    tracker.record([first]);tracker.record([first]);tracker.record([first]);expect(tracker.stalled,false);
    tracker.record([first]);expect(tracker.stalled,true);
    tracker.record([result('No result for B',AgentToolStatus.noResult)]);expect(tracker.stalled,false);
  });
  test('an unregistered task cannot promise an immediate half-hour trip',(){
    const goal=TurnTaskGoal(turnId:'u',slot:TurnEffectSlot.cedarTimedRegistration,description:'登记半小时',
      target:{'game_id':'bar'},minutes:30);
    for(final text in ['「这就出发，半小时后回来汇报！」','「我马上去玩，半个小时后告诉你。」']) {
      expect(OperationalClaimGroundingGuard.evaluate(text:text,taskGoals:[goal]).reason,'unregistered_timed_task_promise');
    }
    expect(OperationalClaimGroundingGuard.evaluate(text:'「还没登记好，暂时没有开始计时。」',taskGoals:[goal]).allowed,true);
    expect(OperationalClaimGroundingGuard.evaluate(text:'「等确认后再开始。」',taskGoals:[goal]).allowed,true);
    const ended=LocalEffectReceipt(turnId:'u',slot:TurnEffectSlot.cedarTimedRegistration,
      payloadHash:'fixture',state:LocalEffectState.committed,result:{'gameId':'bar','minutes':30,'activationState':'ended'},
      runToken:'old',createdAt:1);
    expect(OperationalClaimGroundingGuard.evaluate(text:'「这就出发，半小时后回来汇报！」',
      taskGoals:[goal],taskReceipts:[ended]).reason,'unregistered_timed_task_promise');
  });

  for (final second in [false, true]) {
    test('real runner without task semantics keeps cmd status read-only and first/final efforts separate: $second', () async {
      final files = await Directory.systemTemp.createTemp('read-only378-');
      final previous = PathProviderPlatform.instance; PathProviderPlatform.instance = _Paths(files.path);
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      const channel = MethodChannel('ai_companion/system');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      FlutterSecureStorage.setMockInitialValues({'deepseek_api_key': 'fixture', 'cedar_toy_token': 'ctai_v1_fixture',
        'chat_api_provider': second ? 'aiwangyou_gemini' : 'deepseek', 'aiwangyou_gemini_api_key': 'fixture-final',
        'aiwangyou_final_reply_endpoint': 'https://relay.invalid/v1/chat/completions'});
      var plans = 0, finals = 0;
      var missingWriteGoal = false;
      final game = _ReadGame();
      final client = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final names = [for (final t in body['tools'] as List? ?? []) ((t as Map)['function'] as Map)['name']];
        if (names.any((name) => name != 'agent_request')) {
          plans++;
          expect(body['reasoning_effort'], 'max');
          if (plans == 1) return reply(call('cedar_toy_play', {'game': 'bar', 'action': 'cmd',
            'params_json': '{"command":"status","slot":4}', 'participation_mode': 'solo'}), finish: 'tool_calls');
          return reply({'content': '只读状态已经核实。'});
        }
        if (body.containsKey('max_tokens')) return reply({'content': '{}'});
        finals++;
        if (second) {
          expect(request.url.host, 'relay.invalid');
          final google = (body['extra_body'] as Map)['google'] as Map;
          expect((google['thinking_config'] as Map)['thinking_level'], 'low');
          expect(body.containsKey('reasoning_effort'), false);
        } else {
          expect(body['reasoning_effort'], 'max');
        }
        missingWriteGoal = missingWriteGoal || jsonEncode(body['messages']).contains('本轮仍未获得执行证据的目标');
        return reply({'content': '「余额为零，背包是空的。」'});
      }), jsonClientFactory: () => MockClient((_) async => http.Response(
        jsonEncode({'choices': [{'message': {'content': '{}'}, 'finish_reason': 'stop'}]}), 200)));
      try {
        await db.setSettingsAtomically({'cedar_toy_enabled': '1', 'deepseek_reasoning_effort': 'max', 'reasoning_effort': 'low'});
        final activity = CedarToyActivityStore(db);
        await activity.saveCatalog('bar·酒馆经营，单人·fixture');
        await activity.recordGuide(gameId: 'bar', guide: '单人游戏，每游戏5槽，slot=1-5，cmd status查询，serve操作。');
        await db.tryAcquireLocalLease('chat_turn_lease');
        final job = await db.createGenerationTurn(user: ChatMessage(id: 'u', role: 'user',
          content: '检查酒馆存档4当前状态，只读不要操作', createdAt: DateTime.now()),
          assistantMessageId: 'a', model: 'fixture-first', reasoningEffort: 'high');
        final source = (await ConversationSourceStore.captureMessage(await db.database, 'u'))!;
        final key = '${source.contentHash}:${source.revision}';
        await db.setSettingsAtomically({'nsfw_route_turn_id': 'u', 'nsfw_route_source_key_v2': key,
          'cedar_route_intent_v1': 'act_now', 'cedar_route_certain_v1': '1',
          'route_tool_intent_v1': jsonEncode({'turn_id': 'u', 'source_key': key,
            'route': const SemanticToolRoute(available: true).toJson()}),
          'route_task_intent_v1': jsonEncode({'turn_id': 'u', 'source_key': key,
            'intent': const TurnTaskIntent(available: false).toJson()})});
        final result = await DurableGenerationRunner(db: db, client: client, cedarClientFactory: (_) => game,
          secureConfig: SecureConfig.forTesting(const FlutterSecureStorage())).run(job).timeout(const Duration(seconds: 30));
        expect(result.status, 'completed', reason: result.error?.toString());
        expect(game.reads, 1); expect(finals, 1); expect(missingWriteGoal, false);
        final contract = await db.getSetting('${TurnExecutionStore.goalPrefix}u') ?? '';
        expect(contract, isNot(contains('cedar.foreground_write')));
        expect((await activity.loadState()).completedPlayRounds, 0);
      } finally {
        client.close(); await db.releaseLocalLease('chat_turn_lease'); await db.closeForTesting();
        messenger.setMockMethodCallHandler(channel, null); PathProviderPlatform.instance = previous;
        await files.delete(recursive: true);
      }
    });
  }

  for(final second in [false,true]) {
    for(final scenario in ['seven_reads','reenter','stalled','changed','cancel']) {
      test('real ${second?'second':'first'} channel Agent completes $scenario beyond legacy limits',() async {
        final files=await Directory.systemTemp.createTemp('agent373-');
        final previous=PathProviderPlatform.instance;PathProviderPlatform.instance=_Paths(files.path);
        final db=await AppDatabase.createForTesting(databaseFactoryFfi);
        const channel=MethodChannel('ai_companion/system');
        final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel,(_)async=>null);
        FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'fixture',
          'chat_api_provider':second?'aiwangyou_gemini':'deepseek','aiwangyou_gemini_api_key':'fixture-final',
          'aiwangyou_final_reply_endpoint':'https://relay.invalid/v1/chat/completions','aiwangyou_final_reply_model':'fixture-final'});
        var finals=0,plans=0,systemPlans=0;final cancellation=GenerationCancellationToken();
        final memory=scenario=='seven_reads' || scenario=='reenter' || scenario=='cancel';
        final client=DeepSeekClient(streamClientFactory:()=>MockClient((request)async{
          final body=jsonDecode(request.body) as Map;
          final names=[for(final t in body['tools'] as List? ?? [])((t as Map)['function'] as Map)['name']];
          if(names.any((name)=>name!='agent_request')) {
            plans++;
            if(scenario=='cancel' && plans==4)cancellation.cancel();
            if(names.contains('system_self_read'))systemPlans++;
            if(scenario=='changed' && systemPlans==2) await db.setSetting('cedar_toy_enabled','0');
            if(memory && plans<=7) return reply(call('chat_history_read',{'source_id':'h$plans'}),finish:'tool_calls');
            if((!memory || scenario=='reenter' && !names.contains('chat_history_read')) && (scenario=='stalled' || systemPlans<=2))return reply(call('system_self_read',{'scope':'runtime'}),finish:'tool_calls');
            return reply({'content':'资料已经足够。'});
          }
          if(body.containsKey('max_tokens'))return reply({'content':'{}'});
          finals++;
          if(finals==1 || scenario=='reenter' && finals==2) return reply(call('agent_request',{
            'goal':finals==1?'核实几条原文':'再核实任务的真实运行状态','families':[finals==1 && memory?'memory':'system']}),finish:'tool_calls');
          return reply({'content':'「查清楚了，是这些记录。」'});
        }),jsonClientFactory:()=>MockClient((_)async=>http.Response(jsonEncode({'choices':[{'message':{'content':'{}'}}]}),200)));
        try {
          for(var i=1;i<=7;i++)await db.insertMessage(ChatMessage(id:'h$i',role:'user',content:'资料$i：编号K$i',createdAt:DateTime(2026,1,i)));
          await db.tryAcquireLocalLease('chat_turn_lease');
          final job=await db.createGenerationTurn(user:ChatMessage(id:'u',role:'user',content:'随便聊聊今天吧',createdAt:DateTime.now()),
            assistantMessageId:'a',model:'fixture-first',reasoningEffort:'high');
          final source=(await ConversationSourceStore.captureMessage(await db.database,'u'))!;
          final key='${source.contentHash}:${source.revision}';
          await db.setSetting('nsfw_route_turn_id','u');await db.setSetting('nsfw_route_source_key_v2',key);
          await db.setSetting('route_tool_intent_v1',jsonEncode({'turn_id':'u','source_key':key,'route':const SemanticToolRoute(available:true).toJson()}));
          await db.setSetting('route_task_intent_v1',jsonEncode({'turn_id':'u','source_key':key,'intent':const TurnTaskIntent(available:true).toJson()}));
          final result=await DurableGenerationRunner(db:db,client:client,secureConfig:SecureConfig.forTesting(const FlutterSecureStorage()))
            .run(job,cancellationToken:cancellation).timeout(const Duration(seconds:30));
          if(scenario=='cancel') {expect(result.status,'cancelled_by_user');expect(await db.messageById('a'),isNull);}
          else {
            expect(result.status,'completed',reason:result.error?.toString());
            expect(await db.messageById('a'),isNotNull);
            final outcomes=await db.recentAgentToolOutcomeRecords(limit:20);
            if(scenario=='seven_reads' || scenario=='reenter') {
              expect(outcomes.where((r)=>r.toolId=='chat_history.read'),hasLength(7));expect(plans,greaterThan(6));
            }
            if(scenario=='reenter') {expect(finals,3);expect(outcomes.where((r)=>r.toolId=='system_self.read'),hasLength(1));}
            if(scenario=='stalled') {expect(plans,4);expect(outcomes.where((r)=>r.toolId=='system_self.read'),hasLength(1));}
            if(scenario=='changed')expect(outcomes.where((r)=>r.toolId=='system_self.read'),hasLength(2));
          }
        } finally {
          cancellation.cancel();client.close();await db.releaseLocalLease('chat_turn_lease');await db.closeForTesting();
          messenger.setMockMethodCallHandler(channel,null);PathProviderPlatform.instance=previous;await files.delete(recursive:true);
        }
      });
    }
  }

  test('same-save start/resume ambiguity keeps permission; competing stop and target ambiguity remain blocked',() async {
    final db=await AppDatabase.createForTesting(databaseFactoryFfi);addTearDown(db.closeForTesting);
    final store=CedarToyActivityStore(db);final se=await store.recordGuide(gameId:'bar',guide:'单人，status查询，cmd操作');
    await store.pause();final state=await store.loadState();
    final q=TurnTaskQuestionSet(userText:'去玩半个小时吧',state:state,works:const []);
    final target=q.games.entries.firstWhere((e)=>e.value.id=='bar').key;
    final answers={'task_game':'play','task_game_target':target,'task_duration':'d0','task_creative':'none','cedar':'act_now'};
    final details={'task_game':const JevChoiceDecision(choice:'play',probabilities:{'play':.42,'resume':.39,'none':.16,'pause':.01,'pause_and_release':.01,'report':.01},ambiguous:true),
      'cedar':const JevChoiceDecision(choice:'act_now',probabilities:{'act_now':.65,'accept':.34,'chat':.01},ambiguous:false)};
    final intent=q.interpret(answers,details:details);expect(intent.gameExecutionResolved,true);expect(intent.minutes,30);
    expect(intent.sessionId,se.id);expect(intent.actionResolution,'same_target_play_resume');
    expect(TurnTaskIntent.fromJson(intent.toJson()).actionProbabilities,details['task_game']!.probabilities);
    final uncertain=q.interpret(answers,details:{...details,'task_game_target':JevChoiceDecision(choice:target,probabilities:{target:.51,'none':.49},ambiguous:true)});
    expect(uncertain.gameExecutionResolved,false);
    final stop=q.interpret(answers,details:{...details,'task_game':const JevChoiceDecision(choice:'play',probabilities:{'play':.4,'pause':.39,'resume':.2,'none':.01},ambiguous:true)});
    expect(stop.gameExecutionResolved,false);
    final diagnostic=await AgentRuntimeDiagnostic.read(db);expect(diagnostic['unknown_write_present'],false);
    final projection=CedarTaskPresentation.project(gameId:'bar',session:state.sessions['bar'],pending:null,active:null,clock:null,
      reports:const [],brainAllowed:true,chatBusy:false,now:DateTime.now(),diagnostic:{'terminal':true,'game_id':'bar','session_id':se.id,'used_ms':1800000});
    expect(projection!.historical,true);
  });
}
