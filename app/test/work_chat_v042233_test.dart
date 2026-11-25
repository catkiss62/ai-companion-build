import 'dart:async';
import 'dart:convert';
import 'package:ai_companion_localfirst/core/agent/work_error.dart';
import 'dart:io';
import 'package:ai_companion_localfirst/features/chat/work_html_card.dart';

import 'package:ai_companion_localfirst/core/agent/commission_workspace.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/features/chat/work_conversation.dart';
import 'package:ai_companion_localfirst/features/chat/work_markdown.dart';
import 'package:ai_companion_localfirst/features/chat/work_mode_view.dart';
import 'package:flutter/material.dart';
import 'package:ai_companion_localfirst/features/chat/work_turn_footer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('work failures distinguish a dropped connection, timeout and missing file', () {
    expect(workErrorReason(const SocketException('lost')), '连接中断');
    expect(workErrorReason(TimeoutException('late')), '请求超时');
    expect(workErrorReason(StateError('工作文件已移动或删除')), '工作文件已移动或删除');
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cache hit rate is input weighted and unknown cache usage stays unknown',
    () {
      final first = {'input': 655, 'output': 800, 'hit': 512, 'miss': 143};
      WorkUsage usage(List<Map> lanes) => WorkUsage([
        for (final u in lanes)
          {
            'usage': {'lane': u},
          },
      ]);
      expect(usage([first]).percent, '78.2%');
      expect(
        usage([
          first,
          {'input': 345, 'output': 50, 'hit': 0, 'miss': 345},
        ]).percent,
        '51.2%',
      );
      expect(
        usage([
          first,
          {'input': 2, 'output': 1},
        ]).partialCache,
        true,
      );
      expect(
        usage([
          {'input': 2},
        ]).percent,
        isNull,
      );
    },
  );

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

  testWidgets('copy answer and saved HTML independently', (tester) async {
    const answer = '## 说明\n正文含代码 `ok`';
    const html = '<style>p{color:red}</style>\n<p>小鲸鱼</p><script>let n=1;</script>';
    final copied = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add(call.arguments['text'] as String);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      const WorkTurnFooter({'answer': answer}, live: false),
      WorkHtmlCard(title: '测试作品', load: () async => html),
    ]))));
    await tester.tap(find.byTooltip('复制正文'));
    await tester.pump();
    expect(copied, [answer]);
    await tester.tap(find.text('测试作品'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('复制源码'));
    await tester.pump();
    expect(copied, [answer, html]);
  });

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
          'endedAt': DateTime(2026, 1, 1, 2, 10).millisecondsSinceEpoch,
          'elapsedMs': 2250,
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
            'commission_research_planning': {
              'input': 12,
              'output': 3,
              'hit': 3,
              'miss': 9,
            },
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
    expect(find.text('02:10'), findsOneWidget);
    await tester.tap(find.byTooltip('本轮用量'));
    await tester.pumpAndSettle();
    expect(find.text('25.0%'), findsOneWidget);
    expect(find.text('2.3 秒'), findsOneWidget);
    await tester.tapAt(const Offset(3, 3));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '继续');
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.tap(find.byTooltip('发送工作消息'));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    await tester.tap(find.text('轨迹'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('请求超时', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('规划 2 轮'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
