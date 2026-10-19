import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/ai/nsfw_context_router.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/agent/semantic_tool_route.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/history/room_history_reader.dart';
import 'package:ai_companion_localfirst/core/memory/personality_learning_lifecycle.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_repository.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_models.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_archive_worker.dart';
import 'package:ai_companion_localfirst/core/self/dream_material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async { db = await AppDatabase.createForTesting(databaseFactoryFfi); });
  tearDown(() async { await db.closeForTesting(); });
  Future<void> message(String id, DateTime at) => db.insertMessage(ChatMessage(
    id:id,role:'user',content:'真实经历 $id',createdAt:at));
  Future<ModelDialogueRoom> room() async {
    final r = await ModelDialogueRepository(db).create(title:'讨论甲',topic:'真实话题',participants:const {});
    final m=ModelDialogueMessage(id:'turn',roomId:r.id,sequence:1,speaker:'deepseek',text:'已经保存的想法',model:'test',createdAt:10);
    await db.setSetting('${ModelDialogueRepository.messagePrefix}${r.id}:0000000001',jsonEncode(m.toJson()));
    return r;
  }
  test('semantic reference selects only supplied room, reads paused words without archiving',()async{
    final r=await room(); final q=await SemanticToolQuestions.load(db);
    final route=q.interpret({'tool_route':'room','tool_room_target':'r0','tool_room_view':'summary'});
    expect(route.roomId,r.id);expect(route.directPlan,isNotNull);
    final before=jsonEncode(await (await db.database).query('memory_items'));
    final result=await RoomHistoryReader(db).read(route.directPlan!.calls.single.arguments);
    expect(result.status,AgentToolStatus.succeeded);
    expect(result.promptData,contains('已经保存的想法'));expect(result.promptData,contains('尚未结束'));
    expect(result.promptData,contains('不是用户在聊天框粘贴'));
    expect((await ModelDialogueRepository(db).roomById(r.id))!.ended,false);
    expect(jsonEncode(await (await db.database).query('memory_items')),before);
  });
  test('natural room request uses the existing single JEV batch and caches its source-bound decision',()async{
    final r=await room();final at=DateTime.now();await message('request',at);
    var shortCalls=0;var fullCalls=0;
    final gateway=JevDecisionGateway(enabledReader:()async=>true,keyReader:()async=>'test',
      clientFactory:()=>MockClient((request)async{
        shortCalls++;final sent=jsonDecode(request.body) as Map;final questions=sent['questions'] as Map;
        expect(questions,contains('mode'));expect(questions,contains('tool_route'));
        final answers=<String,Object?>{};
        for(final e in questions.entries){
          final options=(e.value as Map)['criteria'];
          final keys=(options as Map).keys.cast<String>().toList();
          final selected=switch(e.key){'tool_route'=>'room','tool_room_target'=>'r0',_=>keys.first};
          answers[e.key as String]={'type':'choice','choice':selected,'probabilities':{for(final k in keys)k:k==selected?1.0:0.0}};
        }
        return http.Response(jsonEncode({'answers':answers}),200);
      }));
    final client=DeepSeekClient(streamClientFactory:()=>MockClient((_)async{fullCalls++;throw StateError('no full planner expected');}));
    final router=NsfwContextRouter(db:db,client:client,jevGateway:gateway);
    final args=ChatMessage(id:'request',role:'user',content:'结束了，你看看',createdAt:at);
    final first=await router.decide(apiKey:'test',endpoint:'https://test.invalid/chat/completions',turnId:'request',latestUserText:args.content,recent:[args]);
    expect(first.toolRoute.roomId,r.id);expect(shortCalls,1);expect(fullCalls,0);
    final replay=await router.decide(apiKey:'test',endpoint:'https://test.invalid/chat/completions',turnId:'request',latestUserText:args.content,recent:[args]);
    expect(replay.toolRoute.roomId,r.id);expect(shortCalls,1);
  });
  test('chat/ambiguous selection never reads a room simply because one exists',()async{
    await room();final q=await SemanticToolQuestions.load(db);
    expect(q.interpret({'tool_route':'none','tool_room_target':'r0'}).directPlan,isNull);
    expect(q.interpret({'tool_route':'room','tool_room_target':'invented'}).directPlan,isNull);
    expect(AgentToolPlanner.nativeToolDefinitionsFor('今天好累',semanticToolIds:const {}),isEmpty);
    expect(AgentToolPlanner.nativeToolDefinitionsFor('结束了你看看',semanticToolIds:const {'room_history.read'}),hasLength(1));
  });
  test('deleted semantic target is rejected instead of silently choosing a newer room',()async{
    final r=await room();await ModelDialogueRepository(db).delete(r.id);await room();
    expect((await RoomHistoryReader(db).read({'kind':'model_dialogue','room_id':r.id})).status,AgentToolStatus.noResult);
  });
  test('newly ingested earlier timestamp is collected after a sequence cursor',()async{
    final now=DateTime.now();await message('a',now.subtract(const Duration(hours:1)));
    final first=await DreamMaterial.collect(db,{},now,weekly:false);
    await message('rollback',now.subtract(const Duration(hours:2)));
    final second=await DreamMaterial.collect(db,{'cursor':first.cursor},now,weekly:false);
    expect(second.sources.where((s)=>s.fresh).map((s)=>s.id),contains('chat:rollback'));
    expect(second.sources.where((s)=>s.fresh).map((s)=>s.id),isNot(contains('chat:a')));
    final third=await DreamMaterial.collect(db,{'cursor':second.cursor},now,weekly:false);
    expect(third.sources.where((s)=>s.fresh),isEmpty);
  });
  test('legacy cursor migration preserves covered source and catches later rollback insert',()async{
    final now=DateTime.now();final at=now.subtract(const Duration(hours:1));await message('anchor',at);
    await message('later',at.subtract(const Duration(minutes:5)));
    final m=await DreamMaterial.collect(db,{'cursor':{'chat_at':at.millisecondsSinceEpoch,'chat_id':'anchor'}},now,weekly:false);
    expect(m.sources.where((s)=>s.fresh).map((s)=>s.id),contains('chat:later'));
    expect(m.sources.where((s)=>s.fresh).map((s)=>s.id),isNot(contains('chat:anchor')));
    expect(m.cursor['chat_seq'],greaterThan(0));
  });
  test('requeued eligibility source is revisited even though its event time is old',()async{
    final now=DateTime.now();await message('a',now.subtract(const Duration(hours:1)));
    final first=await DreamMaterial.collect(db,{},now,weekly:false);
    final sql=await db.database;await sql.update('messages',{'source_ingest_seq':(first.cursor['chat_seq'] as int)+1},where:'id = ?',whereArgs:['a']);
    final next=await DreamMaterial.collect(db,{'cursor':first.cursor},now,weekly:false);
    expect(next.sources.where((s)=>s.fresh).map((s)=>s.id),contains('chat:a'));
    final source=await ConversationSourceStore.captureMessage(sql,'a');expect(source!.observedAt.millisecondsSinceEpoch,now.subtract(const Duration(hours:1)).millisecondsSinceEpoch);
  });
  test('message quota feedback and ordinary thought action commit together',()async{
    final sql=await db.database;final now=DateTime.now();
    await sql.insert('thoughts',{'id':'t','text':'想分享','drive_key':'curiosity','kind':'flit','strength':.7,'born_at':now.millisecondsSinceEpoch,'updated_at':now.millisecondsSinceEpoch});
    final m=ChatMessage(id:'p',role:'assistant',content:'分享正文',createdAt:now,isProactive:true);
    expect(await db.commitProactiveMessageIfCurrent(message:m,evaluationStartedAt:now,
      proactiveTriggerReason:'test',actedThoughtId:'t',feedback:{'thought_id':'t'}),isNull);
    expect((await db.latestPendingProactiveFeedback())!.proactiveMessageId,'p');
    expect((await db.thoughtById('t'))!.actionCount,1);
    expect(await sql.query('thought_lifecycle_events',where:'message_id = ?',whereArgs:['p']),hasLength(1));
    expect(await sql.query('proactive_history',where:'message_id = ?',whereArgs:['p']),hasLength(1));
  });
  test('feedback failure rolls back message quota and action instead of leaving partial delivery',()async{
    final sql=await db.database;final now=DateTime.now();
    await sql.execute("CREATE TRIGGER refuse_feedback BEFORE INSERT ON proactive_feedback BEGIN SELECT RAISE(ABORT, 'test interruption'); END");
    await expectLater(db.commitProactiveMessageIfCurrent(message:ChatMessage(id:'fail',role:'assistant',content:'正文',createdAt:now,isProactive:true),
      evaluationStartedAt:now,proactiveTriggerReason:'test',feedback:const {}),throwsA(anything));
    expect(await sql.query('messages',where:'id = ?',whereArgs:['fail']),isEmpty);
    expect(await sql.query('proactive_history',where:'message_id = ?',whereArgs:['fail']),isEmpty);
  });
  test('mixed legacy and sequential evidence produces the same conservative result for every permutation',(){
    Map<String,Object?> e(String id,int seq,int at,String polarity)=>{'id':id,'observed_at':at,'polarity':polarity,'weight':1.0,'source_valid':1,
      'lifecycle_json':jsonEncode({'source_seq':seq,'resolves':<String>[]})};
    final a=e('a',1,300,'support'),b=e('b',2,100,'support'),c=e('c',0,200,'contradict');
    final results=[for(final rows in [[a,b,c],[a,c,b],[b,a,c],[b,c,a],[c,a,b],[c,b,a]]) jsonEncode(PersonalityLearningLifecycle.reduce(rows))];
    expect(results.toSet(),hasLength(1));expect(jsonDecode(results.first)['status'],'contradicted');
  });
  test('new sequence permission can resolve a newer sequence boundary despite time rollback',(){
    final result=PersonalityLearningLifecycle.reduce([
      {'id':'block','polarity':'contradict','weight':1.0,'observed_at':300,'source_valid':1,'lifecycle_json':jsonEncode({'source_seq':1})},
      {'id':'permit','polarity':'support','weight':1.0,'observed_at':100,'source_valid':1,'lifecycle_json':jsonEncode({'source_seq':2,'resolves':['block']})},
    ]);
    expect(result['status'],isNot('contradicted'));expect(result['support_count'],1);
  });
  test('archive scan advances beyond 64 backing-off jobs on its next bounded drain',()async{
    final r=await room();final at=DateTime.now();final endedAt=at.millisecondsSinceEpoch;
    await db.setSetting('${ModelDialogueRepository.roomPrefix}${r.id}',jsonEncode({...r.data,'status':'ended','ended_at':endedAt,'sequence':1,'memory_policy':2}));
    final prefix=ModelDialogueRepository.archivePrefix;
    for(var i=0;i<64;i++) await db.setSetting('$prefix!${i.toString().padLeft(3,'0')}',jsonEncode({'roomId':'unused','nextAttemptAt':endedAt+60000}));
    await db.setSetting('$prefix${r.id}',jsonEncode({'roomId':r.id,'endedAt':endedAt,'sequence':1,'attempts':0,'nextAttemptAt':0}));
    var calls=0;final worker=ModelDialogueArchiveWorker(db,generate:(room,messages,fence)async{calls++;return {
      'overview':'讨论了想法','deepseek_view':'已有想法','gemini_view':'','common_ground':'','open_questions':'','user_quotes':<String>[],'worth_remembering':false};});
    await worker.drainOne(now:at);expect(calls,0);
    await worker.drainOne(now:at);expect(calls,1);
    expect(await db.getSetting('$prefix${r.id}'),isNull);
  });
}
