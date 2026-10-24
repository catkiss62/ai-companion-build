import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_http_client.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_outcome_bookkeeper.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_runner.dart';
import 'package:ai_companion_localfirst/core/agent/turn_execution_store.dart';
import 'package:ai_companion_localfirst/core/agent/turn_goal_verification.dart';
import 'package:ai_companion_localfirst/core/agent/turn_task_intent.dart';
import 'package:ai_companion_localfirst/core/ai/thinking_tool_history.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/generation_attempt_fence.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/grounding/operational_claim_grounding_guard.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/memory/memory_brain.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:ai_companion_localfirst/core/storage/pending_media_owner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Cedar extends CedarToyClient {
  _Cedar({this.payload}):super(token:'ctai_v1_fixture');
  final Object? payload;
  final commands=<String>[];
  @override Future<McpToolOutcome> play(String game,String action,Map<String,Object?> params,
      {GenerationCancellationToken? cancellationToken}) async {
    final command=params['command']?.toString() ?? action;commands.add(command);
    if (payload != null) return McpToolOutcome(content: const [], isError: false, structuredContent: payload);
    final rejected=command.contains('wrong');
    return McpToolOutcome(content:const [],isError:false,structuredContent:{
      'text':rejected ? '这杯目前调不出来。用 drinks 查看现有酒单。' : '真实结果：$command',
      'ok':true,'next_actor':'companion','your_turn':true});
  }
}

class _LostRoomReply extends CedarToyClient {
  _LostRoomReply():super(token:'ctai_v1_fixture');
  final calls=<Map<String,Object?>>[];
  @override Future<McpToolOutcome> play(String game,String action,Map<String,Object?> params,
      {GenerationCancellationToken? cancellationToken}) async {
    calls.add(Map<String,Object?>.from(params));
    if(params['message'] != null) throw const McpHttpException('network_or_timeout');
    return const McpToolOutcome(content:[],isError:false,structuredContent:{'ok':true,'next_actor':'wait'});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;
  const channel=MethodChannel('ai_companion/system');
  setUp(()async {
    db=await AppDatabase.createForTesting(databaseFactoryFfi);
    FlutterSecureStorage.setMockInitialValues({'cedar_toy_token':'ctai_v1_fixture'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel,(c)async=>c.method=='runtimeProcessEpoch' ? 'execution374' : null);
  });
  tearDown(()async {
    await db.closeForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null);
  });

  Future<GenerationAttemptFence> turn()async {
    final job=await db.createGenerationTurn(user:ChatMessage(id:'u',role:'user',
      content:'去酒馆把客人招呼好',createdAt:DateTime.now()),assistantMessageId:'a',
      model:'deepseek-flash',reasoningEffort:'high');
    return (await db.captureGenerationAttemptFence((await db.claimGenerationJob(job.id))!))!;
  }
  Future<GenerationAttemptFence> regenerate(GenerationAttemptFence attempt)async {
    expect(await db.completeGenerationJobIfCurrent(jobId:attempt.jobId,runToken:attempt.runToken,
      assistant:ChatMessage(id:'a',role:'assistant',content:'原回复',createdAt:DateTime.now())),true);
    final job=(await db.restartLatestCompletedReply('a'))!;
    return (await db.captureGenerationAttemptFence((await db.claimGenerationJob(job.id))!))!;
  }
  Future<void> game()async {
    final store=CedarToyActivityStore(db);
    await store.saveCatalog('bar 空杯俱乐部');
    await store.recordGuide(gameId:'bar',guide:'solo 单人。cmd command: drinks status guests serve');
  }
  AgentToolRunner runner(_Cedar cedar)=>AgentToolRunner(db:db,android:AndroidBridge.instance,
    cedarClientFactory:(_)=>cedar);
  Future<AgentToolResult> command(AgentToolRunner runner,GenerationAttemptFence attempt,String cmd,{int index=0})async =>
    (await runner.runPlan(AgentToolPlan(calls:[AgentToolCall(toolId:'cedar_toy.play',reasonTag:'explicit_request',
      arguments:{'game':'bar','action':'cmd','params_json':jsonEncode({'command':cmd,'slot':1}),
        'participation_mode':'solo'})]),userMessageId:'u',assistantMessageId:'a',
      eventScopeId:'user_turn:${attempt.jobId}',callIndexOffset:index,
      latestUserText:'把客人招呼好',pendingMediaOwner:PendingMediaOwner.generation(attempt))).single;

  test('message-bearing continuation lost reply never retries as ordinary read poll',() async {
    final activity=CedarToyActivityStore(db); final cedar=_LostRoomReply(); final ai=DeepSeekClient();
    await db.setSettingsAtomically({'active_brain':'1','transfer_lock':'0','cedar_toy_enabled':'1',
      CedarToyAutonomyEngine.enabledKey:'1'});
    await activity.recordGuide(gameId:'duel',guide:'state room_id wait message; move');
    await activity.recordPlay(gameId:'duel',action:'state',mode:CedarParticipationMode.multiplayer,
      nextActor:'wait',shareLevel:'quiet',invitationApproved:true,
      outcome:const McpToolOutcome(content:[],isError:false,structuredContent:{
        'next_actor':'wait','wait_scope':'current_request_only','next_call':{
          'game':'duel','action':'state','params':{'room_id':'ROOM','wait':true,'message':'你好'}}}));
    await activity.deferContinuation(gameId:'duel',delay:Duration.zero);
    final engine=CedarToyAutonomyEngine(db:db,ai:ai,secureConfig:SecureConfig.instance,
      tokenReader:()async=>'ctai_v1_fixture',apiKeyReader:()async=>'fixture',
      endpointReader:()async=>DeepSeekClient.defaultEndpoint,clientFactory:(_)=>cedar);
    try {
      await engine.continueDue(now:DateTime.now().add(const Duration(seconds:1)));
      expect(cedar.calls,hasLength(1));expect(cedar.calls.single['message'],'你好');
      expect(await activity.unresolvedWrite('duel'),isNotNull);
      final current=(await activity.loadSession('duel'))!;
      expect(current.continuationWaitScope,'write_reconcile_once');
      expect(jsonDecode(current.continuationParamsJson).containsKey('message'),false);
      await activity.deferContinuation(gameId:'duel',delay:Duration.zero);
      await engine.continueDue(now:DateTime.now().add(const Duration(seconds:1)));
      expect(cedar.calls.where((c)=>c.containsKey('message')),hasLength(1));
    } finally {ai.close();}
  });

  test('different necessary reads are allowed but alternating unchanged queries are not',() async {
    await game(); final attempt=await turn(); final cedar=_Cedar(); final run=runner(cedar);
    final activity=CedarToyActivityStore(db);
    await command(run,attempt,'status');
    var session=(await activity.loadSession('bar'))!;
    expect(session.repeatsUnchangedRead('cmd',{'command':'status','slot':1}),true);
    expect(session.repeatsUnchangedRead('cmd',{'command':'guests','slot':1}),false);
    await command(run,attempt,'guests');
    session=(await activity.loadSession('bar'))!;
    expect(session.repeatsUnchangedRead('cmd',{'command':'status','slot':1}),true);
    await command(run,attempt,'serve cloud pour:plum_liqueur');
    session=(await activity.loadSession('bar'))!;
    expect(session.repeatsUnchangedRead('cmd',{'command':'status','slot':1}),false);
  });

  test('cmd queries do not consume the three-move solo checkpoint',() async {
    await game(); final attempt=await turn(); final cedar=_Cedar(); final run=runner(cedar);
    for (final query in ['status','guests','drinks']) {
      expect((await command(run,attempt,query)).succeeded,true);
    }
    final episode=await CedarPlayOutcomeBookkeeper(db).loadSoloEpisode();
    expect(episode?.stateChangeCount,0);
    expect(episode?.checkpointPending,false);
    expect((await CedarToyActivityStore(db).loadState()).completedPlayRounds,0);
  });

  test('normal-envelope rejection is failure throughout durable game state',() async {
    await game(); final attempt=await turn(); final cedar=_Cedar();
    expect((await command(runner(cedar),attempt,'serve wrong')).status,AgentToolStatus.failed);
    final state=await CedarToyActivityStore(db).loadState();
    expect(state.completedPlayRounds,0);
    expect(state.sessions['bar']!.events.last.kind,'failure');
    expect((await TurnExecutionStore(db).remoteHistory('u')).single['failed'],true);
  });

  for (final payload in [
    {'error': 'insufficient funds', 'next_actor': 'companion'},
    {'data': {'ok': false, 'message': 'temporarily unavailable'}},
    {'result': jsonEncode([{'accepted': false, 'inventory': []}])},
    {'data': [{'errors': ['remote refusal'], 'next_actor': 'companion'}]},
  ]) {
    test('nested business refusal never becomes a committed Agent game effect: $payload', () async {
      await game(); final attempt = await turn();
      final result = await command(runner(_Cedar(payload: payload)), attempt, 'serve new');
      expect(result.status, AgentToolStatus.failed);
      final state = await CedarToyActivityStore(db).loadState();
      expect(state.completedPlayRounds, 0);
      expect(state.sessions['bar']!.events.last.kind, 'failure');
      expect((await TurnExecutionStore(db).remoteHistory('u')).single['failed'], true);
    });
  }

  test('empty or other-slot snapshot cannot unlock an unknown write',() async {
    await game(); final activity=CedarToyActivityStore(db);
    final id=await activity.beginExecution(gameId:'bar',action:'cmd');
    expect(await activity.admitRemoteDispatch(gameId:'bar',action:'cmd',
      params:{'command':'serve x','slot':1},executionId:id),true);
    await activity.resolveRemoteDispatch(gameId:'bar',executionId:id,action:'cmd',authoritative:true,
      params:{'command':'status','slot':2},outcome:const McpToolOutcome(content:[],isError:false,
        structuredContent:{'ok':true,'next_actor':'companion'}));
    expect(await activity.unresolvedWrite('bar'),isNotNull);
    await activity.resolveRemoteDispatch(gameId:'bar',executionId:id,action:'cmd',authoritative:true,
      params:{'command':'status','slot':1},outcome:const McpToolOutcome(content:[],isError:false));
    expect(await activity.unresolvedWrite('bar'),isNotNull);
    await activity.finishExecution(executionId:id);
  });

  test('same-target cmd reconciliation permits a new step but never replays unknown operation',() async {
    await game(); final attempt=await turn(); final effects=TurnExecutionStore(db);
    final activity=CedarToyActivityStore(db);
    final payload={'game':'bar','action':'cmd','params':{'command':'serve cloud pour:plum_liqueur','slot':1}};
    expect(await effects.reserveRemoteEffect(attempt,payload),isNull);
    final id=await activity.beginExecution(gameId:'bar',action:'cmd');
    expect(await activity.admitRemoteDispatch(gameId:'bar',action:'cmd',
      params:Map<String,Object?>.from(payload['params'] as Map),executionId:id,turnId:'u'),true);
    await activity.finishExecution(executionId:id);
    final retry=await regenerate(attempt); final cedar=_Cedar(); final run=runner(cedar);
    expect((await command(run,retry,'status')).succeeded,true);
    expect(await activity.unresolvedWrite('bar'),isNull);
    expect((await effects.remoteHistory('u')).single['state'],'reconciled');
    expect((await command(run,retry,'serve cloud pour:plum_liqueur',index:1)).status,AgentToolStatus.blocked);
    expect((await command(run,retry,'next',index:2)).succeeded,true);
    expect(cedar.commands,['status','next']);
  });

  test('thinking transport preserves raw reasoning and represents empty tool reasoning explicitly',(){
    final history=<Map<String,Object?>>[
      {'role':'user','content':'问题'},
      {'role':'assistant','content':null,'tool_calls':[{'id':'a'}]},
      {'role':'tool','tool_call_id':'a','content':'结果'},
      {'role':'assistant','content':'历史','reasoning_content':'  原始思考\n'},
    ];
    final out=ThinkingToolHistory.prepare(history,thinking:true,toolsOffered:true);
    expect(out[1]['reasoning_content'],'');expect(out[3]['reasoning_content'],'  原始思考\n');
    expect(history[1].containsKey('reasoning_content'),false);
    expect(out[2],history[2]);
    expect(ThinkingToolHistory.prepare(history,thinking:false,toolsOffered:true),same(history));
  });

  for(final cmd in ['drinks','status','guests','status;guests','help serve']) {
    test('safe cmd query $cmd is not a game write',(){
      expect(CedarPlatformActionPolicy.isReadOnlyCall('cmd',{'command':cmd}),true);
    });
  }
  for(final cmd in ['status;serve cloud pour:plum_liqueur','serve cloud pour:plum_liqueur',
      'unknown','status "unfinished','next','open','?']) {
    test('mutation or unverified cmd $cmd remains a write',(){
      expect(CedarPlatformActionPolicy.isReadOnlyCall('cmd',{'command':cmd}),false);
    });
  }
  test('query then real action survives regeneration without repeating the action',()async {
    await game();final attempt=await turn();final cedar=_Cedar();final first=runner(cedar);
    final read=await command(first,attempt,'drinks');
    expect(TurnGoalVerification.foregroundWrite(read),false);
    expect(await TurnExecutionStore(db).remoteEffect('u'),isNull);
    expect((await command(first,attempt,'serve cloud pour:plum_liqueur',index:1)).succeeded,true);
    final retry=await regenerate(attempt);final next=runner(cedar);
    expect((await command(next,retry,'guests')).succeeded,true);
    expect((await command(next,retry,'serve cloud pour:plum_liqueur',index:1)).succeeded,true);
    expect(cedar.commands,['drinks','serve cloud pour:plum_liqueur','guests']);
    expect((await TurnExecutionStore(db).remoteHistory('u')).length,1);
  });
  test('game-level refusal is failed even when MCP returns a normal envelope; repaired arguments may run',()async {
    await game();final attempt=await turn();final cedar=_Cedar();
    final failed=await command(runner(cedar),attempt,'serve cloud wrong');
    expect(failed.status,AgentToolStatus.failed);expect(TurnGoalVerification.foregroundWrite(failed),false);
    final receipt=(await TurnExecutionStore(db).remoteEffect('u'))!;expect(receipt['failed'],true);
    final retry=await regenerate(attempt);
    expect((await command(runner(cedar),retry,'serve cloud pour:plum_liqueur')).succeeded,true);
    expect(cedar.commands.length,2);
    expect((await TurnExecutionStore(db).remoteEffect('u'))!['prior_rejections'],isNotEmpty);
    expect(OperationalClaimGroundingGuard.evaluate(text:'「这杯已经推到客人手边了。」',
      currentToolResults:[failed]).allowed,false);
  });
  test('rejection checks decode real MCP projections but not dialogue mentioning a rejected action',(){
    for(final blocks in [const <McpContentBlock>[],const [McpContentBlock(kind:McpContentKind.text,
        text:'这杯目前调不出来。用 drinks 查看现有酒单。')]]) {
      final outcome=McpToolOutcome(content:blocks,isError:false,structuredContent:{
        'text':'这杯目前调不出来。用 drinks 查看现有酒单。','ok':true,'next_actor':'companion'});
      expect(CedarPlatformActionPolicy.explicitlyRejected(outcome.text),true);
    }
    expect(CedarPlatformActionPolicy.explicitlyRejected(jsonEncode({
      'text':'客人说：“这杯目前调不出来也没关系。”然后接过了饮料。'})),false);
  });
  test('legacy known cmd read cannot block the next real write after regeneration',()async {
    await game();final attempt=await turn();final store=TurnExecutionStore(db);
    final payload={'game':'bar','action':'cmd','params':{'command':'drinks','slot':1}};
    expect(await store.reserveRemoteEffect(attempt,payload),isNull);
    await store.completeRemoteEffect('u',payload,outcome:'真实酒单',failed:false);
    final retry=await regenerate(attempt);final cedar=_Cedar();
    expect((await command(runner(cedar),retry,'serve cloud pour:plum_liqueur')).succeeded,true);
    expect(cedar.commands,['serve cloud pour:plum_liqueur']);
  });
  test('successful remote action followed by reply 400 is replayed after DS retry without a second action',()async {
    await game();final attempt=await turn();final cedar=_Cedar();
    expect((await command(runner(cedar),attempt,'serve cloud pour:plum_liqueur')).succeeded,true);
    await db.failGenerationJob(attempt.jobId,runToken:attempt.runToken,
      error:'API 400 reasoning_content',recoverable:false);
    expect(await db.retryFailedGenerationJob(attempt.jobId,useDeepSeek:true),true);
    final claimed=(await db.claimGenerationJob(attempt.jobId))!;
    final retry=(await db.captureGenerationAttemptFence(claimed))!;
    expect((await command(runner(cedar),retry,'serve cloud pour:plum_liqueur')).succeeded,true);
    expect(cedar.commands,['serve cloud pour:plum_liqueur']);
    expect(await db.getSetting('generation_manual_deepseek_job_v1'),attempt.jobId);
  });
  test('unknown write remains fenced while safe status query remains available',()async {
    await game();final attempt=await turn();final store=TurnExecutionStore(db);
    expect(await store.reserveRemoteEffect(attempt,{'game':'bar','action':'cmd',
      'params':{'command':'serve cloud pour:plum_liqueur','slot':1}}),isNull);
    final retry=await regenerate(attempt);final cedar=_Cedar();final run=runner(cedar);
    expect((await command(run,retry,'status')).succeeded,true);
    expect((await command(run,retry,'serve cloud pour:plum_liqueur',index:1)).status,AgentToolStatus.blocked);
    expect(cedar.commands,['status']);
  });
  test('a known partial operation can continue a different necessary step after reply failure',()async {
    await game();final attempt=await turn();final cedar=_Cedar();
    expect((await command(runner(cedar),attempt,'serve cloud pour:plum_liqueur')).succeeded,true);
    final retry=await regenerate(attempt);
    expect((await command(runner(cedar),retry,'next')).succeeded,true);
    expect(cedar.commands,['serve cloud pour:plum_liqueur','next']);
    expect((await TurnExecutionStore(db).remoteHistory('u')).length,2);
  });
  test('authorization contradiction requires joint review; review cannot invent targets',()async {
    await game();final q=TurnTaskQuestionSet(userText:'去酒馆玩半小时',
      state:await CedarToyActivityStore(db).loadState(),works:const []);
    const old=TurnTaskIntent(available:true,gameAction:'none',unresolvedFields:{'task_game'});
    expect(TurnTaskQuestionSet.needsReview(old,'act_now',certain:true),true);
    final target=q.games.entries.singleWhere((e)=>e.value.id=='bar').key;
    final fixed=q.reviewed(old,{'task_game':'resume','task_game_target':target,'task_duration':'d0'});
    expect(fixed.gameExecutionResolved,true);expect(fixed.minutes,30);
    expect(fixed.goals('u').map((g)=>g.slot),contains(TurnEffectSlot.cedarForegroundWrite));
    expect(q.reviewed(old,{'task_game':'play','task_game_target':'invented'}).gameExecutionResolved,false);
    expect(q.reviewed(old,{'task_game':'none'}).gameAction,'none');
    expect(TurnTaskQuestionSet.needsReview(const TurnTaskIntent(available:true), 'chat',certain:true),false);
  });
  test('phone activity replaces old conversation wording and does not reopen its separate question',()async {
    await db.upsertThought(id:'phone',text:'还没说改了哪些规则',drive:DriveKey.curiosity,
      kind:'flit',strength:.4,source:'presence/phone_activity',topicKey:'presence:phone_activity');
    await DesireEngine(db).feedThought(text:'刚才切换了几个应用',drive:DriveKey.curiosity,
      source:'presence/phone_activity',topicKey:'presence:phone_activity');
    expect((await db.thoughtById('phone'))!.text,'刚才切换了几个应用');
    await db.applyPostTurnThoughtEvidenceAtomic(sourceMessageId:'a',evidenceKey:'answered',
      text:'规则改动已经解释清楚',drive:DriveKey.curiosity,incomingStrength:.1,
      topicKey:'presence:phone_activity',continuity:'revised');
    expect((await db.thoughtById('phone'))!.text,'刚才切换了几个应用');
    expect((await db.postTurnThoughtCandidates()).any((t)=>t.id=='phone'),false);
  });
  test('regeneration excludes its own previous draft memory without deleting that memory',()async {
    final at=DateTime.now().subtract(const Duration(minutes:1));
    await db.insertMessage(ChatMessage(id:'u',role:'user',content:'去空杯俱乐部出杯',createdAt:at));
    await db.insertMessage(ChatMessage(id:'a',role:'assistant',content:'空杯俱乐部出杯已经完成',
      createdAt:at.add(const Duration(seconds:1))));
    expect(await db.insertMemory(kind:'shared_experience',content:'空杯俱乐部出杯已经完成',
      importance:.9,source:'conversation_turn:a@r0',sourceUserMessageId:'u',sourceAssistantMessageId:'a'),true);
    final brain=MemoryBrain(db);
    final before=await brain.buildContext('空杯俱乐部出杯');
    expect(before.relevant,isNotEmpty);
    final retry=await brain.buildContext('空杯俱乐部出杯',excludedAssistantSources:{'a'});
    expect(retry.relevant,isEmpty);
    expect((await (await db.database).query('memory_items')).length,1);
  });
  test('an answered question stays closed across generic continuation but new relevant evidence can revise it',()async {
    await db.upsertThought(id:'question',text:'想知道具体改动',drive:DriveKey.curiosity,
      kind:'flit',strength:.5,source:'conversation_turn:old',topicKey:'user.optimization');
    await db.upsertUnfinishedThread(id:'thread',title:'解释具体改动',detail:'等待说明',
      importance:.5,topicKey:'user.optimization');
    await db.resolveUnfinishedThreadById('thread');
    await db.applyPostTurnThoughtEvidenceAtomic(sourceMessageId:'a',evidenceKey:'resolution',
      text:'已经解释清楚',drive:DriveKey.curiosity,incomingStrength:.1,
      topicKey:'user.optimization',continuity:'resolved');
    await db.applyPostTurnThoughtEvidenceAtomic(sourceMessageId:'b',evidenceKey:'continuation',
      text:'还想知道原问题',drive:DriveKey.curiosity,incomingStrength:.7,
      topicKey:'user.optimization',continuity:'continued');
    expect((await db.thoughtById('question'))!.lifecycleState,'dormant');
    expect((await db.thoughtById('question'))!.text,'已经解释清楚');
    await db.applyPostTurnThoughtEvidenceAtomic(sourceMessageId:'c',evidenceKey:'genuine-new-detail',
      text:'刚有了新的改动，想知道新功能',drive:DriveKey.curiosity,incomingStrength:.4,
      topicKey:'user.optimization',continuity:'revised');
    expect((await db.thoughtById('question'))!.lifecycleState,'active');
  });
  for (final empty in [<String,Object?>{}, <Object?>[], '', true, {'ok':true}, {'status':'ok'}]) {
    test('empty/ack structured state cannot resolve a real outstanding dispatch: $empty', () async {
      await game(); final store=CedarToyActivityStore(db);
      final id=await store.beginExecution(gameId:'bar',action:'cmd');
      expect(await store.admitRemoteDispatch(gameId:'bar',action:'cmd',
        params:{'command':'serve x','slot':1},executionId:id),true);
      await store.resolveRemoteDispatch(gameId:'bar',executionId:id,action:'cmd',authoritative:true,
        params:{'command':'status','slot':1},outcome:McpToolOutcome(content:[],isError:false,structuredContent:empty));
      expect(await store.unresolvedWrite('bar'),isNotNull);
      await store.resolveRemoteDispatch(gameId:'bar',executionId:id,action:'cmd',authoritative:true,
        params:{'command':'status','slot':1},outcome:const McpToolOutcome(content:[],isError:false,
          structuredContent:{'slot':2,'state':{'balance':0}}));
      expect(await store.unresolvedWrite('bar'),isNotNull);
      await store.resolveRemoteDispatch(gameId:'bar',executionId:id,action:'cmd',authoritative:true,
        params:{'command':'status','slot':1},outcome:const McpToolOutcome(content:[],isError:false,
          structuredContent:{'slot':1,'inventory':[]}));
      expect(await store.unresolvedWrite('bar'),isNull);
      await store.finishExecution(executionId:id);
    });
  }
  test('received result interrupted before local snapshot cannot satisfy a goal or replay a mutation', () async {
    await game();final attempt=await turn();final effects=TurnExecutionStore(db);
    final activity=CedarToyActivityStore(db);
    final payload={'game':'bar','action':'cmd','params':{'command':'serve old','slot':1}};
    expect(await effects.reserveRemoteEffect(attempt,payload),isNull);
    final id=await activity.beginExecution(gameId:'bar',action:'cmd');
    await activity.admitRemoteDispatch(gameId:'bar',action:'cmd',
      params:Map<String,Object?>.from(payload['params'] as Map),executionId:id,turnId:'u');
    await effects.completeRemoteEffect('u',payload,outcome:'服务回包待核验',failed:false,stateApplied:false);
    await activity.finishExecution(executionId:id);
    final retry=await regenerate(attempt);final cedar=_Cedar();final run=runner(cedar);
    final blocked=await command(run,retry,'serve old');
    expect(blocked.status,AgentToolStatus.blocked);
    expect(TurnGoalVerification.foregroundWrite(blocked),false);
    expect(cedar.commands,isEmpty);
    expect((await command(run,retry,'status',index:1)).succeeded,true);
    expect((await effects.remoteHistory('u')).single['state'],'reconciled');
    expect(await activity.unresolvedWrite('bar'),isNull);
    expect((await command(run,retry,'serve old',index:2)).status,AgentToolStatus.blocked);
    expect(cedar.commands,['status']);
    expect((await command(run,retry,'serve new',index:3)).succeeded,true);
    expect(cedar.commands,['status','serve new']);
    expect((await effects.remoteHistory('u')).last['state_applied'],true);
  });
  test('long cmd read keeps exact classification across bounded event storage and JSON roundtrip', () async {
    await game();final attempt=await turn();final cedar=_Cedar();
    final query='help '+List.filled(2400,'x').join();
    expect((await command(runner(cedar),attempt,query)).succeeded,true);
    final session=(await CedarToyActivityStore(db).loadSession('bar'))!;
    expect(session.events.last.inputJson.length,2001);
    expect(session.events.last.isReadOnly,true);
    expect(CedarGameEvent.fromJson(session.events.last.toJson()).isReadOnly,true);
    expect((await CedarPlayOutcomeBookkeeper(db).loadSoloEpisode())?.stateChangeCount,0);
    expect((await CedarToyActivityStore(db).loadState()).completedPlayRounds,0);
    final legacy=CedarGameEvent(id:'legacy',kind:'outcome',summary:'old',createdAt:DateTime.now(),
      action:'cmd',inputJson:'{"command":"cut');
    expect(legacy.isReadOnly,isNull);
  });

  for (final pendingWrite in [false, true]) {
    test('legacy receipt compatibility requires no outstanding state gap: pending=$pendingWrite', () async {
      await game();final attempt=await turn();final effects=TurnExecutionStore(db);
      final activity=CedarToyActivityStore(db);
      final payload={'game':'bar','action':'cmd','params':{'command':'serve old','slot':1}};
      await effects.reserveRemoteEffect(attempt,payload);
      await effects.completeRemoteEffect('u',payload,outcome:'原结果',failed:false);
      final receipt=(await effects.remoteHistory('u')).single..remove('state_applied');
      await db.setSetting('${TurnExecutionStore.remoteJournalPrefix}u',jsonEncode([receipt]));
      if (pendingWrite) {
        final id=await activity.beginExecution(gameId:'bar',action:'cmd');
        await activity.admitRemoteDispatch(gameId:'bar',action:'cmd',
          params:Map<String,Object?>.from(payload['params'] as Map),executionId:id,turnId:'u');
        await activity.finishExecution(executionId:id);
      }
      final cedar=_Cedar();
      final result=await command(runner(cedar),attempt,'serve old');
      expect(result.status,pendingWrite ? AgentToolStatus.blocked : AgentToolStatus.succeeded);
      expect(TurnGoalVerification.foregroundWrite(result),!pendingWrite);
      expect(cedar.commands,isEmpty);
    });
  }

}
