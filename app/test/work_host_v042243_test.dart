import 'dart:convert';
import 'package:ai_companion_localfirst/core/agent/commission_session.dart';
import 'package:ai_companion_localfirst/core/agent/work_error.dart';
import 'package:ai_companion_localfirst/core/agent/work_host_actions.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/phone/calendar_reminder_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('fresh goals, resume, examples and wrapped transport errors', () {
    expect(CommissionSession.resumesOrder('继续任务'), isTrue);
    expect(CommissionSession.resumesOrder('继续，但先取消提醒'), isFalse);
    expect(WorkHostActions.requested('十分钟后提醒我吃饭，完成后响一声'), {'remind','ring'});
    expect(WorkHostActions.requested('做一个有朗读和响铃按钮的网页'), isEmpty);
    expect(WorkHostActions.requested('朗读「明天提醒我吃饭」'), {'speak'});
    expect(WorkHostActions.requested('别取消刚才的提醒'), isEmpty);
    expect(WorkHostActions.requested('别取消提醒，读给我听'), {'speak'});
    expect(WorkHostActions.requested('别忘了提醒我喝水'), {'remind'});
    expect(WorkHostActions.requested('取消刚才的提醒'), {'cancel'});
    expect(WorkHostActions.requested('不要响铃，看看有哪些语音'), isEmpty);
    expect(workErrorReason(StateError('Failed host lookup: example')), '连接中断');
  });

  test('process restart verifies durable reminder and audio receipts', () async {
    final db = await AppDatabase.createForTesting(databaseFactoryFfi);
    addTearDown(db.closeForTesting);
    const channel = MethodChannel('ai_companion/system');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var chimes = 0, schedules = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'syncCalendarReminders') { schedules++; return schedules > 1; }
      if (call.method == 'previewCompanionNotificationSound') { chimes++; return {'played': true}; }
      throw MissingPluginException();
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    WorkHostActions order(String id, Set<String> actions) =>
        WorkHostActions(db, id, 'thread', actions, GenerationCancellationToken());
    final create = order('one', {'remind', 'ring'});
    final date = DateTime.now().add(const Duration(days: 2)).toIso8601String().substring(0,16);
    await expectLater(create.execute({'action':'remind','text':'吃饭','local_time':date}), throwsFormatException);
    await create.execute({'action':'ring'});
    final resumed = order('one', {'remind','ring'});
    expect(await resumed.verifyExisting(), hasLength(2));
    expect(resumed.confirmed, {'remind','ring'});
    expect(chimes, 1);
    expect(await CalendarReminderStore(db).load(), hasLength(1));
    await order('two', {'reschedule'}).execute({'action':'reschedule','local_time':date,'text':'吃药'});
    expect((await CalendarReminderStore(db).load()).single.title, '吃药');
    await expectLater(resumed.verifyExisting(), throwsStateError);
    await order('three', {'cancel'}).execute({'action':'cancel'});
    expect(await CalendarReminderStore(db).load(), isEmpty);
    await order('three', {'cancel'}).verifyExisting();
    await db.setSetting('work_action_interrupted_ring', jsonEncode({'state':'dispatching'}));
    await expectLater(order('interrupted', {'ring'}).verifyExisting(), throwsStateError);
    expect(chimes, 1);
    final stopped = order('stopped', {'ring'})..token.cancel();
    await expectLater(stopped.execute({'action':'ring'}), throwsA(isA<GenerationCancelledByUserException>()));
    expect(chimes, 1);
  });
}
