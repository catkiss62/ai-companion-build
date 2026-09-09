import 'package:ai_companion_localfirst/core/models/chat_language_variant.dart';
import 'package:ai_companion_localfirst/core/tts/tts_acoustic_segmenter.dart';
import 'package:ai_companion_localfirst/core/tts/tts_provider.dart';
import 'package:ai_companion_localfirst/core/tts/tts_voice_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auto voice maps all 19 companion emotions to four Genie profiles', () {
    const expected = <TtsVoiceMode, Set<String>>{
      TtsVoiceMode.daily: {
        'normal', 'serious', 'confident', 'angry', 'disgust', 'confused',
      },
      TtsVoiceMode.gentle: {
        'calm', 'worried', 'crying', 'afraid', 'nervous', 'shy',
        'embarrassed', 'affection',
      },
      TtsVoiceMode.lively: {'happy', 'excited', 'surprised'},
      TtsVoiceMode.cute: {'playful', 'helpless', 'flustered'},
    };
    for (final entry in expected.entries) {
      for (final key in entry.value) {
        expect(
          TtsVoiceProfilePolicy.resolve(
            TtsVoiceMode.auto,
            emotionKey: key,
            confidence: 0.9,
          ),
          entry.key,
        );
      }
    }
    expect(
      TtsVoiceProfilePolicy.resolve(
        TtsVoiceMode.auto,
        emotionKey: 'happy',
        confidence: 0.2,
      ),
      TtsVoiceMode.daily,
    );
  });

  test('fixed voice ignores emotion for the entire queue session', () {
    const cue = TtsEmotionCue(
      key: 'angry',
      label: '生气',
      confidence: 0.99,
      source: 'llm',
    );
    expect(
      TtsVoiceProfilePolicy.resolve(
        TtsVoiceMode.gentle,
        emotionKey: cue.key,
        confidence: cue.confidence,
      ),
      TtsVoiceMode.gentle,
    );
  });

  test('acoustic chunks obey language limits and preserve surrogate pairs', () {
    final zh = TtsAcousticSegmenter.split(
      '${List<String>.filled(52, '中').join()}，后半段继续。',
      ChatLanguage.chinese,
    );
    final en = TtsAcousticSegmenter.split(
      List<String>.filled(45, 'word').join(' '),
      ChatLanguage.english,
    );
    final emoji = TtsAcousticSegmenter.split(
      List<String>.filled(60, '鲸🐳').join(),
      ChatLanguage.japanese,
    );
    expect(zh.every((chunk) => chunk.length <= 54), isTrue);
    expect(en.every((chunk) => chunk.length <= 110), isTrue);
    expect(emoji.join(), List<String>.filled(60, '鲸🐳').join());
    expect(emoji.every((chunk) => !chunk.contains('�')), isTrue);
  });
}
