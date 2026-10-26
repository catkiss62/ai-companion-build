import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/ai/qwen_vision_client.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_vision.dart';
import 'package:ai_companion_localfirst/core/database/automatic_memory_permit.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_group_binding.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_options.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_private_config.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_runtime.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_share_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

class _RealHttp extends HttpOverrides {}
/// Test transport only: preserve signed-URL validation and production request
/// construction while routing a fake COS hostname to an actual loopback peer.
class _CosLoopback implements HttpClient {
  _CosLoopback(this.base):real=_RealHttp().createHttpClient(null);
  final Uri base;final HttpClient real;
  @override Future<HttpClientRequest> openUrl(String method,Uri uri)=>real.openUrl(method,
    uri.host=='fixture.cos.myqcloud.com'?base.resolve(uri.path):uri);
  @override Future<HttpClientRequest> putUrl(Uri uri)=>openUrl('PUT',uri);
  @override void close({bool force=false})=>real.close(force:force);
  @override dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;late QqPrivateConfig config;late QqOptions options;late DateTime now;
  setUp(()async{
    FlutterSecureStorage.setMockInitialValues({});db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);now=DateTime.now();
    await db.ensureStateLineageId();await db.setSetting('post_turn_queue_enabled','0');
    config=const QqPrivateConfig(appId:'12345',secret:'fixture-only',namespace:'binding-test',owner:'owner',replyChannel:'first');
    await config.save();await QqPrivateConfig.bind(config.namespace,config.owner);
    options=QqOptions(namespace:config.namespace,groups:const {'group'},ownerShare:true);
    await options.save(db:db);await db.setSetting('qq_master_enabled_v2','1');
  });
  tearDown(()async=>db.closeForTesting());
  Future<String> note({String text='群友约周六看珊瑚',String share='群里刚刚提起周六去看珊瑚'}) async {
    final fence=await store.capture();final scope=QqRuntime.scope(config);final cid=QqStore.conversationId(scope,'group','group');
    await store.append(fence:fence,scope:scope,kind:'group',target:'group',platformId:'source',sender:'peer',text:text,
      observedAt:now.subtract(const Duration(minutes:2)).millisecondsSinceEpoch,receivedAt:now.millisecondsSinceEpoch);
    final sql=await db.database;final rows=await sql.query('qq_archive',where:'conversation_id=?',whereArgs:[cid]);
    final stamps=<Map<String,Object?>>[];final reader=QqArchiveReader(sql);
    for(final row in rows){await reader.render(row,stamp:stamps);}
    final permit=await AutomaticMemoryPermit.capture(sql,'auto_memory');
    expect(await store.saveNote(fence,cid,rows,stamps,permit,text,share,now.millisecondsSinceEpoch),true);
    return QqStore.hash(['note',cid,rows.last['seq']]);
  }
  test('group identity request is only a candidate until trusted owner confirmation',()async{
    final code=(await QqGroupBinding.request(config,'group','my-member'))!;
    expect((await QqOptions.read()).ownerMembers,isEmpty);
    expect(await QqGroupBinding.confirm(config,code,db:db),true);
    expect((await QqOptions.read()).ownerMembers['group'],'my-member');
    expect(await QqGroupBinding.confirm(config,code,db:db),false);
  });
  test('stale binding confirmation cannot write a replacement owner namespace',()async{
    final code=(await QqGroupBinding.request(config,'group','peer'))!;
    final replacement=const QqPrivateConfig(appId:'12345',secret:'fixture-new',namespace:'replacement',owner:'new-owner');
    await replacement.save();await QqPrivateConfig.bind(replacement.namespace,replacement.owner);
    expect(await QqGroupBinding.confirm(config,code,db:db),false);expect((await QqOptions.read()).ownerMembers,isEmpty);
  });
  test('public requests are bounded and do not enable a group',()async{
    final code=await QqGroupBinding.request(config,'not-enabled','peer');expect(code,isNotNull);
    expect(await QqGroupBinding.request(config,'not-enabled','another-peer'),isNull);
    expect((await QqOptions.read()).groups,{'group'});
  });
  test('share ownership selects one entrance and cannot be claimed twice',()async{
    final id=await note();final shares=QqShareStore(db);
    expect((await shares.candidates(now)).single['id'],id);
    final offer=await shares.claim(id,'app',now);expect(offer,isNotNull);expect(await offer!.matches(await db.database),true);
    expect(await shares.claim(id,'app',now),isNull);expect(await shares.candidates(now,destination:'qq'),isEmpty);
  });
  test('a recent owner QQ conversation chooses QQ rather than App',()async{
    await note();await store.append(fence:await store.capture(),scope:QqRuntime.scope(config),kind:'private',target:'owner',
      platformId:'owner-active',sender:'owner',owner:true,text:'最近在QQ聊天',observedAt:now.millisecondsSinceEpoch,receivedAt:now.millisecondsSinceEpoch);
    final shares=QqShareStore(db);expect(await shares.candidates(now),isEmpty);
    expect((await shares.candidates(now,destination:'qq')).length,1);
  });
  test('known uncertain outbound sharing never becomes another entrance candidate',()async{
    final id=await note();final shares=QqShareStore(db);final offer=(await shares.claim(id,'app',now))!;
    await (await db.database).update('qq_shares',{'state':'send_uncertain'},where:'id=?',whereArgs:[id]);
    expect(await offer.matches(await db.database),false);expect(await shares.candidates(now),isEmpty);
    expect(await shares.candidates(now,destination:'qq'),isEmpty);
  });
  test('turning owner sharing off invalidates an already-generated offer',()async{
    final id=await note();final offer=(await QqShareStore(db).claim(id,'app',now))!;
    await options.copy(ownerShare:false).save(db:db);
    expect(await offer.matches(await db.database),false);expect(await QqShareStore(db).candidates(now),isEmpty);
  });
  test('App share and receipt commit atomically and preserve source identity',()async{
    final id=await note();final offer=(await QqShareStore(db).claim(id,'app',now))!;final sql=await db.database;
    final before=await sql.query('desire_state');
    final message=ChatMessage(id:'shared-app',role:'assistant',content:'群里刚刚提到周六看珊瑚',createdAt:now,isProactive:true);
    expect(await db.commitProactiveMessageIfCurrent(message:message,evaluationStartedAt:now,qqEvidence:offer.evidence,qqShare:offer),isNull);
    expect((await sql.query('qq_shares')).single['destination'],'app:shared-app');
    expect((await sql.query('qq_receipts')).single['message_id'],'shared-app');
    expect(await sql.query('desire_state'),before);
    expect(await db.commitProactiveMessageIfCurrent(message:message,evaluationStartedAt:now,qqEvidence:offer.evidence,qqShare:offer),'qq_share_changed');
  });
  test('source withdrawal before App share leaves no sent record or phantom message',()async{
    final id=await note();final offer=(await QqShareStore(db).claim(id,'app',now))!;
    await store.forget(await store.capture(),QqStore.conversationId(QqRuntime.scope(config),'group','group'));
    expect(await db.commitProactiveMessageIfCurrent(message:ChatMessage(id:'withdrawn',role:'assistant',content:'旧材料',createdAt:now,isProactive:true),
      evaluationStartedAt:now,qqEvidence:offer.evidence,qqShare:offer),'qq_source_changed');
    expect(await db.messageById('withdrawn'),isNull);
  });
  test('QQ media upload exercises prepare, exact multipart bytes, finish and files token',()async{
    final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0);final base=Uri.parse('http://127.0.0.1:${server.port}');
    final bytes=Uint8List.fromList(List.generate(19,(i)=>i));final parts=<List<int>>[];final paths=<String>[];
    server.listen((request)async{
      paths.add(request.uri.path);request.response.headers.contentType=ContentType.json;
      final body=await request.fold<List<int>>([],(out,part)=>out..addAll(part));
      Object result;
      if(request.uri.path.endsWith('/app/getAppAccessToken')){result={'access_token':'fixture-token','expires_in':7200};}
      else if(request.uri.path.endsWith('/upload_prepare')){
        final payload=jsonDecode(utf8.decode(body));expect(payload['file_size'],19);expect(payload['md5'],md5.convert(bytes).toString());
        result={'upload_id':'upload-fixture','block_size':10,'parts':[{'index':1,'presigned_url':'https://fixture.cos.myqcloud.com/part/1'},
          {'index':2,'presigned_url':'https://fixture.cos.myqcloud.com/part/2'}]};
      }else if(request.uri.path.startsWith('/part/')){expect(request.headers.value('authorization'),isNull);parts.add(body);result={};}
      else if(request.uri.path.endsWith('/upload_part_finish')){
        final p=jsonDecode(utf8.decode(body));final part=parts[(p['part_index'] as int)-1];expect(p['md5'],md5.convert(part).toString());expect(p['block_size'],part.length);result={};
      }else if(request.uri.path.endsWith('/files')){expect(jsonDecode(utf8.decode(body)),{'upload_id':'upload-fixture'});result={'file_info':'opaque-media-token'};}
      else {request.response.statusCode=404;result={'error':'unexpected_path'};}
      request.response.write(jsonEncode(result));await request.response.close();
    });
    final api=QqApi(appId:'12345',secret:'fixture-only',client:_CosLoopback(base),apiBase:base.toString(),tokenBase:base.toString());
    try{
      expect(await api.uploadImage(group:true,target:'group',bytes:bytes,filename:'image.gif',current:()async=>true),'opaque-media-token');
      expect(parts.expand((p)=>p).toList(),bytes);expect(paths.where((p)=>p.endsWith('/messages')),isEmpty);
    }finally{api.close();await server.close(force:true);}
  });
  test('first-channel vision fallback sends actual image input with thinking disabled',()async{
    final requests=<http.Request>[];
    final client=QwenVisionClient(client:QqNonThinkingVisionTransport(MockClient((r)async{
      requests.add(r);return http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode({'summary':'一张测试图'})},'finish_reason':'stop'}]}),200,
        headers:{'content-type':'application/json; charset=utf-8'});
    })));
    try{
      await client.observeBytes(apiKey:'fixture',endpoint:'https://first.test/chat',model:'dynamic-first-model',imageBytes:Uint8List.fromList([1,2,3]));
      final body=jsonDecode(requests.single.body) as Map;
      expect(body['thinking'],{'type':'disabled'});expect(body['model'],'dynamic-first-model');
      expect(((body['messages'] as List).last['content'] as List).first['type'],'image_url');
    }finally{client.close();}
  });
  test('media message uses QQ type 7 and image token, without leaking file bytes',()async{
    final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0);final root='http://127.0.0.1:${server.port}';Map? message;
    server.listen((request)async{
      final body=await utf8.decoder.bind(request).join();request.response.headers.contentType=ContentType.json;
      if(request.uri.path.endsWith('/getAppAccessToken')){request.response.write(jsonEncode({'access_token':'test','expires_in':7200}));}
      else {message=jsonDecode(body) as Map;request.response.write(jsonEncode({'id':'real-receipt'}));}
      await request.response.close();
    });
    final api=QqApi(appId:'12345',secret:'fixture',client:_RealHttp().createHttpClient(null),apiBase:root,tokenBase:root);
    try{await api.sendMessage(group:false,target:'owner',messageId:'reply-id',sequence:2,fileInfo:'token');
      expect(message,{'msg_type':7,'media':{'file_info':'token'},'msg_id':'reply-id','msg_seq':2});
    }finally{api.close();await server.close(force:true);}
  });
}
