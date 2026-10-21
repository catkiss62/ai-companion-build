import 'package:ai_companion_localfirst/core/history/conversation_history_reader.dart';
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
    final route=q.interpret({'tool_route':'room','tool_room_target':'r0','tool_room_view':'summary','tool_scope':'single'});
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
          answers[e.key as String]={'type':'choice','choice':selected,'confidence':1.0,'probabilities':{for(final k in keys)k:k==selected?1.0:0.0}};
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
  test('chat directory and multiple original pages reuse one existing JEV route decision',() async {
    final at=DateTime.now();
    await db.insertMessage(ChatMessage(id:'old-original',role:'user',
      content:List.filled(15000,'贝壳').join(),createdAt:at.subtract(const Duration(days:2))));
    await message('history-request',at);
    var calls=0;
    final gateway=JevDecisionGateway(enabledReader:()async=>true,keyReader:()async=>'test',
      clientFactory:()=>MockClient((request)async {
        calls++;
        final questions=(jsonDecode(request.body) as Map)['questions'] as Map;
        final answers=<String,Object?>{};
        for(final e in questions.entries) {
          final keys=((e.value as Map)['criteria'] as Map).keys.cast<String>().toList();
          final selected=switch(e.key){'tool_route'=>'memory','tool_scope'=>'multi',_=>keys.first};
          answers[e.key as String]={'type':'choice','choice':selected,'confidence':1.0,
            'probabilities':{for(final k in keys)k:k==selected?1.0:0.0}};
        }
        return http.Response(jsonEncode({'answers':answers}),200);
      }));
    final route=await NsfwContextRouter(db:db,client:DeepSeekClient(),jevGateway:gateway).decide(
      apiKey:'test',endpoint:'https://test.invalid/chat/completions',turnId:'history-request',
      latestUserText:'查一下以前贝壳那次的原话和具体细节',recent:const []);
    expect(route.toolRoute.kind,'memory');
    expect(route.toolRoute.toolIds,contains('chat_history.read'));
    final reader=ConversationHistoryReader(db);
    final found=await reader.search({'query':'贝壳'});
    Map data(AgentToolResult r)=>jsonDecode(r.promptData.substring(r.promptData.indexOf('{')).split('\n').first) as Map;
    var result=await reader.read({'handle':(data(found)['entries'] as List).first['handle'] as String});
    var pages=0;
    while((data(result)['next_cursor'] as String).isNotEmpty) {
      result=await reader.read({'cursor':data(result)['next_cursor'] as String});
      expect(result.status,AgentToolStatus.succeeded);
      expect(++pages,lessThan(10));
    }
    expect(pages,greaterThan(1));
    expect(calls,1);
  });
  test('existing source-bound task decision survives tool-route upgrade without a second classifier',()async{
    final at=DateTime.now();await message('old-task',at);
    final source=(await ConversationSourceStore.captureMessage(await db.database,'old-task'))!;
    final sourceKey='${source.contentHash}:${source.revision}';
    await db.setSetting('nsfw_route_turn_id','old-task');await db.setSetting('nsfw_route_source_key_v2',sourceKey);
    await db.setSetting('route_task_intent_v1',jsonEncode({'turn_id':'old-task','source_key':sourceKey,
      'intent':{'available':true,'game_action':'pause','game_id':'garden','session_id':'existing-session'}}));
    var calls=0;
    final gateway=JevDecisionGateway(enabledReader:()async{calls++;return false;});
    final result=await NsfwContextRouter(db:db,client:DeepSeekClient(),jevGateway:gateway).decide(
      apiKey:'test',endpoint:'https://test.invalid/chat/completions',turnId:'old-task',latestUserText:'先停一下',recent:const []);
    expect(result.taskIntent.gameAction,'pause');expect(result.taskIntent.gameId,'garden');expect(calls,0);
    expect(result.toolRoute.kind,'none');
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
  test('requeued unchanged representative evidence is not counted as a new dream vote',()async{
    final now=DateTime.now();await message('known',now.subtract(const Duration(hours:1)));
    final first=await DreamMaterial.collect(db,{},now,weekly:false);
    final source=first.sources.single;final sql=await db.database;
    await sql.update('messages',{'source_ingest_seq':(first.cursor['chat_seq'] as int)+1},where:'id = ?',whereArgs:['known']);
    final next=await DreamMaterial.collect(db,{'cursor':first.cursor,'insights':[{'evidence':[{'id':source.id,'fingerprint':source.fingerprint}]}]},now,weekly:false);
    expect(next.sources.where((s)=>s.fresh),isEmpty);
    expect(next.cursor['chat_seq'],greaterThan(first.cursor['chat_seq'] as int));
  });
  test('source sequence cannot reuse an already consumed creative material position',()async{
    await db.setSetting('creative_inspiration_v1',jsonEncode({'cursor':{'chat_seq':200}}));
    await message('after-restore',DateTime.now());
    final source=await ConversationSourceStore.captureMessage(await db.database,'after-restore');
    expect(source!.ingestSeq,greaterThan(200));
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
