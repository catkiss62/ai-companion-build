import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/tts/tts_text_processor.dart';

void main() {
  test('TTS substitutions do not require changing visible text', () {
    const processor = TtsTextProcessor();
    final spoken = processor.process(
      'Yuki **回来了**。',
      replacements: const {'Yuki': '有希'},
    );
    expect(spoken, '有希 回来了。');
  });

  test('A2 fixed Yuki pronunciation is case-insensitive', () {
    const processor = TtsTextProcessor();
    expect(processor.process('YUKI yuki YuKi'), '有希 有希 有希');
  });

  test('A2 removable bracket blocks are speech-only', () {
    const processor = TtsTextProcessor();
    expect(
      processor.process('保留（这里不读。）正文【这个也不读】。'),
      '保留正文。',
    );
  });

  test('new dialogue-only scope reads corner-quoted speech, not action', () {
    const processor = TtsTextProcessor();
    const source = '轻轻把耳鳍压低\n「才没有一直等你。」';
    expect(processor.process(source), '才没有一直等你。');
  });

  test('full-text scope includes actions and dialogue', () {
    const processor = TtsTextProcessor();
    const source = '轻轻把耳鳍压低\n「才没有一直等你。」';
    expect(
      processor.process(source, scope: TtsReadingScope.fullText),
      '轻轻把耳鳍压低。才没有一直等你。',
    );
  });

  test('replacement JSON fails closed on malformed input', () {
    const processor = TtsTextProcessor();
    expect(processor.decodeReplacementJson('{bad json'), isEmpty);
    expect(
      processor.decodeReplacementJson('{"A":"B"}'),
      const {'A': 'B'},
    );
  });
}
