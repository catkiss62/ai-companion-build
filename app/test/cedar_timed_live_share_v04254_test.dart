import 'dart:convert';

import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_live_share_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_session_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_protocol.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<CedarGameSession> guide(AppDatabase db) =>
    CedarToyActivityStore(db)
        .recordGuide(gameId: 'white_room', guide: '单人游戏。start 开始；explore 探索。');

Future<CedarGameSession> outcome(
  AppDatabase db,
  String text, {
  String action = 'explore',
  String actor = 'companion',
}) => CedarToyActivityStore(db).recordPlay(
  gameId: 'white_room',
  action: action,
  outcome: McpToolOutcome(
    content: [McpContentBlock(kind: McpContentKind.text, text: text)],
    isError: false,
    structuredContent: {'next_actor': actor},
  ),
  mode: CedarParticipationMode.solo,
  nextActor: actor,
  shareLevel: 'quiet',
  invitationApproved: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
  });
  tearDown(() async {
    await db.closeForTesting();
  });

  test('duration is a verbatim bounded request, never an invented default', () {
    expect(CedarTimedPlayTaskStore.durationMinutes('半小时', '你去玩半小时白色房间'), 30);
    expect(CedarTimedPlayTaskStore.durationMinutes('三十分钟', '现在玩三十分钟'), 30);
    expect(CedarTimedPlayTaskStore.durationMinutes('10分钟', '玩10分钟看看'), 10);
    expect(CedarTimedPlayTaskStore.durationMinutes('半小时', '你可以自己玩玩'), isNull);
    expect(CedarTimedPlayTaskStore.durationMinutes('60分钟', '去玩60分钟'), isNull);
    expect(CedarTimedPlayTaskStore.durationMinutes('0分钟', '去玩0分钟'), isNull);
  });

  test('native timed tool remains a user-only semantic action', () {
    final plan = AgentToolPlanner.fromNativeToolCalls(
      [
        const DeepSeekToolCall(
          id: 'timed',
          name: 'cedar_toy_start_timed_play',
          arguments: '{"game":"white_room","duration_text":"半小时"}',
        ),
      ],
      latestUserText: '你现在去玩半小时白色房间，看看结果',
      cedarSessionActive: true,
    );
    expect(plan.calls.single.toolId, 'cedar_toy.start_timed_play');
    expect(plan.calls.single.reasonTag, 'explicit_request');
    final automatic = AgentToolPlanner.fromNativeToolCalls(
      [
        const DeepSeekToolCall(
          id: 'timed',
          name: 'cedar_toy_start_timed_play',
          arguments: '{"game":"white_room","duration_text":"半小时"}',
        ),
      ],
      origin: AgentToolOrigin.autonomous,
      cedarSessionActive: true,
    );
    expect(automatic.calls, isEmpty);
  });

  test('stopped or failed reply cannot activate a staged task', () async {
    final session = await guide(db);
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.stage(
      turnId: 'user',
      assistantId: 'missing-reply',
      session: session,
      minutes: 30,
    );
    await tasks.activateCommitted(turnId: 'user');
    expect(await tasks.active(), isNull);
    expect(await CedarPlaySessionStore(db).load(), isNull);
  });

  Future<void> start({int minutes = 30}) async {
    final session = await guide(db);
    await CedarTimedPlayTaskStore(db).stage(
      turnId: 'user',
      assistantId: 'reply',
      session: session,
      minutes: minutes,
    );
    await db.insertMessage(
      ChatMessage(
        id: 'reply',
        role: 'assistant',
        content: '好，我去玩一会儿，结束后告诉你。',
        createdAt: DateTime.now(),
      ),
    );
    await CedarTimedPlayTaskStore(db).activateCommitted(turnId: 'user');
  }

  test(
    'committed reply admits task immediately and retry does not extend it',
    () async {
      await start(minutes: 10);
      final periods = CedarPlaySessionStore(db);
      final first = (await periods.load())!;
      expect(first.limitMs, 600000);
      expect(first.taskId, 'cedar-task:user');
      await CedarTimedPlayTaskStore(db).activateCommitted(turnId: 'user');
      expect((await periods.load())!.startedAt, first.startedAt);
      var tick = first.tick(
        first.startedAt.add(const Duration(minutes: 1)),
        pause: true,
      );
      tick = tick.tick(first.startedAt.add(const Duration(minutes: 5)));
      expect(tick.usedMs, 60000);
      expect(tick.limitMs, 600000);
    },
  );

  test('early finish reports actual progress once even when ambient sharing is off', () async {
    await start();
    await db.setSetting('cedar_toy_game_share_enabled', '0');
    await outcome(db, '找到了出口，白色房间已结束。', actor: 'finished');
    final tasks = CedarTimedPlayTaskStore(db);
    await tasks.reconcile(DateTime.now());
    expect(await tasks.active(), isNull);
    final report = (await tasks.pendingReports()).single;
    expect(report['reason'], 'finished_or_waiting_user');
    expect(report['progressCount'], 1);
    expect(report['usedMs'], lessThan(1800000));
    final thoughtId = (await tasks.queueReport())!;
    expect((await db.thoughtById(thoughtId))!.lifecycleState, 'task_report');
    await db.insertMessage(
      ChatMessage(
        id: 'cedar-share:$thoughtId',
        role: 'assistant',
        content: '找到出口了，这局提前结束。',
        createdAt: DateTime.now(),
      ),
    );
    await tasks.queueReport(); // Recovery after commit, before acknowledgement.
    expect(await tasks.pendingReports(), isEmpty);
  });

  test(
    'a committed pause stops the timed task and cannot revive a pending grant',
    () async {
      await start();
      final tasks = CedarTimedPlayTaskStore(db);
      await tasks.stage(
        turnId: 'another',
        assistantId: 'not-committed',
        session: (await CedarToyActivityStore(db).load())!,
        minutes: 30,
      );
      await db.setSettingsAtomically({
        'nsfw_route_turn_id': 'pause',
        'cedar_game_attitude_route_signal': 'pause',
        'cedar_game_attitude_route_game': 'white_room',
      });
      await CedarGameAttitudeStore(db)
          .commit(turnId: 'pause', now: DateTime.now());
      expect(await tasks.active(), isNull);
      expect(await db.getSetting(CedarTimedPlayTaskStore.pendingKey), '');
      expect(await CedarToyActivityStore(db).load(), isNull);
      expect((await tasks.pendingReports()).single['reason'], 'user_pause');
    },
  );

  test('budget completion parks only the authorized activity', () async {
    await start(minutes: 1);
    final store = CedarPlaySessionStore(db);
    final period = (await store.load())!;
    await store.save(
      period.tick(period.startedAt.add(const Duration(minutes: 1))),
    );
    await CedarTimedPlayTaskStore(db)
        .reconcile(period.startedAt.add(const Duration(minutes: 1)));
    expect(await store.load(), isNull);
    expect(await CedarToyActivityStore(db).load(), isNull);
    final report = (await CedarTimedPlayTaskStore(db).pendingReports()).single;
    expect(report['reason'], 'budget_complete');
    expect(report['usedMs'], 60000);
  });

  test('restored process epoch produces an interruption report, never resumes play', () async {
    await start();
    final raw =
        jsonDecode((await db.getSetting(CedarPlaySessionStore.key))!) as Map;
    raw['processEpoch'] = 'a-different-process';
    raw['usedMs'] = 120000;
    await db.setSetting(CedarPlaySessionStore.key, jsonEncode(raw));
    await CedarTimedPlayTaskStore(db).reconcile(DateTime.now());
    final report = (await CedarTimedPlayTaskStore(db).pendingReports()).single;
    expect(report['reason'], 'runtime_interrupted');
    expect(report['usedMs'], 120000);
    expect(await CedarPlaySessionStore(db).load(), isNull);
    expect(await CedarToyActivityStore(db).load(), isNull);
  });

  test(
    'structured quiet results can be shared, and queued evidence coalesces',
    () async {
      await guide(db);
      await CedarToyActivityStore(db).setViewingPace(CedarViewingPace.fast);
      final first = await outcome(db, '发现了一扇隐藏的门。');
      final shares = CedarLiveSharePolicy(db);
      await shares.offer(first, share: true, now: DateTime.now());
      final id = (await CedarToyActivityStore(db).pendingDirectShares()).single;
      final second = await outcome(db, '门后出现了一条新路线。');
      await shares.offer(second, share: true, now: DateTime.now());
      expect(await CedarToyActivityStore(db).pendingDirectShares(), [id]);
      await db.insertMessage(
        ChatMessage(
          id: 'cedar-share:$id',
          role: 'assistant',
          content: '发现了一扇隐藏门！',
          createdAt: DateTime.now(),
        ),
      );
      await shares.noteDelivered(id);
      await CedarToyActivityStore(db).removeDirectShare(id);
      final third = await outcome(db, '沿新路线继续发现了房间。');
      await shares.offer(third, share: true, now: DateTime.now());
      final nextId = (await CedarToyActivityStore(
        db,
      ).pendingDirectShares()).single;
      expect(nextId, isNot(id));
      expect((await db.thoughtById(nextId))!.text, isNot(contains('隐藏的门')));
      await shares.offer(third, share: true, now: DateTime.now());
      expect(await CedarToyActivityStore(db).pendingDirectShares(), [nextId]);
    },
  );

  test(
    'snapshot, repeated read and already shown foreground results stay quiet',
    () async {
      await guide(db);
      final snapshot = await outcome(db, '重读旧结果', action: 'get_result');
      final shares = CedarLiveSharePolicy(db);
      await shares.offer(snapshot, share: true, now: DateTime.now());
      final state = await outcome(db, '当前状态', action: 'state');
      await shares.offer(state, share: true, now: DateTime.now());
      expect(await CedarToyActivityStore(db).pendingDirectShares(), isEmpty);
      final foreground = await outcome(db, '用户要求的这一动作已完成');
      await shares.noteForeground(foreground);
      await shares.offer(foreground, share: true, now: DateTime.now());
      expect(await CedarToyActivityStore(db).pendingDirectShares(), isEmpty);
    },
  );

  test(
    'share choice piggybacks on exactly one existing native planning request',
    () async {
      var requests = 0;
      final ai = DeepSeekClient(
        streamClientFactory: () => MockClient((request) async {
          requests++;
          final body = jsonDecode(request.body) as Map;
          final parameters = body['tools'][0]['function']['parameters'] as Map;
          expect(parameters['required'], contains('share_previous_outcome'));
          final payload = jsonEncode({
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'id': 'move',
                      'type': 'function',
                      'function': {
                        'name': 'cedar_toy_play',
                        'arguments': jsonEncode({
                          'game': 'white_room',
                          'action': 'explore',
                          'params_json': '{}',
                          'participation_mode': 'solo',
                          'invitation_approved': false,
                          'share_previous_outcome': true,
                        }),
                      },
                    },
                  ],
                },
                'finish_reason': 'tool_calls',
              },
            ],
          });
          return http.Response(
            'data: $payload\n\ndata: [DONE]\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );
      addTearDown(ai.close);
      final decision = await CedarAgentActionPlanner(ai: ai).decide(
        apiKey: 'test',
        endpoint: DeepSeekClient.defaultEndpoint,
        gameId: 'white_room',
        instruction: '根据真实状态继续探索并判断前面新发现。',
        acceptsAction: (action) => action == 'explore',
      );
      expect(decision.sharePreviousOutcome, isTrue);
      expect(requests, 1);
    },
  );
}
