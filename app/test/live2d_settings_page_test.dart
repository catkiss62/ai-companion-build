import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/features/chat/live2d_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
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
