import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_runner.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_solo_episode_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_state_merge.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_http_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:ai_companion_localfirst/core/storage/pending_media_owner.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';

const _guide='单人游戏。action="cmd" params={"command":"...","slot":1}。action="status" 查询存档状态；rest 平台休息。';
class _Secure extends SecureConfig {
  _Secure():super.forTesting(const FlutterSecureStorage());
  final entered=Completer<void>(),release=Completer<void>();
  @override Future<String?> readCedarToyToken()async {if(!entered.isCompleted)entered.complete();await release.future;return 'ctai_v1_synthetic';}
}
class _Game extends CedarToyClient {
  _Game():super(token:'ctai_v1_synthetic');final calls=<String>[];bool timeout=false,reject=true;
  @override Future<McpToolOutcome> getGuide(String game,{GenerationCancellationToken? cancellationToken})async=>
    const McpToolOutcome(isError:false,content:[McpContentBlock(kind:McpContentKind.text,text:'迟到的新版指南。$_guide')]);
  @override Future<McpToolOutcome> play(String game,String action,Map<String,Object?> params,{GenerationCancellationToken? cancellationToken})async {
    calls.add(action);if(timeout)throw const McpHttpException('network_or_timeout');
    return McpToolOutcome(isError:reject,content:[McpContentBlock(kind:McpContentKind.text,text:reject?'明确拒绝，本次没有执行。':'休息已完成。')]);
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late CedarToyActivityStore store;late _Game game;late DeepSeekClient ai;
  const channel=MethodChannel('ai_companion/system');final clock=DateTime(2026,10,29,12);
  setUp(()async {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(call)async=>call.method=='runtimeProcessEpoch'?'fixture151':null);
    db=await AppDatabase.createForTesting(databaseFactoryFfi);store=CedarToyActivityStore(db);game=_Game();ai=DeepSeekClient();
    await store.saveCatalog('bar·酒馆经营，单人·fixture');
    final session=await store.recordGuide(gameId:'bar',guide:_guide);
    await store.save(session.copyWith(mode:CedarParticipationMode.solo,phase:CedarActivityPhase.active,nextActor:'companion',
      continuationAction:'status',continuationParamsJson:'{"slot":1}',continuationWaitScope:'current_request_only'));
  });
  tearDown(()async {ai.close();await db.closeForTesting();TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null);});
  Future<PendingMediaOwner> owner(String id)async {
    final pending=await db.createGenerationTurn(user:ChatMessage(id:id,role:'user',content:'请在酒馆推进一步。',createdAt:clock),
      assistantMessageId:'reply-$id',model:'deepseek-v4-flash',reasoningEffort:'high');
    final job=(await db.claimGenerationJob(pending.id))!;
    return PendingMediaOwner.generation((await db.captureGenerationAttemptFence(job))!);
  }
  Future<List<AgentToolResult>> execute(String tool,SecureConfig secure,PendingMediaOwner ownership)=>AgentToolRunner(
    db:db,android:AndroidBridge.instance,secureConfig:secure,ai:ai,cedarClientFactory:(_)=>game).runPlan(
      AgentToolPlan(calls:[AgentToolCall(toolId:tool,reasonTag:'explicit_request',arguments:{'game':'bar',
        if(tool=='cedar_toy.play')...{'action':'cmd','params_json':'{"slot":1,"command":"advance"}','participation_mode':'solo'}})]),
      eventScopeId:ownership.attempt!.userMessageId,userMessageId:ownership.attempt!.userMessageId,
      assistantMessageId:ownership.attempt!.assistantMessageId,latestUserText:'请推进一步。',pendingMediaOwner:ownership);
  for(final tool in ['cedar_toy.play','cedar_toy.get_guide']) {
    for(final control in ['pause','pause_resume','disable','restore']) {
      test('$tool rejects old turn after $control during preparation',()async {
        final ownership=await owner('old'),secure=_Secure();final pending=execute(tool,secure,ownership);
        try {
          await secure.entered.future.timeout(const Duration(seconds:5));
          if(control=='restore')await db.setSetting('runtime_state_epoch_v1','restored151');
          else if(control=='disable') {await db.setSetting('cedar_toy_enabled','0');await store.suspendForSwitch();}
          else {await store.pause();if(control=='pause_resume')await store.resume();}
          secure.release.complete();final result=(await pending).single;
          expect(game.calls,isEmpty);expect(result.succeeded,false);
          final current=(await store.loadSession('bar'))!;expect(current.guide,isNot(contains('迟到的')));
          expect((await store.loadState()).execution,isNull);
          if(control=='pause')expect(current.phase,CedarActivityPhase.paused);
        }finally {if(!secure.release.isCompleted)secure.release.complete();await pending;}
      });
    }
  }
  test('a fresh explicit turn after Pause may legitimately make its first game call',()async {
    await store.pause();final ownership=await owner('fresh'),secure=_Secure()..release.complete();
    await execute('cedar_toy.play',secure,ownership);expect(game.calls,['cmd']);
  });
  for(final tool in ['cedar_toy.play','cedar_toy.get_guide']) {
    for(final pauseAgain in [false,true]) {
      test('$tool accepts only its own same-target resume receipt, later pause=$pauseAgain',()async {
        await store.pause();final ownership=await owner('resume'),session=(await store.loadSession('bar'))!;
        final admission=await store.applyControl(operation:'resume',gameId:'bar',sessionId:session.id,attemptFence:ownership.attempt);
        expect(admission.receipt?.committed,true);
        final secure=_Secure();final pending=execute(tool,secure,ownership);
        try {
          await secure.entered.future.timeout(const Duration(seconds:5));if(pauseAgain)await store.pause();
          secure.release.complete();final result=(await pending).single;
          if(pauseAgain) {
            expect(result.succeeded,false);expect(game.calls,isEmpty);
            expect((await store.loadSession('bar'))!.guide,isNot(contains('迟到的')));
          }else if(tool=='cedar_toy.play')expect(game.calls,['cmd']);
          else {expect(result.succeeded,true);expect((await store.loadSession('bar'))!.guide,contains('迟到的'));}
        }finally {if(!secure.release.isCompleted)secure.release.complete();await pending;}
      });
    }
  }
  test('a same-turn resume receipt for another game cannot authorize this game',()async {
    await store.recordGuide(gameId:'other',guide:_guide);await store.pause();
    final ownership=await owner('other-resume'),session=(await store.loadSession('other'))!;
    final admission=await store.applyControl(operation:'resume',gameId:'other',sessionId:session.id,attemptFence:ownership.attempt);
    expect(admission.receipt?.committed,true);
    final secure=_Secure()..release.complete();final result=(await execute('cedar_toy.play',secure,ownership)).single;
    expect(result.succeeded,false);expect(game.calls,isEmpty);
  });
  test('outcome commit preserves an independently queued game and user advice',()async {
    final execution=await store.beginExecution(gameId:'bar',action:'cmd');
    final entered=Completer<void>(),release=Completer<void>();var armed=true;
    final delayed=CedarToyActivityStore(db,beforeStateCommit:()async {if(armed){armed=false;entered.complete();await release.future;}});
    final operation=delayed.recordPlay(gameId:'bar',action:'cmd',submittedParams:{'slot':1,'command':'advance'},
      outcome:const McpToolOutcome(isError:false,content:[McpContentBlock(kind:McpContentKind.text,text:'实际完成一步。')]),
      mode:CedarParticipationMode.solo,nextActor:'companion',shareLevel:'quiet',invitationApproved:false,executionId:execution,keepExecution:true);
    try {
      await entered.future.timeout(const Duration(seconds:5));await store.queueSwitch(targetGameId:'other');
      await store.rememberUserAdvice('建议在酒馆里优先照顾新来的客人');release.complete();await operation;
      final state=await store.loadState();expect(state.queuedSwitches.single.targetGameId,'other');
      expect(state.sessions['bar']!.adviceNotes,contains('建议在酒馆里优先照顾新来的客人'));
      expect(state.sessions['bar']!.lastOutcome,contains('实际完成一步'));expect(state.completedPlayRounds,1);
    }finally {if(!release.isCompleted)release.complete();await operation;await store.finishExecution(executionId:execution);}
  });
  test('Pause during a local result commit rejects the old execution',()async {
    final execution=await store.beginExecution(gameId:'bar',action:'cmd');final entered=Completer<void>(),release=Completer<void>();var armed=true;
    final delayed=CedarToyActivityStore(db,beforeStateCommit:()async {if(armed){armed=false;entered.complete();await release.future;}});
    final operation=delayed.recordPlay(gameId:'bar',action:'cmd',submittedParams:{'command':'advance'},
      outcome:const McpToolOutcome(isError:false,content:[McpContentBlock(kind:McpContentKind.text,text:'旧结果')]),mode:CedarParticipationMode.solo,
      nextActor:'companion',shareLevel:'quiet',invitationApproved:false,executionId:execution,keepExecution:true);
    final observed=expectLater(operation,throwsA(isA<CedarExecutionPreemptedException>()));
    try {await entered.future.timeout(const Duration(seconds:5));await store.pause();release.complete();await observed;
      expect((await store.loadSession('bar'))!.phase,CedarActivityPhase.paused);expect((await store.loadSession('bar'))!.lastOutcome,isNot(contains('旧结果')));
    }finally {if(!release.isCompleted)release.complete();await observed;}
  });
  test('merge does not attach an old outcome to a replacement session with the same game id',() {
    final base={'sessions':[{'game_id':'bar','id':'old','last_outcome':''}],'updated_at':1};
    final desired={'sessions':[{'game_id':'bar','id':'old','last_outcome':'old-result'}],'updated_at':2};
    final current={'sessions':[{'game_id':'bar','id':'new','last_outcome':''}],'updated_at':3};
    expect(CedarStateMerge.merge(base,desired,current),isNull);
  });
  Future<void> resetEpisode({int revision=0})=>db.setSetting(CedarToyAutonomyEngine.soloEpisodeKey,jsonEncode(CedarSoloEpisodeState(
    gameId:'bar',startedAt:clock.subtract(const Duration(minutes:20)),checkpointPending:true,checkpointReason:'anti_addiction',
    antiAddictionLevel:CedarAntiAddictionLevel.reminder,allowSelfReset:true,antiAddictionObservedAt:clock.add(Duration(minutes:revision))).toJson()));
  CedarToyAutonomyEngine engine()=>CedarToyAutonomyEngine(db:db,ai:ai,secureConfig:SecureConfig.instance,tokenReader:()async=>'ctai_v1_synthetic',
    apiKeyReader:()async=>'synthetic',endpointReader:()async=>'https://fixture.invalid/chat',clientFactory:(_)=>game);
  test('a timed-out rest is not replayed, even after an authoritative state reconciliation',()async {
    await resetEpisode();game.timeout=true;
    await engine().resumeCheckpoint(now:clock,selfReset:true);expect(game.calls,['rest']);expect(await store.unresolvedWrite('bar'),isNotNull);
    await engine().resumeCheckpoint(now:clock,selfReset:true);expect(game.calls,['rest']);
    final execution=await store.beginExecution(gameId:'bar',action:'status');
    const snapshot=McpToolOutcome(isError:false,content:[],structuredContent:{'slot':1,'inventory':[]});
    await store.recordPlay(gameId:'bar',action:'status',submittedParams:{'slot':1},outcome:snapshot,mode:CedarParticipationMode.solo,
      nextActor:'companion',shareLevel:'quiet',invitationApproved:false,executionId:execution,keepExecution:true);
    await store.resolveRemoteDispatch(gameId:'bar',executionId:execution,action:'status',params:{'slot':1},authoritative:true,outcome:snapshot);
    await store.finishExecution(executionId:execution);expect(await store.unresolvedWrite('bar'),isNull);
    await engine().resumeCheckpoint(now:clock,selfReset:true);expect(game.calls,['rest']);
    await resetEpisode(revision:1);game.timeout=false;game.reject=false;
    expect((await engine().resumeCheckpoint(now:clock,selfReset:true)).state,'self_reset_succeeded');expect(game.calls,['rest','rest']);
  });
  test('an existing unknown game mutation blocks the self-reset entry',()async {
    await resetEpisode();final e=await store.beginExecution(gameId:'bar',action:'cmd');
    expect(await store.admitRemoteDispatch(gameId:'bar',action:'cmd',params:{'command':'advance','slot':1},executionId:e),true);
    await store.finishExecution(executionId:e);await engine().resumeCheckpoint(now:clock,selfReset:true);expect(game.calls,isEmpty);
  });
  test('a known explicit rest rejection may be reconsidered without an unknown receipt',()async {
    await resetEpisode();game.reject=true;
    expect((await engine().resumeCheckpoint(now:clock,selfReset:true)).state,'self_reset_failed');expect(await store.unresolvedWrite('bar'),isNull);
    expect((await engine().resumeCheckpoint(now:clock,selfReset:true)).state,'self_reset_failed');expect(game.calls,['rest','rest']);
  });
}
