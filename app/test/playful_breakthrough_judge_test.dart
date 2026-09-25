import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/ai/playful_breakthrough_judge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Jev sees recent exchanges but judges the latest message', () async {
    final gateway = JevDecisionGateway(
      enabledReader: () async => true,
      keyReader: () async => 'test-key',
      clientFactory: () => MockClient((request) async {
        final sent = jsonDecode(request.body) as Map;
        final state = sent['state'] as Map;
        expect(state['recent_context'], contains('ASSISTANT: 我脸红了'));
        expect(state['latest_user_text'], '你这反应也太可爱了');
        expect(sent['questions'], contains('route'));
        return http.Response(jsonEncode({
          'answers': {
            'route': {
              'type': 'choice', 'choice': 'breakthrough',
              'confidence': 0.91, 'probabilities': {'breakthrough': 0.91},
            },
          },
        }), 200);
      }),
    );
    final judge = PlayfulBreakthroughJudge(DeepSeekClient(),
      jevGateway: gateway,
      fallbackClassifier: (_, __) async => false);
    expect(await judge.decide(
      apiKey: 'ds-key', endpoint: 'https://api.deepseek.com/chat/completions',
      userText: '你这反应也太可爱了',
      recentContext: 'ASSISTANT: 我脸红了',
    ), isTrue);
  });

  test('unavailable Jev calls the DeepSeek classifier instead of guessing', () async {
    var fallbacks = 0;
    final judge = PlayfulBreakthroughJudge(DeepSeekClient(),
      jevGateway: JevDecisionGateway(
        enabledReader: () async => true,
        keyReader: () async => 'test-key',
        clientFactory: () => MockClient((_) async => http.Response('{}', 402)),
      ),
      fallbackClassifier: (_, __) async { fallbacks++; return false; });
    expect(await judge.decide(
      apiKey: 'ds-key', endpoint: 'https://api.deepseek.com/chat/completions',
      userText: '早上好', recentContext: '',
    ), isFalse);
    expect(fallbacks, 1);
  });
}
