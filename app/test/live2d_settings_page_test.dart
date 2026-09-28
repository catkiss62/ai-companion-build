import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/features/chat/live2d_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  testWidgets('an action returns from nested settings directly to chat', (tester) async {
    await tester.runAsync(() async {
      final db = await AppDatabase.createForTesting(databaseFactoryFfi);
      await db.setSetting('chat_portrait_mode', 'caicai_live2d');
      final calls = <String>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('ai_companion/caicai_live2d');
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'control') {
          calls.add((call.arguments as Map)['method'] as String);
          return true;
        }
        return {'available': true};
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(channel, null);
        await db.closeForTesting();
      });
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) => Scaffold(body: TextButton(
          onPressed: () => Navigator.of(context).pushNamed('/quick'),
          child: const Text('聊天画面'),
        ))),
        routes: {'/quick': (context) => Scaffold(body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => Live2DSettingsPage(database: db))),
          child: const Text('进入 Live2D'),
        ))},
      ));
      await tester.tap(find.text('聊天画面')); await tester.pumpAndSettle();
      await tester.tap(find.text('进入 Live2D'));
      // Build the pushed route before waiting for its real SQLite initialization.
      // pumpAndSettle alone advances fake animation time and can starve database IO.
      await tester.pump();
      for (var attempt = 0; attempt < 50 &&
          find.text('启用菜菜 Live2D').evaluate().isEmpty; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      expect(find.text('启用菜菜 Live2D'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('自主待机'),300);
      await tester.tap(find.text('自主待机'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(calls,contains('static'));
      expect(find.text('聊天画面'),findsOneWidget);
      expect(find.text('进入 Live2D'),findsNothing);
      expect(find.text('Live2D 设置'),findsNothing);
    });
  });
  testWidgets('deletion requires confirmation and disables Live2D only after confirmation', (tester) async {
    await tester.runAsync(() async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.setSetting('chat_portrait_mode', 'caicai_live2d');
    var deletions = 0;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('ai_companion/caicai_live2d');
    const legacy = MethodChannel('ai_companion/live2d_model_storage');
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'clearImportedModels') { deletions++; return null; }
      return {'available': true};
    });
    messenger.setMockMethodCallHandler(legacy, (_) async => {'cleared': true, 'deletedBytes': 1});
    addTearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(legacy, null);
      await db.closeForTesting();
    });
    await tester.pumpWidget(MaterialApp(home: Live2DSettingsPage(database: db)));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    final delete = find.text('删除导入模型');
    await tester.scrollUntilVisible(delete, 500);
    await tester.tap(delete); await tester.pumpAndSettle();
    expect(deletions, 0);
    await tester.tap(find.text('取消')); await tester.pumpAndSettle();
    expect(deletions, 0);
    expect(await db.getSetting('chat_portrait_mode'), 'caicai_live2d');
    await tester.tap(delete); await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(deletions, 1);
    expect(await db.getSetting('chat_portrait_mode'), 'static');
    });
  });
}
