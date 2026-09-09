import 'package:ai_companion_localfirst/core/models/chat_language_variant.dart';
import 'package:ai_companion_localfirst/core/tts/genie_fixed_text_segmenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('packs natural sentences with the verified 42/54 policy', () {
    expect(
      GenieFixedTextSegmenter.split(
        '第一句。第二句！第三句？',
        ChatLanguage.chinese,
      ),
      <String>['第一句。第二句！第三句？'],
    );
  });

  test('splits oversized text at the nearest soft stop', () {
    final text = '${List.filled(40, '甲').join()}，'
        '${List.filled(30, '乙').join()}。';
    final chunks = GenieFixedTextSegmenter.split(
      text,
      ChatLanguage.japanese,
    );
    expect(chunks, hasLength(2));
    expect(chunks.first, endsWith('，'));
    expect(chunks.every((item) => item.length <= 54), isTrue);
  });

  test('uses the verified 88/110 limits for English', () {
    final text = '${List.filled(30, 'word ').join()}done.';
    final chunks = GenieFixedTextSegmenter.split(
      text,
      ChatLanguage.english,
    );
    expect(chunks.length, greaterThan(1));
    expect(chunks.every((item) => item.length <= 110), isTrue);
  });

  test('a line break becomes a natural Chinese full stop', () {
    expect(
      GenieFixedTextSegmenter.splitWithLimits('前一句\n后一句'),
      <String>['前一句。后一句'],
    );
  });
}
