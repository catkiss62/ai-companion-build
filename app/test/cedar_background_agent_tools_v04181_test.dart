import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_autonomy_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
    expect(requestBody?['tool_choice'], 'required');
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
}
