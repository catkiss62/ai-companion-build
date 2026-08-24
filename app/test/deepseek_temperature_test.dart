import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uses provider sampling defaults for non-thinking chat', () async {
    Map<String, dynamic>? body;
    final client = DeepSeekClient(
      streamClientFactory: () => MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          'data: {"choices":[{"delta":{"content":"OK"},"finish_reason":"stop"}]}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: const {'content-type': 'text/event-stream'},
        );
      }),
    );

    await client
        .streamChat(
          apiKey: 'test',
          model: DeepSeekModelProfile.flash,
          effort: ReasoningEffort.high,
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          thinking: false,
        )
        .drain<void>();

    expect(body?.containsKey('temperature'), isFalse);
    expect(body?['thinking'], {'type': 'disabled'});
    client.close();
  });

  test('thinking mode sends reasoning effort without temperature', () async {
    Map<String, dynamic>? body;
    final client = DeepSeekClient(
      streamClientFactory: () => MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          'data: {"choices":[{"delta":{"reasoning_content":"h"},"finish_reason":"stop"}]}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: const {'content-type': 'text/event-stream'},
        );
      }),
    );

    await client
        .streamChat(
          apiKey: 'test',
          model: DeepSeekModelProfile.flash,
          effort: ReasoningEffort.high,
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          thinking: true,
        )
        .drain<void>();

    expect(body?.containsKey('temperature'), isFalse);
    expect(body?['thinking'], {'type': 'enabled'});
    expect(body?['reasoning_effort'], 'high');
    client.close();
  });
  test('streams native function-call fragments and sends tool schemas', () async {
    Map<String, dynamic>? body;
    final deltas = <DeepSeekDelta>[];
    final client = DeepSeekClient(
      streamClientFactory: () => MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call-1","type":"function","function":{"name":"public_web_search","arguments":"{\\\"query\\\":\\\"REDMI"}}]},"finish_reason":null}]}\n\n'
          'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":" K80\\\"}"}}]},"finish_reason":"tool_calls"}]}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: const {'content-type': 'text/event-stream'},
        );
      }),
    );

    await for (final delta in client.streamChat(
      apiKey: 'test',
      model: DeepSeekModelProfile.flash,
      effort: ReasoningEffort.high,
      messages: const [
        {'role': 'user', 'content': '查一下 REDMI K80'},
      ],
      thinking: true,
      tools: const [
        {
          'type': 'function',
          'function': {
            'name': 'public_web_search',
            'parameters': {'type': 'object'},
          },
        },
      ],
    )) {
      deltas.add(delta);
    }

    expect(body?['tools'], isA<List<dynamic>>());
    expect(body?['tool_choice'], 'auto');
    final fragments = deltas.expand((delta) => delta.toolCallDeltas).toList();
    expect(fragments.first.name, 'public_web_search');
    expect(
      fragments.map((fragment) => fragment.argumentsFragment).join(),
      '{"query":"REDMI K80"}',
    );
    expect(deltas.any((delta) => delta.finishReason == 'tool_calls'), isTrue);
    client.close();
  });

}
