import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_scene_advance.dart';

void main() {
  test('advance is a recorded control event, never a user utterance', () {
    expect(ImmersiveSceneAdvance.isMarker(ImmersiveSceneAdvance.marker), isTrue);
    expect(ImmersiveSceneAdvance.isMarker('推进剧情'), isFalse);
    expect(ImmersiveSceneAdvance.instruction, contains('不是用户说的话'));
    expect(ImmersiveSceneAdvance.instruction, contains('一个叙事节拍'));
    expect(ImmersiveSceneAdvance.instruction, contains('不要替用户编造台词'));
  });
}
