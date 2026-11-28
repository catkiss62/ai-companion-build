import 'dart:convert';

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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Arcade extends CedarToyClient {
  _Arcade() : super(token: 'ctai_v1_synthetic');
  final received = <Map<String,Object?>>[];
  McpToolOutcome? nextResult;
  final plays = <String>[];
  final guides = <String>[];
  String guide = '独立解谜。look 调查，open_book 揭晓完整谜底。';
  @override
  Future<McpToolOutcome> getGuide(
    String game, {
    GenerationCancellationToken? cancellationToken,
  }) async {
    guides.add(game);
    return McpToolOutcome(
      isError: false,
      content: [McpContentBlock(kind: McpContentKind.text, text: guide)],
    );
  }

  @override
  Future<McpToolOutcome> play(
    String game,
    String action,
    Map<String, Object?> params, {
    GenerationCancellationToken? cancellationToken,
  }) async {
    plays.add(action);
    received.add(params);
    if(nextResult != null) { final result=nextResult!; nextResult=null; return result; }
    return const McpToolOutcome(
      isError: false,
      content: [McpContentBlock(kind: McpContentKind.text, text: '游戏已结束')],
      structuredContent: {'next_actor': 'finished'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CedarToyActivityStore store;
  late _Arcade arcade;
  late CedarToyAutonomyEngine engine;
  var decisions = 0;
  var plannedGame = 'mystery_fixture';
  var firstAction = 'show_solution';
  var plannedMode = 'puzzle';
  var proposedParams=<String,Object?>{};
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
    FlutterSecureStorage.setMockInitialValues({});
    await db.setSetting('cedar_toy_enabled', '1');
    await db.setSetting('cedar_toy_autonomy_enabled', '1');
    store = CedarToyActivityStore(db);
    arcade = _Arcade();
    decisions = 0;
    plannedGame='mystery_fixture';
    firstAction='show_solution'; plannedMode='puzzle'; proposedParams={};
    final ai = DeepSeekClient(
      streamClientFactory: () => MockClient((r) async {
        final action = decisions++ == 0 ? firstAction : 'look';
        final arguments = {
          'game': plannedGame,
          'action': action,
          'params_json': jsonEncode(proposedParams),
          'participation_mode': plannedMode,
          'invitation_approved': false,
          'share_previous_outcome': false,
        };
        final payload = {
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'id': 'choice',
                    'type': 'function',
                    'function': {
                      'name': 'cedar_toy_play',
                      'arguments': jsonEncode(arguments),
                    },
                  },
                ],
              },
              'finish_reason': 'tool_calls',
            },
          ],
        };
        return http.Response(
          'data: ${jsonEncode(payload)}\n\ndata: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      }),
    );
    addTearDown(ai.close);
    engine = CedarToyAutonomyEngine(
      db: db,
      ai: ai,
      secureConfig: SecureConfig.instance,
      tokenReader: () async => 'ctai_v1_test',
      apiKeyReader: () async => 'test',
      endpointReader: () async => DeepSeekClient.defaultEndpoint,
      clientFactory: (_) => arcade,
    );
  });

  Future<DateTime> makeDue(CedarGameSession s) async {
    final now = DateTime.now();
    await store.save(
      s.copyWith(nextActionAt: now.subtract(const Duration(seconds: 1))),
    );
    const taskId = 'cedar-task:guide';
    await db.setSetting(
      CedarTimedPlayTaskStore.activeKey,
      jsonEncode({
        'id': taskId,
        'gameId': s.gameId,
        'sessionId': s.id,
        'minutes': 30,
        'startedAt': now.millisecondsSinceEpoch,
        'usedMs': 0,
      }),
    );
    await CedarPlaySessionStore(db).save(
      CedarPlaySession(
        gameId: s.gameId,
        startedAt: now,
        lastTickAt: now,
        taskId: taskId,
        limitMs: 1800000,
      ),
    );
    return now;
  }

  McpToolOutcome nextCall(String action, Map<String,Object?> params) => McpToolOutcome(
    isError:false, content:const [McpContentBlock(kind:McpContentKind.text,text:'等待新的局面')],
    structuredContent:{'next_actor':'wait','wait_scope':'current_request_only',
      'next_call':{'game':'puzzle_box','action':action,'params':params}});

  Future<CedarGameSession> pending(String action,Map<String,Object?> params) =>
    store.recordPlay(gameId:'puzzle_box',action:'look',mode:CedarParticipationMode.puzzle,
      nextActor:'wait',shareLevel:'quiet',invitationApproved:false,outcome:nextCall(action,params));


  for(final layout in ['plain','markdown','json']) {
    test('explicit puzzle declarations at first MCP dispatch: $layout',() async {
      plannedMode='solo';
      final guide=switch(layout){
        'plain'=>'独立解谜。look 调查。show_solution 查看完整答案。',
        'markdown'=>'# 钟楼\n\n游戏类型：独立解谜\nlook 调查。show_solution 查看完整答案。',
        _=>jsonEncode({'game':'钟楼','mode':'puzzle','actions':[{'name':'look','description':'调查'},{'name':'show_solution','description':'查看完整答案'}]}),
      };
      final s=await store.recordGuide(gameId:plannedGame,guide:guide);
      await engine.continueDue(now:await makeDue(s));
      expect(s.mode,CedarParticipationMode.puzzle);
      expect(arcade.plays,['look']);
    });
  }
  test('restores automatic preference after a known guide revision', () async {
    const game='seasonal_puzzle';
    await store.recordGuide(gameId:game,guide:'单人游戏。look 观察。');
    final revised=await store.recordGuide(gameId:game,guide:'独立解谜。look 调查。');
    expect(revised.mode,CedarParticipationMode.puzzle);
    expect(await store.selectPlayMode(revised,preference:'co_play'),true);
    final manual=(await store.loadState()).sessions[game]!;
    expect(manual.mode,CedarParticipationMode.coPlay);
    expect(await store.selectPlayMode(manual,preference:'auto'),true);
    final auto=(await store.loadState()).sessions[game]!;
    print('restores automatic state ${auto.mode} preference ${auto.puzzle.preference}');
    expect(auto.mode,CedarParticipationMode.puzzle);
  });
  test('explicit puzzle guide protects first move despite solo proposal', () async {
    plannedMode='solo';
    final session=await store.recordGuide(gameId:plannedGame,guide:'独立解谜。look 调查。show_solution 查看完整答案。');
    expect(session.mode,CedarParticipationMode.puzzle);
    await engine.continueDue(now:await makeDue(session));
    expect(arcade.plays,['look']);
  });

  for (final explicitOther in [true,false]) {
    test('revised game outcome-only room $explicitOther',() async {
      plannedGame='puzzle_box'; firstAction='walk';
      proposedParams = explicitOther ? {'room_id':'R8'} : {};
      await store.recordGuide(gameId:plannedGame,guide:'独立解谜。old_move 移动；look 查看局面。');
      final result=McpToolOutcome(isError:false,content:const [],structuredContent:{'room_id':'R7','next_actor':'wait','wait_scope':'current_request_only','next_call':{'game':'puzzle_box','action':'old_move','params':{}}});
      final old=await store.recordPlay(gameId:plannedGame,action:'look',mode:CedarParticipationMode.puzzle,nextActor:'wait',shareLevel:'quiet',invitationApproved:false,outcome:result);
      await store.save(old.copyWith(nextActor:'companion'));
      final revised=await store.recordGuide(gameId:plannedGame,
        guide:'独立解谜。已移除 old_move。walk 移动一步，须提供 room_id；look 查看当前局面。');
      expect(revised.continuationNeedsReview,true);
      expect(revised.lastOutcome,contains('R7')); expect(jsonDecode(revised.continuationParamsJson),isEmpty);
      await engine.continueDue(now:await makeDue(revised));
      if (explicitOther) {
        expect(arcade.received.where((p)=>p['room_id']=='R8'),isEmpty);
      } else {
        expect(arcade.plays,['walk']); expect(arcade.received.single['room_id'],'R7');
      }
    });
  }

  test('conflicting server room list cannot authorize a revised write', () async {
    await store.recordGuide(gameId:'puzzle_box',guide:'独立解谜。old_move 移动。');
    final old=await pending('old_move',{});
    await store.save(old.copyWith(nextActor:'companion',lastOutcome:'{"rooms":[{"room_id":"A"},{"room_id":"B"}]}'));
    final revised=await store.recordGuide(gameId:'puzzle_box',guide:'独立解谜。walk 移动。rooms 查看房间。');
    expect(revised.permitsRevisedCall('walk',{'room_id':'A'}),false);
    expect(revised.permitsRevisedCall('walk',{}),false);
    expect(revised.permitsRevisedCall('rooms',{}),true);
  });

  for (final explicitOther in [true,false]) {
    test('guide change preserves current room $explicitOther',() async {
      plannedGame='puzzle_box'; firstAction='walk';
      proposedParams = explicitOther ? {'room_id':'R8'} : {};
      await store.recordGuide(gameId:plannedGame,guide:'独立解谜。old_move 移动；look 查看局面。');
      final old=await pending('old_move',{'room_id':'R7'});
      await store.save(old.copyWith(nextActor:'companion'));
      final revised=await store.recordGuide(gameId:plannedGame,
        guide:'独立解谜。已移除 old_move。walk 移动一步，须提供 room_id；look 查看当前局面。');
      expect(revised.continuationNeedsReview,true);
      expect(jsonDecode(revised.continuationParamsJson)['room_id'],'R7');
      await engine.continueDue(now:await makeDue(revised));
      if (explicitOther) {
        expect(arcade.received.where((p)=>p['room_id']=='R8'),isEmpty);
      } else {
        expect(arcade.plays,['walk']); expect(arcade.received.single['room_id'],'R7');
      }
    });
  }

  test('revised guide puts the retirement verb ahead of the action',() async {
    plannedGame='puzzle_box'; firstAction='legacy_move';
    await store.recordGuide(gameId:plannedGame,guide:'独立解谜。legacy_move 移动；look 查看局面。');
    final old=await pending('legacy_move',{'room_id':'R7'});
    await store.save(old.copyWith(nextActor:'companion'));
    final revised=await store.recordGuide(gameId:plannedGame,
      guide:'独立解谜。已移除 legacy_move。walk 移动；look 查看当前局面。');
    expect(revised.continuationNeedsReview,true);
    expect(revised.permitsRevisedCall('legacy_move',{}),false);
    expect(revised.copyWith(guide:'没有移除 legacy_move，仍可使用。')
      .permitsRevisedCall('legacy_move',{}),true);
    final result=await engine.continueDue(now:await makeDue(revised));
    expect(arcade.plays,['look'],reason:result.state);
  });

  for (final testCase in ['common_description','flag_equals','flag_space','safe_flag']) {
    test('MCP dispatch $testCase',() async {
      final guide=jsonEncode({'actions':[{'name':'read_page',
        'description': testCase=='common_description' ? '可以阅读线索，也可以查看完整谜底' : '翻书',
        'parameters':{'properties':{'page':{'oneOf':[
          {'const':'notes','description':'阅读线索'},
          {'const':'last_leaf','description':'揭晓完整谜底'}]}}}}]});
      await store.recordGuide(gameId:'puzzle_box', guide:guide);
      final action=testCase=='common_description'?'read_page':'cmd';
      final args=<String,Object?>{if(action=='read_page') 'page':'notes' else
        'command':switch(testCase){'flag_equals'=>'read_page --page=last_leaf',
          'safe_flag'=>'read_page --page notes', _=>'read_page --page last_leaf'}};
      final result=await engine.continueDue(now:await makeDue(await pending(action,args)));
      if(testCase=='flag_space'||testCase=='flag_equals') {
        expect(arcade.plays,isEmpty);
      }else {
        expect(arcade.plays,[action], reason:result.state);
        expect(arcade.received.single,containsPair(args.keys.single,args.values.single));
      }
    });
  }

  for(final page in ['notes','last_leaf']) {
    test('shared navigation verifies chosen option before dispatch: $page',() async {
      final guide=jsonEncode({'actions':[{'name':'read_page','description':'翻书','parameters':{
        'properties':{'page':{'oneOf':[{'const':'notes','description':'阅读线索'},
          {'const':'last_leaf','description':'揭晓完整谜底'}]}}}}]});
      await store.recordGuide(gameId:'puzzle_box',guide:guide);
      final s=await pending('read_page',{'page':page});
      final result=await engine.continueDue(now:await makeDue(s));
      if(page=='notes') {
        expect(arcade.received.single['page'],page);
      } else {
        expect(result.state,'puzzle_continuation_withheld');
        expect(arcade.plays,isEmpty);
      }
    });
  }

  test('revised rules recheck the same room then accept fresh server extension',() async {
    plannedGame='puzzle_box'; firstAction='legacy_move';
    await store.recordGuide(gameId:plannedGame,guide:'独立解谜。legacy_move 移动；look 查看局面。');
    final old=await pending('legacy_move',{'room_id':'R7'});
    final revised=await store.recordGuide(gameId:plannedGame,
      guide:'独立解谜。legacy_move 已停用；walk 移动；look 查看局面，可传 room_id。');
    expect(revised.id,old.id);
    expect(revised.nextActor,old.nextActor);
    expect(revised.continuationNeedsReview,true);
    arcade.nextResult=nextCall('server_extension',{'room_id':'R7'});
    final result=await engine.continueDue(now:await makeDue(revised));
    expect(arcade.plays,['look'],reason:result.state);
    expect(arcade.received.single['room_id'],'R7');
    final fresh=(await store.load())!;
    expect(fresh.continuationNeedsReview,false);
    await engine.continueDue(now:await makeDue(fresh));
    expect(arcade.plays,['look','server_extension']);
  });

  test(
    'first move applies the mode from the same decision; retry can investigate',
    () async {
      final session = await store.recordGuide(
        gameId: 'mystery_fixture',
        guide: '玩家指南。look 调查，show_solution 查看完整解答',
      );
      expect(session.mode, CedarParticipationMode.unknown);
      final result = await engine.continueDue(now: await makeDue(session));
      expect(arcade.plays, ['look'], reason: result.state);
      expect(arcade.guides, isEmpty);
      expect(decisions, greaterThanOrEqualTo(2));
    },
  );

  for (final actor in ['wait', 'user']) {
    test(
      'blocked server continuation is consumed once and preserves $actor',
      () async {
        await store.recordGuide(gameId: 'puzzle_box', guide: arcade.guide);
        final session = await store.recordPlay(
          gameId: 'puzzle_box',
          action: 'look',
          mode: CedarParticipationMode.puzzle,
          nextActor: actor,
          shareLevel: 'quiet',
          invitationApproved: false,
          outcome: McpToolOutcome(
            isError: false,
            content: const [
              McpContentBlock(kind: McpContentKind.text, text: '进度'),
            ],
            structuredContent: {
              'next_actor': actor,
              'wait_scope': 'current_request_only',
              'next_call': {
                'game': 'puzzle_box',
                'action': 'open_book',
                'params': {},
              },
            },
          ),
        );
        final result = await engine.continueDue(now: await makeDue(session));
        final after = (await store.load())!;
        expect(result.state, 'puzzle_continuation_withheld');
        expect(arcade.plays, isEmpty);
        expect(after.hasContinuationCall, false);
        expect(after.nextActor, actor);
        expect(after.id, session.id);
        if (actor == 'user') expect(after.nextActionAt, isNull);
      },
    );
  }

  test(
    'only selected stale guide is refreshed; same guide preserves actor and manual choice',
    () async {
      final old = await store.recordGuide(
        gameId: 'mystery_fixture',
        guide: '单人游戏。look 参观',
      );
      final session = old.copyWith(
        phase: CedarActivityPhase.active,
        mode: CedarParticipationMode.solo,
        guideCheckedAt: DateTime(2020),
      );
      final result = await engine.continueDue(now: await makeDue(session));
      expect(result.state, 'guide_refreshed');
      expect(arcade.guides, ['mystery_fixture']);
      expect(arcade.plays, isEmpty);
      expect(decisions, 0);
      final current = (await store.load())!;
      expect(current.id, old.id);
      expect(current.mode, CedarParticipationMode.puzzle);
      expect(current.guideNeedsRefresh(DateTime.now()), false);
      await store.selectPlayMode(current, preference: 'co_play');
      final manual = await store.recordGuide(
        gameId: old.gameId,
        guide: '新指南。look 参观。',
      );
      expect(manual.mode, CedarParticipationMode.coPlay);
      final incomplete = await store.recordGuide(
        gameId: old.gameId,
        guide: '新' * (CedarToyActivityStore.maxGuidePromptChars + 1),
      );
      expect(incomplete.guideComplete, false);
      expect(incomplete.id, old.id);
      expect(incomplete.guide, manual.guide);
      expect(incomplete.companionCanContinue, false);
      final recovered = await store.recordGuide(
        gameId: old.gameId,
        guide: manual.guide,
      );
      expect(recovered.guideComplete, true);
      expect(recovered.mode, CedarParticipationMode.coPlay);
    },
  );

  test(
    'player guesses, host questions and hints coexist with guide-specific spoiler commands',
    () {
      const guide =
          'look 查看线索；ask 向主持人提问；submit 提交自己的答案；flip 揭晓完整谜底；hint 提供局部提示，不会揭示谜底';
      bool blocks(String action, [Map<String, Object?> params = const {}]) =>
          CedarPuzzleState.revealsSolution(
            CedarParticipationMode.puzzle,
            action,
            params,
            guide: guide,
          );
      expect(blocks('flip'), true);
      expect(blocks('cmd', {'command': 'flip'}), true);
      expect(blocks('look'), false);
      expect(blocks('ask', {'text': '答案和时间有关吗？'}), false);
      expect(blocks('submit', {'answer': 'flip'}), false);
      expect(blocks('hint'), false);
      final json = jsonEncode({
        'actions': [
          {'name': 'book', 'description': 'reveal the full solution'},
          {'name': 'talk', 'description': 'ask a witness'},
        ],
      });
      expect(
        CedarPuzzleState.revealsSolution(
          CedarParticipationMode.puzzle,
          'book',
          {},
          guide: json,
        ),
        true,
      );
      expect(
        CedarPuzzleState.revealsSolution(
          CedarParticipationMode.puzzle,
          'talk',
          {},
          guide: json,
        ),
        false,
      );
    },
  );
}
