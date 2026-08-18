import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sends temperature for non-thinking chat', () async {
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
          temperature: 1.4,
        )
        .drain<void>();

    expect(body?['temperature'], 1.4);
    expect(body?['thinking'], {'type': 'disabled'});
    client.close();
  });

  test('omits ignored temperature for DeepSeek thinking mode', () async {
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
          temperature: 1.8,
        )
        .drain<void>();

    expect(body?.containsKey('temperature'), isFalse);
    expect(body?['thinking'], {'type': 'enabled'});
    client.close();
  });
}
