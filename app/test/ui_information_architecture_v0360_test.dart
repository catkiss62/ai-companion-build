import 'package:ai_companion_localfirst/features/more/companion_more_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('five stable domains are visible without placeholder features',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CompanionMorePage())),
    );
    for (final label in ['她', '你们', '能力', '手机感知', '数据与高级']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('MCP 连接'), findsNothing);
    expect(find.textContaining('Skills 安装'), findsNothing);
  });
}
