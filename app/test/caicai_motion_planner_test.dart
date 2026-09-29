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
        expect(questions.keys, containsAll(['f0_head','f1_head','f2_head','f3_head','face','action','emotion','tempo','f0_intensity','f3_root']));
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
    expect(frames[0]['parameters']['ParamBodyAngleX'],-5);
    expect(frames[0]['parameters']['OUT'],1);
    expect(frames[1]['time'],closeTo(.60*.98,.0001));
    expect((frames[1]['parameters'] as Map).containsKey('OUT'),isFalse);
    expect((frames[1]['parameters'] as Map).containsKey('ParamBodyAngleX'),isFalse);
  });
  test('nineteen dialog emotions use the native Caicai IDs', () {
    expect(CaicaiMotionPlanner.buildPlan({'emotion': 'crying'}, {})['emotion'], 'sad');
    expect(CaicaiMotionPlanner.buildPlan({'emotion': 'nervous'}, {})['emotion'], 'tense');
    expect(CaicaiMotionPlanner.buildPlan({'emotion': 'embarrassed'}, {})['emotion'], 'ashamed');
  });
  test('Jev intensity and tempo control head/body and root but preserve face targets', () {
    final plan=CaicaiMotionPlanner.buildPlan({'tempo':'俏皮快拍','f0_head':'右侧头',
      'f0_intensity':'夸张','f0_root':'小腿支点左倾','f0_mouth':'顽皮笑'}, {
      'ParamAngleX3':{'min':-30,'max':30},'ParamMouthForm':{'min':-1,'max':1},
    });
    final frames=plan['frames'] as List;
    expect(frames[0]['parameters']['ParamAngleX3'],closeTo(24.64,.001));
    expect(frames[0]['parameters']['ParamMouthForm'],1);
    expect(frames[0]['root']['tilt'],closeTo(4.48,.001));
    expect(frames[1]['time'],.86);
    expect(frames[0]['duration'],closeTo(.86*.42,.001));
    expect(frames.last['root'],isEmpty);
  });
  test('repeated strong pose has one emphasis and no hip reset each beat', () {
    final answers = <String, String>{'tempo': '俏皮快拍'};
    for (var beat = 0; beat < 4; beat++) {
      answers['f${beat}_head'] = '右侧头';
      answers['f${beat}_body'] = '俏皮侧身';
      answers['f${beat}_intensity'] = '夸张';
      answers['f${beat}_root'] = beat == 0 ? '向左探身' : '不位移';
    }
    final plan = CaicaiMotionPlanner.buildPlan(answers, {
      for (final id in ['ParamAngleX3','ParamBodyAngleX','ParamBodyAngleY','ParamBodyAngleZ'])
        id: {'min': id.startsWith('ParamBody') ? -10 : -30,
          'max': id.startsWith('ParamBody') ? 10 : 30},
    });
    final frames = plan['frames'] as List;
    expect(frames.length, 5); // Four poses and one final hip release.
    expect(frames[0]['root']['x'], closeTo(-.04, .0001));
    expect(frames[0]['parameters']['ParamBodyAngleX'], closeTo(3.75, .0001));
    expect(frames[1]['parameters']['ParamAngleX3'], closeTo(24.64, .0001));
    expect(frames[1]['parameters']['ParamBodyAngleX'], closeTo(5.6, .0001));
    expect(frames[2]['parameters']['ParamBodyAngleX'], 5);
    expect(frames[3]['parameters']['ParamBodyAngleX'], 5);
    expect((frames.last['parameters'] as Map).containsKey('ParamBodyAngleX'), isFalse);
    expect(frames[0]['duration'], greaterThan(.3));
  });

}
