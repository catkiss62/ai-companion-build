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
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
    FlutterSecureStorage.setMockInitialValues({});
    await db.setSetting('cedar_toy_enabled', '1');
    await db.setSetting('cedar_toy_autonomy_enabled', '1');
    store = CedarToyActivityStore(db);
    arcade = _Arcade();
    decisions = 0;
    final ai = DeepSeekClient(
      streamClientFactory: () => MockClient((r) async {
        final action = decisions++ == 0 ? 'show_solution' : 'look';
        final arguments = {
          'game': 'mystery_fixture',
          'action': action,
          'params_json': '{}',
          'participation_mode': 'puzzle',
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

  test(
    'first move applies the mode from the same decision; retry can investigate',
    () async {
      final session = await store.recordGuide(
        gameId: 'mystery_fixture',
        guide: '解谜游戏。look 调查，show_solution 查看完整解答',
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
