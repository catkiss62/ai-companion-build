import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/features/chat/word_slice_bridge.dart';

void main() {
  testWidgets('snapshot keeps visible text coordinates and never changes text', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      const Text('不在聊天区域'),
      SizedBox(key: key, width: 280, height: 80, child: const WordSliceText(child: Text('鲸🐳 爱', style: TextStyle(fontSize: 20)))),
    ]))));
    final glyphs = captureVisibleGlyphs(key);
    expect(glyphs.map((g) => g['ch']).join(), '鲸🐳爱');
    expect(glyphs.every((g) => (g['x'] as double) >= 0 && (g['y'] as double) >= 0), isTrue);
    expect(find.text('鲸🐳 爱'), findsOneWidget);
  });
  testWidgets('snapshot excludes scrolled-off paragraphs and clips visible area', (tester) async {
    final key = GlobalKey();
    final scroll = ScrollController(initialScrollOffset: 80);
    await tester.pumpWidget(MaterialApp(home: Center(child: SizedBox(key: key, width: 280, height: 80, child: ListView(
      controller: scroll, children: const [SizedBox(height: 80, child: WordSliceText(child: Text('旧'))),
        SizedBox(height: 80, child: WordSliceText(child: Text('新'))),
      ],
    )))));
    final chars = captureVisibleGlyphs(key).map((g) => g['ch']).join();
    expect(chars, isNot(contains('旧')));
    expect(chars, contains('新'));
    await tester.pumpWidget(const SizedBox()); scroll.dispose();
  });
  testWidgets('real selectable rich body captured, footer and icons excluded', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      key: key, width: 320, height: 240, child: const Column(children: [
        WordSliceText(child: SelectableText.rich(TextSpan(children: [
          TextSpan(text: '屏幕上的聊天'), TextSpan(text: '文字', style: TextStyle(fontStyle: FontStyle.italic)),
        ]))),
        Text('14:58'), Icon(Icons.copy), SelectableText('工具详情不抓取'),
      ]),
    ))));
    final glyphs = captureVisibleGlyphs(key);
    expect(glyphs.map((g) => g['ch']).join(), '屏幕上的聊天文字');
    expect(glyphs.map((g) => g['x']).toSet().length, greaterThan(3));
    expect(find.text('14:58'), findsOneWidget);
  });
  testWidgets('selectable graphemes remain whole and actual body bounds retained', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Padding(
      padding: const EdgeInsets.only(left: 40, top: 90), child: SizedBox(
        key: key, width: 300, height: 100,
        child: const WordSliceText(child: SelectableText('鲸👩‍👩‍👧‍👦é')),
      ),
    ))));
    final glyphs = captureVisibleGlyphs(key);
    expect(glyphs.map((g) => g['ch']).toList(), ['鲸', '👩‍👩‍👧‍👦', 'é']);
    expect(glyphs.every((g) => (g['x'] as double) >= 40 && (g['y'] as double) >= 90), isTrue);
  });

}
