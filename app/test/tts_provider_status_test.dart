import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/tts/tts_provider.dart';

void main() {
  test('golden integrity status decodes from native map', () {
    final status = TtsStatus.fromMap({
      'available': true,
      'initialized': false,
      'engine': 'Meju Bert-VITS2 · MNN (local)',
      'detail': 'ok',
      'integrity': 'verified',
      'artifactCount': 32,
      'goldenReference': '新版妹居本地 TTS · b72ebc8544de',
      'runtimeProfile': 'auto_affinity_v084',
      'autoAffinityEnabled': true,
    });
    expect(status.available, isTrue);
    expect(status.integrityVerified, isTrue);
    expect(status.integrityFailed, isFalse);
    expect(status.artifactCount, 32);
    expect(status.runtimeProfile, 'auto_affinity_v084');
    expect(status.autoAffinityEnabled, isTrue);
  });

  test('missing integrity fields fail closed as unchecked', () {
    final status = TtsStatus.fromMap(const {});
    expect(status.integrity, 'unchecked');
    expect(status.integrityVerified, isFalse);
    expect(status.runtimeProfile, 'unknown');
    expect(status.autoAffinityEnabled, isFalse);
  });
}
