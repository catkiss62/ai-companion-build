import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_motion_planner.dart';

void main() {
  final parameters = <String, dynamic>{for (final id in [
    'AngleX','AngleY','AngleZ','PositionX','PositionY','PositionZ','LeanInput',
    'ParamEyeBallX','ParamEyeBallY','ParamBrowLY','ParamBrowRY','BrowInnerUp',
    'ParamMouthOpenY','REyeSquint','LEyeSquint','TongueOut','MouthPuckerWiden','ParamMouthForm','Mouthpucker','CheeckPuff','MouthX','MouthFunnel',
  ]) id: {'min': id.startsWith('Angle') ? -9 : -30, 'max': 30}};
  test('four beats use real DeepSeek channels and Core bounds', () {
    final p = DeepseekMotionPlanner.buildPlan({
      'f0_head':'左转','lean_use':'yes','lean_moment':'f0','f1_root':'左倾','f2_mouth':'撅嘴',
      'emotion':'crying',
    }, parameters);
    final frames = p['frames'] as List;
    expect(frames, hasLength(4));
    expect((frames[0]['parameters'] as Map)['AngleX'], -9);
    expect(p['lean_at'],0);
    expect((frames[0]['parameters'] as Map).containsKey('LeanInput'),false);
    expect((frames[2]['parameters'] as Map)['ParamMouthForm'], -1);
    expect((frames[2]['parameters'] as Map)['Mouthpucker'], 1);
    expect(p['emotion'], 'sad');
    for (final frame in frames) {
      final keys = (frame['parameters'] as Map).keys;
      expect(keys.any((id) => '$id'.startsWith('Clothes') || '$id'.startsWith('Movement')), isFalse);
    }
  });
  test('tongue cue reaches its full value and keeps clothing out of the plan', () {
    final p=DeepseekMotionPlanner.buildPlan({'f0_mouth':'吐舌'},parameters);
    expect(((p['frames'] as List).first['parameters'] as Map)['TongueOut'],1);
  });
  test('missing gates fail closed while eye style and wink can compose', () {
    expect(DeepseekMotionPlanner.preset({'face':'爱心眼','wink':'吐舌wink'}, '')['face'], '');
    final p = DeepseekMotionPlanner.preset({'face_use':'yes','face':'圈圈眼',
      'wink_use':'yes','wink':'吐舌wink','effect_use':'yes','effect':'脸红','action':'扶胸'}, '');
    expect(p, {'face':'圈圈眼','wink':'吐舌wink','effect':'脸红','effects':['脸红'],'comic':'','action':'扶胸'});
    expect(DeepseekMotionPlanner.preset({'action':'2比耶'}, '')['action'], '');
  });
  test('real speech motion never writes mouth, clothes or morph', () {
    for (final delivery in DeepseekMotionPlanner.deliveries.keys) {
      for (final frame in DeepseekMotionPlanner.speechFrames(delivery, parameters)) {
        expect((frame['parameters'] as Map).keys.every((id) =>
          const ['AngleX','AngleY','AngleZ','PositionY','PositionZ','ParamEyeBallX','BrowInnerUp','LeanInput'].contains(id)), isTrue);
      }
    }
  });
  test('ordinary or incomplete gates cannot lean through old per-beat or speech choices', () {
    for (final gate in [null,'no','invalid']) {
      final a=<String,String>{if(gate!=null)'lean_use':gate,'lean_moment':'f0',
        'f0_lean':'贴近屏幕','f2_lean':'贴近屏幕','speech0_delivery':'lean'};
      final p=DeepseekMotionPlanner.buildPlan(a,parameters);
      expect((p['frames'] as List).every((f)=>!(f['parameters'] as Map).containsKey('LeanInput')),true);
      expect(DeepseekMotionPlanner.speechDelivery(a,0),'hold');
    }
  });
  test('one semantic gate selects an opening interval or a single audio cue', () {
    for (var start=0;start<3;start++) {
      final p=DeepseekMotionPlanner.buildPlan({'lean_use':'yes','lean_moment':'f$start'},parameters);
      final f=p['frames'] as List;
      expect(p['lean_at'],closeTo(start*.95,.0001));
      for(var i=0;i<4;i++) expect(f[i]['parameters'].containsKey('LeanInput'),false);
    }
    final a={'lean_use':'yes','lean_moment':'speech1','speech0_delivery':'lean',
      'speech1_delivery':'nod','speech2_delivery':'lean'};
    final p=DeepseekMotionPlanner.buildPlan(a,parameters);
    expect((p['frames'] as List).every((f)=>!(f['parameters'] as Map).containsKey('LeanInput')),true);
    expect([for(var i=0;i<3;i++) DeepseekMotionPlanner.speechDelivery(a,i)],['hold','nod','hold']);
    expect(DeepseekMotionPlanner.speechDelivery(a,1,supportsLean:false),'nod');
    expect(DeepseekMotionPlanner.speechFrames('lean',parameters),isEmpty); // Posture has its own owner.
  });
  test('reduced rig skips unsupported channels and nonfinite metadata', () {
    final p = DeepseekMotionPlanner.buildPlan({'f0_head':'右转','f0_mouth':'鼓脸'},
      {'AngleX':{'min':double.nan,'max':30}});
    expect(((p['frames'] as List).first as Map)['parameters'], isEmpty);
  });
}
