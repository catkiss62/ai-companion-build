import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_runner.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_game_protocol.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String _toolResponse(Map<String, Object?> arguments) {
  final event = jsonEncode(<String, Object?>{
    'choices': <Object?>[
      <String, Object?>{
        'delta': <String, Object?>{
          'tool_calls': <Object?>[
            <String, Object?>{
              'index': 0,
              'id': 'cedar-call',
              'type': 'function',
              'function': <String, Object?>{
                'name': 'cedar_toy_play',
                'arguments': jsonEncode(arguments),
              },
            },
          ],
        },
        'finish_reason': 'tool_calls',
      },
    ],
  });
  return 'data: $event\n\ndata: [DONE]\n\n';
}

Map<String, Object?> _decision({
  String game = 'duel',
  String action = 'move',
  Object params = const <String, Object?>{
    'room_id': 'ROOM',
    'revision': 4,
    'move': <String, Object?>{'row': 7, 'col': 7},
  },
}) =>
    <String, Object?>{
      'game': game,
      'action': action,
      'params_json': params is String ? params : jsonEncode(params),
      'participation_mode': 'multiplayer',
      'invitation_approved': true,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('transport hydration never invents choices or an ambiguous room', () {
    final hydrated = CedarExecutableCallPolicy.hydrateTransportParams(
      planned: const <String, Object?>{
        'move': <String, Object?>{'row': 7, 'col': 7},
      },
      continuationParamsJson:
          '{"room_id":"ROOM","revision":9,"legal_moves":["ignored"]}',
      lastOutcome: '',
    );
    expect(hydrated['room_id'], 'ROOM');
    expect(hydrated['revision'], 9);
    expect(hydrated, isNot(contains('game_type')));

    final ambiguousHydration =
        CedarExecutableCallPolicy.hydrateTransportParams(
      planned: const <String, Object?>{},
      continuationParamsJson: '',
      lastOutcome:
          '{"rooms":[{"room_id":"ONE"},{"room_id":"TWO"}]}',
    );
    expect(
      ambiguousHydration,
      isNot(contains('room_id')),
      reason: 'transport hydration must not silently pick one room',
    );

    expect(
      CedarExecutableCallPolicy.uniqueTransportValue(
        key: 'room_id',
        structuredContent: const <String, Object?>{'room_id': 'ONLY'},
        text: '',
      ),
      'ONLY',
    );
    expect(
      CedarExecutableCallPolicy.uniqueTransportValue(
        key: 'room_id',
        structuredContent: const <String, Object?>{
          'rooms': <Object?>[
            <String, Object?>{'room_id': 'ONE'},
            <String, Object?>{'room_id': 'TWO'},
          ],
        },
        text: '',
      ),
      isEmpty,
      reason: 'the APK must not choose between multiple rooms',
    );
  });

  test('explicit guide-required fields block an incomplete mutation', () {
    final missing = CedarExecutableCallPolicy.missingExplicitRequiredFields(
      action: 'new',
      params: const <String, Object?>{},
      guide: CedarPlayerProtocolContract.actionSignaturesFor('duel'),
      playProtocol: '',
    );
    expect(missing, contains('game_type'));
  });

  test('background action accepts a native play call with empty model body',
      () async {
    Map<String, dynamic>? requestBody;
    final client = DeepSeekClient(
      streamClientFactory: () => MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          _toolResponse(_decision()),
          200,
          headers: const {'content-type': 'text/event-stream'},
        );
      }),
    );

    final result = await CedarAgentActionPlanner(ai: client).decide(
      apiKey: 'test',
      endpoint: DeepSeekClient.defaultEndpoint,
      gameId: 'duel',
      instruction: '推进当前棋局',
      acceptsAction: (action) => action == 'move',
    );

    expect(result.gameId, 'duel');
    expect(result.action, 'move');
    expect(result.mode, CedarParticipationMode.multiplayer);
    expect(result.params['revision'], 4);
    expect(result.params['move'], {'row': 7, 'col': 7});
    expect(requestBody?['tool_choice'], 'auto');
    expect((requestBody?['tools'] as List), hasLength(1));
    expect(
      requestBody?['tools'][0]['function']['name'],
      'cedar_toy_play',
    );
    client.close();
  });

  test('repeated read-only state is rejected then replanned as a move',
      () async {
    final requestBodies = <Map<String, dynamic>>[];
    final retries = <Object>[];
    var calls = 0;
    final client = DeepSeekClient(
      streamClientFactory: () => MockClient((request) async {
        requestBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        calls += 1;
        return http.Response(
          _toolResponse(
            _decision(
              action: calls == 1 ? 'state' : 'move',
              params: calls == 1
                  ? const <String, Object?>{'room_id': 'ROOM'}
                  : const <String, Object?>{
                      'room_id': 'ROOM',
                      'revision': 4,
                      'move': <String, Object?>{'row': 8, 'col': 8},
                    },
            ),
          ),
          200,
          headers: const {'content-type': 'text/event-stream'},
        );
      }),
    );

    final result = await CedarAgentActionPlanner(
      ai: client,
      onRetry: (error) async => retries.add(error),
    ).decide(
      apiKey: 'test',
      endpoint: DeepSeekClient.defaultEndpoint,
      gameId: 'duel',
      instruction: '状态已经读取，轮到 companion',
      acceptsAction: (action) => action == 'move',
    );

    expect(calls, 2);
    expect(result.action, 'move');
    expect(retries.single, isA<CedarAgentActionPlanningException>());
    expect((requestBodies.first['messages'] as List), hasLength(1));
    expect((requestBodies.last['messages'] as List), hasLength(2));
    expect(requestBodies.first['thinking'], {'type': 'enabled'});
    expect(requestBodies.last['thinking'], {'type': 'disabled'});
    client.close();
  });

  test('wrong game id is rejected and corrected without free JSON fallback',
      () async {
    var calls = 0;
    final client = DeepSeekClient(
      streamClientFactory: () => MockClient((request) async {
        calls += 1;
        return http.Response(
          _toolResponse(_decision(game: calls == 1 ? 'fishing' : 'duel')),
          200,
          headers: const {'content-type': 'text/event-stream'},
        );
      }),
    );

    final result = await CedarAgentActionPlanner(ai: client).decide(
      apiKey: 'test',
      endpoint: DeepSeekClient.defaultEndpoint,
      gameId: 'duel',
      instruction: '只推进 duel',
      acceptsAction: (action) => action == 'move',
    );

    expect(calls, 2);
    expect(result.gameId, 'duel');
    client.close();
  });

  test('two invalid tool decisions stop after the bounded retry', () async {
    var calls = 0;
    final client = DeepSeekClient(
      streamClientFactory: () => MockClient((request) async {
        calls += 1;
        return http.Response(
          _toolResponse(_decision(action: 'state')),
          200,
          headers: const {'content-type': 'text/event-stream'},
        );
      }),
    );

    await expectLater(
      CedarAgentActionPlanner(ai: client).decide(
        apiKey: 'test',
        endpoint: DeepSeekClient.defaultEndpoint,
        gameId: 'duel',
        instruction: '必须真实推进',
        acceptsAction: (action) => action == 'move',
      ),
      throwsA(
        isA<CedarAgentActionPlanningException>().having(
          (error) => error.category,
          'category',
          'non_executable_action',
        ),
      ),
    );
    expect(calls, 2);
    client.close();
  });

  test('provider object params are accepted defensively', () async {
    final client = DeepSeekClient(
      streamClientFactory: () => MockClient((request) async => http.Response(
            _toolResponse(
              <String, Object?>{
                ..._decision(),
                'params_json': <String, Object?>{
                  'room_id': 'ROOM',
                  'revision': 5,
                },
              },
            ),
            200,
            headers: const {'content-type': 'text/event-stream'},
          )),
    );

    final result = await CedarAgentActionPlanner(ai: client).decide(
      apiKey: 'test',
      endpoint: DeepSeekClient.defaultEndpoint,
      gameId: 'duel',
      instruction: '推进当前棋局',
      acceptsAction: (action) => action == 'move',
    );

    expect(result.params, {'room_id': 'ROOM', 'revision': 5});
    client.close();
  });

  test('autonomous native parsing grants only registry-approved tools', () {
    DeepSeekToolCall call(String name, Map<String, Object?> arguments) =>
        DeepSeekToolCall(
          id: 'call',
          name: name,
          arguments: jsonEncode(arguments),
        );

    final cedar = AgentToolPlanner.fromNativeToolCalls(
      <DeepSeekToolCall>[
        call('cedar_toy_play', _decision()),
      ],
      origin: AgentToolOrigin.autonomous,
      cedarSessionActive: true,
      maxCalls: 1,
    );
    expect(cedar.calls.single.toolId, 'cedar_toy.play');
    expect(cedar.calls.single.reasonTag, 'autonomous_agent');

    final sticker = AgentToolPlanner.fromNativeToolCalls(
      <DeepSeekToolCall>[
        call('sticker_send', const <String, Object?>{'intent': '开心'}),
      ],
      origin: AgentToolOrigin.autonomous,
      latestUserText: '发个表情包',
      maxCalls: 1,
    );
    expect(sticker.isEmpty, isTrue);
  });

  test('autonomous runner blocks capabilities not granted by the registry',
      () async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    try {
      final results = await AgentToolRunner(
        db: db,
        android: AndroidBridge.instance,
        secureConfig: SecureConfig.instance,
      ).runPlan(
        const AgentToolPlan(
          calls: <AgentToolCall>[
            AgentToolCall(
              toolId: 'sticker.send',
              arguments: <String, String>{'intent': '开心'},
              reasonTag: 'autonomous_agent',
            ),
          ],
        ),
        origin: AgentToolOrigin.autonomous,
        eventScopeId: 'autonomous-registry-test',
      );
      expect(results.single.status, AgentToolStatus.blocked);
      expect(results.single.errorCode, 'registry_blocked');
    } finally {
      await db.closeForTesting();
    }
  });
}
