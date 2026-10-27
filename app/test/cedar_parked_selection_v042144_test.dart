import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';

class _Game extends CedarToyClient {
  _Game():super(token:'ctai_v1_synthetic');
  int lists=0,plays=0;final guides=<String>[];
  @override Future<McpToolOutcome> listGames({GenerationCancellationToken? cancellationToken})async {
    lists++;return const McpToolOutcome(isError:false,content:[McpContentBlock(kind:McpContentKind.text,
      text:'garden_cat·种花养猫·合成目录\nfishing·钓鱼收集·合成目录')]);
  }
  @override Future<McpToolOutcome> getGuide(String game,{GenerationCancellationToken? cancellationToken})async {
    guides.add(game);return const McpToolOutcome(isError:false,content:[McpContentBlock(kind:McpContentKind.text,text:'单人游戏。action="cast"；先选择合法鱼饵。')]);
  }
  @override Future<McpToolOutcome> play(String game,String action,Map<String,Object?> params,{GenerationCancellationToken? cancellationToken})async {
    plays++;throw StateError('Unknown mutation must never be replayed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late CedarToyActivityStore store;late _Game game;late DeepSeekClient ai;
  late CedarToyAutonomyEngine engine;late String selected;
  const native=MethodChannel('ai_companion/system');
  const receipt='cedar_unresolved_write_v1:garden_cat';
  final clock=DateTime(2026,10,27,12);
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(native,
      (call)async=>call.method=='runtimeProcessEpoch'?'synthetic-144':null);
    db=await AppDatabase.createForTesting(databaseFactoryFfi);store=CedarToyActivityStore(db);game=_Game();selected='fishing';
    ai=DeepSeekClient(jsonClientFactory:()=>MockClient((r)async=>http.Response(jsonEncode({'choices':[{
      'message':{'content':jsonEncode({'game':selected,'title':'合成游戏'})},'finish_reason':'stop'}]}),200,headers:{'content-type':'application/json'})));
    engine=CedarToyAutonomyEngine(db:db,ai:ai,secureConfig:SecureConfig.instance,tokenReader:()async=>'synthetic',
      apiKeyReader:()async=>'synthetic',endpointReader:()async=>'https://fixture.invalid/chat',clientFactory:(_)=>game);
  });
  tearDown(() async {ai.close();await db.closeForTesting();TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(native,null);});
  Future<void> parked({String source='blocked_unresolved_write'})async {
    final original=await store.recordGuide(gameId:'garden_cat',guide:'单人。action="cmd"，command=plant 或 status，slot=1。');
    await store.pause(source:source);
    final state=await store.loadState();
    await db.setSettingsAtomically(CedarToyActivityStore.stateSettingValues(state.copyWith(activeGameId:original.gameId)));
    await db.setSetting(receipt,jsonEncode({'schema':1,'execution_id':'old-unknown-write','action':'cmd',
      'params':{'command':'plant synthetic_seed 1','slot':1},'state':'dispatching','query_task_id':'','query_attempts':3}));
  }
  test('blocked unknown write can release active slot without changing receipt or session',()async {
    await parked();final before=await db.getSetting(receipt),session=(await store.load())!;
    expect(await store.releaseParkedUnresolvedWrite(),true);expect(await store.load(),isNull);
    expect(await db.getSetting(receipt),before);
    final saved=(await store.loadState()).sessions['garden_cat']!;
    expect(saved.id,session.id);expect(saved.phase,CedarActivityPhase.paused);expect(saved.pauseSource,'blocked_unresolved_write');
    expect(game.plays,0);
  });
  test('normal user pause and a current timed task are not released',()async {
    await parked(source:'local_control');expect(await store.releaseParkedUnresolvedWrite(),false);expect(await store.load(),isNotNull);
    await parked();await db.setSetting(CedarTimedPlayTaskStore.activeKey,'synthetic-active-task');
    expect(await store.releaseParkedUnresolvedWrite(),false);expect(await store.load(),isNotNull);
  });
  test('fresh autonomous choice cannot reactivate a paused unknown-write game',()async {
    await parked();await store.releaseParkedUnresolvedWrite();selected='garden_cat';
    final before=await db.getSetting(receipt);
    final result=await engine.progress(now:clock);
    // Sleep is separately exercised in wake-policy suites; this test must
    // reach the real catalog decision rather than passing on an early gate.
    expect(result.state,'invalid_game_choice');expect(game.lists,1);expect(game.guides,isEmpty);
    expect(await store.load(),isNull);expect(await db.getSetting(receipt),before);expect(game.plays,0);
  });
  test('a different available game can be selected while the unknown write stays parked',()async {
    await parked();final before=await db.getSetting(receipt);
    final result=await engine.progress(now:clock);
    expect(result.state,'guide_ready');expect(game.guides,['fishing']);expect((await store.load())!.gameId,'fishing');
    expect((await store.loadState()).sessions['garden_cat']!.phase,CedarActivityPhase.paused);
    expect(await db.getSetting(receipt),before);expect(game.plays,0);
  });
  test('a fresh choice can revisit a naturally finished solo period without resuming user pauses',()async {
    await store.recordGuide(gameId:'garden_cat',guide:'单人。cmd status plant。');
    await store.recordPlay(gameId:'garden_cat',action:'cmd',outcome:const McpToolOutcome(isError:false,
      content:[McpContentBlock(kind:McpContentKind.text,text:'合成照料完成')]),mode:CedarParticipationMode.solo,
      nextActor:'companion',shareLevel:'quiet',invitationApproved:false);
    await store.pauseAndRelease(source:'budget_complete');selected='garden_cat';
    expect((await store.loadState()).sessions['garden_cat']!.canRevisitAfterBudget,true);
    final result=await engine.progress(now:clock);
    expect(result.state,'guide_ready');expect((await store.load())!.phase,CedarActivityPhase.active);
    expect((await store.load())!.pauseSource,'');expect(game.plays,0);
  });
}
