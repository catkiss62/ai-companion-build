import 'dart:convert';
import 'dart:io';

import 'package:ai_companion_localfirst/core/agent/commission_workspace.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/features/chat/work_conversation.dart';
import 'package:ai_companion_localfirst/features/chat/work_markdown.dart';
import 'package:ai_companion_localfirst/features/chat/work_mode_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'narrow dark document renders a table and copies the fenced source',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 620);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = call.arguments['text'];
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      const source =
          '## 对比\n\n> 已核实\n\n| 文件 | 状态 | 说明 |\n| --- | --- | --- |\n| A | 完成 | 可复查 |\n\n~~~dart\nprint(42);\n~~~';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: workSurface,
            body: SingleChildScrollView(child: WorkMarkdown(source)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Table), findsOneWidget);
      expect(find.byTooltip('复制代码'), findsOneWidget);
      await tester.tap(find.byTooltip('复制代码'));
      await tester.pump();
      expect(copied, 'print(42);');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reopening a saved task exposes only recorded tools and usage', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync();
    addTearDown(() => dir.deleteSync(recursive: true));
    final ws = CommissionWorkspace(directory: dir);
    const id = '00000000-0000-0000-0000-000000000001';
    final work = WorkConversation(
      AppDatabase.instance,
      SecureConfig.instance,
      () => false,
    );
    final input = TextEditingController();
    final focus = FocusNode();
    addTearDown(work.dispose);
    addTearDown(input.dispose);
    addTearDown(focus.dispose);
    await tester.runAsync(() async {
      await ws.write(
        '任务-$id.json',
        jsonEncode({
          'id': id,
          'goal': '核对仓库',
          'answer': '## 结论\n正文',
          'state': 'completed',
          'planningRounds': 2,
          'receipts': [
            {
              'tool': 'github_read_readme',
              'target': 'foo/bar',
              'state': 'failed',
              'error': 'github_timeout',
            },
          ],
          'usage': {
            'commission_research_planning': {'input': 12, 'output': 3},
          },
        }),
      );
      await work.open(ws, '任务-$id.json');
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkPanel(
            work: work,
            input: input,
            focus: focus,
            onSend: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('已回报 15 Token'), findsOneWidget);
    await tester.tap(find.text('轨迹'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('github_timeout', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('规划 2 轮'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
