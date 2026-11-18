import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/features/chat/word_slice_bridge.dart';

void main() {
  testWidgets('snapshot keeps visible text coordinates and never changes text', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      const Text('不在聊天区域'),
      SizedBox(key: key, width: 280, height: 80, child: const Text('鲸🐳 爱', style: TextStyle(fontSize: 20))),
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
      controller: scroll, children: const [SizedBox(height: 80, child: Text('旧')),
        SizedBox(height: 80, child: Text('新')),
      ],
    )))));
    final chars = captureVisibleGlyphs(key).map((g) => g['ch']).join();
    expect(chars, isNot(contains('旧')));
    expect(chars, contains('新'));
    await tester.pumpWidget(const SizedBox()); scroll.dispose();
  });
}
