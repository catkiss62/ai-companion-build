import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_addressing.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_incoming.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_delivery.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

class _RealHttp extends HttpOverrides {}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;late QqApi api;
  const scope='address-fixture';final cid=QqStore.conversationId(scope,'group','g');
  setUp(() async {db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);api=QqApi(appId:'synthetic',secret:'synthetic');});
  tearDown(() async {api.close();await db.closeForTesting();});
  Future<QqBatch> source() async {
    final at=DateTime.now().millisecondsSinceEpoch,fence=await store.capture(conversationId:cid);
    final seq=(await store.append(fence:fence,scope:scope,kind:'group',target:'g',platformId:'human-source',sender:'peer',
      text:'合成问题',observedAt:at,receivedAt:at))!;
    return (await store.claim(fence,cid,seq,at))!;
  }
  test('only a confirmed same-group self echo establishes the group namespace',() async {
    final b=await source();store.received(b,1,platformId:'actual-outgoing-id');
    await store.sentPart(b,1,'已确认原话','',DateTime.now().millisecondsSinceEpoch);
    final addressing=QqAddressing(store,api),fence=await store.capture(conversationId:cid);
    final own=await addressing.inspect({'id':'actual-outgoing-id','content':'已确认原话','author':{'member_openid':'group-self'},
      '_trusted_event_type':'GROUP_MESSAGE_CREATE'},fence,scope:scope,group:'g');
    expect(own.selfEcho,true);
    Map<String,dynamic> mention(String id)=>{'id':'incoming','content':'<@$id> 你怎么看','mentions':[{'id':id,'username':'同名昵称'}],
      '_trusted_event_type':'GROUP_MESSAGE_CREATE'};
    expect((await addressing.inspect(mention('group-self'),fence,scope:scope,group:'g')).mentioned,true);
    expect((await addressing.inspect(mention('other-id'),fence,scope:scope,group:'g')).mentioned,false);
    expect((await addressing.inspect(mention('group-self'),fence,scope:scope,group:'other-group')).mentioned,false);
    final forwarded=mention('group-self')..['content']='[群聊的聊天记录]\n=== 消息 1 ===\n[发送者] 合成人物\n[消息内容] <@group-self> 合成旧指令';
    expect((await addressing.inspect(forwarded,fence,scope:scope,group:'g',outerText:QqIncoming.parse(forwarded).text)).mentioned,false);
  });
  test('unverified full-message metadata or a matching name never becomes trusted',() async {
    final b=await source(),a=QqAddressing(store,api);
    final e=<String,dynamic>{'id':'unverified','content':'<@ready-id> 小鲸鱼','mentions':[{'id':'ready-id','username':'小鲸鱼'}],
      '_trusted_event_type':'GROUP_MESSAGE_CREATE'};
    expect((await a.inspect(e,b.fence,scope:scope,group:'g')).mentioned,false);
    e['_trusted_event_type']='GROUP_AT_MESSAGE_CREATE';expect((await a.inspect(e,b.fence,scope:scope,group:'g')).mentioned,true);
  });
  test('real HTTP send receipt is archived atomically through unchanged callbacks',() async {
    final b=await source(),server=await HttpServer.bind(InternetAddress.loopbackIPv4,0);
    server.listen((r)async {
      await r.drain<void>();r.response.headers.contentType=ContentType.json;
      r.response.write(jsonEncode(r.uri.path.endsWith('getAppAccessToken')?{'access_token':'synthetic','expires_in':7200}:
        {'id':'actual-platform-id','msg_idx':'actual-index'}));await r.response.close();
    });
    final url='http://127.0.0.1:${server.port}';api.close();
    api=QqApi(appId:'synthetic',secret:'synthetic',client:_RealHttp().createHttpClient(null),apiBase:url,tokenBase:url);
    try {
      await QqReplyDelivery(api).send(group:true,target:'g',messageId:'human-source',text:'确认的正文',fileInfo:'',current:()async=>true,
        beforeSend:()async{},received:(part,r)=>store.received(b,part,platformId:r.id,platformIndex:r.index),
        sent:(part,text,image)=>store.sentPart(b,part,text,'',DateTime.now().millisecondsSinceEpoch));
      final row=(await (await db.database).query('qq_archive',where:"role='assistant'")).single;
      expect(row['platform_id'],'actual-platform-id');expect(row['context_meta'],contains('actual-index'));
      expect(api.confirmedMessage(group:true,target:'g',platformId:'actual-platform-id'),true);
    } finally {await server.close(force:true);}
  });
  test('a connection failure before the first write is definitely unsent',() async {
    final unused=await HttpServer.bind(InternetAddress.loopbackIPv4,0),port=unused.port;await unused.close(force:true);
    api.close();api=QqApi(appId:'synthetic',secret:'synthetic',client:_RealHttp().createHttpClient(null));
    await expectLater(api.request('POST','http://127.0.0.1:$port/messages',body:{'content':'合成'},sending:true),
      throwsA(isA<QqApiException>().having((e)=>e.uncertain,'uncertain',false)));
  });
  test('connection loss after the server receives a POST remains unknown',() async {
    final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0);var received=0;
    server.listen((r)async {await r.drain<void>();received++;final socket=await r.response.detachSocket(writeHeaders:false);socket.destroy();});
    api.close();api=QqApi(appId:'synthetic',secret:'synthetic',client:_RealHttp().createHttpClient(null));
    try {
      await expectLater(api.request('POST','http://127.0.0.1:${server.port}/messages',body:{'content':'合成'},sending:true),
        throwsA(isA<QqApiException>().having((e)=>e.uncertain,'uncertain',true)));
      expect(received,1);
    } finally {await server.close(force:true);}
  });
}
