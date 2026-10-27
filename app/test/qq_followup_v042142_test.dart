import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_group_learning.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_options.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_private_config.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_runtime.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_sketch.dart';

class _Secure extends SecureConfig {
  _Secure():super.forTesting(const FlutterSecureStorage());
  @override Future<String?> readApiKey() async=>'synthetic';
  @override Future<String> readEndpoint() async=>'https://fixture.invalid/chat';
}
class _Store extends QqStore {
  _Store(super.db);
  bool failPending=false;
  @override Future<List<Map<String,Object?>>> pending(String cid) async {
    if(failPending) {failPending=false;throw StateError('synthetic pending read failure');}
    return super.pending(cid);
  }
}
class _Api extends QqApi {
  _Api():super(appId:'fixture',secret:'synthetic');
  final sent=<String>[];
  final signals=<String,Completer<void>>{};
  @override Future<String> uploadImage({required bool group,required String target,required Uint8List bytes,required String filename,required Future<bool> Function() current}) async {
    if(!await current())throw StateError('invalid');return 'synthetic-image';
  }
  @override Future<void> sendMessage({required bool group,required String target,required String messageId,required int sequence,String text='',String fileInfo=''}) async {
    sent.add('$target:$text');final signal=signals[target];if(signal!=null && !signal.isCompleted)signal.complete();
  }
}
http.Response _json(Object result)=>http.Response.bytes(utf8.encode(jsonEncode({'choices':[{'message':{'content':jsonEncode(result)},'finish_reason':'stop'}]})),200,headers:{'content-type':'application/json'});
http.Response _sse(String text)=>http.Response.bytes(utf8.encode('data: ${jsonEncode({'choices':[{'delta':{'content':text},'finish_reason':'stop'}]})}\n\ndata: [DONE]\n\n'),200,headers:{'content-type':'text/event-stream'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late _Store store;late _Api api;late QqRuntime runtime;
  late DateTime clock;late Future<http.Response> Function(Map) respond;
  final statuses=<String>[];Completer<void>? memoryFailure;
  var optionsCalls=0,failOptionsAt=0;
  const config=QqPrivateConfig(appId:'fixture',secret:'synthetic',owner:'owner',namespace:'followup-142',replyChannel:'first');
  final scope=QqRuntime.scope(config);final cid=QqStore.conversationId(scope,'group','a');
  final secure=_Secure();
  DeepSeekClient factory(Future<bool> Function() abort)=>DeepSeekClient(abortWhen:abort,
    jsonClientFactory:()=>MockClient((r)=>respond(jsonDecode(r.body) as Map)),
    streamClientFactory:()=>MockClient((r)=>respond(jsonDecode(r.body) as Map)));
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});db=await AppDatabase.createForTesting(databaseFactoryFfi);store=_Store(db);api=_Api();clock=DateTime(2026,10,27,12);statuses.clear();memoryFailure=null;optionsCalls=0;failOptionsAt=0;
    await db.setSetting('sticker_expression_mode_v1','off');await db.setSetting('qq_sketch_auto_v1','0');
    respond=(_) async=>_json({'memory':'','share':''});
    runtime=QqRuntime(store:store,api:api,secure:secure,config:config,allowed:()async=>true,
      status:(s){statuses.add(s);if(s=='memory_failed' && memoryFailure?.isCompleted==false)memoryFailure!.complete();},
      now:()=>clock,configReader:()async=>config,optionsReader:()async {optionsCalls++;if(optionsCalls==failOptionsAt)throw StateError('synthetic maintenance options failure');return const QqOptions(groups:{'a','b'},ownerShare:false);},clientFactory:factory,
      privatePrompt:(_,__,___,____)async=>'你是小鲸鱼，正常回复本人。',privateCurrent:(_)async=>true);
  });
  tearDown(() async {await runtime.stop();api.close();await db.closeForTesting();});
  Future<int> add(String id,{String text='新发言'}) async=>(await store.append(fence:await store.capture(conversationId:cid),scope:scope,kind:'group',target:'a',platformId:id,sender:'peer',text:text,observedAt:clock.millisecondsSinceEpoch,receivedAt:clock.millisecondsSinceEpoch))!;
  Map<String,dynamic> event(String id,{bool group=false,String target='owner',String text='你好'})=>{
    'id':id,'content':text,'timestamp':clock.toUtc().toIso8601String(),
    'author':{if(group)'member_openid':'peer',if(!group)'user_openid':'owner'},
    if(group)'group_openid':target,if(group)'_trusted_event_type':'GROUP_AT_MESSAGE_CREATE'};

  for(final repair in [false,true]) {
    for(final value in [{}, {'memory':null,'share':''}, {'memory':42,'share':''}, {'memory':[],'share':''}, {'memory':'fact','share':null}]) {
      test('real summarize rejects malformed business result $value repair=$repair',() async {
        final seq=await add('source');final sql=await db.database;
        if(repair)await sql.insert('qq_notes',{'id':'repair','conversation_id':cid,'content':'','sources':jsonEncode([seq]),'source_stamp':'[]','through_seq':seq,'created_at':clock.millisecondsSinceEpoch,'valid':0});
        respond=(_)async=>_json(value);
        await expectLater(runtime.summarize(cid,idle:true),throwsFormatException);
        final c=(await sql.query('qq_conversations')).single;
        final work=(await sql.query('qq_work_items')).single;
        expect(c['summary_seq'],0);expect(work['state'],'pending');expect(work['attempts'],1);
        expect(work['next_at'],clock.millisecondsSinceEpoch+120000);
        expect((await sql.query('qq_notes')).length,repair?1:0);
        if(repair)expect((await sql.query('qq_notes')).single['valid'],0);
      });
    }
  }
  test('real summarize valid empty completes once; malformed batches stop at three attempts',() async {
    await add('source');var calls=0;respond=(_)async{calls++;return _json({});};
    for(final advance in [0,120000,600000]) {
      clock=clock.add(Duration(milliseconds:advance));await expectLater(runtime.summarize(cid,idle:true),throwsFormatException);
    }
    expect((await (await db.database).query('qq_work_items')).single['state'],'failed');
    clock=clock.add(const Duration(days:1));await runtime.summarize(cid,idle:true);expect(calls,3);
    await add('valid-empty');respond=(_)async=>_json({'memory':'','share':''});await runtime.summarize(cid,idle:true);
    final work=await (await db.database).query('qq_work_items');expect(work.where((r)=>r['state']=='complete').length,1);
  });
  for(final fault in ['pending','maintenance']) {
  test('$fault failure cannot strand later same-conversation reply',() async {
    await db.setSetting('auto_memory','0');await store.discover(await store.capture(),scope,'private','owner');
    final privateCid=QqStore.conversationId(scope,'private','owner');
    store.failPending=fault=='pending';failOptionsAt=fault=='maintenance'?4:0;
    memoryFailure=Completer<void>();runtime.wakeWork(privateCid);
    await memoryFailure!.future.timeout(const Duration(seconds:5));
    respond=(b)async=>b['stream']==true?_sse('收到'):_json({'safe':true});
    for(var i=0;i<2;i++) {
      api.signals['owner']=Completer<void>();await runtime.accept(event('fresh-$i'));
      await api.signals['owner']!.future.timeout(const Duration(seconds:5));
    }
    expect(api.sent,['owner:收到','owner:收到']);
  });
  }
  for(final operation in ['edit','disable','delete']) {
    for(final retry in [false,true]) {
      test('old profile $operation leaves unrelated new ${retry?'backoff':'running'} learning intact',() async {
        final oldSeq=await add('old');final learning=QqGroupLearning(store);await learning.setEnabled(cid,true);
        final sql=await db.database;final oldRaw=(await sql.query('qq_archive')).single;final stamp=<Map<String,Object?>>[];
        await QqArchiveReader(sql).render(oldRaw,stamp:stamp);
        await sql.insert('qq_styles',{'id':'old-profile','conversation_id':cid,'content':'旧观察','sources':jsonEncode([oldSeq]),'source_stamp':jsonEncode(stamp),'created_at':clock.millisecondsSinceEpoch});
        final old=(await learning.profiles(cid)).single;final oldProjection=(await learning.projection(cid)).stamp;
        for(var i=0;i<12;i++)await add('new-$i');
        final entered=Completer<void>(),release=Completer<void>();var calls=0;
        respond=(_)async {calls++;if(retry && calls==1)return _json({'habits':42});entered.complete();await release.future;return _json({'habits':['新批次的观察']});};
        Future<void> learn()=>learning.learn(cid,now:clock.millisecondsSinceEpoch,secure:secure,clientFactory:factory,allowed:()async=>true);
        if(retry) {await expectLater(learn(),throwsFormatException);clock=clock.add(const Duration(minutes:2));}
        Future<void> edit()=>learning.edit(old,content:operation=='edit'?'手改旧观察':null,enabled:operation=='disable'?false:null,delete:operation=='delete');
        if(retry)await edit();
        final task=learn();await entered.future.timeout(const Duration(seconds:5));
        if(!retry)await edit();
        expect((await learning.projection(cid)).stamp,isNot(oldProjection));release.complete();await task;
        expect((await learning.profiles(cid)).where((r)=>r['content']=='新批次的观察').length,1);
        expect((await sql.query('qq_work_items')).single['state'],'complete');
        expect((await learning.profiles(cid)).where((r)=>r['content']=='旧观察').length,operation=='disable'?1:0);
      });
    }
  }
  test('drawing yields to other QQ replies, keeps same-group order, and sends once',() async {
    await db.setSetting('auto_memory','0');
    final entered=Completer<void>(),release=Completer<void>();var drawings=0;
    const svg='<svg viewBox="0 0 512 512"><circle cx="200" cy="200" r="50" fill="#aaffff"/></svg>';
    final channel=const MethodChannel('ai_companion/qq_private_runtime');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(_)async=>Uint8List.fromList([137,80,78,71]));
    respond=(b) async {
      if(b['stream']==true)return _sse(jsonEncode(b['messages']).contains('【可选小涂鸦】')?'给你<qq_sketch mode="with_text">蓝色圆圈</qq_sketch>':'收到');
      if(b['max_tokens']==QqSketchService.outputTokens) {drawings++;entered.complete();await release.future;return _json({'svg':svg,'description':'蓝色圆圈'});}
      return _json(b['max_tokens']==60?{'safe':true}:{'participation':'direct'});
    };
    try {
      api.signals['a']=Completer<void>();await runtime.accept(event('draw',group:true,target:'a',text:'画个圆'),group:true);
      await entered.future.timeout(const Duration(seconds:8));
      for(final target in ['owner','b']) {
        api.signals[target]=Completer<void>();await runtime.accept(event('other-$target',group:target=='b',target:target),group:target=='b');
        await api.signals[target]!.future.timeout(const Duration(seconds:5),onTimeout:()=>throw TestFailure('reply $target stalled; status=$statuses; sent=${api.sent}'));
      }
      await runtime.accept(event('same-group-next',group:true,target:'a'),group:true);
      expect(api.sent.where((s)=>s.startsWith('a:')),isEmpty);expect(drawings,1);
      release.complete();await api.signals['a']!.future.timeout(const Duration(seconds:5),onTimeout:()=>throw TestFailure('drawing delivery stalled; status=$statuses; sent=${api.sent}'));
      expect(api.sent.where((s)=>s.startsWith('a:')).single,'a:给你');
      api.signals['a']=Completer<void>();await api.signals['a']!.future.timeout(const Duration(seconds:6));
      expect(api.sent.where((s)=>s.startsWith('a:')).toList(),['a:给你','a:收到']);expect(drawings,1);
    } finally {
      if(!release.isCompleted)release.complete();await runtime.stop();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null);
    }
  });
}
