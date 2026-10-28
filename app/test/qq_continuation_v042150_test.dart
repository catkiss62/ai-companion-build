import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/qq_archive_schema.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_tasks.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_delivery.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

class _Api extends QqApi {
  _Api():super(appId:'fixture',secret:'fixture');
  int calls=0;
  @override Future<void> sendMessage({required bool group,required String target,required String messageId,
    required int sequence,String text='',String fileInfo='',Future<bool> Function()? current}) async {calls++;}
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;late QqReplyTasks tasks;late int clock;
  const scope='fixture-150',target='g';final cid=QqStore.conversationId(scope,'group',target);
  setUp(() async {db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);tasks=QqReplyTasks(store);clock=DateTime.now().millisecondsSinceEpoch;});
  tearDown(() async=>db.closeForTesting());
  Future<int> add(String id,{bool mention=false,bool private=false}) async => (await store.append(fence:await store.capture(),scope:scope,
    kind:private?'private':'group',target:target,platformId:id,sender:'peer',text:'问题$id',observedAt:clock,receivedAt:clock,mentioned:mention,policy:'p'))!;
  Future<QqBatch> claim(int seq,{bool private=false}) async => (await store.claim(await store.capture(),
    private?QqStore.conversationId(scope,'private',target):cid,seq,clock,policy:'p'))!;
  for(final terminal in ['sent','partially_sent','send_uncertain','sent_archive_failed']) {
    test('successor $terminal consumes original semantic-direct source before a late AT',() async {
      final seq=await add('original'),first=await claim(seq);await tasks.addressed(first);await store.mark(first,'failed');
      clock+=1000;final next=await claim(await add('follow'));
      final pending=(await tasks.pending(next,clock,'p'))!;expect(await tasks.consume(next,pending,cancel:false),true);
      await store.mark(next,terminal);
      expect(await store.append(fence:await store.capture(),scope:scope,kind:'group',target:target,platformId:'original',
        sender:'peer',text:'问题original',observedAt:clock-1000,receivedAt:clock,mentioned:true,policy:'p'),isNull);
      expect(await store.pending(cid),isEmpty);
    });
  }
  test('a failed successor preserves original requests and original deadline',() async {
    final first=await claim(await add('root',mention:true));await store.mark(first,'failed');
    final deadline=clock+QqReplyTasks.ttl.inMilliseconds;
    clock+=1000;final next=await claim(await add('follow'));
    expect(await tasks.consume(next,(await tasks.pending(next,clock,'p'))!,cancel:false),true);await store.mark(next,'failed');
    clock+=1000;final last=await claim(await add('again'));
    final pending=(await tasks.pending(last,clock,'p'))!;
    expect(pending.requests,['问题root','问题follow']);expect(pending.row['expires_at'],deadline);
    expect(await tasks.pending(last,deadline,'p'),isNull);
  });
  test('bounded source unions survive production export and import',() async {
    for(var batch=0;batch<5;batch++) {
      var through=0;for(var i=0;i<40;i++)through=await add('$batch-$i',mention:i==0);
      final current=await claim(through),prior=await tasks.pending(current,clock,'p');
      if(prior!=null)await tasks.consume(current,prior,cancel:false);
      await store.mark(current,'failed');clock+=1000;
    }
    for(final row in await (await db.database).query('qq_reply_tasks')) {
      expect((jsonDecode(row['sources'] as String) as List).length,lessThanOrEqualTo(80));
      expect((jsonDecode(row['source_stamp'] as String) as List).length,lessThanOrEqualTo(160));
    }
    final backup=await db.exportAll();QqArchiveSchema.validate(Map<String,dynamic>.from(backup['tables'] as Map),version:67);
    await db.closeForTesting();db=await AppDatabase.createForTesting(databaseFactoryFfi);
    await db.importAll(Map<String,dynamic>.from(backup));
    expect((await (await db.database).query('qq_reply_tasks')).every((r)=>r['valid']==0),true);
  });
  test('private failures are addressed and have bounded consumable continuation state',() async {
    final first=await claim(await add('private-root',private:true),private:true);await store.mark(first,'failed');
    clock+=1000;final next=await claim(await add('private-follow',private:true),private:true);
    final prior=(await tasks.pending(next,clock,'p'))!;
    expect(prior.requests,['问题private-root']);expect(await tasks.consume(next,prior,cancel:true),true);
    expect(await tasks.pending(next,clock,'p'),isNull);
    expect(QqReplyTasks.parseRelation('<qq_pending>continue</qq_pending>正常正文').text,'正常正文');
    expect(QqReplyTasks.parseRelation('普通文本').relation,'unclear');
  });
  for(final chunks in [['一','二'],['唯一一段']]) {
    test('confirmed journal distinguishes ${chunks.length} planned parts when archive fails',() async {
      final b=await claim(await add('delivery',mention:true)),api=_Api();
      await tasks.saveDraft(b,{'raw':chunks.join('\n')});
      try {
        await QqReplyDelivery(api,pause:(_)async{}).send(group:true,target:target,messageId:'delivery',text:chunks.join('\n'),messages:chunks,fileInfo:'',
          current:()async=>true,beforeSend:()=>store.mark(b,'sending'),planned:(count)=>tasks.plan(b,count),
          received:(seq,_)=>store.received(b,seq,platformId:'real-$seq',platformIndex:'index-$seq'),
          confirmed:()=>store.mark(b,'sent_archive_pending'),confirmedPart:(seq,text,image,language)=>tasks.confirmed(b,seq,text,image,language),
          sent:(_,_,_)async=>throw StateError('local archive failure'));
        fail('expected local archive failure');
      } on QqDeliveryFailure catch(e) {await tasks.failure(b,'archive');await store.mark(b,e.state);expect(e.confirmed,1);}
      finally {api.close();}
      clock+=1000;final next=await claim(await add('followup'));
      final pending=(await tasks.pending(next,clock,'p'))!;
      expect(api.calls,1);expect(pending.hint['all_parts_confirmed'],chunks.length==1);
      expect(pending.hint['previous_request_unfinished'],chunks.length!=1);
      expect(pending.hint['confirmed_delivered'],[chunks.first]);
      expect((pending.hint['confirmed_parts'] as List).single['platform_id'],'real-1');
      expect(pending.draft,isNull);
    });
  }
  test('unknown and confirmed predecessor facts survive another generation failure',() async {
    final first=await claim(await add('root-unknown',mention:true));
    await tasks.saveDraft(first,{'raw':'不能重发的旧正文'});await tasks.plan(first,2);
    store.received(first,1,platformId:'confirmed-first');await tasks.confirmed(first,1,'已经送达的一段',false,'');
    await store.mark(first,'send_uncertain');clock+=1000;
    final next=await claim(await add('retry'));
    expect(await tasks.consume(next,(await tasks.pending(next,clock,'p'))!,cancel:false),true);
    await tasks.saveDraft(next,{'raw':'新的草稿'});await tasks.failure(next,'group_boundary');await store.mark(next,'failed');clock+=1000;
    final last=await claim(await add('retry-again')),pending=(await tasks.pending(last,clock,'p'))!;
    expect(pending.hint['delivery_unknown'],true);expect(pending.hint['confirmed_delivered'],['已经送达的一段']);
    expect(pending.draft,isNull);expect(pending.requests,contains('问题root-unknown'));
  });

  test('more than a hundred unrelated watched batches cannot hide a successor receipt',() async {
    final original=await add('old-direct'),first=await claim(original);await tasks.addressed(first);await store.mark(first,'failed');
    for(var i=0;i<110;i++) {clock+=1000;await store.mark(await claim(await add('watch-$i')),'watching');}
    clock+=1000;final successor=await claim(await add('answer-followup'));
    expect(await tasks.consume(successor,(await tasks.pending(successor,clock,'p'))!,cancel:false),true);await store.mark(successor,'sent');
    expect(await store.append(fence:await store.capture(),scope:scope,kind:'group',target:target,platformId:'old-direct',sender:'peer',
      text:'问题old-direct',observedAt:clock-111000,receivedAt:clock,mentioned:true,policy:'p'),isNull);
    expect(await store.pending(cid),isEmpty);
  });

}
