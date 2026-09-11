import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/chat_api_provider.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('provider selection keeps exact fixed Gemini relay contract', () {
    expect(
      ChatApiProvider.fromEndpoint(ChatApiProvider.aiWangYouEndpoint),
      ChatApiProvider.aiWangYouGemini,
    );
    expect(
      ChatApiProvider.aiWangYouGemini.effectiveModel(
        DeepSeekModelProfile.flash,
      ),
      '[特价]gemini-3.7-flash-0.5',
    );
    expect(
      ChatApiProvider.aiWangYouGemini.reasoningEfforts,
      const [
        ReasoningEffort.low,
        ReasoningEffort.medium,
        ReasoningEffort.high,
      ],
    );
    expect(
      ChatApiProvider.deepSeek.reasoningEfforts,
      const [
        ReasoningEffort.low,
        ReasoningEffort.high,
        ReasoningEffort.max,
      ],
    );
    expect(
      ChatApiProvider.fromStorage('shuaiapi_gemini'),
      ChatApiProvider.aiWangYouGemini,
    );
    expect(
      ChatApiProvider.fromEndpoint(
        'https://api.shuaiapi.com/v1/chat/completions',
      ),
      ChatApiProvider.deepSeek,
    );
  });

  test('Gemini relay streams official thought summaries without DeepSeek fields',
      () async {
    Map<String, dynamic>? body;
    Uri? requestUri;
    String? authorization;
    final deltas = <DeepSeekDelta>[];
    final client = DeepSeekClient(
      streamClientFactory: () => MockClient((request) async {
        requestUri = request.url;
        authorization = request.headers['authorization'];
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          'data: {"choices":[{"delta":{"reasoning_content":"先计算。"},"finish_reason":null}]}\n\n'
          'data: {"choices":[{"delta":{"content":"323"},"finish_reason":"stop"}]}\n\n'
          'data: [DONE]\n\n',
          200,
          headers: const {
            'content-type': 'text/event-stream; charset=utf-8',
          },
        );
      }),
    );

    await for (final delta in client.streamChat(
      apiKey: 'relay-secret',
      endpoint: ChatApiProvider.aiWangYouEndpoint,
      model: DeepSeekModelProfile.flash,
      effort: ReasoningEffort.high,
      messages: const [
        {'role': 'user', 'content': '17×19'},
      ],
      thinking: true,
    )) {
      deltas.add(delta);
    }

    expect(requestUri.toString(), ChatApiProvider.aiWangYouEndpoint);
    expect(authorization, 'Bearer relay-secret');
    expect(body?['model'], ChatApiProvider.aiWangYouModel);
    expect(body?.containsKey('thinking'), isFalse);
    expect(body?.containsKey('reasoning_effort'), isFalse);
    expect(body?.containsKey('extra_body'), isFalse);
    expect(body?['google'], {
      'thinking_config': {
        'thinking_level': 'high',
        'include_thoughts': true,
      },
    });
    expect(deltas.map((delta) => delta.reasoning).join(), '先计算。');
    expect(deltas.map((delta) => delta.content).join(), '323');
    client.close();
  });

  test('Gemini relay background JSON uses low hidden thinking', () async {
    Map<String, dynamic>? body;
    final client = DeepSeekClient(
      client: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          '{"choices":[{"message":{"content":"{\\"ok\\":true}"}}]}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.jsonCompletion(
      apiKey: 'relay-secret',
      endpoint: ChatApiProvider.aiWangYouEndpoint,
      model: DeepSeekModelProfile.flash,
      messages: const [
        {'role': 'user', 'content': 'json'},
      ],
      thinking: false,
      effort: ReasoningEffort.max,
    );

    expect(result, {'ok': true});
    expect(body?['model'], ChatApiProvider.aiWangYouModel);
    expect(body?.containsKey('thinking'), isFalse);
    expect(body?.containsKey('reasoning_effort'), isFalse);
    expect(body?.containsKey('extra_body'), isFalse);
    expect(body?['google'], {
      'thinking_config': {
        'thinking_level': 'low',
        'include_thoughts': false,
      },
    });
    client.close();
  });
}
