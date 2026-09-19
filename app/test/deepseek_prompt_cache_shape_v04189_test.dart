import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('canonical tool schemas share a body-free prompt shape', () async {
    final requestTools = <String>[];
    final usage = <DeepSeekUsageEvent>[];
    final client = DeepSeekClient(
      streamClientFactory: () => MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requestTools.add(jsonEncode(body['tools']));
        return http.Response(
          'data: {"choices":[],"usage":{"prompt_tokens":21,'
          '"completion_tokens":2,"prompt_cache_hit_tokens":16,'
          '"prompt_cache_miss_tokens":5}}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: const {'content-type': 'text/event-stream'},
        );
      }),
      onUsage: usage.add,
    );

    const messages = <Map<String, Object?>>[
      {'role': 'system', 'content': 'stable contract'},
      {'role': 'user', 'content': 'private dynamic value'},
    ];
    const firstTools = <Map<String, Object?>>[
      {
        'type': 'function',
        'function': {
          'parameters': {
            'required': ['query'],
            'type': 'object',
            'properties': {
              'query': {'description': 'q', 'type': 'string'},
            },
          },
          'name': 'search',
          'description': 'search once',
        },
      },
    ];
    const secondTools = <Map<String, Object?>>[
      {
        'function': {
          'description': 'search once',
          'name': 'search',
          'parameters': {
            'properties': {
              'query': {'type': 'string', 'description': 'q'},
            },
            'type': 'object',
            'required': ['query'],
          },
        },
        'type': 'function',
      },
    ];

    for (final tools in <List<Map<String, Object?>>>[
      firstTools,
      secondTools,
    ]) {
      await client
          .streamChat(
            apiKey: 'test',
            model: DeepSeekModelProfile.flash,
            effort: ReasoningEffort.low,
            messages: messages,
            tools: tools,
            usageLane: 'cache_shape_test',
          )
          .drain<void>();
    }

    expect(requestTools, hasLength(2));
    expect(requestTools[0], requestTools[1]);
    expect(usage, hasLength(2));
    expect(usage.every((event) => event.lane == 'cache_shape_test'), isTrue);
    expect(usage[0].promptShape.toolHash, usage[1].promptShape.toolHash);
    expect(usage[0].promptShape.messages, hasLength(2));
    expect(usage[0].promptShape.messages[0].role, 'system');
    expect(usage[0].promptShape.messages[0].characters, 15);
    expect(usage[0].promptShape.messages[0].hash, hasLength(12));
    expect(usage[0].promptShape.messages[0].hash, isNot('stable contract'));
    expect(
      usage[0].promptShape.messages[1].hash,
      isNot('private dynamic value'),
    );
    client.close();
  });
}
