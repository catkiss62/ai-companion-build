import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/caicai_motion_planner.dart';
import 'package:ai_companion_localfirst/core/ai/caicai_preset_catalog.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';
import 'package:ai_companion_localfirst/core/ai/speech_performance_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('one real JEV request exposes every authored family per audio span', () async {
    var calls = 0;
    final gateway = JevDecisionGateway(keyReader:() async=>'test', enabledReader:() async=>true,
      clientFactory:()=>MockClient((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map;
        final questions = body['questions'] as Map;
        for(var i=0;i<2;i++) {
          expect((questions['speech${i}_face']['criteria'] as Map).keys,
            unorderedEquals(CaicaiPresetCatalog.overlayFaces));
          expect((questions['speech${i}_wink']['criteria'] as Map).keys,
            unorderedEquals(CaicaiPresetCatalog.winks));
          expect((questions['speech${i}_action']['criteria'] as Map).keys,
            unorderedEquals(CaicaiPresetCatalog.actions));
        }
        final answers = <String,Object?>{};
        for(final e in questions.entries) {
          final options = ((e.value as Map)['criteria'] as Map).keys.cast<String>().toList();
          final name = e.key as String;
          final choice = name.endsWith('_face_use') ? 'yes' : name.endsWith('_wink_use') ? 'yes'
              : name.endsWith('_face') ? '1红脸' : name.endsWith('_wink') ? 'wink吐舌'
              : name.endsWith('_action') ? '2奶茶' : options.first;
          answers[name] = {'type':'choice','choice':choice,'confidence':1.0,
            'probabilities':{for(final option in options) option:option==choice?1.0:0.0}};
        }
        return http.Response(jsonEncode({'answers':answers}),200);
      }));
    final plan = await CaicaiMotionPlanner(gateway:gateway).plan(user:'你好',reply:'前半句，后半句。',
      spokenText:'前半句，后半句。',emotion:'normal',parameters:{'ParamAngleY2':{'min':-30,'max':30}});
    expect(calls,1);expect(plan,isNotNull);
    final cues = plan!['speech'] as List;
    expect(cues,hasLength(2));
    for(final cue in cues) {
      expect(cue['face'],'1红脸');expect(cue['wink'],'wink吐舌');expect(cue['action'],'2奶茶');
    }
  });
  test('type winners never enable audio overlays without a valid independent use decision', () {
    final spans = SpeechPerformancePlan.candidates('一段语音。');
    for(final gate in [null,'no','invalid']) {
      final cues = SpeechPerformancePlan.decode(spans,{
        'speech0_emotion':'keep','speech0_delivery':'hold',
        if(gate!=null) 'speech0_face_use':gate,
        if(gate!=null) 'speech0_wink_use':gate,
        'speech0_face':'1爱心','speech0_wink':'比耶wink吐舌','speech0_action':'unknown',
      },{'normal'});
      expect(cues.single['face'],'');expect(cues.single['wink'],'');expect(cues.single['action'],'');
    }
  });
  test('audio gestures include calibrated body coordination without mouth writes', () {
    final parameters = {for(final id in ['ParamAngleY2','ParamBodyAngleY','ParamEyeBallY'])
      id:{'min':-1,'max':1}};
    final frames = SpeechPerformancePlan.frames('nod',parameters);
    expect((frames.first['parameters'] as Map)['ParamBodyAngleY'],-1.0);
    expect(frames.last['parameters'],isEmpty);
    expect(jsonEncode(frames),isNot(contains('Mouth')));
  });
}
