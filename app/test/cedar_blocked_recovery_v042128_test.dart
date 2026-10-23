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
import 'package:ai_companion_localfirst/core/mcp/cedar_play_session_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'support/cedar_task_fixture.dart';

class _Game extends CedarToyClient {
  _Game():super(token:'ctai_v1_fixture');
  final actions=<String>[];
  final slots=<Object?>[];
  bool fail=false;
  @override Future<McpToolOutcome> play(String game,String action,Map<String,Object?> params,
      {GenerationCancellationToken? cancellationToken}) async {
    actions.add(action);slots.add(params['slot']);
    return McpToolOutcome(isError:fail,content:[McpContentBlock(kind:McpContentKind.text,
      text:fail?'temporary failure':'同一个存档的真实状态')],
      structuredContent:fail?null:{'next_actor':'companion','participation_mode':'solo'});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late CedarToyActivityStore activity;late CedarTimedPlayTaskStore tasks;
  const channel=MethodChannel('ai_companion/system');
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,
      (call) async=>call.method=='runtimeProcessEpoch'?'blocked-test':null);
    db=await AppDatabase.createForTesting(databaseFactoryFfi);
    activity=CedarToyActivityStore(db);tasks=CedarTimedPlayTaskStore(db);
  });
  tearDown(() async {
    await db.closeForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null);
  });

  Future<CedarGameSession> start({String guide='单人游戏。action="status" 查询；action="cmd" 执行。',
      String game='bar',int priorQueryAttempts=0,String queryTaskId=''}) async {
    final session=await activity.recordGuide(gameId:game,guide:guide);
    // Anonymous equivalent of a restored in-flight dispatch with no next_call.
    await db.setSetting('${CedarToyActivityStore.uncertainWritePrefix}$game',jsonEncode({
      'schema':1,'execution_id':'dead-runtime','state':'dispatching','action':'cmd',
      'query_attempts':priorQueryAttempts,'query_task_id':queryTaskId,
      'params':{'slot':1,'command':'old-mutation-do-not-repeat'}}));
    final staged=await stageCedarTask(db,session:session,turnId:'u',assistantId:'a',minutes:30);
    expect(await commitCedarTask(db,staged),true);
    await tasks.activateCommitted();
    return session;
  }

  CedarToyAutonomyEngine engine(_Game game,{bool missingKey=false}) {
    final ai=DeepSeekClient(streamClientFactory:()=>MockClient((request) async {
      final payload={'choices':[{'delta':{'tool_calls':[{'index':0,'id':'new-step','type':'function',
        'function':{'name':'cedar_toy_play','arguments':jsonEncode({'game':'bar','action':'cmd',
          'params_json':'{"slot":1,"command":"new-valid-step"}','participation_mode':'solo',
          'invitation_approved':false,'share_previous_outcome':false})}}]},'finish_reason':'tool_calls'}]};
      return http.Response('data: ${jsonEncode(payload)}\n\ndata: [DONE]\n\n',200,
        headers:{'content-type':'text/event-stream'});
    }));addTearDown(ai.close);
    return CedarToyAutonomyEngine(db:db,ai:ai,secureConfig:SecureConfig.instance,
      tokenReader:() async=>'ctai_v1_fixture',apiKeyReader:() async=>missingKey?'':'fixture',
      endpointReader:() async=>DeepSeekClient.defaultEndpoint,clientFactory:(_)=>game);
  }

  test('thirty minutes of checkpoints cannot consume a blocked task with zero moves',() async {
    await start();final at=DateTime.now();
    for(var i=1;i<=20;i++)await tasks.reconcile(at.add(Duration(seconds:90*i)));
    expect((await tasks.active())!['usedMs'],0);
    expect((await CedarPlaySessionStore(db).load())!.paused,true);
    expect(await tasks.pendingReports(),isEmpty);
    expect((await tasks.active())!['progressCount'],0);
  });

  test('real committed task rebuilds read route, queries same slot, then plans and plays a new step',() async {
    final session=await start();final client=_Game();final runner=engine(client);
    final repaired=await runner.continueDue(now:DateTime.now());
    expect(repaired.state,'write_reconciliation_scheduled');expect(client.actions,isEmpty);
    final recovered=(await activity.load())!;
    expect(recovered.continuationAction,'status');
    expect(jsonDecode(recovered.continuationParamsJson)['slot'],1);
    await activity.deferContinuation(gameId:'bar',delay:Duration.zero,
      now:DateTime.now().subtract(const Duration(seconds:1)));
    expect((await runner.continueDue(now:DateTime.now())).state,'write_reconciled');
    expect(client.actions,['status']);expect(client.slots,[1]);
    expect(await activity.unresolvedWrite('bar'),isNull);
    expect((await tasks.active())!['progressCount'],0);
    await activity.deferContinuation(gameId:'bar',delay:Duration.zero,
      now:DateTime.now().subtract(const Duration(seconds:1)));
    expect((await runner.continueDue(now:DateTime.now())).state,'played_one_step');
    expect(client.actions,['status','cmd']);
    expect((await activity.load())!.id,session.id);
    expect((await tasks.active())!['progressCount'],1);
    expect((await tasks.active())!['toolCalls'],2);
    expect((await tasks.active())!['planningRounds'],1);
    expect((await activity.load())!.events.last.inputJson,contains('new-valid-step'));
  });

  test('three failed queries stop with a factual zero-progress report and never replay the mutation',() async {
    await start();final client=_Game()..fail=true;final runner=engine(client);
    await runner.continueDue(now:DateTime.now());
    for(var i=0;i<3;i++) {
      await activity.deferContinuation(gameId:'bar',delay:Duration.zero,
        now:DateTime.now().subtract(const Duration(seconds:1)));
      await runner.continueDue(now:DateTime.now());
    }
    expect(client.actions,['status','status','status']);
    expect(await tasks.active(),isNull);
    final report=(await tasks.pendingReports()).single;
    expect(report['progressCount'],0);expect(report['usedMs'],0);
    expect(report['reason'],'blocked_unresolved_write');
    expect(await activity.unresolvedWrite('bar'),isNotNull);
    expect(await CedarPlaySessionStore(db).load(),isNull);
    await runner.continueDue(now:DateTime.now());expect(client.actions,hasLength(3));
  });

  test('a new committed task can query again after an older task exhausted its reads',() async {
    await start(priorQueryAttempts:3,queryTaskId:'cedar-task:older-request');
    final client=_Game()..fail=true;final runner=engine(client);
    expect((await runner.continueDue(now:DateTime.now())).state,'write_reconciliation_scheduled');
    await activity.deferContinuation(gameId:'bar',delay:Duration.zero,
      now:DateTime.now().subtract(const Duration(seconds:1)));
    await runner.continueDue(now:DateTime.now());
    expect(client.actions,['status']);
    final marker=(await activity.unresolvedWrite('bar'))!;
    expect(marker['query_attempts'],1);expect(marker['query_task_id'],'cedar-task:u');
    expect(await tasks.active(),isNotNull);
  });

  test('an unknown query protocol reports blockage without guessing a write or spending time',() async {
    await start(guide:'单人游戏。cmd 执行写操作。');final client=_Game();final runner=engine(client);
    expect((await runner.continueDue(now:DateTime.now())).state,'write_reconciliation_unavailable');
    expect(client.actions,isEmpty);expect(await tasks.active(),isNull);
    expect((await tasks.pendingReports()).single['reason'],'blocked_unresolved_write');
  });

  test('explicit pause cannot be undone by automatic unknown-write recovery',() async {
    await start();await activity.pauseAndRelease();final client=_Game();
    await engine(client).continueDue(now:DateTime.now());
    expect(client.actions,isEmpty);expect(await tasks.active(),isNull);
    expect((await activity.loadSession('bar'))!.phase,CedarActivityPhase.paused);
  });

  test('diagnostic never invents zero counts for legacy tasks or verified state mutations',() {
    final d=CedarTimedPlayTaskStore.diagnostic({'id':'legacy'},phase:'active',terminal:false);
    expect(d['planning_rounds'],isNull);expect(d['tool_calls'],isNull);
    expect(d['committed_mutations'],isNull);
  });
}
