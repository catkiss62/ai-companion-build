import 'package:ai_companion_localfirst/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all settings exposes six responsibility domains',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SettingsPage()),
      ),
    );

    for (final title in const [
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
  });
}
