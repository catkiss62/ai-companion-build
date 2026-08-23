import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/emotion/emotion_classifier_service.dart';
import 'package:ai_companion_localfirst/core/emotion/emotion_contract.dart';
import 'package:ai_companion_localfirst/core/tts/tts_provider.dart';

void main() {
  test('emotion envelope stays hidden while its leading tag streams', () {
    expect(EmotionEnvelope.streamingVisible('<emo'), isEmpty);
    expect(
      EmotionEnvelope.streamingVisible('<emotion>害羞</emotion>\n「别看。」'),
      '「别看。」',
    );
    final parsed =
        EmotionEnvelope.parse('<emotion>害羞</emotion>\n轻轻偏开脸\n「别看。」');
    expect(parsed.found, isTrue);
    expect(parsed.rawTag, '害羞');
    expect(parsed.visibleText, '轻轻偏开脸\n「别看。」');
  });

  test('canonical LLM tag bypasses the local classifier', () async {
    var calls = 0;
    final service = EmotionClassifierService(
      classify: (text) async {
        calls++;
        return null;
      },
    );
    final result = await service.resolve(
      rawTag: '心动',
      visibleText: '「过来一点。」',
    );
    expect(calls, 0);
    expect(result.key, 'affection');
    expect(result.source, 'llm');
    expect(result.confidence, 1);
  });

  test('nonstandard short tag is normalized by 19emo when decisive', () async {
    final service = EmotionClassifierService(
      classify: (text) async => <Object?, Object?>{
        'label': '调皮',
        'confidence': 0.78,
        'margin': 0.31,
        'top3': <Object?>[
          <Object?, Object?>{'label': '调皮', 'confidence': 0.78},
          <Object?, Object?>{'label': '高兴', 'confidence': 0.17},
          <Object?, Object?>{'label': '平静', 'confidence': 0.05},
        ],
      },
    );
    final result = await service.resolve(
      rawTag: '有点坏心眼',
      visibleText: '「猜错了，重来。」',
    );
    expect(result.key, 'playful');
    expect(result.source, '19emo');
    expect(result.top3, hasLength(3));
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
