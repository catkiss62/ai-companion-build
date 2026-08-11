import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/tts/tts_sentence_segmenter.dart';

void main() {
  test('mirrors A2 punctuation and drops delimiters', () {
    final s = TtsSentenceSegmenter();
    expect(s.add('你终于回来'), isEmpty);
    expect(s.add('了。还有一件'), ['你终于回来了']);
    expect(s.add('事想告诉你！'), ['还有一件事想告诉你']);
    expect(s.flush(), isEmpty);
  });

  test('does not split on comma newline ideographic comma or ellipsis', () {
    final s = TtsSentenceSegmenter();
    expect(s.add('今天不急，慢慢聊、也可以\n停一下……都没关系'), isEmpty);
    expect(s.add('。'), ['今天不急，慢慢聊、也可以\n停一下……都没关系']);
  });

  test('ignores sentence punctuation inside A2 removable brackets', () {
    final s = TtsSentenceSegmenter();
    expect(s.add('你好（这里。不会切）世界。'), ['你好（这里。不会切）世界']);
    expect(s.flush(), isEmpty);
  });

  test('does not speak fenced code blocks', () {
    final s = TtsSentenceSegmenter();
    final out = <String>[];
    out.addAll(s.add('先说一句。```dart\nprint("不要读");'));
    out.addAll(s.add('\n```然后继续。'));
    out.addAll(s.flush());
    expect(out, ['先说一句', '然后继续']);
  });

  test('punctuation-free text waits until final flush without soft split', () {
    final s = TtsSentenceSegmenter();
    final text = '这是一段非常长的内容，为了严格保持妹居A2行为，即使很长也不会因为字符数量被人为切开';
    expect(s.add(text), isEmpty);
    expect(s.flush(), [text]);
  });
}
