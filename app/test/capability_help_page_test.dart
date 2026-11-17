import 'package:ai_companion_localfirst/features/settings/capability_help_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets('help sections remain readable at 320 dp and scale $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const CapabilityHelpPage(),
      ));
      // Exercise real expandable sections, including registry-generated lists.
      for (final title in [
        '普通聊天可调用', '她可自主使用', '模型通道与深度思考',
        '小作品、委托与自主创作', 'QQ 私聊与群聊', '记忆、原文与房间',
        '停止、刷新与卡住时怎么办', '网页、图片与查手机', 'Cedar Toy 游戏厅',
        '本地语音与呈现', '备份、恢复与设备接管', '权限与隐私边界',
        '尚未开放', '排查问题时提供什么',
      ]) {
        final heading = find.text(title);
        await tester.scrollUntilVisible(heading, 200,
            scrollable: find.byType(Scrollable).first, maxScrolls: 100);
        await tester.tap(heading);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: title);
        // Collapse before moving on so offscreen retained paragraphs do not
        // conceal a missing section or cause excessive test scrolling.
        await tester.ensureVisible(heading);
        await tester.tap(heading);
        await tester.pumpAndSettle();
      }
    });
  }
}
