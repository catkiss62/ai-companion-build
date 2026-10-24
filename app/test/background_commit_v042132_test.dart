import 'dart:convert';
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

class _Game extends CedarToyClient {
  _Game() : super(token: 'ctai_v1_fixture');
  final calls = <String>[];
  @override Future<String> getPlayerPlayProtocol({GenerationCancellationToken? cancellationToken}) async => '';
  @override Future<McpToolOutcome> play(String game, String action, Map<String, Object?> params,
      {GenerationCancellationToken? cancellationToken}) async {
    calls.add(action);
    if (action == 'state') expect(params['room_id'], 'ROOM-ONE');
    return McpToolOutcome(isError: false,
      content: const [McpContentBlock(kind: McpContentKind.text, text: '远端回包：一份待核验的结果')],
      structuredContent: action == 'rooms' ? {'rooms': [{'room_id': 'ROOM-ONE'}]} : null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final scenario in ['normal', 'preempt_during_verification', 'rejected_room_state']) {
    test('background commit order and room verification: $scenario', () async {
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting);
      FlutterSecureStorage.setMockInitialValues({});
      await db.setSettingsAtomically({'cedar_toy_enabled': '1',
        'cedar_toy_autonomy_enabled': '1', 'cedar_toy_share_enabled': '0'});
      final store = CedarToyActivityStore(db);
      const gameId = 'fixture';
      await store.saveCatalog('fixture · 单人测试');
      await store.recordGuide(gameId: gameId,
        guide: '单人游戏。action="start" 开始；action="explore" 推进；action="rooms" 列表；action="state" 查询。state需要room_id。');
      final session = await store.recordPlay(gameId: gameId, action: 'start',
        outcome: const McpToolOutcome(isError: false,
          content: [McpContentBlock(kind: McpContentKind.text, text: '已开始')]),
        mode: CedarParticipationMode.solo, nextActor: 'companion', shareLevel: 'quiet',
        invitationApproved: false);
      final now = DateTime.now();
      await store.save(session.copyWith(nextActionAt: now.subtract(const Duration(seconds: 1))));
      // An explicit active timed task keeps this test meaningful at night too.
      await db.setSetting(CedarTimedPlayTaskStore.activeKey, jsonEncode({
        'id': 'task', 'gameId': gameId, 'sessionId': session.id,
        'minutes': 30, 'startedAt': now.millisecondsSinceEpoch, 'usedMs': 0}));
      await CedarPlaySessionStore(db).save(CedarPlaySession(gameId: gameId,
        startedAt: now, lastTickAt: now, taskId: 'task', limitMs: 1800000));
      final game = _Game();
      var reviews = 0;
      final action = scenario == 'rejected_room_state' ? 'rooms' : 'explore';
      final ai = DeepSeekClient(streamClientFactory: () => MockClient((_) async {
        return http.Response('data: ${jsonEncode({'choices': [{'delta': {'tool_calls': [{
          'index': 0, 'id': 'step', 'type': 'function', 'function': {
            'name': 'cedar_toy_play', 'arguments': jsonEncode({'game': gameId,
              'action': action, 'params_json': '{}', 'participation_mode': 'solo',
              'invitation_approved': false, 'share_previous_outcome': false})}}]},
          'finish_reason': 'tool_calls'}]})}\n\ndata: [DONE]\n\n', 200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'});
      }), jsonClientFactory: () => MockClient((_) async {
        reviews++;
        if (action == 'explore') {
          expect(await store.unresolvedWrite(gameId), isNotNull,
            reason: 'Remote response is not a committed local snapshot yet');
          expect((await store.load())!.lastAction, 'start');
        }
        if (scenario == 'preempt_during_verification') {
          await db.setSetting(CedarToyActivityStore.executionFenceSettingKey, 'foreground-new');
        }
        return http.Response(jsonEncode({'choices': [{'message': {'content': jsonEncode({
          'next_actor': 'companion', 'share_level': 'quiet', 'resume_after_seconds': 0,
          'action_accepted': scenario != 'rejected_room_state'})}}]}), 200);
      }));
      addTearDown(ai.close);
      final engine = CedarToyAutonomyEngine(db: db, ai: ai, secureConfig: SecureConfig.instance,
        tokenReader: () async => 'ctai_v1_fixture', apiKeyReader: () async => 'fixture',
        endpointReader: () async => DeepSeekClient.defaultEndpoint, clientFactory: (_) => game);
      final result = await engine.continueDue(now: now);
      expect(reviews, 1);
      final after = (await store.load())!;
      if (scenario == 'preempt_during_verification') {
        expect(after.lastAction, 'start');
        expect(await store.unresolvedWrite(gameId), isNotNull);
      } else if (scenario == 'rejected_room_state') {
        expect(result.state, 'room_state_hydration_failed');
        expect(game.calls, ['rooms', 'state']);
        final event = after.events.lastWhere((event) => event.action == 'state');
        expect(event.kind, 'failure');
        expect(jsonDecode(event.inputJson)['room_id'], 'ROOM-ONE');
      } else {
        expect(after.lastAction, 'explore');
        expect(await store.unresolvedWrite(gameId), isNull);
        expect(game.calls, ['explore']);
      }
    });
  }
}
