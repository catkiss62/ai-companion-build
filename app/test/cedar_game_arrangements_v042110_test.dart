import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/memory_extractor.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_arrangements.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CedarGameArrangementStore store;
  late ChatMessage user, assistant;
  late DateTime origin;
  late CedarGameSession session;
  late CedarArrangementExtraction context;
  late Map<String,Object?> sources;

  Future<void> saveSession(CedarGameSession value, {String? active}) async {
    final state=CedarToyActivityState(activeGameId:active??value.gameId,
      sessions:{value.gameId:value},updatedAt:DateTime.now());
    await db.setSetting(CedarToyActivityStore.stateSettingKey,jsonEncode(state.toJson()));
  }
  CedarGameEvent event(String id,{int slot=1,bool success=true,bool failed=false,
      String action='cmd',DateTime? at,String command='plant daisy 3'}) => CedarGameEvent(
    id:id,kind:failed?'failure':'outcome',summary:jsonEncode({'ok':success,'message':'在盆3种下了雏菊'}),
    createdAt:at??DateTime.now(),action:action,inputJson:jsonEncode({'slot':slot,'command':command}));
  Future<MemoryItem> item() async => MemoryItem.fromDb((await (await db.database).query('memory_items',
    where:'source LIKE ?',whereArgs:['game_arrangement:%'],orderBy:'created_at DESC')).first);
  Map<String,Object?> proposal({String actor='ai',String operation='remember',String target='',String? scope}) => {
    'action':operation,'scope_id':scope??context.scopes.single.id,'topic_key':'daisy.planting',
    'text':'下次把雏菊种在盆3，实际种下后完成。','condition':'下次玩同一存档时',
    'actor':actor,'executor':'ai','target_id':target,
    'assistant_quote':actor=='user'?'':assistant.content,'user_quote':actor=='ai'?'':user.content};
  Future<int> apply(List<Object?> plans,{Object? local}) => store.applyExtraction(plans,
    localContext:local??context.toJson(),localTimeSources:sources,user:user,assistant:assistant);
  Future<CedarArrangementReviewBundle> review() async => store.captureReview(
    (await CedarToyActivityStore(db).loadState()).sessions[session.gameId]!);

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'test-only'});
    db=await AppDatabase.createForTesting(databaseFactoryFfi);store=CedarGameArrangementStore(db);
    for(final key in ['daily_continuity_enabled','memory_fading_enabled','memory_consolidation_enabled',
        'relationship_continuity_enabled','personality_learning_enabled','post_turn_queue_enabled'])await db.setSetting(key,'0');
    origin=DateTime.now().subtract(const Duration(hours:1));
    user=ChatMessage(id:'arr-user',role:'user',content:'你自己决定种哪里，下次去种吧。',createdAt:origin);
    assistant=ChatMessage(id:'arr-ai',role:'assistant',content:'好，下次我把雏菊种到盆3。',createdAt:origin.add(const Duration(seconds:1)));
    await db.insertMessage(user);await db.insertMessage(assistant);
    session=CedarGameSession.fromJson({'id':'garden-session','game_id':'garden_cat','game_title':'种花养猫',
      'guide':'每游戏5槽，slot=1-5，cmd buy plant water harvest','guide_complete':true,
      'mode':'solo','phase':'active','next_actor':'companion','updated_at':origin.millisecondsSinceEpoch,
      'events':[event('old-play',at:origin.subtract(const Duration(minutes:5))).toJson()]});
    await saveSession(session);
    final fence=(await db.captureBrainWorkFence(settingKeys:const ['conversation_context_reset_at','conversation_context_reset_count']))!;
    context=(await store.captureExtraction(fence,assistant.createdAt))!;
    final sql=await db.database;
    sources={'user':(await ConversationSourceStore.qualifyMessage(sql,user.id))!.toJson(),
      'assistant':(await ConversationSourceStore.qualifyMessage(sql,assistant.id))!.toJson()};
  });
  tearDown(() async => db.closeForTesting());

  test('real memory extraction carries the game scope in one existing request',() async {
    var calls=0;Map<String,dynamic>? sent;
    final client=DeepSeekClient(client:MockClient((request) async {
      calls++;sent=jsonDecode(request.body) as Map<String,dynamic>;
      return http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode({
        'game_arrangements':[proposal()], 'memories':[], 'threads':[], 'thoughts':[],
        'relationship_events':[], 'desire_pulses':{}})},'finish_reason':'stop'}]}),200,
        headers:{'content-type':'application/json; charset=utf-8'});
    }));
    try {
      await MemoryExtractor(db:db,client:client,desireEngine:DesireEngine(db)).extractFromTurn(user:user,assistant:assistant);
      expect(calls,1);
      expect(jsonEncode(sent!['messages']),contains(context.scopes.single.id));
      expect((await review()).items,hasLength(1));
    } finally {client.close();}
  });

  test('an imported archive retains game identity and memory source metadata',() async {
    expect(await apply([proposal()]),1);
    final before=await item();
    final archive=Map<String,dynamic>.from(await db.exportAll());
    await db.importAll(archive);
    expect((await item()).sourceContextJson,before.sourceContextJson);
    expect((await review()).items,hasLength(1));
  });

  test('AI own plan survives a full chat window and remains a normal deletable memory',() async {
    expect(await apply([proposal()]),1);
    for(var n=0;n<15;n++) await db.insertMessage(ChatMessage(id:'later-$n',role:'user',content:'今天的生活闲聊$n',createdAt:DateTime.now()));
    final bundle=await review();expect(bundle.items,hasLength(1));
    expect(bundle.prompt,contains('下次把雏菊种在盆3'));
    expect((await item()).factState,'ongoing');
    await (await db.database).delete('memory_items',where:'id = ?',whereArgs:[(await item()).id]);
    expect((await review()).items,isEmpty);
    expect(await apply([proposal()]),0,reason:'a replay must honor manual deletion');
    expect(await (await db.database).query('unfinished_threads'),isEmpty);
  });

  test('user and mutual arrangements require their actual source quotes',() async {
    final invalid=proposal(actor:'shared')..['user_quote']='用户没有说过这句话';
    expect(await apply([invalid]),0);
    expect(await apply([proposal(actor:'shared')]),1);
    expect((await item()).actorKey,'shared');
  });

  for(final invalid in ['scope','quote','role','completion']) {
    test('rejects $invalid supplied by an extraction response',() async {
      final p=proposal();
      if(invalid=='scope')p['scope_id']='a made up slot';
      if(invalid=='quote')p['assistant_quote']='我从未说过的计划';
      if(invalid=='role')p['actor']='external';
      if(invalid=='completion')p['action']='complete';
      expect(await apply([p]),0);expect(await (await db.database).query('memory_items'),isEmpty);
    });
  }

  test('ordinary chat and old source snapshots cannot become game authority after a reset',() async {
    await db.beginFreshConversationContext();
    expect(await apply([proposal()]),0);
  });

  test('edited and deleted source messages revoke later plan use',() async {
    expect(await apply([proposal()]),1);
    await (await db.database).update('messages',{'content':'改过的旧回复'},where:'id = ?',whereArgs:[assistant.id]);
    expect((await review()).items,isEmpty);
  });

  test('source object with genuine ID but invented text cannot authorize an arrangement',() async {
    assistant=assistant.copyWith(content:'伪造的新计划');
    expect(await apply([proposal()]),0);
  });

  test('another game or another slot does not receive this save arrangement',() async {
    expect(await apply([proposal()]),1);
    final otherSlot=session.copyWith(events:[...session.events,event('slot-two',slot:2)]);
    await saveSession(otherSlot);expect((await store.captureReview(otherSlot)).items,isEmpty);
    final otherGame=CedarGameSession.fromJson({...session.toJson(),'id':'pond-session','game_id':'fishing','game_title':'钓鱼'});
    await saveSession(otherGame);expect((await store.captureReview(otherGame)).items,isEmpty);
  });

  test('a real later result can settle the plan and an extraction replay cannot recreate it',() async {
    final p=proposal();expect(await apply([p]),1);
    session=session.copyWith(events:[...session.events,event('new-plant')]);await saveSession(session);
    final bundle=await review();
    expect(await store.completeReviewed(bundle,[{'id':bundle.items.single.id,'event_id':'new-plant'}]),1);
    expect((await item()).factState,'completed');
    expect((await review()).items,isEmpty);
    expect(await apply([p]),0);
    expect(await (await db.database).query('memory_items'),hasLength(1));
  });

  test('an operation before the spoken plan cannot count as its fulfillment',() async {
    expect(await apply([proposal()]),1);final bundle=await review();
    expect(await store.completeReviewed(bundle,[{'id':bundle.items.single.id,'event_id':'old-play'}]),0);
    expect((await item()).factState,'ongoing');
  });

  for(final kind in ['failed','business-failed','unknown','read-only']) {
    test('$kind result does not falsely complete the plan',() async {
      expect(await apply([proposal()]),1);
      final e=event('invalid-result',failed:kind=='failed',success:kind!='business-failed',action:kind=='read-only'?'status':'cmd');
      session=session.copyWith(events:[...session.events,e]);await saveSession(session);
      final bundle=await review();
      expect(await store.completeReviewed(bundle,[{'id':bundle.items.single.id,'event_id':kind=='unknown'?'missing-event':e.id}]),0);
    });
  }

  test('a requested user action cannot be completed by her own operation',() async {
    final p=proposal(actor:'user')..['executor']='user';expect(await apply([p]),1);
    session=session.copyWith(events:[...session.events,event('new-plant')]);await saveSession(session);
    final bundle=await review();
    expect(await store.completeReviewed(bundle,[{'id':bundle.items.single.id,'event_id':'new-plant'}]),0);
  });

  test('stop, slot change and changed memory invalidate an in-flight completion',() async {
    expect(await apply([proposal()]),1);
    session=session.copyWith(events:[...session.events,event('new-plant')]);await saveSession(session);
    final bundle=await review();
    await db.setSetting(CedarToyActivityStore.userControlRevisionKey,'new-stop');
    expect(await store.completeReviewed(bundle,[{'id':bundle.items.single.id,'event_id':'new-plant'}]),0);
    final fresh=await review();
    await (await db.database).update('memory_items',{'content':'已经改约的另一件事'},where:'id = ?',whereArgs:[fresh.items.single.id]);
    expect(await store.completeReviewed(fresh,[{'id':fresh.items.single.id,'event_id':'new-plant'}]),0);
  });

  test('cancellation needs a captured target and a new user quote for user-owned requirements',() async {
    expect(await apply([proposal(actor:'user')]),1);final old=await item();
    user=ChatMessage(id:'cancel-user',role:'user',content:'那朵不用留了，取消这个约定吧。',createdAt:origin.add(const Duration(minutes:2)));
    assistant=ChatMessage(id:'cancel-ai',role:'assistant',content:'好，这个约定取消。',createdAt:origin.add(const Duration(minutes:2,seconds:1)));
    await db.insertMessage(user);await db.insertMessage(assistant);
    final sql=await db.database;
    sources={'user':(await ConversationSourceStore.qualifyMessage(sql,user.id))!.toJson(),
      'assistant':(await ConversationSourceStore.qualifyMessage(sql,assistant.id))!.toJson()};
    final fence=(await db.captureBrainWorkFence())!;
    context=(await store.captureExtraction(fence,assistant.createdAt))!;
    expect(await apply([proposal(operation:'cancel',target:old.id)]),0);
    expect(await apply([proposal(actor:'user',operation:'cancel',target:old.id)]),1);
    expect((await item()).factState,'cancelled');expect((await review()).items,isEmpty);
  });

  test('new-save epochs persist through serialization and prevent old save arrangements applying',() async {
    expect(await apply([proposal()]),1);
    final activity=CedarToyActivityStore(db);
    final next=await activity.recordPlay(gameId:'garden_cat',action:'new',submittedParams:const {'slot':1,'confirm':true},
      outcome:McpToolOutcome(content:const [],isError:false,structuredContent:const {'ok':true,'message':'new garden'}),
      mode:CedarParticipationMode.solo,nextActor:'companion',shareLevel:'none',invitationApproved:false);
    expect(next.arrangementSaveEpochs['1'],isNotNull);
    expect(CedarGameSession.fromJson(next.toJson()).arrangementSaveEpochs,next.arrangementSaveEpochs);
    expect((await store.captureReview(next)).items,isEmpty);
  });
  test('MCP business failure does not create a new save epoch or completion evidence',() async {
    expect(await apply([proposal()]),1);
    final activity=CedarToyActivityStore(db);
    final failed=await activity.recordPlay(gameId:'garden_cat',action:'new',submittedParams:const {'slot':1},
      outcome:McpToolOutcome(content:const [],isError:false,structuredContent:const {'ok':false,'error':'save exists'}),
      mode:CedarParticipationMode.solo,nextActor:'companion',shareLevel:'none',invitationApproved:false);
    expect(failed.arrangementSaveEpochs,isEmpty);
    expect(CedarGameArrangementStore.successfulReceipt(failed.events.last),isFalse);
    expect((await store.captureReview(failed)).items,hasLength(1));
  });

}
