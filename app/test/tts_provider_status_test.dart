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
      'artifactCount': 37,
      'goldenReference': 'MejuTTS v2.7 · 63a8c10f5fc0',
    });
    expect(status.available, isTrue);
    expect(status.integrityVerified, isTrue);
    expect(status.integrityFailed, isFalse);
    expect(status.artifactCount, 37);
  });

  test('missing integrity fields fail closed as unchecked', () {
    final status = TtsStatus.fromMap(const {});
    expect(status.integrity, 'unchecked');
    expect(status.integrityVerified, isFalse);
  });
}
