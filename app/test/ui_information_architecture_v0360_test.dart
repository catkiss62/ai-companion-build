import 'package:ai_companion_localfirst/features/more/companion_more_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the unique More center exposes identity and settings domains',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CompanionMorePage())),
    );
    for (final label in [
      '她',
      '你们',
      '模型与联网',
      '记忆与成长',
      '主动联系与感知',
      '语音与聊天呈现',
      '表情包',
      '设备与数据',
      '诊断与开发',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('更多与全部设置'), findsOneWidget);
    expect(find.textContaining('唯一完整设置中心'), findsOneWidget);
    expect(find.textContaining('MCP 连接'), findsNothing);
    expect(find.textContaining('Skills 安装'), findsNothing);
  });
}
