import 'package:ai_companion_localfirst/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Historical validator label: all settings exposes six responsibility domains.
  testWidgets('all settings exposes help and responsibility domains',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SettingsPage()),
      ),
    );

    for (final title in const [
      '帮助与真实能力',
      '模型与联网',
      '记忆与成长',
      '主动联系与感知',
      '语音与聊天呈现',
      '设备与数据',
      '诊断与开发',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('保存'), findsNothing);
    expect(
      find.textContaining('两处使用同一份设置'),
      findsOneWidget,
    );

    await tester.tap(find.text('帮助与真实能力'));
    await tester.pumpAndSettle();
    expect(find.text('让她检查自己的系统'), findsOneWidget);
    expect(find.textContaining('【检查系统】看看你有哪些真实功能'),
        findsOneWidget);
    expect(find.text('普通聊天可调用'), findsOneWidget);
  });
}
