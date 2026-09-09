import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/tts/tts_text_processor.dart';
import 'package:ai_companion_localfirst/core/models/chat_language_variant.dart';

void main() {
  test('TTS substitutions do not require changing visible text', () {
    const processor = TtsTextProcessor();
    final spoken = processor.process(
      'Yuki **回来了**。',
      replacements: const {'Yuki': '有希'},
    );
    expect(spoken, '有希 回来了。');
  });

  test('Yuki is no longer changed by a fixed pronunciation rule', () {
    const processor = TtsTextProcessor();
    expect(processor.process('YUKI yuki YuKi'), 'YUKI yuki YuKi');
  });

  test('Chinese Genie hotwords are case-insensitive and speech-only', () {
    const processor = TtsTextProcessor();
    expect(
      processor.process('DeepSeek 用了 TOKEN 和 token。'),
      '地铺C咳 用了 拖肯 和 拖肯。',
    );
    expect(
      processor.process(
        'DeepSeek generated tokens.',
        language: ChatLanguage.english,
      ),
      'DeepSeek generated tokens.',
    );
  });

  test('A2 removable bracket blocks are speech-only', () {
    const processor = TtsTextProcessor();
    expect(
      processor.process('保留（这里不读。）正文【这个也不读】。'),
      '保留正文。',
    );
  });

  test('dialogue-only scope reads corner quotes and skips actions', () {
    const processor = TtsTextProcessor();
    const source = '（她轻轻把耳鳍压低）\n\n「才没有一直等你。」';
    expect(processor.process(source), '才没有一直等你。');
  });

  test('dialogue-only scope also accepts Chinese curly quotes', () {
    const processor = TtsTextProcessor();
    const source = '（她轻轻吸了口气）\n\n“你轻点……”';
    expect(processor.process(source), '你轻点……');
  });

  test('dialogue-only scope skips a standalone action after dialogue', () {
    const processor = TtsTextProcessor();
    const source = '「才没有。」\n\n话音落下，尾巴尖又偷偷晃了一下。';
    expect(processor.process(source), '才没有。');
  });

  test('full-text scope includes actions and dialogue', () {
    const processor = TtsTextProcessor();
    const source = '（她轻轻把耳鳍压低）\n\n「才没有一直等你。」';
    expect(
      processor.process(source, scope: TtsReadingScope.fullText),
      '她轻轻把耳鳍压低。才没有一直等你。',
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
