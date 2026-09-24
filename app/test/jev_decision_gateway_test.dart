import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';

void main() {
  const question = JevChoiceQuestion('Select a route', <String, String>{
    'daily': 'Normal conversation.',
    'explicit': 'Needs detailed scene continuity.',
  });

  JevDecisionGateway gateway(int status, Object body) => JevDecisionGateway(
        enabledReader: () async => true,
        keyReader: () async => 'test-key',
        clientFactory: () => MockClient((request) async {
          expect(request.url.toString(), JevDecisionGateway.endpoint);
          expect(request.headers['authorization'], 'Bearer test-key');
          final sent = jsonDecode(request.body) as Map;
          expect(sent['model'], JevDecisionGateway.model);
          expect((sent['questions'] as Map).containsKey('route'), isTrue);
          return http.Response(jsonEncode(body), status);
        }),
      );

  test('valid typed result returns the selected option', () async {
    final decision = await gateway(200, <String, Object?>{
      'answers': <String, Object?>{
        'route': <String, Object?>{
          'type': 'choice',
          'choice': 'daily',
          'confidence': 0.93,
          'probabilities': <String, double>{'daily': 0.96, 'explicit': 0.04},
        },
      },
      'usage': <String, int>{'input_tokens': 153, 'output_tokens': 16},
    }).chooseMany(
      state: const <String, String>{'latest_user_text': '你好'},
      questions: const <String, JevChoiceQuestion>{'route': question},
    );
    expect(decision, <String, String>{'route': 'daily'});
  });

  test('out of credits or uncertain answer leaves original route in charge',
      () async {
    final insufficient = await gateway(402, <String, String>{'error': 'balance'})
        .chooseMany(state: '你好', questions: const {'route': question});
    final uncertain = await gateway(200, <String, Object?>{
      'answers': <String, Object?>{
        'route': <String, Object?>{
          'type': 'choice',
          'choice': 'daily',
          'confidence': 0.2,
          'probabilities': <String, double>{'daily': 0.52, 'explicit': 0.48},
        },
      },
    }).chooseMany(state: '你好', questions: const {'route': question});
    expect(insufficient, isNull);
    expect(uncertain, isNull);
  });

  test('disabled or missing key makes no OpenRouter request', () async {
    var calls = 0;
    JevDecisionGateway makeGateway(bool enabled, String? key) =>
        JevDecisionGateway(
          enabledReader: () async => enabled,
          keyReader: () async => key,
          clientFactory: () {
            calls++;
            return MockClient((request) async => http.Response('{}', 200));
          },
        );
    expect(await makeGateway(false, 'test-key').chooseMany(
        state: 'hello', questions: const {'route': question}), isNull);
    expect(await makeGateway(true, '').chooseMany(
        state: 'hello', questions: const {'route': question}), isNull);
    expect(calls, 0);
  });

  test('batch requires every answer and does not partially apply events',
      () async {
    final partial = await gateway(200, <String, Object?>{
      'answers': <String, Object?>{
        'route': <String, Object?>{
          'type': 'choice',
          'choice': 'daily',
          'confidence': 0.93,
          'probabilities': <String, double>{'daily': 0.96, 'explicit': 0.04},
        },
      },
    }).chooseMany(state: 'hello', questions: const {
      'route': question,
      'event': JevChoiceQuestion('Did it happen?', {'none': 'Nothing'}),
    });
    expect(partial, isNull);
  });
}
