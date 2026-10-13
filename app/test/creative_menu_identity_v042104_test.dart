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
  Future<T> bounded<T>(Future<T> operation, String phase) => operation.timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw TimeoutException('Creative menu test timed out: $phase'));
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await bounded(tester.pump(), 'waiting for $finder');
    }
    expect(finder, findsOneWidget);
  }

  for (final action in ['暂停制作', '删除作品']) {
    testWidgets('open $action menu retains its original request through an in-flight card refresh', (tester) async {
      // Keep IO, its barriers and all UI callbacks in one real async zone.
      // A Completer created in the widget fake zone cannot be completed and
      // awaited inside runAsync without also draining that fake zone.
      await tester.runAsync(() async {
        final db = await bounded(AppDatabase.createForTesting(databaseFactoryFfi), 'open SQLite');
        final store = CreativeStore(db);
        final chat = ChatController(db: db);
        final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (_) async => null);
        final release = Completer<void>();
        Future<void>? blocked;
        var bodyFailed = false;
        try {
          final old = await bounded(store.commission(deepThinking: true,
            requestId: 'original', messageId: 'old-card', brief: '小灯',
            requestQuote: '小灯', latestText: '做小灯'), 'original commission');
          final id = old['id'] as String;
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: CreativeCards(chat: chat))));
          await waitFor(tester, find.text('新的小作品'));
          await tester.tap(find.text('新的小作品')); await tester.pump();

          final entered = Completer<void>();
          await bounded(store.stop(id), 'pause original commission');
          final next = await bounded(store.commission(deepThinking: true, requestId: 'replacement',
            messageId: 'new-card', brief: '蓝灯', requestQuote: '蓝灯', latestText: '改蓝灯', workId: id),
            'replacement commission');
          expect(await bounded(store.write(next, {...next, 'title': '新版作品'}), 'replacement title'), isTrue);
          final handle = await db.database;
          blocked = handle.transaction((txn) async { entered.complete(); await release.future; });
          await bounded(Future.any<void>([entered.future, blocked.then<void>((_) {
            if (!entered.isCompleted) throw StateError('SQLite blocker finished before entering');
          })]), 'SQLite blocker entry');
          // Start the real periodic refresh before showing the menu, then let
          // its database reads finish while the old menu is still open. Since
          // the widget was mounted in runAsync, its 4 s timer uses real time.
          await Future<void>.delayed(const Duration(milliseconds: 4100));
          await tester.pump();
          expect(find.text('新的小作品'), findsOneWidget);
          expect(find.text('新版作品'), findsNothing);
          expect(tester.widget<CreativeWorkCard>(find.byType(CreativeWorkCard))
            .work['request_id'], 'original');
          await tester.tap(find.byType(PopupMenuButton<String>));
          await tester.pumpAndSettle(timeout: const Duration(seconds: 2));
          expect(find.text(action), findsOneWidget);
          release.complete(); await bounded(blocked, 'SQLite blocker release');
          await waitFor(tester, find.text('新版作品'));
          // The real card rebuilt while this same popup route stayed open.
          expect(tester.widget<CreativeWorkCard>(find.byType(CreativeWorkCard))
            .work['request_id'], 'replacement');
          expect(find.text(action), findsOneWidget);
          await tester.tap(find.text(action));
          await tester.pumpAndSettle(timeout: const Duration(seconds: 2));
          if (action == '删除作品') {
            expect(find.text('删除这件作品？'), findsOneWidget);
            await tester.tap(find.text('删除'));
            await tester.pumpAndSettle(timeout: const Duration(seconds: 2));
          }
          await waitFor(tester, find.text('作品或当前任务已变化，请刷新后重试'));
          final after = await bounded(store.get(id), 'read surviving commission');
          expect(after['request_id'], 'replacement');
          expect(after['status'], 'queued');
        } catch (_) {
          bodyFailed = true;
          rethrow;
        } finally {
          if (!release.isCompleted) release.complete();
          Object? cleanupError;
          StackTrace? cleanupStack;
          Future<void> clean(Future<void> Function() operation, String phase) async {
            try { await bounded(operation(), phase); }
            catch (error, stack) { cleanupError ??= error; cleanupStack ??= stack; }
          }
          await clean(() async { await blocked; }, 'drain SQLite blocker');
          await clean(() => tester.pumpWidget(const SizedBox.shrink()), 'dispose cards and timer');
          chat.dispose();
          await clean(db.closeForTesting, 'close SQLite');
          messenger.setMockMethodCallHandler(channel, null);
          if (!bodyFailed && cleanupError != null) {
            Error.throwWithStackTrace(cleanupError!, cleanupStack!);
          }
        }
      });
    }, timeout: const Timeout(Duration(seconds: 30)));
  }
}
