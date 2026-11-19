import 'package:ai_companion_localfirst/features/settings/settings_page.dart';
import 'package:ai_companion_localfirst/features/more/companion_domains_page.dart';
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
    for (final removed in ['表情包', 'Cedar Toy 游戏厅', 'QQ 私聊']) {
      expect(find.text(removed), findsNothing);
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
  testWidgets('能力和她页按顺序展示入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final (page, labels) in [
      (const CapabilitiesDomainPage(), ['模型、联网、识图与 TTS', '表情包', '生图', 'Cedar Toy 游戏厅', 'QQ 接入']),
      (const CompanionDomainPage(), ['外观与动态状态', '七大规则', '世界书']),
      (const DataAdvancedDomainPage(), ['七大规则']),
    ]) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
      var previous = double.negativeInfinity;
      for (final label in labels) {
        final title = find.text(label);
        expect(title, findsOneWidget);
        final y = tester.getCenter(title).dy;
        expect(y, greaterThan(previous));
        previous = y;
      }
    }
  });

}
