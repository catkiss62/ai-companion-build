import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/phone/calendar_reminder_store.dart';
import 'package:ai_companion_localfirst/features/phone/calendar_reminder_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  testWidgets('weekly editor validates days, persists selection, and can disable the alarm', (tester) async {
    await tester.runAsync(() async {
      final db=await AppDatabase.createForTesting(databaseFactoryFfi);
      final store=CalendarReminderStore(db);
      const channel=MethodChannel('ai_companion/system');
      final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel,(call) async {
        if(call.method=='canScheduleExactReminders' || call.method=='syncCalendarReminders') return true;
        if(call.method=='calendarReminderPresentationStatus') return {'overlay':true,'fullScreen':true};
        return null;
      });
      addTearDown(() async { messenger.setMockMethodCallHandler(channel,null);await db.closeForTesting(); });
      await tester.pumpWidget(MaterialApp(home:CalendarReminderPage(store:store)));
      for(var i=0;i<50 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;i++) {
        await Future<void>.delayed(const Duration(milliseconds:20));await tester.pump();
      }
      await tester.tap(find.byTooltip('添加事项'));await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField),'上班出发');
      await tester.tap(find.byType(DropdownButtonFormField<String>));await tester.pumpAndSettle();
      await tester.tap(find.text('自定义星期').last);await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));await tester.pumpAndSettle();
      expect(find.text('请至少选择一个星期'),findsOneWidget);
      await tester.tap(find.text('周一'));await tester.tap(find.text('周五'));await tester.pump();
      await tester.ensureVisible(find.text('到点响铃提醒'));
      await tester.tap(find.text('到点响铃提醒'));await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await Future<void>.delayed(const Duration(milliseconds:100));await tester.pumpAndSettle();
      var saved=(await store.load()).single;
      expect(saved.repeat,'weekly');expect(saved.weekdays,[1,5]);expect(saved.timed,isTrue);expect(saved.enabled,isTrue);
      await tester.tap(find.byType(Switch));
      await Future<void>.delayed(const Duration(milliseconds:100));await tester.pumpAndSettle();
      saved=(await store.load()).single;expect(saved.enabled,isFalse);expect(saved.weekdays,[1,5]);
      expect(find.textContaining('已停用'),findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
