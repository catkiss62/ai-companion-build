import 'package:ai_companion_localfirst/core/tts/tts_playback_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('speech speed keeps the supported pitch-preserving range', () {
    expect(TtsPlaybackTuning.speedFromSetting(null), 1.0);
    expect(TtsPlaybackTuning.speedFromSetting('0.25'), 0.5);
    expect(TtsPlaybackTuning.speedFromSetting('1.35'), 1.35);
    expect(TtsPlaybackTuning.speedFromSetting('3'), 2.0);
  });

  test('speech volume permits boost up to two hundred percent', () {
    expect(TtsPlaybackTuning.volumeFromSetting(null), 1.0);
    expect(TtsPlaybackTuning.volumeFromSetting('-1'), 0.0);
    expect(TtsPlaybackTuning.volumeFromSetting('1.5'), 1.5);
    expect(TtsPlaybackTuning.volumeFromSetting('3'), 2.0);
  });
}
