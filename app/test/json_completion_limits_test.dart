import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const messages = <Map<String, Object?>>[
    {'role': 'user', 'content': '返回JSON'},
  ];
  http.Response reply(String? finishReason) => http.Response(jsonEncode({
    'choices': [{
      if (finishReason != null) 'finish_reason': finishReason,
      'message': {'content': '{"text":"可解析但不一定完整"}'},
    }],
  }), 200, headers: {'content-type': 'application/json; charset=utf-8'});

  test('JSON output budget can be omitted without changing the short-task default', () async {
    final requests = <Map<String, dynamic>>[];
    final client = DeepSeekClient(client: MockClient((request) async {
      requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return reply('stop');
    }));
    await client.jsonCompletion(apiKey: 'test', model: DeepSeekModelProfile.flash,
      messages: messages);
    await client.jsonCompletion(apiKey: 'test', model: DeepSeekModelProfile.flash,
      messages: messages, thinking: true, maxTokens: null);
    await client.jsonCompletion(apiKey: 'test', model: DeepSeekModelProfile.flash,
      messages: messages, maxTokens: 260);
    expect(requests[0]['max_tokens'], 1400);
    expect(requests[1].containsKey('max_tokens'), isFalse);
    expect(requests[2]['max_tokens'], 260);
    client.close();
  });

  for (final reason in ['length', 'content_filter', 'safety', 'error']) {
    test('explicit $reason cannot turn parseable partial JSON into success', () async {
      final client = DeepSeekClient(client: MockClient((_) async => reply(reason)));
      await expectLater(client.jsonCompletion(apiKey: 'test',
        model: DeepSeekModelProfile.flash, messages: messages),
        throwsA(isA<IncompleteJsonCompletionException>().having(
          (error) => error.finishReason, 'finish reason', reason)));
      client.close();
    });
  }

  test('legacy endpoints without finish reason remain compatible', () async {
    final client = DeepSeekClient(client: MockClient((_) async => reply(null)));
    final result = await client.jsonCompletion(apiKey: 'test',
      model: DeepSeekModelProfile.flash, messages: messages);
    expect(result['text'], '可解析但不一定完整');
    client.close();
  });
}
