import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_motion_planner.dart';

void main() {
  final parameters = <String, dynamic>{for (final id in [
    'AngleX','AngleY','AngleZ','PositionX','PositionY','PositionZ','LeanInput',
    'ParamEyeBallX','ParamEyeBallY','ParamBrowLY','ParamBrowRY','BrowInnerUp',
    'REyeSquint','LEyeSquint','ParamMouthForm','Mouthpucker','CheeckPuff','MouthX','MouthFunnel',
  ]) id: {'min': id.startsWith('Angle') ? -9 : -30, 'max': 30}};
  test('four beats use real DeepSeek channels and Core bounds', () {
    final p = DeepseekMotionPlanner.buildPlan({
      'f0_head':'左转','f0_body':'贴近屏幕','f1_root':'左倾','f2_mouth':'撅嘴',
      'emotion':'crying',
    }, parameters);
    final frames = p['frames'] as List;
    expect(frames, hasLength(4));
    expect((frames[0]['parameters'] as Map)['AngleX'], -9);
    expect((frames[0]['parameters'] as Map)['LeanInput'], -30);
    expect((frames[2]['parameters'] as Map)['ParamMouthForm'], -1);
    expect((frames[2]['parameters'] as Map)['Mouthpucker'], 1);
    expect(p['emotion'], 'sad');
    for (final frame in frames) {
      final keys = (frame['parameters'] as Map).keys;
      expect(keys.any((id) => '$id'.startsWith('Clothes') || '$id'.startsWith('Movement') || id == 'ParamMouthOpenY'), isFalse);
    }
  });
  test('missing or invalid use gates fail closed, eyes win over wink', () {
    expect(DeepseekMotionPlanner.preset({'face':'爱心眼','wink':'吐舌wink'}, '')['face'], '');
    final p = DeepseekMotionPlanner.preset({'face_use':'yes','face':'圈圈眼',
      'wink_use':'yes','wink':'吐舌wink','effect_use':'yes','effect':'脸红','action':'扶胸'}, '');
    expect(p, {'face':'圈圈眼','wink':'','effect':'脸红','action':'扶胸'});
    expect(DeepseekMotionPlanner.preset({'action':'2比耶'}, '')['action'], '');
  });
  test('real speech motion never writes mouth, clothes or morph', () {
    for (final delivery in DeepseekMotionPlanner.deliveries.keys) {
      for (final frame in DeepseekMotionPlanner.speechFrames(delivery, parameters)) {
        expect((frame['parameters'] as Map).keys.every((id) =>
          const ['AngleX','AngleY','AngleZ','PositionY','PositionZ','ParamEyeBallX','BrowInnerUp'].contains(id)), isTrue);
      }
    }
  });
  test('reduced rig skips unsupported channels and nonfinite metadata', () {
    final p = DeepseekMotionPlanner.buildPlan({'f0_head':'右转','f0_mouth':'鼓脸'},
      {'AngleX':{'min':double.nan,'max':30}});
    expect(((p['frames'] as List).first as Map)['parameters'], isEmpty);
  });
}
