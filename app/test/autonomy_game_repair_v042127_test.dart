import 'dart:convert';
import 'package:ai_companion_localfirst/core/agent/turn_task_intent.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';
import 'package:ai_companion_localfirst/core/ai/dialogue_expression_plan.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/autonomy_prompt_revision.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_solo_episode_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_conversation_target.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _ResumeProbe extends CedarToyAutonomyEngine {
  _ResumeProbe(AppDatabase db) : super(db:db,ai:DeepSeekClient(),secureConfig:SecureConfig.instance);
  @override Future<CedarAutonomyProgress> continueDue({required DateTime now,bool episodeAuthorized=false}) async {
    expect(episodeAuthorized,isTrue);
    expect(await CedarToyActivityStore(db).nextContinuationDelay(now),Duration.zero,
      reason:'The resume writer and immediate due reader must use the same heartbeat clock');
    return const CedarAutonomyProgress('played_one_step');
  }
}
class _CatalogClient extends CedarToyClient {
  _CatalogClient() : super(token:'ctai_v1_test');
  int calls=0;
  bool fail=false;
  @override Future<McpToolOutcome> listGames({GenerationCancellationToken? cancellationToken}) async {
    calls++;
    return McpToolOutcome(isError:fail,content:[McpContentBlock(kind:McpContentKind.text,
      text:fail?'temporarily unavailable':'white_room·自由叙事，单人·test\nfishing·野外钓鱼，单人·test')]);
  }
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;
  setUp(()async{FlutterSecureStorage.setMockInitialValues({});db=await AppDatabase.createForTesting(databaseFactoryFfi);});
  tearDown(()async{await db.closeForTesting();});
  test('real checkpoint resume does not write a later clock before its immediate consumer',()async{
    final store=CedarToyActivityStore(db);
    await store.recordGuide(gameId:'fishing',guide:'单人钓鱼；cast 抛竿');
    await store.recordPlay(gameId:'fishing',action:'cast',outcome:const McpToolOutcome(
      isError:false,content:[McpContentBlock(kind:McpContentKind.text,text:'钓到小鱼')]),
      mode:CedarParticipationMode.solo,nextActor:'companion',shareLevel:'quiet',invitationApproved:false);
    final now=DateTime.now().subtract(const Duration(seconds:2));
    await db.setSetting(CedarToyAutonomyEngine.soloEpisodeKey,jsonEncode(CedarSoloEpisodeState(
      gameId:'fishing',startedAt:now.subtract(const Duration(minutes:10)),stateChangeCount:3,
      checkpointPending:true,checkpointReason:'state_change_limit').toJson()));
    final result=await _ResumeProbe(db).resumeCheckpoint(now:now,selfReset:false);
    expect(result.state,'played_one_step');
    final saved=jsonDecode((await db.getSetting(CedarToyAutonomyEngine.soloEpisodeKey))!) as Map;
    expect(saved['checkpoint_pending'],false);
  });
  test('daily lightweight catalog refresh retains cache on failure and backs off',()async{
    final client=_CatalogClient();final ai=DeepSeekClient();addTearDown(ai.close);
    final engine=CedarToyAutonomyEngine(db:db,ai:ai,secureConfig:SecureConfig.instance,
      tokenReader:()async=>'ctai_v1_test',clientFactory:(_)=>client);
    final now=DateTime(2026,10,23,12);
    expect((await engine.refreshCatalogIfDue(now)).state,'catalog_refreshed');
    expect((await engine.refreshCatalogIfDue(now.add(const Duration(hours:2)))).state,'catalog_current');
    expect(client.calls,1);
    final store=CedarToyActivityStore(db);final old=await store.loadCatalog();client.fail=true;
    expect((await engine.refreshCatalogIfDue(now.add(const Duration(days:1)))).state,'catalog_refresh_failed_cached');
    expect(await store.loadCatalog(),old);
    expect((await engine.refreshCatalogIfDue(now.add(const Duration(days:1,minutes:5)))).state,'catalog_refresh_backoff');
    expect(client.calls,2);
  });
  test('complete lightweight catalog and confirmed aliases reach the same semantic target',()async{
    final catalog=[for(var i=0;i<70;i++)'game_$i·游戏$i，单人·test',
      'white_room·自由叙事，单人·test'].join('\n');
    final q=TurnTaskQuestionSet(userText:'去白房间玩半小时',state:await CedarToyActivityStore(db).loadState(),works:const [],catalog:catalog);
    expect(q.games,hasLength(71));
    final target=q.games.entries.singleWhere((e)=>e.value.id=='white_room').key;
    expect(q.context.toString(),contains('白房间'));
    expect(q.questions['task_game_target']!.toString(),isNotEmpty);
    final task=q.interpret({'task_game':'play','task_game_target':target,'task_duration':'d0','task_creative':'none','cedar':'act_now'},
      details:{'task_game':const JevChoiceDecision(choice:'play',probabilities:{'play':.51,'none':.43},ambiguous:true),
        'cedar':const JevChoiceDecision(choice:'act_now',probabilities:{'act_now':1},ambiguous:false)});
    expect(task.gameExecutionResolved,true);expect(task.minutes,30);
    expect(task.goals('u').every((g)=>g.authorized),true);
    expect(CedarCatalogParser.displayAliases('white_room'),contains('白房间'));
    expect(CedarConversationTarget.recentGameId(latestUserText:'白房间',now:DateTime.now(),previous:const [],catalog:catalog),'white_room');
  });
  test('cached invitation reconciliation cannot resolve targets, time or a stop',(){
    final old=const TurnTaskIntent(available:true,gameAction:'play',gameId:'fishing',invitationCanResolveAction:true,
      unresolvedFields:{'task_game','task_game_target','task_duration'},durationResolved:false);
    final reconciled=old.resolvePresentInvitation(cedarIntent:'accept',certain:true);
    expect(reconciled.unresolvedFields,{'task_game_target','task_duration'});
    expect(reconciled.gameExecutionResolved,false);expect(reconciled.durationResolved,false);
    expect(old.resolvePresentInvitation(cedarIntent:'defer',certain:true),same(old));
    expect(old.resolvePresentInvitation(cedarIntent:'accept',certain:false),same(old));
  });
  test('approved retreat clauses are removed without replacing surrounding custom rules or controls',()async{
    final sql=await db.database;
    await sql.delete('settings',where:'key = ?',whereArgs:[autonomyPromptRevisionMarker]);
    const id='fixture-personality-spectrum';
    const original='自定义前文。偶尔得意、顶嘴或短暂闹别扭；对方明确拒绝或话题转为认真时自然收住，保留口语。\n'
      '仍然接住对方真正说的事，认真场合收住脾气，不强行羞辱或替对方决定行动。\n自定义末尾。';
    await sql.insert('reference_documents',{'id':id,'name':'性格光谱','kind':'character',
      'aliases':'','raw_content':original,'enabled':0,'created_at':1,'updated_at':1,
      'entry_type':'behavior','activation_mode':'always','activation_probability':37});
    await migrateAutonomyPromptsV042127(sql);
    final after=(await sql.query('reference_documents',where:'id = ?',whereArgs:[id])).single;
    expect(after['enabled'],0);expect(after['activation_probability'],37);
    expect(after['raw_content'],contains('自定义前文'));expect(after['raw_content'],contains('自定义末尾'));
    expect(after['raw_content'],isNot(contains('认真时自然收住')));
    expect(after['raw_content'],contains('不替对方决定行动'));
    await sql.update('reference_documents',{'raw_content':'后来自己编辑的新稿'},where:'id = ?',whereArgs:[id]);
    await migrateAutonomyPromptsV042127(sql);
    expect((await sql.query('reference_documents',where:'id = ?',whereArgs:[id])).single['raw_content'],'后来自己编辑的新稿');
    final contract=PromptBuilder.capabilityPersonaContract();
    expect(contract,contains('是否接受请求'));expect(contract,isNot(contains('先真正满足内容要求')));
    expect(DialogueExpressionPlan.select(latestUserText:'你又来了').render(),isNot(contains('识别他具体指出的失败维度')));
  });
}
