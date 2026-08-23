import 'package:ai_companion_localfirst/widgets/action_tint_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits full-width and ASCII action parentheses without changing text', () {
    const source = '先说话（耳鳍抖了一下），再靠近你 (小声笑)。';
    final segments = splitActionText(source);
    expect(segments.map((item) => item.text).join(), source);
    expect(
      segments.where((item) => item.isAction).map((item) => item.text),
      ['（耳鳍抖了一下）', '(小声笑)'],
    );
  });

  test('unmatched parentheses stay ordinary text', () {
    const source = '这句话（还没有收尾';
    final segments = splitActionText(source);
    expect(segments, hasLength(1));
    expect(segments.single.text, source);
    expect(segments.single.isAction, isFalse);
  });

  test('dialogue tint recognizes both supported Chinese quote styles', () {
    const source = '（她轻轻把耳鳍压低）\n\n「才没有一直等你。」\n“回来就好。”';
    final segments = splitDialogueText(source);
    expect(segments.map((item) => item.text).join(), source);
    expect(
      segments.where((item) => item.isDialogue).map((item) => item.text),
      ['「才没有一直等你。」', '“回来就好。”'],
    );
  });
}
