import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/qq_archive_schema.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_recovery.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_ingress_buffer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;late int now;
  final cid=QqStore.conversationId('fixture','group','g');
  setUp(() async {db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);now=DateTime.now().millisecondsSinceEpoch;});
  tearDown(() async {await db.closeForTesting();});
  Future<QqBatch> batch(String id) async {
    final fence=await store.capture(conversationId:cid);
    final seq=(await store.append(fence:fence,scope:'fixture',kind:'group',target:'g',platformId:id,sender:'peer',text:'合成问题',observedAt:now,receivedAt:now,policy:'policy'))!;
    return (await store.claim(fence,cid,seq,now,policy:'policy'))!;
  }
  test('unsent technical failure retries without a new message after backoff',() async {
    final b=await batch('one'),retry=QqReplyRecovery(store);
    await store.mark(b,'failed');expect(await retry.defer(b,now),true);
    expect(await retry.claim(await store.capture(),cid,now,'policy'),isNull);
    now+=15000;
    final next=(await retry.claim(await store.capture(),cid,now,'policy'))!;
    expect(next.id,b.id);expect(next.rows.single['seq'],b.through);
    await store.mark(next,'failed');expect(await retry.defer(next,now),true);
    expect(await retry.claim(await store.capture(),cid,now+15000,'policy'),isNull);
    expect(await retry.claim(await store.capture(),cid,now+30000,'policy'),isNotNull);
  });
  for(final state in ['send_uncertain','partially_sent','sent_archive_failed','sent']) {
    test('$state is never automatically replayed',() async {
      final b=await batch(state),retry=QqReplyRecovery(store);
      await store.mark(b,state);expect(await retry.defer(b,now),false);
      expect(await retry.claim(await store.capture(),cid,now+60000,'policy'),isNull);
    });
  }
  test('backup orphan recovers only after unfreeze, and a sending orphan stays unknown',() async {
    final b=await batch('first'),retry=QqReplyRecovery(store);
    final token=await db.acquireTransferFreeze(purpose:'backup_export');
    await expectLater(retry.due(await store.capture(),now,{}),throwsA(anything));
    await db.releaseTransferFreeze(token);
    expect(await retry.due(await store.capture(),now,{}),contains(cid));
    final next=(await retry.claim(await store.capture(),cid,now,'policy'))!;
    await store.mark(next,'sending');
    expect(await retry.due(await store.capture(),now,{}),isEmpty);
    final row=(await (await db.database).query('qq_reply_tasks',where:'id=?',whereArgs:[b.id])).single;
    expect(row['stage'],'send_uncertain');
  });
  test('active owner, changed policy, newer topic, expiry and restored tasks cannot replay',() async {
    final b=await batch('first'),retry=QqReplyRecovery(store);
    expect(await retry.due(await store.capture(),now,{cid}),isEmpty);
    await store.mark(b,'failed');await retry.defer(b,now);now+=15000;
    expect(await retry.claim(await store.capture(),cid,now,'changed'),isNull);
    await batch('new-topic');
    expect(await retry.claim(await store.capture(),cid,now,'policy'),isNull);
    expect(await retry.claim(await store.capture(),cid,now+240000,'policy'),isNull);
    await QqArchiveSchema.restored(await db.database);
    expect(await retry.claim(await store.capture(),cid,now,'policy'),isNull);
  });
  test('malformed or inherited confirmation facts never allow an automatic retry',() async {
    final b=await batch('one'),sql=await db.database;
    await store.mark(b,'failed');
    for(final raw in ['broken',jsonEncode({'inherited_delivery':{'unknown':true}}),jsonEncode({'delivery':{'confirmed':[{'sequence':1}]}})]) {
      await sql.update('qq_reply_tasks',{'draft':raw},where:'id=?',whereArgs:[b.id]);
      expect(await QqReplyRecovery(store).defer(b,now),false);
    }
  });
  test('private backup inbox survives reopening and consumes only after acceptance',() async {
    final temp=await Directory.systemTemp.createTemp('qq-inbox-fixture-');
    try {
      final file=File('${temp.path}/inbox.json'),fence=await store.capture();
      await QqIngressBuffer(file).hold({'id':'one','content':'合成消息'},true,fence,'policy',now);
      final buffer=QqIngressBuffer(file);var calls=0;
      await buffer.drain(fence,'policy',now+1000,(e,g,at) async {calls++;expect(at,now);return false;});
      await buffer.drain(fence,'policy',now+2000,(e,g,at) async {calls++;return true;});
      await buffer.drain(fence,'policy',now+3000,(e,g,at) async {fail('duplicate');return true;});
      expect(calls,2);expect(jsonDecode(await file.readAsString()),isEmpty);
    } finally {await temp.delete(recursive:true);}
  });
  test('inbox drops changed policy, expired messages and a different state identity',() async {
    final buffer=QqIngressBuffer(),fence=await store.capture();
    Future<bool> no(Map<String,dynamic> e,bool g,int at) async {fail('stale event accepted');return true;}
    await buffer.hold({'id':'one'},true,fence,'old',now);
    await buffer.drain(fence,'new',now,no);
    await buffer.hold({'id':'two'},true,fence,'new',now);
    await buffer.drain(fence,'new',now+240001,no);
    await buffer.hold({'id':'three'},true,fence,'new',now);
    await db.setSetting('runtime_state_epoch_v1','different');
    await buffer.drain(await store.capture(),'new',now,no);
  });
}
