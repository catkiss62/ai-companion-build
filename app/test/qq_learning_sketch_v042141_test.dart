import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/qq_archive_schema.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_admin.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_group_learning.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_options.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_delivery.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_sketch.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_work_queue.dart';

class _Secure extends SecureConfig {
  _Secure():super.forTesting(const FlutterSecureStorage());
  @override Future<String?> readApiKey()async=>'synthetic-key';
  @override Future<String> readEndpoint()async=>'https://fixture.invalid/chat';
}
class _Api extends QqApi {
  _Api():super(appId:'fixture',secret:'synthetic');
  final sent=<String>[];
  @override Future<void> sendMessage({required bool group,required String target,required String messageId,required int sequence,String text='',String fileInfo=''}) async {sent.add(text);}
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;late QqArchiveAdmin admin;
  const scope='fixture-141';final cid=QqStore.conversationId(scope,'group','a');
  final at=DateTime(2026,10,27,12).millisecondsSinceEpoch;
  const svg='<svg viewBox="0 0 512 512"><circle cx="256" cy="256" r="60" fill="#aaffff"/></svg>';
  setUp(() async {FlutterSecureStorage.setMockInitialValues({});db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);admin=QqArchiveAdmin(db);});
  tearDown(() async=>db.closeForTesting());
  Future<int?> add(String id,{String text='新消息',String target='a',int? when}) async=>store.append(fence:await store.capture(conversationId:QqStore.conversationId(scope,'group',target)),scope:scope,kind:'group',target:target,platformId:id,sender:'peer',text:text,observedAt:when??at,receivedAt:when??at,policy:'p');
  Future<void> remove(int seq) async {final sql=await db.database;final c=(await sql.query('qq_conversations',where:'id=?',whereArgs:[cid])).single;await admin.deleteRange(cid,DateTime(2026,10,27),DateTime(2026,10,28),expectedVersion:c['version'] as int,throughSeq:seq);}

  test('ingress survives a note epoch change; output fence still expires',() async {
    await add('one');final old=await store.capture(conversationId:cid);
    await db.setSetting('qq_archive_epoch_v1:$cid','1');
    expect(await store.current(old),false);
    final batch=await store.claim(await store.capture(conversationId:cid),cid,1,at,policy:'p');
    expect(batch!.rows.single['content'],'新消息');
    await add('two');await db.setSetting('conversation_context_reset_count','99');
    expect(await store.claim(await store.capture(conversationId:cid),cid,2,at,policy:'p'),isNull);
  });
  test('deleting or forgetting recent raw cannot resurrect a replay',() async {
    final seq=(await add('platform-one'))!;await remove(seq);
    expect(await add('platform-one',when:at+1000),isNull);
    await add('new');await store.forget(await store.capture(),cid);
    expect(await add('new',when:at+1000),isNull);
    expect(await (await db.database).query('qq_archive'),isEmpty);
  });
  test('failed summary retries exact work after backoff and stops at three attempts',() async {
    await add('source');var claim=(await store.claimSummary(await store.capture(conversationId:cid),cid,idle:true,at:at))!;
    final id=claim.workId;
    await QqWorkQueue.fail(db,id,claim.runToken,at);
    expect(await store.claimSummary(await store.capture(conversationId:cid),cid,idle:true,at:at+1000),isNull);
    claim=(await store.claimSummary(await store.capture(conversationId:cid),cid,idle:true,at:at+120000))!;
    expect(claim.workId,id);await QqWorkQueue.fail(db,id,claim.runToken,at+120000);
    claim=(await store.claimSummary(await store.capture(conversationId:cid),cid,idle:true,at:at+720000))!;
    await QqWorkQueue.fail(db,id,claim.runToken,at+720000);
    expect(await store.claimSummary(await store.capture(conversationId:cid),cid,idle:true,at:at+2000000),isNull);
    expect((await (await db.database).query('qq_work_items')).single['state'],'failed');
    expect(await QqWorkQueue.retrySummary(db,cid),1);
    expect((await store.claimSummary(await store.capture(conversationId:cid),cid,idle:true,at:at+2000000))!.workId,id);
  });
  test('empty successful summary completes once; complete original text reaches extractor',() async {
    await add('long',text:'HEAD${'长'*15000}TAIL_SENTINEL');
    final claim=(await store.claimSummary(await store.capture(conversationId:cid),cid,idle:true,at:at))!;
    expect(claim.input,contains('TAIL_SENTINEL'));expect(claim.input,isNot(contains('partial_text')));
    expect(await store.saveNote(await store.capture(conversationId:cid),cid,claim.rows,claim.stamp,claim.permit,'','',at,workId:claim.workId,runToken:claim.runToken),true);
    expect((await (await db.database).query('qq_work_items')).single['state'],'complete');
    expect(await store.claimSummary(await store.capture(conversationId:cid),cid,idle:true,at:at+2000000),isNull);
  });
  test('deleting sources cancels running result and keeps valid portable graph',() async {
    final seq=(await add('one'))!;final claim=(await store.claimSummary(await store.capture(conversationId:cid),cid,idle:true,at:at))!;
    await remove(seq);
    expect(await QqWorkQueue.current(await db.database,claim.workId,claim.runToken),false);
    final raw=jsonDecode(jsonEncode(await db.exportAll())) as Map;
    QqArchiveSchema.validate((raw['tables'] as Map).cast<String,dynamic>(),version:AppDatabase.schemaVersion);
  });
  test('field patches preserve concurrent revoke and mapping; stale snapshots fail',() async {
    await QqOptions(namespace:'fixture',groups:const {'a'}).save(db:db);
    final stale=await QqOptions.read(namespace:'fixture');
    await Future.wait([
      QqOptions.update((fresh)=>fresh.copy(groups:{}),db:db,namespace:'fixture'),
      QqOptions.update((fresh)=>fresh.copy(owners:{...fresh.ownerMembers,'a':'trusted-member'}),db:db,namespace:'fixture'),
    ]);
    final current=await QqOptions.read(namespace:'fixture');expect(current.groups,isEmpty);expect(current.ownerMembers['a'],'trusted-member');
    expect(await db.getSetting('qq_options_policy_v2:fixture'),QqStore.hash(current.toJson()));
    await expectLater(stale.copy(ownerShare:false).save(db:db),throwsStateError);
  });
  test('all semantic parts validated before first platform send',() async {
    final api=_Api();
    await expectLater(QqReplyDelivery(api,pause:(_)async{}).send(group:true,target:'a',messageId:'source',text:'',messages:['a'*1801,'b'*1801,'c'*1700],fileInfo:'',current:()async=>true,beforeSend:()async{},sent:(_,__,___)async{}),throwsFormatException);
    expect(api.sent,isEmpty);
    await QqReplyDelivery(api,pause:(_)async{}).send(group:true,target:'a',messageId:'source',text:'',messages:['完整一条','补一句','最后一句'],fileInfo:'',current:()async=>true,beforeSend:()async{},sent:(_,__,___)async{});
    expect(api.sent,['完整一条','补一句','最后一句']);
  });
  test('group style has revision controls, survives backup, and withdraws with sources',() async {
    final seq=(await add('human'))!;final sql=await db.database;final learning=QqGroupLearning(store);
    expect(await learning.enabled(cid),false);await learning.setEnabled(cid,true);
    final row=(await sql.query('qq_archive')).single;final stamp=<Map<String,Object?>>[];await QqArchiveReader(sql).render(row,stamp:stamp);
    await sql.insert('qq_styles',{'id':'style-fixture','conversation_id':cid,'content':'接梗时偶尔简短复读','sources':jsonEncode([seq]),'source_stamp':jsonEncode(stamp),'created_at':at});
    expect((await learning.projection(cid)).text,contains('简短复读'));
    final profile=(await learning.profiles(cid)).single;await learning.edit(profile,content:'先简短反应，再偶尔补一句');
    await expectLater(learning.edit(profile,content:'过时编辑'),throwsA(anything));
    var edited=(await learning.profiles(cid)).single;await learning.edit(edited,enabled:false);
    expect((await learning.projection(cid)).text,isNot(contains('先简短')));
    edited=(await learning.profiles(cid)).single;await learning.edit(edited,enabled:true);
    final saved=jsonDecode(jsonEncode(await db.exportAll())) as Map<String,dynamic>;await db.importAll(saved);
    expect((await learning.profiles(cid)).single['content'],'先简短反应，再偶尔补一句');expect(await learning.enabled(cid),false);
    await remove(seq);expect(await learning.profiles(cid),isEmpty);
  });
  test('only actually delivered sketch source is archived and can preview without model',() async {
    await add('draw',text:'画个小鲸鱼');final b=(await store.claim(await store.capture(conversationId:cid),cid,1,at,policy:'p'))!;
    expect(await (await db.database).query('qq_sketches'),isEmpty);
    await store.sentPart(b,1,'给你','一条蓝色小鲸鱼',at,sketchSvg:svg);
    final sketches=await (await db.database).query('qq_sketches');expect(sketches.single['svg'],svg);
    final binding=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    binding.setMockMethodCallHandler(const MethodChannel('ai_companion/qq_private_control'),(call) async {expect(call.method,'renderSketch');expect((call.arguments as Map)['svg'],svg);return Uint8List.fromList([137,80,78,71]);});
    expect(await QqSketchService.preview(svg),isNotEmpty);
    binding.setMockMethodCallHandler(const MethodChannel('ai_companion/qq_private_control'),null);
    final raw=jsonDecode(jsonEncode(await db.exportAll())) as Map<String,dynamic>;await db.importAll(raw);
    expect((await (await db.database).query('qq_sketches')).single['svg'],svg);
    await store.forget(await store.capture(),cid);expect(await (await db.database).query('qq_sketches'),isEmpty);
  });
  test('real learner only consumes new human group messages once and honors midflight disable',() async {
    await add('before',text:'旧发言不应自动学');final learning=QqGroupLearning(store);await learning.setEnabled(cid,true);
    for(var i=0;i<12;i++)await add('human$i',text:'接梗节奏$i');
    await store.append(fence:await store.capture(),scope:scope,kind:'group',target:'a',platformId:'assistant',sender:'assistant',text:'不准从这条自我学习',role:'assistant',observedAt:at,receivedAt:at);
    var calls=0;final replies=<Map<String,Object?>>[];
    DeepSeekClient factory(Future<bool> Function() abort)=>DeepSeekClient(abortWhen:abort,jsonClientFactory:()=>MockClient((r)async {
      calls++;final body=jsonDecode(r.body) as Map;final input=jsonEncode(body['messages']);expect(input,isNot(contains('不准从这条自我学习')));expect(input,isNot(contains('旧发言不应自动学')));
      replies.add(body.cast<String,Object?>());return http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode({'habits':['接梗时偶尔重复一两个词']})},'finish_reason':'stop'}]}),200,headers:{'content-type':'application/json'});
    }));
    await learning.learn(cid,now:at,secure:_Secure(),clientFactory:factory,allowed:()async=>true);
    expect(calls,1);expect((await learning.profiles(cid)).single['content'],contains('重复'));
    await learning.learn(cid,now:at+1000,secure:_Secure(),clientFactory:factory,allowed:()async=>true);expect(calls,1);
    for(var i=0;i<12;i++)await add('later$i',text:'稍后的真人发言$i');
    final entered=Completer<void>(),finish=Completer<void>();
    final task=learning.learn(cid,now:at+const Duration(hours:7).inMilliseconds,secure:_Secure(),allowed:()async=>true,clientFactory:(abort)=>DeepSeekClient(abortWhen:abort,jsonClientFactory:()=>MockClient((r)async {
      entered.complete();await finish.future;return http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode({'habits':['关闭后不应入库']})},'finish_reason':'stop'}]}),200,headers:{'content-type':'application/json'});
    })));
    await entered.future;await learning.setEnabled(cid,false);finish.complete();try {await task;}catch(_) {}
    expect((await learning.profiles(cid)).length,1);
  });
  test('sketch generator follows current first model and effort; cancelled draw never reaches renderer',() async {
    await add('ask',text:'画个鲸鱼');final b=(await store.claim(await store.capture(conversationId:cid),cid,1,at,policy:'p'))!;
    await db.setSetting('deepseek_model','future-first-model');await db.setSetting('deepseek_reasoning_effort','max');
    var calls=0,rendered=0;var active=true;
    final channel=const MethodChannel('ai_companion/qq_private_runtime');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(call)async {rendered++;expect(call.method,'renderSketch');return Uint8List.fromList([137,80,78,71]);});
    DeepSeekClient client({bool cancel=false})=>DeepSeekClient(abortWhen:()async=>!active,jsonClientFactory:()=>MockClient((r)async {
      calls++;final body=jsonDecode(r.body) as Map;expect(body['model'],'future-first-model');expect(body['reasoning_effort'],'max');expect(body['thinking'],{'type':'enabled'});
      if(cancel)active=false;
      return http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode({'svg':svg,'description':'蓝色圆圈小鲸鱼'})},'finish_reason':'stop'}]}),200,headers:{'content-type':'application/json'});
    }));
    final first=client();final service=QqSketchService(store,channel:channel);
    final result=await service.generate(b,const QqSketchChoice('小鲸鱼',true),now:at,secure:_Secure(),client:first,current:()async=>active);first.close();
    expect(result.svg,svg);expect(calls,1);expect(rendered,1);expect(await (await db.database).query('qq_sketches'),isEmpty);
    final second=client(cancel:true);
    await expectLater(service.generate(b,const QqSketchChoice('小鲸鱼',true),now:at+1000,secure:_Secure(),client:second,current:()async=>active),throwsA(anything));second.close();expect(rendered,1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null);
  });
  test('drawing metadata stays invisible; unsafe SVG and unwanted drawing rejected',() {
    const raw='随手画了个<qq_sketch mode="only">蓝色鲸鱼</qq_sketch>';
    expect(QqSketchChoice.parse(raw)!.only,true);expect(QqSketchChoice.visible(raw),'随手画了个');
    expect(QqSketchService.explicit('帮我画个鲸鱼'),true);expect(QqSketchService.explicit('不要画个鲸鱼'),false);
    expect(QqSketchService.acceptable(svg),true);expect(QqSketchService.acceptable('<svg><script>x</script></svg>'),false);
    expect(QqSketchService.acceptable('<svg><image href="file:///x"/></svg>'),false);
  });
}
