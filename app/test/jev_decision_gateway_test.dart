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
          expect(sent['questions'], isA<Map>());
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

  test('largest probability wins when API choice disagrees', () async {
    final decision = await gateway(200, <String, Object?>{
      'answers': <String, Object?>{
        'route': <String, Object?>{
          'type': 'choice', 'choice': 'daily', 'confidence': 0.73,
          'probabilities': <String, double>{'daily': 0.21, 'explicit': 0.79},
        },
      },
    }).chooseMany(state: '例子', questions: const {'route': question});
    expect(decision, <String, String>{'route': 'explicit'});
  });

  test('out of credits falls back but a valid low-confidence route is used',
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
    expect(uncertain, <String, String>{'route': 'daily'});
  });

  test('close playful options become neutral without discarding other answers',
      () async {
    final result = await gateway(200, <String, Object?>{
      'answers': <String, Object?>{
        'mode': <String, Object?>{
          'type': 'choice', 'choice': 'daily', 'confidence': 0.95,
          'probabilities': <String, double>{'daily': 0.95, 'nsfw': 0.05},
        },
        'interaction': <String, Object?>{
          'type': 'choice', 'choice': 'mutual', 'confidence': 0.2,
          'probabilities': <String, double>{
            'mutual': 0.50, 'ordinary': 0.45, 'strong': 0.05,
          },
        },
        'initiative': <String, Object?>{
          'type': 'choice', 'choice': 'open', 'confidence': 0.2,
          'probabilities': <String, double>{'open': 0.52, 'closed': 0.48},
        },
      },
    }).chooseMany(state: 'test', usageLane: 'chat_intimacy_route', questions: const {
      'mode': JevChoiceQuestion('route', {'daily': 'daily', 'nsfw': 'nsfw'}),
      'interaction': JevChoiceQuestion('heat', {
        'mutual': 'tease', 'ordinary': 'neutral', 'strong': 'strong',
      }),
      'initiative': JevChoiceQuestion('opening', {
        'open': 'yes', 'closed': 'no',
      }),
    });
    expect(result, <String, String>{
      'mode': 'daily', 'interaction': 'ordinary', 'initiative': 'closed',
    });
  });

  test('a close game decision does not open Cedar planning', () async {
    final result = await gateway(200, <String, Object?>{
      'answers': <String, Object?>{
        'cedar': <String, Object?>{
          'type': 'choice', 'choice': 'act_now', 'confidence': 0.52,
          'probabilities': <String, double>{
            'act_now': 0.52, 'accept': 0, 'defer': 0, 'chat': 0.48,
          },
        },
      },
    }).chooseMany(state: '例子', usageLane: 'chat_intimacy_route',
        questions: const {'cedar': JevChoiceQuestion('game', {
          'act_now': 'act', 'accept': 'accept', 'defer': 'defer', 'chat': 'chat',
        })});
    expect(result?['cedar'], 'chat');
  });

  test('recorded half-hour invitation keeps its shared authorization', () async {
    final result = await gateway(200, {
      'answers': {
        'cedar': {
          'type': 'choice', 'choice': 'act_now', 'confidence': 0.16,
          'probabilities': {
            'act_now': 0.37, 'accept': 0.32, 'defer': 0.07, 'chat': 0.24,
          },
        },
      },
    }).chooseMany(state: '那你去玩半小时白房间吧',
        usageLane: 'chat_intimacy_route', questions: const {
      'cedar': JevChoiceQuestion('game', {
        'act_now': 'act', 'accept': 'accept', 'defer': 'defer', 'chat': 'chat',
      }),
    });
    expect(result?['cedar'], 'act_now');
  });

  test('Cedar grouping preserves refusal, sparse answers and lane isolation', () {
    expect(JevDecisionGateway.resolveCedarGroup('chat_intimacy_route', 'cedar',
        {'act_now': .1, 'accept': .1, 'defer': .7, 'chat': .1}), 'defer');
    expect(JevDecisionGateway.resolveCedarGroup('chat_intimacy_route', 'cedar',
        {'act_now': .25, 'accept': .26, 'defer': .49}), 'chat');
    expect(JevDecisionGateway.resolveCedarGroup('chat_intimacy_route', 'cedar',
        {'accept': .7}), 'accept');
    expect(JevDecisionGateway.resolveCedarGroup('chat_intimacy_route', 'cedar',
        {'act_now': .2, 'accept': .1, 'chat': .7}), 'chat');
    expect(JevDecisionGateway.resolveCedarGroup('cedar_context_intent', 'route',
        {'advance': .52, 'chat': .48}), isNull);
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
