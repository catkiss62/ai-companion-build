import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/ai/playful_self_judge.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  JevDecisionGateway gateway(int status, Object body) => JevDecisionGateway(
        enabledReader: () async => true,
        keyReader: () async => 'test-key',
        clientFactory: () => MockClient((request) async {
          final sent = jsonDecode(request.body) as Map<String, dynamic>;
          final state = sent['state'] as Map<String, dynamic>;
          expect(state['assistant_reply'], '才不怕你呢。');
          expect((sent['questions'] as Map).keys, contains('route'));
          return http.Response(jsonEncode(body), status);
        }),
      );

  test('valid Jev judgment counts the actual assistant challenge once',
      () async {
    var fallbackCalls = 0;
    final judge = PlayfulSelfJudge(
      client: DeepSeekClient(),
      jevGateway: gateway(200, {
        'answers': {
          'route': {
            'type': 'choice',
            'choice': 'playful',
            'confidence': 0.92,
            'probabilities': {
              'none': 0.02,
              'playful': 0.95,
              'strong': 0.02,
              'settle': 0.01,
            },
          },
        },
      }),
      fallbackClassifier: (_, __) async {
        fallbackCalls++;
        return PlayfulSelfActivity.strong;
      },
    );
    final value = await judge.classify(
      apiKey: 'deepseek-key',
      endpoint: 'https://api.deepseek.com/chat/completions',
      userText: '你别吹牛了',
      assistantText: '才不怕你呢。',
    );
    expect(value, PlayfulSelfActivity.playful);
    expect(fallbackCalls, 0);
  });

  test('insufficient Jev balance calls DeepSeek fallback for the same reply',
      () async {
    var fallbackCalls = 0;
    final judge = PlayfulSelfJudge(
      client: DeepSeekClient(),
      jevGateway: gateway(402, {'error': 'insufficient_balance'}),
      fallbackClassifier: (user, assistant) async {
        fallbackCalls++;
        expect(user, '你别吹牛了');
        expect(assistant, '才不怕你呢。');
        return PlayfulSelfActivity.strong;
      },
    );
    expect(
      await judge.classify(
        apiKey: 'deepseek-key',
        endpoint: 'https://api.deepseek.com/chat/completions',
        userText: '你别吹牛了',
        assistantText: '才不怕你呢。',
      ),
      PlayfulSelfActivity.strong,
    );
    expect(fallbackCalls, 1);
  });
}
