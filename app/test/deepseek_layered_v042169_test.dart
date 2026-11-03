import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_motion_planner.dart';
import 'package:ai_companion_localfirst/core/ai/jev_decision_gateway.dart';

void main() {
  final parameters=<String,dynamic>{for(final channel in DeepseekMotionPlanner.channels.values)
    for(final value in channel.values) for(final id in value.keys)
      id:{'min':id.contains('Open')?0:-30,'max':id.contains('Open')?1.5:30}};
  test('independent effects preserve combinations and eye style no longer erases wink',() {
    final p=DeepseekMotionPlanner.preset({'face_use':'yes','face':'圈圈眼','wink_use':'yes','wink':'右wink',
      'effect_sweat':'yes','effect_blush':'yes','effect_shade':'yes','effect_loading':'no'},'');
    expect(p['face'],'圈圈眼');expect(p['wink'],'右wink');
    expect(p['effects'],['黑脸','脸红','流冷汗']);
    expect(p['effect'],'');
    expect(DeepseekMotionPlanner.preset({'effect_sweat':'invalid','face':'嫌弃眼'},'')['effects'],isEmpty);
  });
  test('new effect decisions round trip to speech and one lean does not consume nod',() async {
    var calls=0;
    final gateway=JevDecisionGateway(enabledReader:()async=>true,keyReader:()async=>'synthetic',
      clientFactory:()=>MockClient((request)async {
        calls++;final body=jsonDecode(request.body) as Map;
        final questions=body['questions'] as Map;
        final answers=<String,Object?>{};
        for(final entry in questions.entries) {
          final options=(entry.value as Map)['criteria'] as Map;
          var choice=options.keys.first.toString();
          if(options.containsKey('no')) choice='no';
          const chosen={'lean_use':'yes','lean_moment':'speech0','speech0_delivery':'nod',
            'speech0_emotion':'happy','speech0_face_use':'yes','speech0_face':'爱心眼',
            'speech0_effect_blush':'yes','speech0_effect_tears':'yes','speech0_comic':'装懂小老师'};
          choice=chosen[entry.key]??choice;
          answers[entry.key]={'type':'choice','choice':choice,'confidence':1.0,'probabilities':{choice:1.0}};
        }
        return http.Response(jsonEncode({'answers':answers}),200,headers:{'content-type':'application/json'});
      }));
    final plan=await DeepseekMotionPlanner(gateway:gateway).plan(user:'悄悄靠近',reply:'让我悄悄告诉你。',
      spokenText:'让我悄悄告诉你。',emotion:'happy',parameters:parameters);
    expect(calls,1);expect(plan,isNotNull);
    final cue=(plan!['speech'] as List).first as Map;
    expect(cue['delivery'],'nod');expect(cue['lean'],true);
    expect(cue['effects'],['落泪','脸红']);expect(cue['comic'],'装懂小老师');
    expect((plan['frames'] as List).every((f)=>!(f['parameters'] as Map).containsKey('LeanInput')),true);
  });
  test('speech keeps fixed-mouth contempt excluded without banning its ordinary emotion',() async {
    Map? sent;
    final gateway=JevDecisionGateway(enabledReader:()async=>true,keyReader:()async=>'synthetic',
      clientFactory:()=>MockClient((request)async {sent=jsonDecode(request.body) as Map;return http.Response('{}',503);}));
    await DeepseekMotionPlanner(gateway:gateway).plan(user:'就这？',reply:'哼，就这？',
      spokenText:'哼，就这？',emotion:'disgust',parameters:parameters);
    final q=sent!['questions'] as Map;
    expect((q['face']['criteria'] as Map).containsKey('嫌弃眼'),true);
    expect((q['speech0_face']['criteria'] as Map).containsKey('嫌弃眼'),false);
    expect((q['speech0_emotion']['criteria'] as Map).containsKey('disgust'),true);
    expect(q['face_use']['instructions'],contains('普通打趣、吐槽、嘴硬关心不用'));
    expect(q.keys.where((key)=>'$key'.startsWith('effect_')),hasLength(7));
  });
  test('three authored smiles open only off audio and all targets obey Core bounds',() {
    expect(DeepseekMotionPlanner.mouthPreviews['闭嘴微笑']!['ParamMouthOpenY'],0);
    expect(DeepseekMotionPlanner.mouthPreviews['露齿微笑']!['ParamMouthOpenY'],lessThan(.15));
    expect(DeepseekMotionPlanner.mouthPreviews['张嘴微笑']!['ParamMouthOpenY'],greaterThan(.4));
    final plan=DeepseekMotionPlanner.buildPlan({'f0_mouth':'张嘴微笑','f0_body':'轻提'},parameters);
    final target=(plan['frames'] as List).first['parameters'] as Map;
    expect(target['ParamMouthOpenY'],.5);expect(target['PositionY'],20);
    for(final delivery in DeepseekMotionPlanner.deliveries.keys) {
      expect(DeepseekMotionPlanner.speechFrames(delivery,parameters).every((f)=>
        !(f['parameters'] as Map).containsKey('ParamMouthOpenY')),true);
    }
  });
}
