import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/qq_archive_schema.dart';
import 'package:ai_companion_localfirst/core/qq/qq_message_material.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_tasks.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;
  const scope='recovery-fixture';final cid=QqStore.conversationId(scope,'group','g');
  var now=DateTime(2026,10,28,12).millisecondsSinceEpoch;
  setUp(() async {db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);now=DateTime(2026,10,28,12).millisecondsSinceEpoch;});
  tearDown(() async {await db.closeForTesting();});
  Future<int?> add(String id,{bool mention=false,String text='合成问题',String reply='',String context=''}) async => store.append(
    fence:await store.capture(conversationId:cid),scope:scope,kind:'group',target:'g',platformId:id,sender:'peer',text:text,
    observedAt:now,receivedAt:now,mentioned:mention,replyTo:reply,contextMeta:context,policy:'policy');
  Future<QqBatch> claim(int through) async => (await store.claim(await store.capture(conversationId:cid),cid,through,now,policy:'policy'))!;

  for(final whileActive in [false,true]) {
    test('late AT upgrades one logical source ${whileActive?'while judging':'after watch'} and is consumed once',() async {
      final seq=(await add('same'))!;final first=await claim(seq);
      if(!whileActive)await store.mark(first,'watching');
      expect(await add('same',mention:true),seq);
      expect((await (await db.database).query('qq_archive',where:"role='user'")).length,1);
      if(whileActive) {
        expect(await store.mentioned(first),true);
        await store.sentPart(first,1,'已回应','',now);await store.mark(first,'sent');
      } else {
        final resumed=await claim(seq);expect(resumed.id,isNot(first.id));
        expect(await store.mentioned(resumed),true);await store.mark(resumed,'watching');
      }
      expect(await add('same',mention:true),isNull);
      expect(await store.pending(cid),isEmpty);
      await store.recover(await store.capture());expect(await store.pending(cid),isEmpty);
    });
  }
  for(final state in ['sent','sent_archive_failed','partially_sent','send_uncertain']) {
    test('late AT never reopens $state including pre-upgrade receipts',() async {
      final seq=(await add('sent-source'))!,b=await claim(seq);
      await store.mark(b,state);
      if(state=='sent')await (await db.database).delete('qq_reply_tasks');
      expect(await add('sent-source',mention:true),isNull);
      expect(await store.pending(cid),isEmpty);
    });
  }
  test('failed addressed request is read only on a new trigger and verification draft is reusable',() async {
    final first=await claim((await add('first',mention:true))!);final tasks=QqReplyTasks(store);
    await tasks.saveDraft(first,{'raw':'原正文'});await tasks.failure(first,'group_boundary');await store.mark(first,'failed');
    expect(await store.pending(cid),isEmpty);
    now+=1000;final next=await claim((await add('follow',text:'卡住了？'))!);
    final pending=await tasks.pending(next,now,'policy');expect(pending,isNotNull);
    expect(pending!.hint['previous_request_unfinished'],true);expect(pending.requests,['合成问题']);
    expect(pending.draft!['raw'],'原正文');
    await tasks.consume(next,pending,cancel:false);
    expect(await tasks.pending(next,now,'policy'),isNull);
    final row=(await (await db.database).query('qq_reply_tasks',where:'id=?',whereArgs:[next.id])).single;
    expect((jsonDecode(row['source_stamp'] as String) as List).length,2);
  });
  test('unknown or partial delivery never supplies a resendable draft',() async {
    final first=await claim((await add('first',mention:true))!);final tasks=QqReplyTasks(store);
    await tasks.saveDraft(first,{'raw':'不能重发'});await tasks.failure(first,'send');await store.mark(first,'send_uncertain');
    now+=1000;final next=await claim((await add('follow'))!);
    final pending=(await tasks.pending(next,now,'policy'))!;
    expect(pending.hint['delivery_unknown'],true);expect(pending.draft,isNull);
  });
  test('expiry, policy change and archive source deletion make old requests unavailable',() async {
    final first=await claim((await add('first',mention:true))!);await store.mark(first,'failed');
    now+=1000;final next=await claim((await add('follow'))!);final tasks=QqReplyTasks(store);
    expect(await tasks.pending(next,now,'other-policy'),isNull);
    expect(await tasks.pending(next,now+QqReplyTasks.ttl.inMilliseconds,'policy'),isNull);
    await (await db.database).delete('qq_archive',where:'seq=?',whereArgs:[first.through]);
    expect(await tasks.pending(next,now,'policy'),isNull);
  });
  test('restore invalidates drafts and mention triggers without restoring permission',() async {
    final first=await claim((await add('first',mention:true))!);await store.mark(first,'failed');
    await QqReplyTasks(store).saveDraft(first,{'raw':'旧草稿'});
    final sql=await db.database;await QqArchiveSchema.restored(sql);
    expect((await sql.query('qq_reply_tasks')).single['draft'],'');
    expect((await sql.query('qq_reply_tasks')).single['valid'],0);
    expect(await db.getSetting('qq_master_enabled_v2'),'0');expect(await store.pending(cid),isEmpty);
  });
  test('confirmed platform id and index join only same-group assistant quotes',() async {
    final first=await claim((await add('first'))!);
    store.received(first,1,platformId:'platform-receipt',platformIndex:'platform-index');
    await store.sentPart(first,1,'真实已发送的原话','',now);await store.mark(first,'sent');
    now+=1000;await add('quote',reply:'platform-receipt',context:const QqMessageMaterial(kind:'quote',reference:'platform-index').encode());
    final sql=await db.database,reader=QqArchiveReader(sql),stamp=<Map<String,Object?>>[];
    final row=(await sql.query('qq_archive',where:"platform_id='quote'")).single;
    final projection=await reader.render(row,stamp:stamp);
    expect(projection,contains('quoted_assistant'));expect(projection,contains('真实已发送的原话'));
    expect(await reader.matches(stamp),true);
    await sql.delete('qq_archive',where:"role='assistant'");expect(await reader.matches(stamp),false);
  });
}
