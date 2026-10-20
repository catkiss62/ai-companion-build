import 'dart:convert';
import 'dart:io';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_runner.dart';
import 'package:ai_companion_localfirst/core/agent/semantic_tool_route.dart';
import 'package:ai_companion_localfirst/core/agent/turn_task_intent.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/durable_generation_runner.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/history/room_history_reader.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_session_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_models.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_repository.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
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
http.Response _response(Map<String,Object?> delta,{String finish='stop'}) =>
  http.Response.bytes(utf8.encode('data: ${jsonEncode({'choices':[{'delta':delta,'finish_reason':finish}]})}\n\ndata: [DONE]\n\n'),200,
    headers:{'content-type':'text/event-stream; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {db=await AppDatabase.createForTesting(databaseFactoryFfi);});
  tearDown(() async {await db.closeForTesting();});
  Future<ModelDialogueRoom> room(String name,int at,{bool ended=false}) async {
    final repo=ModelDialogueRepository(db);
    final r=await repo.create(title:name,topic:name,participants:const {});
    final m=ModelDialogueMessage(id:'m-${r.id}',roomId:r.id,sequence:1,speaker:'deepseek',
      text:'$name 的已保存原文',model:'fixture',createdAt:at);
    await db.setSetting('${ModelDialogueRepository.messagePrefix}${r.id}:0000000001',jsonEncode(m.toJson()));
    if(ended)await repo.end(r.id);
    return (await repo.roomById(r.id))!;
  }
  test('all former neutral fallbacks retain high A over low C, with separate uncertainty',()async{
    final specs=<String,Map<String,double>>{
      'game_attitude':{'encourage':.47,'pause':.45,'none':.08},
      'task_game':{'pause':.47,'pause_and_release':.45,'none':.08},
      'task_creative':{'commission':.47,'stop':.45,'none':.08},
      'task_game_target':{'g0':.47,'g1':.45,'none':.08},
      'task_work_target':{'w0':.47,'w1':.45,'unresolved':.08},
      'task_duration':{'d0':.47,'d1':.45,'none':.08},
    };
    var requests=0; final details=<String,JevChoiceDecision>{};
    final gateway=JevDecisionGateway(enabledReader:()async=>true,keyReader:()async=>'fixture',
      clientFactory:()=>MockClient((_)async{requests++;return http.Response(jsonEncode({'answers':{
        for(final e in specs.entries)e.key:{'type':'choice','choice':e.value.keys.last,
          'confidence':.2,'probabilities':e.value}}}),200);}));
    final result=await gateway.chooseMany(state:'fixture',usageLane:'chat_intimacy_route',
      questions:{for(final e in specs.entries)e.key:JevChoiceQuestion('fixture',{
        for(final k in e.value.keys)k:k})},decisionDetails:details);
    expect(requests,1);
    for(final e in specs.entries){
      expect(result?[e.key],e.value.keys.first);expect(details[e.key]!.choice,e.value.keys.first);
      expect(details[e.key]!.ambiguous,true);expect(details[e.key]!.probabilities,e.value);
    }
  });
  test('semantic groups combine equivalent authorization but never fabricate chat',(){
    const p={'act_now':.25,'accept':.26,'defer':.49,'chat':0.0};
    expect(JevDecisionGateway.resolveCedarGroup('chat_intimacy_route','cedar',p),'accept');
    expect(JevDecisionGateway.ambiguousChoice('chat_intimacy_route','cedar',p),true);
    const shared={'act_now':.47,'accept':.45,'defer':.04,'chat':.04};
    expect(JevDecisionGateway.ambiguousChoice('chat_intimacy_route','cedar',shared),false);
    expect(JevDecisionGateway.ambiguousChoice('chat_intimacy_route','tool_room_target',{'r0':.47,'r1':.45,'none':.08}),true);
    expect(JevDecisionGateway.ambiguousChoice('x','y',{'yes':.2}),true);
    expect(JevDecisionGateway.ambiguousChoice('x','y',{'yes':.9}),false);
  });
  test('uncertain task retains its intent while write admission is deferred',()async{
    final state=await CedarToyActivityStore(db).loadState();
    final q=TurnTaskQuestionSet(userText:'暂停一下',state:state,works:const []);
    final intent=q.interpret({'task_game':'pause','task_creative':'none'},details:{
      'task_game':const JevChoiceDecision(choice:'pause',probabilities:{'pause':.47,'resume':.45,'none':.08},ambiguous:true)});
    expect(intent.gameAction,'pause');expect(intent.available,true);
    expect(intent.gameExecutionResolved,false);expect(intent.goals('u').single.authorized,false);
    expect(TurnTaskIntent.fromJson(intent.toJson()).unresolvedFields,{'task_game'});
    final outcomes=await AgentToolRunner(db:db,android:AndroidBridge.instance).runPlan(AgentToolPlan(calls:[AgentToolCall(
      toolId:'cedar_toy.manage_activity',arguments:const {'operation':'pause'},reasonTag:'explicit_request')]),
      userMessageId:'u',deferredToolIds:intent.deferredToolIds);
    expect(outcomes.single.status,AgentToolStatus.blocked);
    expect(outcomes.single.errorCode,'registry_blocked');
    expect(outcomes.single.promptData,contains('仍有歧义'));
    expect(await CedarToyActivityStore(db).load(),isNull);
    await db.setSetting('nsfw_route_turn_id','u');
    await db.setSetting('cedar_game_attitude_route_signal','encourage');
    await db.setSetting('cedar_game_attitude_certain_v1','0');
    await CedarGameAttitudeStore(db).commit(turnId:'u',now:DateTime.now());
    expect(await CedarGameAttitudeStore(db).load(),isNull);
  });
  test('irrelevant target uncertainty cannot turn ordinary chat into a task',()async{
    final q=TurnTaskQuestionSet(userText:'今天好累',state:await CedarToyActivityStore(db).loadState(),works:const []);
    final intent=q.interpret({'task_game':'none','task_creative':'none'},details:{
      'task_game_target':const JevChoiceDecision(choice:'g0',probabilities:{'g0':.47,'g1':.45,'none':.08},ambiguous:true),
      'task_work_target':const JevChoiceDecision(choice:'w0',probabilities:{'w0':.47,'w1':.45,'unresolved':.08},ambiguous:true)});
    expect(intent.unresolvedFields,isEmpty);expect(intent.deferredToolIds,isEmpty);
    expect(intent.goals('u'),isEmpty);
    expect(const SemanticToolRoute(available:true).planningContext,isEmpty);
  });
  test('near room targets discover first, semantic no cannot fall through to latest',()async{
    final a=await room('甲',DateTime.now().millisecondsSinceEpoch);
    await room('乙',DateTime.now().millisecondsSinceEpoch);
    final q=await SemanticToolQuestions.load(db);
    final r=q.interpret({'tool_route':'room','tool_room_target':'r0','tool_scope':'single'},details:{
      'tool_room_target':const JevChoiceDecision(choice:'r0',probabilities:{'r0':.47,'r1':.45,'none':.08},ambiguous:true)});
    expect(r.kind,'room');expect(r.roomId,isEmpty);expect(r.directPlan,isNull);
    final plan=AgentToolPlanner.routeForTurn('昨天模型对谈说了什么？',r)!;
    expect(plan.calls.single.toolId,'room_history.search');
    final no=q.interpret({'tool_route':'none','tool_room_target':'r0'});
    expect(AgentToolPlanner.routeForTurn('昨天模型对谈说了什么？',no),isNull);
    expect(AgentToolPlanner.nativeToolDefinitionsFor('昨天模型对谈说了什么？',
      semanticReadAuthoritative:no.available,semanticToolIds:no.toolIds),isEmpty);
    final blocked=await RoomHistoryReader(db).read({'kind':'model_dialogue','require_target':'1'});
    expect(blocked.status,AgentToolStatus.noResult);
    final explicit=await RoomHistoryReader(db).read({'kind':'model_dialogue','require_target':'1','room_id':a.id});
    expect(explicit.status,AgentToolStatus.succeeded);
  });
  test('relative dates use actual utterances, including rooms outside recent candidates',()async{
    final now=DateTime(2026,10,20,17,30);
    final old=await room('昨日那一场',DateTime(2026,10,19,14).millisecondsSinceEpoch,ended:true);
    // A rename/closure today cannot turn yesterday's utterance into today's.
    await db.setSetting('${ModelDialogueRepository.roomPrefix}${old.id}',jsonEncode({...old.data,
      'updated_at':DateTime(2026,10,19,14).millisecondsSinceEpoch}));
    for(var i=0;i<7;i++)await room('今日$i',DateTime(2026,10,20,12,i).millisecondsSinceEpoch,ended:true);
    final gap=await room('跨日但昨日无发言',DateTime(2026,10,18,14).millisecondsSinceEpoch,ended:true);
    await db.setSetting('${ModelDialogueRepository.messagePrefix}${gap.id}:0000000002',jsonEncode(
      ModelDialogueMessage(id:'gap-today',roomId:gap.id,sequence:2,speaker:'gemini',text:'今天继续',model:'fixture',
        createdAt:DateTime(2026,10,20,14).millisecondsSinceEpoch).toJson()));
    final q=await SemanticToolQuestions.load(db,now:now);
    expect(q.context['current_local_time'],contains('2026-10-20'));
    expect(q.rooms.values.any((r)=>r['id']==old.id),false);
    final route=q.interpret({'tool_route':'room','tool_room_target':'none','tool_scope':'single','tool_room_period':'yesterday'});
    expect(DateTime.parse(route.dateFrom).millisecondsSinceEpoch,DateTime(2026,10,19).millisecondsSinceEpoch);
    final result=await RoomHistoryReader(db).search(route.discoveryPlan!.calls.single.arguments);
    expect(result.status,AgentToolStatus.succeeded);expect(result.resultCount,1);
    expect(result.promptData,contains('昨日那一场'));expect(result.promptData,isNot(contains('今日0')));
    expect(result.promptData,isNot(contains('跨日但昨日无发言')));
    expect(result.promptData,contains('2026-10-19'));
    final wrong=q.interpret({'tool_route':'room','tool_room_target':'r0','tool_scope':'single','tool_room_period':'yesterday'});
    expect(wrong.directPlan,isNull);expect(wrong.targetUncertain,true);
    final invalid=await RoomHistoryReader(db).search({'date_from':'not-a-date'});
    expect(invalid.status,AgentToolStatus.noResult);
  });
  test('only an explicit single completed summary may finish without planning',(){
    const multi=SemanticToolRoute(kind:'room',available:true,roomId:'a',roomKind:'model_dialogue');
    const single=SemanticToolRoute(kind:'room',available:true,roomId:'a',roomKind:'model_dialogue',singleRead:true);
    expect(multi.canFinishAfterSummary(succeeded:true,otherGoalsPending:false),false);
    expect(single.canFinishAfterSummary(succeeded:true,otherGoalsPending:true),false);
    expect(single.canFinishAfterSummary(succeeded:true,otherGoalsPending:false),true);
    expect(multi.toolIds,containsAll({'room_history.read','public_web.search'}));
    final old=SemanticToolRoute.decode({'kind':'room','room_id':'a','room_kind':'model_dialogue','view':'summary'});
    expect(old.available,true);expect(old.singleRead,false);expect(old.roomId,'a');
  });

  for(final scenario in ['multi','long_multi','single','no_tool','ambiguous']) {
    test('real runner preserves semantic routing and remaining reads: $scenario',()async{
      final files=await Directory.systemTemp.createTemp('semantic-runner-');
      final oldPaths=PathProviderPlatform.instance;PathProviderPlatform.instance=_Paths(files.path);
      const channel=MethodChannel('ai_companion/system');
      final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel,(_)async=>null);
      FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'fixture','chat_api_provider':'deepseek'});
      final secure=SecureConfig.forTesting(const FlutterSecureStorage());
      final token=GenerationCancellationToken();var planning=0;
      final a=await room('甲讨论',DateTime.now().millisecondsSinceEpoch);
      final b=await room('乙讨论',DateTime.now().millisecondsSinceEpoch);
      final route=scenario=='long_multi' ? const SemanticToolRoute(kind:'mixed',available:true,multiStep:true)
        : scenario=='no_tool' ? const SemanticToolRoute(available:true)
        : scenario=='ambiguous' ? const SemanticToolRoute(kind:'room',available:true,targetUncertain:true,singleRead:true)
        : SemanticToolRoute(kind:'room',available:true,roomId:a.id,roomKind:'model_dialogue',singleRead:scenario=='single');
      final client=DeepSeekClient(streamClientFactory:()=>MockClient((request)async{
        final body=jsonDecode(request.body) as Map;
        if(scenario=='no_tool')expect(jsonEncode(body['messages']),isNot(contains('【本轮工具需求】')));
        if((body['tools'] as List?)?.isNotEmpty==true){
          planning++;
          if(scenario=='long_multi' && planning<=4) {
            final search=planning==1||planning==3;
            return _response({'tool_calls':[{'index':0,'id':'step-$planning','type':'function',
              'function':{'name':search?'room_history_search':'room_history_read',
                'arguments':jsonEncode(search?{'kind':'model_dialogue','query':planning==1?'甲讨论':'乙讨论'}
                  :{'kind':'model_dialogue','room_id':planning==2?a.id:b.id,'view':'summary'})}}]},finish:'tool_calls');
          }
          if(scenario=='multi' || scenario=='long_multi') {
            expect(jsonEncode(body['messages']),contains('甲讨论 的已保存原文'));
            if(scenario=='multi' && planning==1)return _response({'tool_calls':[{'index':0,'id':'read-$planning','type':'function',
              'function':{'name':'room_history_read','arguments':jsonEncode({'kind':'model_dialogue','room_id':b.id,'view':'summary'})}}]},finish:'tool_calls');
            expect(jsonEncode(body['messages']),contains('甲讨论 的已保存原文'));
            expect(jsonEncode(body['messages']),contains('乙讨论 的已保存原文'));
          } else if(scenario=='ambiguous') {
            expect(jsonEncode(body['messages']),contains('房间记录目录'));
          } else {fail('$scenario must not open a planner');}
        }
        return _response({'content':'这次的回复。'});
      }));
      try {
        await db.tryAcquireLocalLease('chat_turn_lease');
        final job=await db.createGenerationTurn(user:ChatMessage(id:'user',role:'user',
          content:scenario=='multi'||scenario=='long_multi'?'比较甲讨论和乙讨论，再给我看法':'昨天模型对谈说了什么？',createdAt:DateTime.now()),
          assistantMessageId:'reply',model:'deepseek-flash',reasoningEffort:'high');
        final source=(await ConversationSourceStore.captureMessage(await db.database,'user'))!;
        final key='${source.contentHash}:${source.revision}';
        await db.setSetting('nsfw_route_turn_id','user');await db.setSetting('nsfw_route_source_key_v2',key);
        await db.setSetting('route_tool_intent_v1',jsonEncode({'turn_id':'user','source_key':key,'route':route.toJson()}));
        final result=await DurableGenerationRunner(db:db,client:client,secureConfig:secure).run(job,cancellationToken:token)
          .timeout(const Duration(seconds:20));
        expect(result.status,'completed',reason:result.error?.toString());
        expect(planning,scenario=='long_multi'?5:scenario=='multi'?2:scenario=='ambiguous'?1:0);
        final records=await db.recentAgentToolOutcomeRecords(limit:20);
        final reads=records.where((r)=>r.toolId=='room_history.read').toList();
        expect(reads,hasLength(scenario=='multi'||scenario=='long_multi'?2:scenario=='single'?1:0));
        if(scenario=='ambiguous')expect(records.any((r)=>r.toolId=='room_history.search'),true);
        expect(await db.messageById('reply'),isNotNull);
      } finally {
        token.cancel();client.close();await db.releaseLocalLease('chat_turn_lease');
        await Future<void>.delayed(const Duration(milliseconds:100));
        messenger.setMockMethodCallHandler(channel,null);PathProviderPlatform.instance=oldPaths;
        await files.delete(recursive:true);
      }
    });
  }
}
