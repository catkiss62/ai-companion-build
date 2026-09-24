import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/ai/playful_turn_judge.dart';
import 'package:ai_companion_localfirst/core/personality/playful_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  JevDecisionGateway gateway(int status, Object body) => JevDecisionGateway(
        enabledReader: () async => true,
        keyReader: () async => 'test-key',
        clientFactory: () => MockClient((request) async {
          final sent = jsonDecode(request.body) as Map;
          expect(sent['questions'], containsPair('interaction', isA<Map>()));
          expect(sent['questions'], containsPair('initiative', isA<Map>()));
          return http.Response(jsonEncode(body), status);
        }),
      );

  test('immersive user participation and opportunity share one Jev request',
      () async {
    final judge = PlayfulTurnJudge(
      DeepSeekClient(),
      jevGateway: gateway(200, {
        'answers': {
          'interaction': {
            'type': 'choice', 'choice': 'ordinary', 'confidence': 0.96,
            'probabilities': {'ordinary': 0.96},
          },
          'initiative': {
            'type': 'choice', 'choice': 'open', 'confidence': 0.91,
            'probabilities': {'open': 0.91},
          },
        },
      }),
      fallbackClassifier: (_, __) async =>
          const PlayfulTurnDecision(PlayfulInteraction.strong, false),
    );
    final decision = await judge.decide(
      apiKey: 'deepseek-key',
      endpoint: 'https://api.deepseek.com/chat/completions',
      userText: '你好',
      recentContext: '',
    );
    expect(decision.interaction, PlayfulInteraction.ordinary);
    expect(decision.initiativeOpportunity, isTrue);
  });

  test('balance failure reaches DeepSeek fallback without raising heat',
      () async {
    var fallbackCalls = 0;
    final judge = PlayfulTurnJudge(
      DeepSeekClient(),
      jevGateway: gateway(402, {'error': 'insufficient_balance'}),
      fallbackClassifier: (user, context) async {
        fallbackCalls++;
        return const PlayfulTurnDecision(PlayfulInteraction.ordinary, false);
      },
    );
    final result = await judge.decide(
      apiKey: 'deepseek-key',
      endpoint: 'https://api.deepseek.com/chat/completions',
      userText: '平常聊天',
      recentContext: '',
    );
    expect(result.interaction, PlayfulInteraction.ordinary);
    expect(fallbackCalls, 1);
  });
}
