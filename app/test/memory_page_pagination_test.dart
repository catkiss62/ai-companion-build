import 'dart:async';

import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/features/memory/memory_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
  });
  tearDown(() => db.closeForTesting());

  Future<void> seed(int count) async {
    final database = await db.database;
    final batch = database.batch();
    for (var index = 0; index < count; index++) {
      final id = index.toString().padLeft(3, '0');
      batch.insert('memory_items', {
        'id': id,
        'kind': 'shared_experience',
        'content': '记忆$id',
        'created_at': 1000,
        'updated_at': 2000,
        'importance': 0.5,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 150 && finder.evaluate().isEmpty; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
    expect(finder, findsOneWidget);
  }

  Future<void> waitForMore(WidgetTester tester) async {
    for (var attempt = 0; attempt < 150 &&
        find.text('正在加载…').evaluate().isNotEmpty; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
    expect(find.text('正在加载…'), findsNothing);
  }

  testWidgets('load more reaches memories after 300 with a truthful end marker', (tester) async {
    await tester.runAsync(() async {
      await seed(301);
      await tester.pumpWidget(MaterialApp(home: MemoryPage(database: db)));
      await waitFor(tester, find.text('记忆000'));
      for (var page = 1; page <= 3; page++) {
        await tester.scrollUntilVisible(
          find.text('加载更多'),
          1200,
          scrollable: find.descendant(
            of: find.byType(ListView), matching: find.byType(Scrollable)),
        );
        expect(find.text('已加载 ${page * 100} 条记忆'), findsOneWidget);
        await tester.tap(find.text('加载更多'));
        await tester.pump();
        await waitForMore(tester);
      }
      await tester.scrollUntilVisible(
        find.text('已显示全部 301 条记忆'),
        1200,
        scrollable: find.descendant(
          of: find.byType(ListView), matching: find.byType(Scrollable)),
      );
      expect(find.text('记忆300'), findsOneWidget);
      expect(find.text('加载更多'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('a new search invalidates a pending load-more before debounce completes', (tester) async {
    await tester.runAsync(() async {
      await seed(120);
      final database = await db.database;
      await database.insert('memory_items', {
        'id': 'unique',
        'kind': 'user_profile',
        'content': '筛选唯一',
        'created_at': 1000,
        'updated_at': 2000,
        'importance': 0.5,
      });
      await tester.pumpWidget(MaterialApp(home: MemoryPage(database: db)));
      await waitFor(tester, find.text('记忆000'));
      await tester.scrollUntilVisible(
        find.text('加载更多'),
        1200,
        scrollable: find.descendant(
          of: find.byType(ListView), matching: find.byType(Scrollable)),
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      final blocked = database.transaction((txn) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      try {
        await tester.tap(find.text('加载更多'));
        await tester.pump();
        expect(find.text('正在加载…'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '筛选唯一');
        await tester.pump();
      } finally {
        release.complete();
        await blocked;
      }
      await waitFor(tester, find.text('已显示全部 1 条记忆'));
      expect(find.widgetWithText(ListTile, '筛选唯一'), findsOneWidget);
      expect(find.text('记忆100'), findsNothing);
      expect(find.text('加载更多'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
