import 'dart:async';

import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/features/chat/chat_controller.dart';
import 'package:ai_companion_localfirst/features/creative/creative_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const channel = MethodChannel('ai_companion/system');
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
    expect(finder, findsOneWidget);
  }

  for (final action in ['暂停制作', '删除作品']) {
    testWidgets('open $action menu retains its original request through an in-flight card refresh', (tester) async {
      final db = (await tester.runAsync(() => AppDatabase.createForTesting(databaseFactoryFfi)))!;
      final store = CreativeStore(db);
      final chat = ChatController(db: db);
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      final release = Completer<void>();
      Future<void>? blocked;
      try {
        final old = (await tester.runAsync(() => store.commission(deepThinking: true,
          requestId: 'original', messageId: 'old-card', brief: '小灯',
          requestQuote: '小灯', latestText: '做小灯')))!;
        final id = old['id'] as String;
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: CreativeCards(chat: chat))));
        await tester.runAsync(() => waitFor(tester, find.text('新的小作品')));
        await tester.tap(find.text('新的小作品')); await tester.pump();

        final entered = Completer<void>();
        await tester.runAsync(() async {
          await store.stop(id);
          final next = await store.commission(deepThinking: true, requestId: 'replacement',
            messageId: 'new-card', brief: '蓝灯', requestQuote: '蓝灯', latestText: '改蓝灯', workId: id);
          await store.write(next, {...next, 'title': '新版作品'});
          final handle = await db.database;
          blocked = handle.transaction((txn) async { entered.complete(); await release.future; });
          await entered.future;
        });
        // Start the real periodic refresh before showing the menu, then let
        // its database reads finish while the old menu is still open.
        await tester.pump(const Duration(seconds: 4));
        await tester.tap(find.byType(PopupMenuButton<String>)); await tester.pumpAndSettle();
        await tester.runAsync(() async {
          release.complete(); await blocked;
          await waitFor(tester, find.text('新版作品'));
        });
        await tester.tap(find.text(action)); await tester.pumpAndSettle();
        if (action == '删除作品') {
          expect(find.text('删除这件作品？'), findsOneWidget);
          await tester.tap(find.text('删除')); await tester.pumpAndSettle();
        }
        await tester.runAsync(() => waitFor(tester, find.text('作品或当前任务已变化，请刷新后重试')));
        final after = (await tester.runAsync(() => store.get(id)))!;
        expect(after['request_id'], 'replacement');
        expect(after['status'], 'queued');
      } finally {
        if (!release.isCompleted) release.complete();
        await tester.runAsync(() async { await blocked; });
        await tester.pumpWidget(const SizedBox.shrink());
        chat.dispose();
        await tester.runAsync(db.closeForTesting);
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  }
}
