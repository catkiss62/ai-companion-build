import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/phone/calendar_reminder_followup.dart';
import 'package:ai_companion_localfirst/core/phone/calendar_reminder_state.dart';
import 'package:ai_companion_localfirst/core/phone/calendar_reminder_store.dart';
import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  const channel=MethodChannel('ai_companion/system');
  late AppDatabase db;
  late Map<String,Object?> snapshot;
  late Map<String,Object?> event;
  late DateTime start;
  var notifications=0;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db=await AppDatabase.createForTesting(databaseFactoryFfi);
    start=DateTime.now().subtract(const Duration(seconds:10));
    final due=DateTime(start.year,start.month,start.day,start.hour,start.minute);
    event={'id':'test','occurrence':'test:${due.millisecondsSinceEpoch}','title':'出发',
      'startedAt':start.millisecondsSinceEpoch,'scheduledAt':due.millisecondsSinceEpoch,
      'status':'ringing','delivery':'pending'};
    snapshot={'revision':await CalendarReminderStateStore.revision(await db.database),'sequence':1,'records':[event]};
    notifications=0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(call) async {
      if(call.method=='calendarReminderState') return jsonDecode(jsonEncode(snapshot));
      if(call.method=='markCalendarReminderDelivery') {
        final args=Map<String,Object?>.from(call.arguments as Map);
        if(args['revision']==snapshot['revision']) { event['delivery']=args['outcome'];snapshot['sequence']=(snapshot['sequence'] as int)+1; }
      }
      if(call.method=='postCompanionNotification') notifications++;
      if(call.method=='syncCalendarReminders') return true;
      return null;
    });
    await CalendarReminderStore(db).save([CalendarReminder(id:'test',title:'出发',year:due.year,month:due.month,
        day:due.day,yearly:false,hour:due.hour,minute:due.minute)]);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null);
    await db.closeForTesting();
  });
  void finishEvent(String status) {
    event['status']=status;event['stoppedAt']=DateTime.now().millisecondsSinceEpoch;
    event[status=='confirmed'?'confirmedAt':'timedOutAt']=event['stoppedAt'];
    snapshot['sequence']=(snapshot['sequence'] as int)+1;
  }
  ChatMessage reply(String id,DateTime now) => ChatMessage(id:id,role:'assistant',content:'聊天',createdAt:now,isProactive:true);

  test('quick confirmation preserves the one in-flight reminder and does not force another turn',() async {
    final started=Completer<void>();final result=Completer<({String text,String model})?>();var requests=0;
    final followup=CalendarReminderFollowup(db,generator:(messages,current,id) async {
      requests++;started.complete();return result.future;
    });
    final running=followup.deliverOne();await started.future.timeout(const Duration(seconds:20));
    finishEvent('confirmed');
    result.complete((text:'你的出发时间到了。',model:'test'));await running;
    expect((await db.messageById('calendar-reminder:${event['occurrence']}'))?.content,'你的出发时间到了。');
    expect(event['delivery'],'delivered');expect(notifications,1);
    await followup.deliverOne();expect(requests,1);
    for(final mode in PromptGenerationMode.values) {
      final prompt=await PromptBuilder(db).buildChatPrompt(latestUserText:'',recent:const [],
          desire:await db.loadDesire(),thoughts:const [],mode:mode);
      expect(prompt.messages.map((m)=>m['content']).join('\n'),contains('已确认收到'));
    }
  });
  test('a sent user message cancels a stalled generation and its late notification',() async {
    final started=Completer<void>();final result=Completer<({String text,String model})?>();
    late Future<bool> Function() current;
    final running=CalendarReminderFollowup(db,generator:(messages,check,id) async {
      current=check;started.complete();return result.future;
    }).deliverOne();await started.future.timeout(const Duration(seconds:20));
    await db.insertMessage(ChatMessage(id:'user',role:'user',content:'知道啦，我这就去',createdAt:DateTime.now()));
    expect(await current(),isFalse);
    result.complete((text:'旧提醒',model:'test'));await running;
    expect(await db.messageById('calendar-reminder:${event['occurrence']}'),isNull);
    expect(event['delivery'],'cancelled');expect(notifications,0);
  });
  test('editing the schedule cancels an in-flight result at its durable fence',() async {
    final started=Completer<void>();final result=Completer<({String text,String model})?>();
    final running=CalendarReminderFollowup(db,generator:(messages,current,id) async {
      started.complete();return result.future;
    }).deliverOne();await started.future.timeout(const Duration(seconds:20));
    await CalendarReminderStore(db).save(const []);
    result.complete((text:'旧提醒',model:'test'));await running;
    expect(await db.messageById('calendar-reminder:${event['occurrence']}'),isNull);expect(notifications,0);
  });
  test('timeout is a fact, not another forced reply; a late initial reminder is allowed',() async {
    finishEvent('timed_out');var requests=0;
    final followup=CalendarReminderFollowup(db,generator:(messages,current,id) async {
      requests++;expect(messages.map((m)=>m['content']).join('\n'),contains('超时未确认'));
      return (text:'出发的安排现在还来得及吗？',model:'test');
    });
    await followup.deliverOne();await followup.deliverOne();expect(requests,1);
    final state=await CalendarReminderStateStore.read(await db.database);
    expect(state.prompt(DateTime.now()),contains('不推断没听见'));
  });
  test('ordinary proactive commit waits through ringing and ten minutes after stop without quota writes',() async {
    final now=DateTime.now();
    expect(await db.commitProactiveMessageIfCurrent(message:reply('during',now),evaluationStartedAt:now),
      'calendar_reminder_quiet');
    finishEvent('confirmed');final stopped=DateTime.fromMillisecondsSinceEpoch(event['stoppedAt'] as int);
    expect(await db.commitProactiveMessageIfCurrent(message:reply('after',now),evaluationStartedAt:now,
      deliveryAt:stopped.add(const Duration(minutes:9,seconds:59)),proactiveTriggerReason:'ordinary'),
      'calendar_reminder_quiet');
    expect((await (await db.database).query('proactive_history')),isEmpty);
    expect(await db.commitProactiveMessageIfCurrent(message:reply('ready',now),evaluationStartedAt:now,
      deliveryAt:stopped.add(const Duration(minutes:10))),isNull);
    expect(await db.commitProactiveMessageIfCurrent(message:reply('game',now),evaluationStartedAt:now,
      proactiveGameShare:true),isNull);
  });
  test('transaction rejects a user message sent after the reminder preflight check',() async {
    expect(await db.tryAcquireLocalLease('calendar_reminder_followup_lease_until'),isTrue);
    final fence=(await db.captureBrainWorkFence(leaseKey:'calendar_reminder_followup_lease_until'))!;
    await db.insertMessage(ChatMessage(id:'user-atomic',role:'user',content:'已经出发',createdAt:DateTime.now()));
    expect(await db.insertBackgroundMessage(reply('late',DateTime.now()),fence,
      reminderStartedAt:start.millisecondsSinceEpoch,reminderOccurrence:event['occurrence'] as String),isFalse);
    expect(await db.messageById('late'),isNull);
  });
  test('stale native snapshot cannot replace a newer confirmation or a restored identity',() async {
    finishEvent('confirmed');await CalendarReminderStateStore.read(await db.database);
    snapshot['sequence']=1;event['status']='ringing';
    expect((await CalendarReminderStateStore.read(await db.database)).records.single.status,'confirmed');
    // The restore coordinator supplies a fresh runtime epoch to importAll.
    // Bare importAll intentionally preserves exported identity for low-level use.
    final backup=await db.exportAll();await db.importAll(backup,
        runtimeSettingOverrides: {'runtime_state_epoch_v1':'restored-epoch'});
    expect(await CalendarReminderStateStore.revision(await db.database),isNot(snapshot['revision']));
    expect((await CalendarReminderStateStore.read(await db.database)).records,isEmpty);
  });
}
