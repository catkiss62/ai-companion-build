import 'package:ai_companion_localfirst/core/models/chat_language_variant.dart';
import 'package:ai_companion_localfirst/core/tts/tts_queued_segment_packer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('packs queued Chinese units toward Genie target', () {
    final packed = TtsQueuedSegmentPacker.packPrefix(
      const ['我忍不住笑出声。', '她也跟着笑了。', '后来我们继续往前走。'],
      ChatLanguage.chinese,
    );

    expect(packed.text, '我忍不住笑出声。她也跟着笑了。后来我们继续往前走。');
    expect(packed.sourceUnits, 3);
    expect(packed.text.length, lessThanOrEqualTo(54));
  });

  test('does not cross the hard maximum', () {
    final first = '这是一段已经比较接近目标长度的自然语句。';
    final second = List<String>.filled(
      2,
      '这一个后续句子很长，所以必须留到下一轮单独处理。',
    ).join();
    final packed = TtsQueuedSegmentPacker.packPrefix(
      [first, second],
      ChatLanguage.chinese,
    );

    expect(packed.text, first);
    expect(packed.sourceUnits, 1);
  });

  test('restores a space between queued English units', () {
    final packed = TtsQueuedSegmentPacker.packPrefix(
      const ['A short sentence.', 'Another short sentence.'],
      ChatLanguage.english,
    );

    expect(packed.text, 'A short sentence. Another short sentence.');
    expect(packed.sourceUnits, 2);
  });
}
