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
}
