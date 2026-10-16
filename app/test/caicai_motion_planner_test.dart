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
      'face_use': 'yes', 'face': '1生气', 'action': 'unknown',
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
    Map? sent;
    final gateway = JevDecisionGateway(enabledReader: () async => true,
      keyReader: () async => 'test-key', clientFactory: () => MockClient((request) async {
        calls++;
        sent = jsonDecode(request.body) as Map;
        return http.Response('{}', 503);
      }));
    expect(await CaicaiMotionPlanner(gateway: gateway).plan(user: '看看左边', reply: '好呀',
      emotion: 'normal', parameters: {'ParamAngleX3': {'min': -30, 'max': 30}}), isNull);
    expect(calls, 1);
    // Keep request assertions outside the gateway's transport-error catch.
    final questions = sent!['questions'] as Map;
    expect(questions.keys, containsAll(['f0_head','f1_head','f2_head','f3_head','face_use','face','wink_use','wink','action','emotion','tempo','f0_intensity','f3_root']));
    final face = questions['face'] as Map;
    final wink = questions['wink'] as Map;
    expect((face['criteria'] as Map).keys, unorderedEquals(CaicaiMotionPlanner.overlayFaces));
    expect((wink['criteria'] as Map).keys, unorderedEquals(CaicaiMotionPlanner.winks));
    for (final family in ['face', 'wink']) {
      expect((questions['${family}_use']['criteria'] as Map).keys,
        unorderedEquals(['yes', 'no']));
      expect((questions[family]['criteria'] as Map).containsKey('无'), isFalse);
    }
  });
  test('tongue releases while the slower body X remains continuous', () {
    final plan = CaicaiMotionPlanner.buildPlan({'f0_body':'左移重心','f0_mouth':'吐舌'}, {
      'ParamBodyAngleX':{'min':-10,'max':10}, 'ParamBodyAngleZ':{'min':-10,'max':10},
      'OUT':{'min':0,'max':1},
    });
    final frames=plan['frames'] as List;
    expect(frames[0]['parameters']['ParamBodyAngleX'],-4);
    expect(frames[0]['parameters']['OUT'],1);
    expect(frames[1]['time'],closeTo(.60*.95,.0001));
    expect((frames[1]['parameters'] as Map).containsKey('OUT'),isFalse);
    expect(frames[1]['parameters']['ParamBodyAngleX'],-4);
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
    expect(frames[0]['parameters']['ParamAngleX3'],closeTo(28,.001));
    expect(frames[0]['parameters']['ParamMouthForm'],1);
    expect(frames[0]['root']['tilt'],closeTo(5.6,.001));
    expect(frames[1]['time'],.82);
    expect(frames[0]['duration'],closeTo(.82*.34,.001));
    expect(frames.last['root'],isEmpty);
  });
  test('Jev keeps each of four visible beats while using tuned pose limits', () {
    final answers = <String, String>{'tempo': '俏皮快拍'};
    for (var beat = 0; beat < 4; beat++) {
      answers['f${beat}_head'] = '右侧头';
      answers['f${beat}_body'] = '俏皮侧身';
      answers['f${beat}_intensity'] = '夸张';
      answers['f${beat}_root'] = beat.isEven ? '向左探身' : '向右探身';
    }
    final plan = CaicaiMotionPlanner.buildPlan(answers, {
      for (final id in ['ParamAngleX3','ParamBodyAngleX','ParamBodyAngleY','ParamBodyAngleZ'])
        id: {'min': id.startsWith('ParamBody') ? -10 : -30,
          'max': id.startsWith('ParamBody') ? 10 : 30},
    });
    final frames = plan['frames'] as List;
    expect(frames.length, 4); // Body axes no longer get forced midbeat releases.
    expect(frames[0]['root']['x'], closeTo(-.038 * 1.12, .0001));
    expect(frames[1]['root']['x'], closeTo(.038 * 1.12, .0001));
    expect(frames[0]['parameters']['ParamBodyAngleX'], closeTo(4 * 1.12 * .75, .0001));
    expect(frames[1]['parameters']['ParamAngleX3'], closeTo(28, .0001));
    expect(frames[1]['parameters']['ParamBodyAngleX'], closeTo(4 * 1.12 * .75, .0001));
    expect(frames[0]['duration'], closeTo(.82 * .34, .0001));
  });

  test('overlay, wink, emotion and action survive as independent layers', () {
    final plan = CaicaiMotionPlanner.buildPlan({'face_use':'yes', 'face':'1红脸',
      'wink_use':'yes', 'wink':'wink吐舌',
      'emotion':'embarrassed', 'action':'2奶茶', 'f0_brows':'皱眉'},
      {'ParamBrowLY':{'min':-1,'max':1},'ParamBrowRY':{'min':-1,'max':1}});
    expect(plan['face'], '1红脸');
    expect(plan['wink'], 'wink吐舌');
    expect(plan['action'], '2奶茶');
    expect(plan['emotion'], 'ashamed');
    expect((plan['frames'] as List).first['parameters'], isNotEmpty);
    expect(CaicaiMotionPlanner.buildPlan({'wink_use':'yes', 'wink':'1红脸'}, {})['wink'], '');
  });

  test('three original wink presets are available with native names', () {
    for (final name in ['wink', 'wink吐舌', '比耶wink吐舌']) {
      expect(CaicaiMotionPlanner.faces, contains(name));
      expect(CaicaiMotionPlanner.buildPlan({'wink_use':'yes', 'wink': name}, {})['wink'], name);
    }
  });

  test('type winners cannot bypass no, missing or invalid use gates', () {
    for (final gate in [null, 'no', 'invalid']) {
      final plan = CaicaiMotionPlanner.buildPlan({
        if (gate != null) 'face_use': gate,
        if (gate != null) 'wink_use': gate,
        'face': '1红脸', 'wink': '比耶wink吐舌',
        'emotion': 'embarrassed', 'action': '2奶茶', 'f0_head': '左侧头',
      }, {'ParamAngleX3': {'min': -30, 'max': 30}});
      expect(plan['face'], '');
      expect(plan['wink'], '');
      expect(plan['emotion'], 'ashamed');
      expect(plan['action'], '2奶茶');
      expect((plan['frames'] as List).first['parameters'], {'ParamAngleX3': -25.0});
    }
    for (final type in [null, '无', 'unknown', 'wink']) {
      expect(CaicaiMotionPlanner.buildPlan({
        'face_use': 'yes', if (type != null) 'face': type,
      }, {})['face'], '');
    }
    expect(CaicaiMotionPlanner.buildPlan({'wink_use': 'yes'}, {})['wink'], '');
  });

  // Exercise the real gateway: its highest-probability policy, required-answer
  // validation and transport batching must survive the new planner questions.
  Future<Map<String, Object?>?> responsePlan(
      void Function(Map<String, dynamic>) change) async {
    var calls = 0;
    final gateway = JevDecisionGateway(enabledReader: () async => true,
      keyReader: () async => 'test-key', clientFactory: () => MockClient((request) async {
        calls++;
        final questions = (jsonDecode(request.body) as Map)['questions'] as Map;
        final answers = <String, dynamic>{};
        for (final entry in questions.entries) {
          final first = (entry.value['criteria'] as Map).keys.first as String;
          answers[entry.key as String] = {
            'type': 'choice', 'choice': first, 'confidence': .03,
            'probabilities': {first: 1.0},
          };
        }
        change(answers);
        return http.Response(jsonEncode({'answers': answers}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
      }));
    final result = await CaicaiMotionPlanner(gateway: gateway).plan(
      user: '测试', reply: '测试回复', emotion: 'normal',
      parameters: {'ParamAngleX3': {'min': -30, 'max': 30}});
    expect(calls, 1);
    return result;
  }

  Map<String, Object> choice(String selected, Map<String, double> probabilities) => {
    'type': 'choice', 'choice': selected, 'confidence': .03,
    'probabilities': probabilities,
  };

  test('binary use and conditional types use their own highest probabilities', () async {
    final plan = await responsePlan((answers) {
      // A close binary yes is accepted even with low reported confidence.
      answers['face_use'] = choice('no', {'yes': .51, 'no': .49});
      answers['wink_use'] = choice('no', {'yes': .52, 'no': .48});
      // A type need not exceed 50%; the strongest preset is not a default.
      answers['face'] = choice('1生气', {'1红脸': .29, '1爱心': .26,
        '1生气': .22, '1星星眼': .10, '1黑脸': .06, '1钱钱': .04, '1流泪': .03});
      answers['wink'] = choice('比耶wink吐舌', {'wink': .40, 'wink吐舌': .35, '比耶wink吐舌': .25});
    });
    expect(plan, isNotNull);
    expect(plan!['face'], '1红脸');
    expect(plan['wink'], 'wink');
  });

  test('each use decision controls only its own independent layer', () async {
    for (final faceUse in ['yes', 'no']) {
      for (final winkUse in ['yes', 'no']) {
        final plan = await responsePlan((answers) {
          answers['face_use'] = choice(faceUse, {faceUse: 1.0});
          answers['wink_use'] = choice(winkUse, {winkUse: 1.0});
          answers['face'] = choice('1红脸', {'1红脸': 1.0});
          answers['wink'] = choice('wink吐舌', {'wink吐舌': 1.0});
        });
        expect(plan!['face'], faceUse == 'yes' ? '1红脸' : '');
        expect(plan['wink'], winkUse == 'yes' ? 'wink吐舌' : '');
      }
    }
  });

  test('missing or invalid required use answers fail without an extra request', () async {
    for (final family in ['face', 'wink']) {
      expect(await responsePlan((answers) => answers.remove('${family}_use')), isNull);
      expect(await responsePlan((answers) {
        answers['${family}_use'] = choice('unknown', {'unknown': 1.0});
      }), isNull);
    }
  });

}
