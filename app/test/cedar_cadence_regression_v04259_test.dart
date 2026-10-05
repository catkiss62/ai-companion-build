import 'package:ai_companion_localfirst/core/desire/daily_wake_store.dart';
import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_play_session_policy.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_client.dart';
import 'package:ai_companion_localfirst/core/mcp/mcp_http_client.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  for (final taskId in ['', 'cedar-task:fixture']) {
    test('sustained solo continuation preserves ordinary pacing (task=$taskId)', () async {
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      addTearDown(db.closeForTesting);
      FlutterSecureStorage.setMockInitialValues({});
      await db.setSetting('cedar_toy_enabled', '1');
      await db.setSetting('cedar_toy_autonomy_enabled', '1');
      final store = CedarToyActivityStore(db);
      await store.recordGuide(gameId: 'white_room',
        guide: '单人游戏。actions: start explore。');
      final session = await store.recordPlay(gameId: 'white_room', action: 'start',
        outcome: McpToolOutcome(isError: false, content: const [
          McpContentBlock(kind: McpContentKind.text, text: '游戏已开始'),
        ]), mode: CedarParticipationMode.solo, nextActor: 'companion',
        shareLevel: 'quiet', invitationApproved: false);
      final now = DateTime.now();
      await store.save(session.copyWith(nextActionAt: now.subtract(const Duration(seconds: 1))));
      if (taskId.isNotEmpty) {
        await db.setSetting(CedarTimedPlayTaskStore.activeKey, jsonEncode({
          'id': taskId, 'gameId': session.gameId, 'sessionId': session.id,
          'minutes': 30, 'startedAt': now.millisecondsSinceEpoch, 'usedMs': 0,
        }));
      }
      await CedarPlaySessionStore(db).save(CedarPlaySession(gameId: 'white_room',
        startedAt: now, lastTickAt: now, taskId: taskId, limitMs: 1800000));
      var calls = 0;
      final ai = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
        final payload = jsonEncode({'choices': [
          {'delta': {'tool_calls': [
            {'index': 0, 'id': 'step', 'type': 'function', 'function': {
              'name': 'cedar_toy_play', 'arguments': jsonEncode({
                'game': 'white_room', 'action': 'explore', 'params_json': '{}',
                'participation_mode': 'solo', 'invitation_approved': false,
                'share_previous_outcome': false,
              }),
            }},
          ]}, 'finish_reason': 'tool_calls'},
        ]});
        return http.Response('data: $payload\n\ndata: [DONE]\n\n', 200,
          headers: {'content-type': 'text/event-stream'});
      }));
      addTearDown(ai.close);
      final transport = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if (body['method'] == 'notifications/initialized') return http.Response('{}', 202);
        final result = body['method'] == 'initialize' ? <String, dynamic>{} : {
          'content': [{'type': 'text', 'text': '已探索，下一步仍由伴侣行动'}],
          'structuredContent': {'next_actor': 'companion', 'participation_mode': 'solo'},
          'isError': false,
        };
        if (body['method'] == 'tools/call') calls++;
        return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final engine = CedarToyAutonomyEngine(db: db, ai: ai,
        secureConfig: SecureConfig.instance,
        tokenReader: () async => 'ctai_v1_test', apiKeyReader: () async => 'test',
        endpointReader: () async => DeepSeekClient.defaultEndpoint,
        clientFactory: (token) => CedarToyClient(token: token,
          transport: McpHttpClient(endpoint: Uri.parse('https://example.invalid/mcp'), client: transport)));
      final progress = await engine.continueDue(now: now);
      // Night sleep remains authoritative. During daytime the real execution
      // used to overwrite recordPlay's two minutes with the sustained 15s gap.
      if (taskId.isEmpty && (await DailyWakeStore.read(await db.database, now)).beforeWake(now)) {
        expect(progress.state, 'not_due');
        expect(calls, 0);
        return;
      }
      expect(progress.state, 'played_one_step');
      expect(calls, 1);
      final after = (await store.load())!;
      expect(after.nextActionAt!.difference(after.updatedAt), const Duration(minutes: 2));
      expect((await engine.continueDue(now: after.updatedAt.add(const Duration(seconds: 30)))).state, 'not_due');
      expect(calls, 1);
    });
  }
}
