import 'package:ai_companion_localfirst/widgets/action_tint_text.dart';
import 'package:flutter/material.dart';
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

  test('presentation hides legacy action delimiters and streaming opener', () {
    expect(
      stripActionDelimitersForDisplay('（耳鳍抖了一下）\n「回来啦。」'),
      '耳鳍抖了一下\n\n「回来啦。」',
    );
    expect(
      stripActionDelimitersForDisplay('（她刚刚抬起眼'),
      '她刚刚抬起眼',
    );
  });

  test('dialogue tint is limited to corner quotes', () {
    const source = '（她轻轻把耳鳍压低，说“回来就好”）\\n\\n「才没有一直等你。」\\n"ordinary"';
    final segments = splitDialogueText(source);
    expect(segments.map((item) => item.text).join(), source);
    expect(
      segments.where((item) => item.isDialogue).map((item) => item.text),
      ['「才没有一直等你。」'],
    );
  });

  test('an unmatched opening quote is tinted during streaming', () {
    const source = '（她抬起眼）\n\n「刚刚开始说';
    final segments = splitDialogueText(source);
    expect(segments.map((item) => item.text).join(), source);
    expect(
      segments.where((item) => item.isDialogue).map((item) => item.text),
      ['「刚刚开始说'],
    );
  });

  test('curly and ASCII double quotes inherit action styling', () {
    expect(splitDialogueText('“还没说完').last.isDialogue, isFalse);
    expect(splitDialogueText('"still streaming').last.isDialogue, isFalse);
  });

  testWidgets('actions stay italic and corner dialogue uses novel gold',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActionTintText(text: '耳鳍抖了一下\n\n「回来啦。」'),
        ),
      ),
    );

    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    final children = selectable.textSpan!.children!.cast<TextSpan>();
    expect(children.first.style!.fontStyle, FontStyle.italic);
    expect(children.last.style!.fontStyle, FontStyle.normal);
    expect(children.last.style!.color, chatDialogueGold);
    expect(chatDialogueGold, const Color(0xFFFDE68A));
  });

  testWidgets('subjectless narration remains visible and italic', (tester) async {
    const narration = '歪头看你，尾巴在身后轻轻扫了一下。';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActionTintText(text: '$narration\n\n「抓到你了。」'),
        ),
      ),
    );

    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    final children = selectable.textSpan!.children!.cast<TextSpan>();
    expect(children.first.text, contains(narration));
    expect(children.first.style!.fontStyle, FontStyle.italic);
    expect(children.last.text, '「抓到你了。」');
    expect(children.last.style!.color, chatDialogueGold);
  });

}
