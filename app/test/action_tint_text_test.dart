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

  test('nested corner quotes keep the whole outer dialogue tinted', () {
    const source =
        '动作在前\n\n「正被你那句「在干嘛呢」从刚才的坏心思里拽回来呢。」\n\n动作在后';
    final segments = splitDialogueText(source);
    expect(segments.map((item) => item.text).join(), source);
    expect(
      segments.where((item) => item.isDialogue).map((item) => item.text),
      ['「正被你那句「在干嘛呢」从刚才的坏心思里拽回来呢。」'],
    );
  });

  test('nested quote remains tinted while the outer quote is streaming', () {
    const source = '「正被你那句「在干嘛呢」从刚才';
    final segments = splitDialogueText(source);
    expect(segments, hasLength(1));
    expect(segments.single.text, source);
    expect(segments.single.isDialogue, isTrue);
  });

  test('curly and ASCII double quotes inherit action styling', () {
    expect(splitDialogueText('“还没说完').last.isDialogue, isFalse);
    expect(splitDialogueText('"still streaming').last.isDialogue, isFalse);
  });

  test('immersive prose recognizes curly and ASCII dialogue quotes', () {
    const source = '叙述。\n\n“你回来了。”\n\n"Welcome back."';
    final segments = splitNovelDialogueText(source);
    expect(segments.map((item) => item.text).join(), source);
    expect(
      segments.where((item) => item.isDialogue).map((item) => item.text),
      ['“你回来了。”', '"Welcome back."'],
    );
  });

  test('immersive prose keeps mixed nested quotes in one dialogue span', () {
    const source = '「正被你那句“在干嘛呢”拽回来呢。」';
    final segments = splitNovelDialogueText(source);
    expect(segments, hasLength(1));
    expect(segments.single.text, source);
    expect(segments.single.isDialogue, isTrue);
  });

  test('immersive curly quote remains tinted while streaming', () {
    const source = '“还没说完';
    final segments = splitNovelDialogueText(source);
    expect(segments, hasLength(1));
    expect(segments.single.text, source);
    expect(segments.single.isDialogue, isTrue);
  });

  testWidgets('actions stay white italic and dialogue defaults to purple',
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
    expect(children.first.style!.color, Colors.white);
    expect(children.last.style!.fontStyle, FontStyle.normal);
    expect(children.last.style!.color, chatDialoguePurple);
    expect(chatDialoguePurple, const Color(0xFFD4BBFC));
    expect(chatDialogueGold, const Color(0xFFFDE68A));
    expect(chatDialoguePink, const Color(0xFFF1B7C5));
  });

  testWidgets('one dialogue color scope controls normal and immersive text',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatDialogueColorScope(
            option: ChatDialogueColorOption.pink,
            child: Column(
              children: [
                ActionTintText(text: '动作\n\n「普通。」'),
                NovelTintText(text: '叙述。\n\n“沉浸。”'),
              ],
            ),
          ),
        ),
      ),
    );

    final text = tester.widgetList<SelectableText>(find.byType(SelectableText));
    for (final selectable in text) {
      final dialogue = selectable.textSpan!.children!
          .cast<TextSpan>()
          .where((span) => span.style?.color == chatDialoguePink);
      expect(dialogue, isNotEmpty);
    }
  });

  testWidgets('immersive prose stays upright and preserves parentheses',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NovelTintText(text: '她停了一下（没有转身）。\n\n「继续。」'),
        ),
      ),
    );
    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    final children = selectable.textSpan!.children!.cast<TextSpan>();
    expect(children.map((item) => item.text).join(),
        '她停了一下（没有转身）。\n\n「继续。」');
    expect(children.first.style!.fontStyle, FontStyle.normal);
    expect(children.first.style!.color, Colors.white);
    expect(children.last.style!.color, chatDialoguePurple);
  });

}
