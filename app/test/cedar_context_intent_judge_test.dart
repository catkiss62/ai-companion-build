import 'dart:convert';

import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_context_intent_judge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  JevDecisionGateway gateway(String decision) => JevDecisionGateway(
        enabledReader: () async => true,
        keyReader: () async => 'test-key',
        clientFactory: () => MockClient((request) async {
          final sent = jsonDecode(request.body) as Map;
          expect(sent['state']['previous_assistant'], contains('钓鱼'));
          expect(sent['state']['latest_user'], '那就去吧，我陪你');
          expect(sent['state']['original_user_invitation'], '陪你钓鱼？');
          return http.Response(jsonEncode({
            'answers': {
              'route': {
                'type': 'choice', 'choice': decision, 'confidence': 0.9,
                'probabilities': {
                  'advance': decision == 'advance' ? 0.9 : 0.1,
                  'chat': decision == 'chat' ? 0.9 : 0.1,
                },
              },
            },
          }), 200);
        }),
      );

  Future<bool> decide(JevDecisionGateway gateway) =>
      CedarContextIntentJudge(gateway: gateway).shouldOfferTools(
        userText: '那就去吧，我陪你',
        previousAssistantText: '想去钓鱼海沟看看吗？',
        originalInvitationText: '陪你钓鱼？',
        activeGameTitle: '深海钓鱼',
      );

  test('Jev decides whether a contextual game reply opens tools', () async {
    expect(await decide(gateway('advance')), isTrue);
    expect(await decide(gateway('chat')), isFalse);
  });

  test('unavailable Jev leaves the existing DeepSeek tool decision reachable', () async {
    expect(await decide(JevDecisionGateway(
      enabledReader: () async => false,
      keyReader: () async => null,
    )), isTrue);
  });
}
