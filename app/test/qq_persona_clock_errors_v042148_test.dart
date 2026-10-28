import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/desire/daily_wake_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_circadian.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_failure_history.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_group_persona.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  test('public draft preserves three distinct complete rules and seven public traits',() {
    final p=QqGroupPersonaProjection.compose(card:'用户编辑的小卡');
    for(final name in ['用户编辑的小卡','【对话活人感】','【角色表达自然化】','【日常对话规则】','去工具化与自主判断','单一聚焦与去表演化']) {
      expect(p,contains(name));
    }
    expect(p,contains('不替当前发言者及其他群成员编写'));expect(p,contains('允许说长、说细'));
    expect(p,isNot(contains('动作独占一行')));expect(p,isNot(contains('身体诚实')));
    const custom=QqOptions(core:'自定义小卡',personaSetting:'用户公开稿');
    expect(custom.copy(ownerShare:false).core,'自定义小卡');expect(custom.copy(ownerShare:false).publicPersona,'用户公开稿');
    expect(const QqOptions().toJson().containsKey('persona'),false);
  });
  for(final entry in {'08:42':'resting','08:43':'waking','09:27':'waking','09:28':'daytime','22:00':'sleepy','23:00':'very_sleepy','00:01':'resting'}.entries) {
    test('shared 08:43 wake / 09:28 clear gives ${entry.key}=${entry.value}',() {
      final parts=entry.key.split(':');final time=DateTime(2026,10,28,int.parse(parts[0]),int.parse(parts[1]));
      expect(QqCircadianProjection.derive(time,wakeMinute:523).phase,entry.value);
    });
  }
  test('QQ does not sample or write a missing shared day',() async {
    final db=await AppDatabase.createForTesting(databaseFactoryFfi);
    try {
      final time=DateTime(2026,10,28,8,50),key=DailyWakeStore.keyFor(DateTime(2026,10,28));
      await (await db.database).delete('settings',where:'key=?',whereArgs:[key]);
      expect((await QqCircadianProjection.read(db,time)).phase,'resting');expect(await db.getSetting(key),isNull);
      await db.setSetting(key,jsonEncode({'minute':523,'sampledAt':1}));
      final before=await db.getSetting(key);expect((await QqCircadianProjection.read(db,time)).phase,'waking');expect(await db.getSetting(key),before);
    } finally {await db.closeForTesting();}
  });
  test('twenty operations retain associated retries and recovery without raw exceptions',() {
    var history='[]';
    for(var i=0;i<21;i++)history=QqFailureHistory.record(history,operation:'op$i',at:i,phase:'second_reply',code:'network',attempt:1);
    expect(QqFailureHistory.decode(history).length,20);expect(QqFailureHistory.decode(history).last['operation'],'op1');
    for(var attempt=2;attempt<=3;attempt++)history=QqFailureHistory.record(history,operation:'op20',at:30+attempt,
      phase:attempt==3?'first_reply':'second_reply',code:'timeout',attempt:attempt);
    history=QqFailureHistory.finish(history,'op20','sent');
    final row=QqFailureHistory.decode(history).first;
    expect(row['attempts'],hasLength(3));expect(row['outcome'],'sent');
    expect(QqFailureHistory.safeCode('https://example.com/?token=secret'),'operation_failed');
    expect(QqFailureHistory.decode('not json'),isEmpty);
  });
}
