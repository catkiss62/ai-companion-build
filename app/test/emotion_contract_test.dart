import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/emotion/emotion_classifier_service.dart';
import 'package:ai_companion_localfirst/core/emotion/emotion_contract.dart';
import 'package:ai_companion_localfirst/core/tts/tts_provider.dart';

void main() {
  test('emotion envelope is machine-only throughout streaming', () {
    expect(EmotionEnvelope.streamingVisible('<emo'), isEmpty);
    expect(
      EmotionEnvelope.streamingVisible(
        '<emotion>害羞</emotion>\n（她轻轻偏开脸）\n\n「别看。」',
      ),
      '\n（她轻轻偏开脸）\n\n「别看。」',
    );
    expect(
      EmotionEnvelope.streamingVisible('（她抬起眼）\n<emotion>心动'),
      '（她抬起眼）\n',
    );
  });

  test('misplaced and duplicate emotion tags never reach visible content', () {
    final parsed = EmotionEnvelope.parse(
      '（她靠近了一点）\n<emotion>心动</emotion>\n'
      '「过来。」\n<emotion>害羞</emotion>',
    );
    expect(parsed.found, isTrue);
    expect(parsed.rawTag, '心动');
    expect(parsed.visibleText, '（她靠近了一点）\n\n「过来。」');
    expect(parsed.visibleText, isNot(contains('<emotion')));
  });

  test('canonical DeepSeek tag is the authoritative 19-label emotion', () async {
    const service = EmotionClassifierService();
    final result = await service.resolve(
      rawTag: '心动',
      visibleText: '「过来一点。」',
    );
    expect(result.key, 'affection');
    expect(result.label, '心动');
    expect(result.source, 'llm');
    expect(result.confidence, 1);
  });

  test('noncanonical tag degrades without calling native code', () async {
    const service = EmotionClassifierService();
    final result = await service.resolve(
      rawTag: '有点坏心眼',
      visibleText: '「猜错了，重来。」',
    );
    expect(result.key, 'calm');
    expect(result.source, 'heuristic');
  });

  test('19 labels have stable keys and future MiniMax mappings', () {
    expect(EmotionCatalog.labelsByKey, hasLength(19));
    final cue = TtsEmotionCue(
      key: 'angry',
      label: '生气',
      confidence: 0.9,
      source: 'llm',
    );
    expect(cue.minimaxEmotion, 'angry');
    expect(cue.toChannelMap()['emotion_label'], '生气');
  });
}
