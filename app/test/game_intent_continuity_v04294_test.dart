import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/desire/daily_wake_store.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_solo_episode_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_outcome_bookkeeper.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_http_client.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_live_share_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_conversation_context.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/wishes/companion_wish.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_engine.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_store.dart';
import 'package:ai_companion_localfirst/core/wishes/wish_game_evidence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.setSetting('active_brain','1');
    await db.setSetting('transfer_lock','0');
  });
  tearDown(() => db.closeForTesting());

  Future<void> oldThought() => db.upsertThought(id:'old', text:'那个问题还没有讨论过',
      drive:DriveKey.curiosity,kind:'fixation',strength:.95,fedCount:40,
      source:'self_drive/thread',lifecycleState:'fixation',topicKey:'game:room');
  Future<void> evidence(String id,String text,String continuity) async {
    await db.applyPostTurnThoughtEvidenceAtomic(sourceMessageId:id,
      evidenceKey:'1|curiosity|game:room|$text',text:text,drive:DriveKey.curiosity,
      incomingStrength:.35,topicKey:'game:room',continuity:continuity);
  }
  test('new understanding replaces stale unanswered text without inheriting fixation', () async {
    await oldThought();
    await evidence('answer','已经理解了，想看看新的房间','revised');
    var thought = (await db.thoughtById('old'))!;
    expect(thought.text,'已经理解了，想看看新的房间');
    expect(thought.fedCount,1);
    expect(thought.lifecycleState,'active');
    expect(thought.kind,'flit');
    expect(thought.strength,.35);
    await evidence('answer','已经理解了，想看看新的房间','revised');
    expect((await db.thoughtById('old'))!.fedCount,1);
    await evidence('new','新房间的同一个问题有了新线索','continued');
    expect((await db.thoughtById('old'))!.fedCount,2);
    await evidence('solved','这个问题已经得到回答','resolved');
    thought = (await db.thoughtById('old'))!;
    expect(thought.text,'这个问题已经得到回答');
    expect(thought.lifecycleState,'dormant');
    expect(thought.strength,lessThan(.1));
  });
  test('legacy descriptions use committed evidence once without deleting the memory', () async {
    await oldThought();
    final handle=await db.database;
    await handle.insert('thought_lifecycle_events', {'id':'ev','thought_id':'old',
      'event_type':'post_turn_evidence','detail':'1|curiosity|game:room|答案已经聊过，我期待新变化',
      'message_id':'answer','created_at':DateTime.now().millisecondsSinceEpoch});
    await db.refreshLegacyThoughtDescriptions();
    expect((await db.thoughtById('old'))!.text,'答案已经聊过，我期待新变化');
    expect((await db.thoughtById('old'))!.fedCount,1);
    await evidence('later','新的想法','revised');
    await db.refreshLegacyThoughtDescriptions();
    expect((await db.thoughtById('old'))!.text,'新的想法');
  });
  test('read-only transferred device cannot repair records', () async {
    await oldThought(); await db.setSetting('transfer_lock','1');
    await db.refreshLegacyThoughtDescriptions();
    expect((await db.thoughtById('old'))!.fedCount,40);
    expect(await db.getSetting('thought_description_repaired_v338'),isNull);
  });
  test('background gets recent assistant intentions as speech, not completed actions', () {
    final now=DateTime.now();
    final context=CedarConversationContext.format([
      ChatMessage(id:'a',role:'assistant',content:'这次先只输入一个问号',createdAt:now),
      ChatMessage(id:'u',role:'user',content:'去试试吧',createdAt:now),
      ChatMessage(id:'old',role:'user',content:'旧指令',createdAt:now.subtract(const Duration(days:2))),
      ChatMessage(id:'future',role:'assistant',content:'未来的话',createdAt:now.add(const Duration(days:1))),
    ],now);
    expect(context,contains('这次先只输入一个问号'));
    expect(context,contains('不是游戏执行证据'));
    expect(context,isNot(contains('旧指令')));
    expect(context,isNot(contains('未来的话')));
  });
  test('game receipt input survives log rotation, failed fenced write cannot pin evidence', () async {
    final store=CedarToyActivityStore(db);
    final now=DateTime.now();
    final wish=CompanionWish(id:'wish',goal:'想只输入问号看看反应',reason:'好奇',
      route:'game',criterion:'输入问号并取得真实回应',gameId:'room',
      completionKind:'game_result',createdAt:now.subtract(const Duration(minutes:1)),updatedAt:now);
    await db.setSetting(WishStore.stateKey,jsonEncode({'items':[wish.toJson()]}));
    await store.recordGuide(gameId:'room',guide:'cmd: command');
    Future<CedarGameSession> play(String command,{String fence=''}) => store.recordPlay(
      gameId:'room',action:'cmd',submittedParams:{'command':command},
      outcome:McpToolOutcome(isError:false,content:[McpContentBlock(kind:McpContentKind.text,text:'返回:$command')]),
      mode:CedarParticipationMode.solo,nextActor:'companion',shareLevel:'quiet',invitationApproved:false,
      executionId:fence);
    final first=await play('?');
    expect(first.events.last.inputJson,contains('?'));
    expect(CedarGameEvent.fromJson(first.events.last.toJson()).inputJson,contains('?'));
    for(var i=0;i<32;i++) { await play('后续$i'); }
    final gathered=await WishEngine(db).collect(DateTime.now(),wishes:[wish]);
    final receipt=gathered.singleWhere((e)=>e.id.endsWith(first.events.last.id));
    expect(receipt.text,contains('"command":"?"'));
    expect(receipt.text,contains('返回:?'));
    final before=await db.getSetting(WishGameEvidence.key);
    await expectLater(play('不应保存',fence:'stale-fence'),throwsA(isA<CedarExecutionPreemptedException>()));
    expect(await db.getSetting(WishGameEvidence.key),before);
    expect(WishGameEvidence.decode(before!).length,lessThanOrEqualTo(24));
    final decisions=<Map<String,Object?>>[];
    final reviewed=WishPolicy.apply(wishes:[wish],payload:{'updates':[{
      'id':'wish','state':'completed','evidence_id':receipt.id,'quote':'返回:?',
      'same_target':true,'observed':true,'confidence':.95}]},evidence:gathered,
      catalogIds:{'room'},now:DateTime.now(),canGenerate:false,decisions:decisions);
    expect(reviewed.single.state,'completed');
  });
  test('share judgement sees actual prior messages and preserves round gate', () async {
    final store=CedarToyActivityStore(db);
    await store.recordGuide(gameId:'garden',guide:'grow');
    await db.insertMessage(ChatMessage(id:'cedar-share:old',role:'assistant',content:'已经分享过收花',createdAt:DateTime.now()));
    final policy=CedarLiveSharePolicy(db);
    final context=await policy.planningContext((await store.load())!,DateTime.now());
    expect(context,contains('已经分享过收花'));
    expect(context,contains('普通重复'));
    expect(context,contains('"interval_elapsed":false'));
    await policy.offer((await store.load())!,share:true,now:DateTime.now());
    expect(await store.pendingDirectShares(),isEmpty);
  });

  for (final choice in ['bar', 'rest']) {
    test('solo checkpoint may $choice while preserving the previous game', () async {
      final store=CedarToyActivityStore(db);
      final now=DateTime.now();
      await db.setSetting('cedar_toy_enabled','1');
      await db.setSetting(CedarToyAutonomyEngine.enabledKey,'1');
      await store.saveCatalog('garden·花园·author\nbar·酒馆·author');
      await store.recordGuide(gameId:'garden',guide:'solo grow');
      await store.recordPlay(gameId:'garden',action:'grow',
        outcome:McpToolOutcome(isError:false,content:const [McpContentBlock(kind:McpContentKind.text,text:'种子已经种下')]),
        mode:CedarParticipationMode.solo,nextActor:'companion',shareLevel:'quiet',invitationApproved:false);
      await CedarPlayOutcomeBookkeeper(db).saveSoloEpisode(CedarSoloEpisodeState(
        gameId:'garden',startedAt:now,stateChangeCount:3,checkpointPending:true,checkpointReason:'state_change_limit'));
      final wish=CompanionWish(id:'bar-wish',goal:'去酒馆看看',reason:'好奇',route:'game',
        criterion:'取得真实回执',gameId:'bar',completionKind:'game_result',createdAt:now,updatedAt:now);
      await db.setSetting(WishStore.stateKey,jsonEncode({'items':[wish.toJson()]}));
      var decisions=0;
      final ai=DeepSeekClient(jsonClientFactory:()=>MockClient((request) async {
        decisions++;
        expect(request.body,contains('不要求完成愿望'));
        return http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode({'choice':choice})}}]}),200);
      }));
      addTearDown(ai.close);
      final toolNames=<String>[];
      final transport=MockClient((request) async {
        final body=jsonDecode(request.body) as Map;
        if(body['method']=='notifications/initialized') return http.Response('{}',202);
        if(body['method']=='tools/call') toolNames.add(body['params']['name'] as String);
        return http.Response(jsonEncode({'jsonrpc':'2.0','id':body['id'],'result':
          body['method']=='initialize' ? {} : {'content':[{'type':'text','text':'单人酒馆。actions: start order。'}],'isError':false}}),200,
          headers:{'content-type':'application/json; charset=utf-8'});
      });
      final engine=CedarToyAutonomyEngine(db:db,ai:ai,secureConfig:SecureConfig.instance,
        tokenReader:() async=>'ctai_v1_test',apiKeyReader:() async=>'test',
        endpointReader:() async=>DeepSeekClient.defaultEndpoint,
        clientFactory:(token)=>CedarToyClient(token:token,transport:McpHttpClient(endpoint:Uri.parse('https://example.invalid/mcp'),client:transport)));
      final progress=await engine.resumeCheckpoint(now:now,selfReset:false);
      if((await DailyWakeStore.read(await db.database,DateTime.now())).beforeWake(DateTime.now())) {
        expect(progress.state,'night_sleep'); expect(decisions,0); expect(toolNames,isEmpty); return;
      }
      expect(decisions,1);
      final state=await store.loadState();
      expect(state.sessions['garden']!.lastOutcome,contains('种子已经种下'));
      expect((await WishStore(db).load()).single.actionAttemptAt,isNull);
      if(choice=='bar') {
        expect(progress.state,'wish_checkpoint_switched');
        expect(state.activeSession!.gameId,'bar');
        expect(state.activeSession!.phase,CedarActivityPhase.guideReady);
        expect(toolNames,hasLength(1)); // Guide only: no start/reset or wish completion.
        expect((await WishStore(db).load()).single.state,'active');
      } else {
        expect(progress.state,'wish_checkpoint_rest');
        expect(state.activeSession!.gameId,'garden');
        expect(state.activeSession!.nextActionAt!.isAfter(now),isTrue);
        expect(toolNames,isEmpty);
      }
    });
  }
}
