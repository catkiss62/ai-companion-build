import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion_localfirst/core/tts/emotion_sound_service.dart';

void main() {
  test('emotion cue volume defaults to full scale', () {
    expect(EmotionSoundService.normalizedVolume(null), 1.0);
    expect(EmotionSoundService.normalizedVolume(''), 1.0);
    expect(EmotionSoundService.normalizedVolume('invalid'), 1.0);
  });

  test('emotion cue volume preserves stored value and clamps safely', () {
    expect(EmotionSoundService.normalizedVolume('0.35'), closeTo(0.35, 0.0001));
    expect(EmotionSoundService.normalizedVolume('0'), 0.0);
    expect(EmotionSoundService.normalizedVolume('-2'), 0.0);
    expect(EmotionSoundService.normalizedVolume('4'), 1.0);
  });
}
