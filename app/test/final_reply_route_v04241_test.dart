import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/chat_api_provider.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/final_reply_route.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('successful second channel still owns semantic corrections', () {
    final route = FinalReplyRoute(secondChannelEnabled: true);
    final providers = <String>[];
    // First candidate, truth rejection and rewritten candidate are one route.
    for (var candidate = 0; candidate < 3; candidate++) {
      providers.add(route.useSecondChannel ? 'gemini' : 'deepseek');
    }
    expect(providers, ['gemini', 'gemini', 'gemini']);
    route.recordFailure(StateError('HTTP 400'));
    expect(route.useSecondChannel, isFalse);
    expect(FinalReplyRoute(secondChannelEnabled: true).useSecondChannel, isTrue);
    expect(FinalReplyRoute(secondChannelEnabled: false).useSecondChannel, isFalse);
  });

  for (final lane in ['final_reply', 'proactive_final_reply',
    'cedar_room_final_reply', 'immersive_reply', 'calendar_reminder_final']) {
    test('$lane: real transport retains second-channel model and repairs system-only shape', () async {
      final requests = <Map<String, dynamic>>[];
      final client = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('data: {"choices":[{"delta":{"content":"正文"},"finish_reason":"stop"}]}\n\n'
            'data: [DONE]\n\n', 200, encoding: utf8,
            headers: {'content-type': 'text/event-stream; charset=utf-8'});
      }));
      final route = FinalReplyRoute(secondChannelEnabled: true);
      const source = <Map<String, Object?>>[{'role': 'system', 'content': '真实事件'}];
      for (final messages in [source, [...source, {'role': 'system', 'content': '修正真实性'}]]) {
        await client.streamChat(apiKey: 'test', model: DeepSeekModelProfile.flash,
          effort: ReasoningEffort.high, messages: messages, usageLane: lane,
          endpoint: 'https://relay.invalid/v1/chat/completions',
          requestProvider: route.useSecondChannel ? ChatApiProvider.aiWangYouGemini : null,
          modelName: route.useSecondChannel ? 'configured-gemini' : null).drain<void>();
      }
      expect(requests.map((r) => r['model']), ['configured-gemini', 'configured-gemini']);
      for (final request in requests) {
        final messages = request['messages'] as List;
        expect(messages.last['role'], 'user');
        expect(messages.last['content'], contains('不是真实用户发言'));
      }
      expect(source, hasLength(1)); // Never insert fake turns into source/history.
      client.close();
    });
  }

  test('HTTP 400 permits fallback but a new round attempts Gemini again', () async {
    final models = <String>[];
    final client = DeepSeekClient(streamClientFactory: () => MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      models.add(body['model'] as String);
      return models.length == 1 ? http.Response('{"error":{"message":"bad request"}}', 400)
          : http.Response('data: {"choices":[{"delta":{"content":"正文"},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n', 200, encoding: utf8);
    }));
    Future<void> request(FinalReplyRoute route) => client.streamChat(apiKey: 'test',
      model: DeepSeekModelProfile.flash, effort: ReasoningEffort.high,
      messages: const [{'role': 'system', 'content': '分享真实事件'}],
      requestProvider: route.useSecondChannel ? ChatApiProvider.aiWangYouGemini : ChatApiProvider.deepSeek,
      modelName: route.useSecondChannel ? 'configured-gemini' : null).drain<void>();
    final route = FinalReplyRoute(secondChannelEnabled: true);
    Object? failure;
    try { await request(route); } catch (error) { failure = error; }
    expect(failure, isNotNull);
    route.recordFailure(failure!);
    await request(route);
    await request(FinalReplyRoute(secondChannelEnabled: true));
    expect(models, ['configured-gemini', DeepSeekModelProfile.flash.apiName, 'configured-gemini']);
    client.close();
  });

  test('existing real user messages remain unchanged', () {
    final messages = <Map<String, Object?>>[{'role': 'user', 'content': '你好'}];
    expect(identical(messages, FinalReplyRoute.prepareMessages(messages)), isTrue);
  });
}
