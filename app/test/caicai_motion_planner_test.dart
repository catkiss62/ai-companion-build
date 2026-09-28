import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/caicai_motion_planner.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('native limits clamp motion and unsupported channels never enter plan', () {
    final plan = CaicaiMotionPlanner.buildPlan({
      'f0_head': '左侧头', 'f0_mouth': '撅嘴', 'f1_head': '自然待机',
      'face': '1生气', 'action': 'unknown',
    }, {'ParamAngleX3': {'min': -10, 'max': 10}});
    final frames = plan['frames'] as List;
    expect(frames.first['parameters'], {'ParamAngleX3': -10.0});
    expect(frames[1]['parameters'], isEmpty);
    expect(plan['face'], '1生气');
    expect(plan['action'], '');
    expect(plan['emotion'], '');
    for (final channel in CaicaiMotionPlanner.channels.values) {
      for (final target in channel.values) {
        expect(target.containsKey('ParamMouthOpenY'), isFalse);
        expect(target.containsKey('ParamBreath'), isFalse);
      }
    }
  });
  test('all frame questions share one Jev request and failure has no second call', () async {
    var calls = 0;
    final gateway = JevDecisionGateway(enabledReader: () async => true,
      keyReader: () async => 'test-key', clientFactory: () => MockClient((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map;
        final questions = body['questions'] as Map;
        expect(questions.keys, containsAll(['f0_head','f1_head','f2_head','f3_head','face','action','emotion']));
        return http.Response('{}', 503);
      }));
    expect(await CaicaiMotionPlanner(gateway: gateway).plan(user: '看看左边', reply: '好呀',
      emotion: 'normal', parameters: {'ParamAngleX3': {'min': -30, 'max': 30}}), isNull);
    expect(calls, 1);
  });
  test('hip and tongue gestures release within the same conversational beat', () {
    final plan = CaicaiMotionPlanner.buildPlan({'f0_body':'左移重心','f0_mouth':'吐舌'}, {
      'ParamBodyAngleX':{'min':-10,'max':10}, 'ParamBodyAngleZ':{'min':-10,'max':10},
      'OUT':{'min':0,'max':1},
    });
    final frames=plan['frames'] as List;
    expect(frames[0]['parameters']['ParamBodyAngleX'],-9);
    expect(frames[0]['parameters']['OUT'],1);
    expect(frames[1]['time'],.55);
    expect((frames[1]['parameters'] as Map).containsKey('OUT'),isFalse);
    expect((frames[1]['parameters'] as Map).containsKey('ParamBodyAngleX'),isFalse);
  });
  test('nineteen dialog emotions use the native Caicai IDs', () {
    expect(CaicaiMotionPlanner.buildPlan({'emotion': 'crying'}, {})['emotion'], 'sad');
    expect(CaicaiMotionPlanner.buildPlan({'emotion': 'nervous'}, {})['emotion'], 'tense');
    expect(CaicaiMotionPlanner.buildPlan({'emotion': 'embarrassed'}, {})['emotion'], 'ashamed');
  });
}
