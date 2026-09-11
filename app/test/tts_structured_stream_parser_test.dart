import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/tts/tts_structured_stream_parser.dart';
import 'package:ai_companion_localfirst/core/tts/tts_text_processor.dart';

void main() {
  test('emits closed immersive sentences with stable semantic roles', () {
    final parser = TtsStructuredStreamParser();

    final first = parser.add('（她抬起眼。');
    final second = parser.add('）\n\n「先说第一句。再说');
    final third = parser.add('第二句。」');

    expect(first.map((unit) => unit.text), ['她抬起眼。']);
    expect(first.single.role, TtsSpeechRole.narration);
    expect(second.map((unit) => unit.text), ['先说第一句。']);
    expect(second.single.role, TtsSpeechRole.dialogue);
    expect(third.map((unit) => unit.text), ['再说第二句。']);
    expect(third.single.role, TtsSpeechRole.dialogue);
    expect(parser.finish(), isEmpty);
  });

  test('interrupted tail stays buffered until verified finish', () {
    final parser = TtsStructuredStreamParser();

    expect(parser.add('「这句还没有结束'), isEmpty);
    parser.reset();
    expect(parser.finish(), isEmpty);

    expect(parser.add('「完整终止但没有标点'), isEmpty);
    expect(parser.finish().single.text, '完整终止但没有标点');
  });
}
