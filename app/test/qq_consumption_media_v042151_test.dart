import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/qq_archive_schema.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_admin.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_echo.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_delivery.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_tasks.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

class _Api extends QqApi {
  _Api():super(appId:'fixture',secret:'synthetic');int sends=0;
  @override Future<void> sendMessage({required bool group,required String target,required String messageId,
    required int sequence,String text='',String fileInfo='',Future<bool> Function()? current})async {sends++;}
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;late QqReplyTasks tasks;late QqEchoService echoes;late int clock;int serial=0;
  const scope='fixture151';final cid=QqStore.conversationId(scope,'group','g');
  setUp(()async {db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);tasks=QqReplyTasks(store);echoes=QqEchoService(store);clock=DateTime.now().millisecondsSinceEpoch;serial=0;});
  tearDown(()async {echoes.clear();await db.closeForTesting();});
  Future<int> add(String id,{bool mention=false,int? at})async=>(await store.append(fence:await store.capture(),scope:scope,kind:'group',target:'g',
    platformId:id,sender:'peer',text:'问题$id',observedAt:at??clock,receivedAt:at??clock,mentioned:mention,policy:'p'))!;
  Future<QqBatch> claim(int seq)async=>(await store.claim(await store.capture(conversationId:cid),cid,seq,clock,policy:'p'))!;
  Future<void> mark(QqBatch b,String stage)async {await store.mark(b,stage);await (await db.database).update('qq_reply_tasks',{'updated_at':clock},where:'id=?',whereArgs:[b.id]);}
  Future<({int seq,QqBatch last,int at})> chain(String terminal)async {
    final a=await claim(await add('a'));await tasks.addressed(a);await mark(a,'failed');
    clock+=const Duration(minutes:8).inMilliseconds;final at=clock,seq=await add('b'),b=await claim(seq);
    expect(await tasks.consume(b,(await tasks.pending(b,clock,'p'))!,cancel:false),true);await mark(b,'failed');
    clock+=60000;final c=await claim(await add('c'));
    expect(await tasks.consume(c,(await tasks.pending(c,clock,'p'))!,cancel:false),true);await mark(c,terminal);
    return (seq:seq,last:c,at:at);
  }
  for(final stage in ['sent','sent_archive_pending','sent_archive_failed','partially_sent','send_uncertain']) {
    test('expired $stage continuation retains source consumption without extending its request',()async {
      final history=await chain(stage);clock+=120000;
      final sql=await db.database;await QqReplyTasks.prune(sql,clock);
      expect((await sql.query('qq_reply_tasks',where:'id=?',whereArgs:[history.last.id])),hasLength(1));
      final row=(await sql.query('qq_reply_tasks',where:'id=?',whereArgs:[history.last.id])).single;
      expect((row['expires_at'] as int)<clock,true);
      expect(await store.append(fence:await store.capture(),scope:scope,kind:'group',target:'g',platformId:'b',sender:'peer',
        text:'问题b',observedAt:history.at,receivedAt:clock,mentioned:true,policy:'p'),isNull);
      final next=await claim(await add('new'));expect(await tasks.pending(next,clock,'p'),isNull);
      await QqReplyTasks.prune(sql,clock+QqReplyTasks.deliveredRetention.inMilliseconds);
      expect(await sql.query('qq_reply_tasks',where:'id=?',whereArgs:[history.last.id]),isEmpty);
    });
  }
  test('deleting unrelated history preserves successor proof and withdraws old drafts',()async {
    final oldAt=clock-const Duration(days:60).inMilliseconds;
    await mark(await claim(await add('old',at:oldAt)),'watching');final history=await chain('sent_archive_failed');
    final sql=await db.database;final version=(await sql.query('qq_conversations',where:'id=?',whereArgs:[cid])).single['version'] as int;
    final result=await QqArchiveAdmin(db).deleteRange(cid,DateTime.fromMillisecondsSinceEpoch(oldAt-1),DateTime.fromMillisecondsSinceEpoch(oldAt+1),expectedVersion:version);
    expect(result.messages,1);final row=(await sql.query('qq_reply_tasks',where:'id=?',whereArgs:[history.last.id])).single;
    expect(row['valid'],0);expect(row['draft'],'');
    expect(await store.append(fence:await store.capture(),scope:scope,kind:'group',target:'g',platformId:'b',sender:'peer',
      text:'问题b',observedAt:history.at,receivedAt:clock,mentioned:true,policy:'p'),isNull);
  });
  test('deleting the through source rebases retained proof and survives production import',()async {
    final history=await chain('sent'),sql=await db.database;
    final version=(await sql.query('qq_conversations',where:'id=?',whereArgs:[cid])).single['version'] as int;
    await QqArchiveAdmin(db).deleteRange(cid,DateTime.fromMillisecondsSinceEpoch(clock-1),DateTime.fromMillisecondsSinceEpoch(clock+1),expectedVersion:version);
    final row=(await sql.query('qq_reply_tasks',where:'id=?',whereArgs:[history.last.id])).single;
    expect(row['through_seq'],history.seq);expect(jsonDecode(row['sources'] as String),contains(history.seq));
    final backup=await db.exportAll();QqArchiveSchema.validate(Map<String,dynamic>.from(backup['tables'] as Map),version:67);
    await db.closeForTesting();db=await AppDatabase.createForTesting(databaseFactoryFfi);await db.importAll(Map<String,dynamic>.from(backup));
    expect((await (await db.database).query('qq_reply_tasks')).where((r)=>r['id']==history.last.id),hasLength(1));
  });
  test('an empty archive range is a no-op for pending tasks and the conversation epoch',()async {
    final b=await claim(await add('pending',mention:true));await tasks.saveDraft(b,{'raw':'未完成'});await mark(b,'failed');
    final sql=await db.database,version=(await (await db.database).query('qq_conversations',where:'id=?',whereArgs:[cid])).single['version'] as int;
    final r=await QqArchiveAdmin(db).deleteRange(cid,DateTime.fromMillisecondsSinceEpoch(clock-3000),DateTime.fromMillisecondsSinceEpoch(clock-2000),expectedVersion:version);
    expect(r.messages,0);expect((await sql.query('qq_reply_tasks')).single['draft'],contains('未完成'));
    expect((await sql.query('qq_conversations')).single['version'],version);
  });
  Future<QqBatch> seen(String sender)async {
    final seq=(await store.append(fence:await store.capture(),scope:scope,kind:'group',target:'g',platformId:'image${++serial}',
      sender:sender,text:'',images:1,observedAt:clock,receivedAt:clock,policy:'p'))!;
    final b=await claim(seq),image=(await store.images(seq)).single;
    echoes.remember(b,b.rows.single,image,Uint8List.fromList([1,2,3]),'image/gif','same',clock);
    await store.observation(b.fence,image['id'] as String,'viewed','同一张图','fp');return b;
  }
  for(final stage in ['sent_archive_pending','sent_archive_failed','partially_sent']) {
    test('$stage without complete per-part evidence conservatively suppresses the same image wave',()async {
      final a=await seen('one');echoes.release(a);final b=await seen('two'),candidate=(await echoes.candidate(b,clock))!;
      await store.mark(b,stage,sticker:candidate.usageKey);echoes.release(b);
      expect(await echoes.candidate(await seen('three'),clock),isNull);
    });
  }
  test('a platform-confirmed image with local archive failure cannot become a new echo candidate',()async {
    final a=await seen('one');echoes.release(a);final b=await seen('two'),candidate=(await echoes.candidate(b,clock))!,api=_Api();
    await tasks.saveDraft(b,{'raw':'<qq_echo mode="only">e1</qq_echo>'});
    try {
      await QqReplyDelivery(api,pause:(_)async{}).send(group:true,target:'g',messageId:'image2',text:'',fileInfo:'uploaded',
        current:()async=>true,beforeSend:()=>store.mark(b,'sending',sticker:candidate.usageKey),planned:(n)=>tasks.plan(b,n),
        confirmed:()=>store.mark(b,'sent_archive_pending'),confirmedPart:(seq,text,image,language)=>tasks.confirmed(b,seq,text,image,language),
        sent:(_,_,_)async=>throw StateError('archive failure'));
      fail('expected archive failure');
    }on QqDeliveryFailure catch(e){await store.mark(b,e.state,confirmedParts:e.confirmed);}
    finally{api.close();}
    echoes.release(b);expect(api.sends,1);expect(await echoes.candidate(await seen('three'),clock),isNull);
  });
  test('complete confirmation facts permit a definitely unsent image after text-only archive failure',()async {
    final a=await seen('one');echoes.release(a);final b=await seen('two'),candidate=(await echoes.candidate(b,clock))!;
    await tasks.plan(b,2);await tasks.confirmed(b,1,'仅文字已送达',false,'');
    await store.mark(b,'sent_archive_failed',sticker:candidate.usageKey,confirmedParts:1);echoes.release(b);
    expect(await echoes.candidate(await seen('three'),clock),isNotNull);
    await store.mark(b,'sent_archive_failed',confirmedParts:2);
    expect(await echoes.candidate(await seen('four'),clock),isNull,reason:'An unjournaled confirmed part may be the image');
  });
}
