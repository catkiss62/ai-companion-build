import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/model_profile.dart';
import 'package:ai_companion_localfirst/core/ai/qwen_vision_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_expression_service.dart';
import 'package:ai_companion_localfirst/core/stickers/sticker_pack.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_failure.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_incoming.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_stickers.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_vision.dart';

class _Secure extends SecureConfig {
  _Secure():super.forTesting(const FlutterSecureStorage());
  @override Future<String?> readApiKey()async=>'synthetic-first';
  @override Future<String> readEndpoint()async=>'https://first.invalid/chat';
  @override Future<String?> readVisionApiKey()async=>'synthetic-vision';
  @override Future<String> readVisionEndpoint()async=>'https://vision.invalid/chat';
  @override Future<String> readVisionModel()async=>'configured-vision';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;late Directory temp;
  const scope='synthetic-144';final cid=QqStore.conversationId(scope,'group','one');
  const paths=MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);
    temp=await Directory.systemTemp.createTemp('qq-144-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(paths,(call)async=>temp.path);
  });
  tearDown(() async {
    await db.closeForTesting();TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(paths,null);
    if(await temp.exists())await temp.delete(recursive:true);
  });
  Future<int> add(String id,String text,{int at=1000,QqIncoming? incoming}) async=>(await store.append(
    fence:await store.capture(conversationId:cid),scope:scope,kind:'group',target:'one',platformId:id,sender:'peer',
    text:incoming?.text??text,contextMeta:incoming?.material.encode()??'',images:incoming?.urls.length??0,
    observedAt:at,receivedAt:at))!;

  test('live reply context includes delivered answers beyond input cutoff, never later human input',() async {
    final first=await add('first','合成问题');final b=(await store.claim(await store.capture(conversationId:cid),cid,first,1001))!;
    final next=await add('next','生成期间的补充',at:1002);
    await store.sentPart(b,1,'已经回答的海星说明','',1003);await store.mark(b,'sent');
    await add('future','尚未处理的未来发言',at:1004);
    final reader=QqArchiveReader(await db.database),stamp=<Map<String,Object?>>[];
    final context=await reader.groupContext(cid,through:next,stamp:stamp,includeDeliveredAfterThrough:true);
    expect(context,contains('已经回答的海星说明'));expect(context,isNot(contains('尚未处理的未来发言')));
    expect(await reader.groupContext(cid,through:next),isNot(contains('已经回答的海星说明')));
    final small=await reader.participationContext(cid,through:next,stamp:[]);
    expect(small,contains('already_sent_after_pending_input'));expect(small,isNot(contains('尚未处理的未来发言')));
    expect(await reader.matches(stamp),true);
    await (await db.database).delete('qq_archive',where:"role='assistant'");expect(await reader.matches(stamp),false);
  });

  test('twenty compact exchanges retain multipart replies without counting each bubble as a turn',() async {
    var through=0;
    for(var i=0;i<24;i++) {
      through=await add('turn-$i','human-$i',at:1000+i*30000);
      final b=(await store.claim(await store.capture(conversationId:cid),cid,through,1001+i*30000))!;
      for(var p=1;p<=3;p++)await store.sentPart(b,p,'reply-$i-part-$p','',1001+i*30000+p);
      await store.mark(b,'sent');
    }
    final stamp=<Map<String,Object?>>[],reader=QqArchiveReader(await db.database);
    final small=await reader.participationContext(cid,through:through,stamp:stamp);
    final blocks=small.split('\n').map((s)=>jsonDecode(s) as Map).toList();
    expect(blocks.first['shown_groups'],40);expect(small.length,lessThan(7800));
    expect(blocks.skip(1).where((b)=>(b['seqs'] as List).length==3).length,20);
    expect(small,contains('human-4'));expect(small,isNot(contains('human-3"')));expect(small,contains('reply-23-part-3'));
    expect(await reader.matches(stamp),true);
  });

  test('flattened forwarded transcript remains unverified material with no persisted media URL',() async {
    final incoming=QqIncoming.parse({'content':'[群聊的聊天记录]\n=== 消息 1 ===\n[发送者] 合成人物\n[消息内容] 测试台词\n[附件] URL:https://fixture.invalid/media?token=synthetic'});
    expect(incoming.text,'');expect(incoming.material.kind,'embedded');expect(incoming.urls,isEmpty);
    expect(incoming.material.encode(),isNot(contains('https://')));
    await add('flat','',incoming:incoming);final row=(await (await db.database).query('qq_archive')).single;
    final reader=QqArchiveReader(await db.database);
    expect(await reader.render(row),contains('not_current_group_utterance'));
    expect(await reader.render(row,ownTextOnly:true),isNot(contains('测试台词')));
  });

  test('small enabled packs remain candidates beside a huge pack even when their only image was recently sent',() {
    StickerPackMeta pack(String id)=>StickerPackMeta(id:id,name:id,description:'synthetic',license:'test',rootPath:'/unused',count:1);
    StickerReplyCandidate item(String id,int i)=>StickerReplyCandidate('',pack(id),StickerRecord(packId:id,path:'memes/$i.png',
      tag:'daily',caption:'合成图片',keywords:'合成',toneScope:'normal',intensity:1,enabled:true));
    final tiny=item('q-whale-001',0),pool=[for(var i=0;i<200;i++)item('large',i),tiny,item('other',0)];
    final selected=QqStickers.groupSelection('seed','合成',pool,{tiny.record.usageKey});
    expect(selected.length,8);expect(selected.map((c)=>c.pack.id).toSet(),{'large','q-whale-001','other'});
    expect(selected.map((c)=>c.record.usageKey).toSet().length,8);
    expect(QqStickers.choicePrompt(selected),contains('Q版鲸鱼娘'));
    expect(QqStickers.groupSelection('seed','Q版鲸鱼娘',pool,{}).first.pack.id,'q-whale-001');
  });

  final still=base64Decode('iVBORw0KGgoAAAANSUhEUgAAACAAAAAYCAIAAAAUMWhjAAAAJElEQVR4nGP8z0BbwERj80ctGLVg1IJRC0YtGLVg1IJRC6gEAPHIAS8Wxt4fAAAAAElFTkSuQmCC');
  http.Response observed()=>http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode({'summary':'合成图片可见'})},'finish_reason':'stop'}]}),200,headers:{'content-type':'application/json'});
  for(final firstChannel in [true,false]) {
    test('${firstChannel?'group first channel':'private App vision'} uses the selected key model and endpoint once',() async {
      final requests=<http.Request>[];var primary=0,first=0;
      final vision=QqVision(_Secure(),downloader:MockClient((r)async=>http.Response.bytes(still,200)),
        visionFactory:()=>QwenVisionClient(client:MockClient((r)async {primary++;requests.add(r);return observed();})),
        fallbackFactory:()=>QwenVisionClient(client:QqNonThinkingVisionTransport(MockClient((r)async {first++;requests.add(r);return observed();}))));
      try {
        await vision.observe('https://fixture.invalid/picture.png',firstModel:DeepSeekModelProfile.fromApiName('future-first-model'),
          firstChannel:firstChannel,fallback:true,current:()async=>true);
        expect(primary,firstChannel?0:1);expect(first,firstChannel?1:0);
        final request=requests.single,body=jsonDecode(request.body) as Map;
        expect(request.url.host,firstChannel?'first.invalid':'vision.invalid');
        expect(request.headers['Authorization'],'Bearer ${firstChannel?'synthetic-first':'synthetic-vision'}');
        expect(body['model'],firstChannel?'future-first-model':'configured-vision');
        expect(jsonEncode(body['messages']),contains('data:image/'));
        if(firstChannel)expect(body['thinking'],{'type':'disabled'});
      } finally {vision.close();}
    });
  }
  test('group first-channel failure does not invoke App Qwen even when private fallback is enabled',() async {
    var qwen=0,first=0;
    final vision=QqVision(_Secure(),downloader:MockClient((r)async=>http.Response.bytes(still,200)),
      visionFactory:()=>QwenVisionClient(client:MockClient((r)async {qwen++;return observed();})),
      fallbackFactory:()=>QwenVisionClient(client:MockClient((r)async {first++;return http.Response('synthetic failure',503);})));
    try {
      await expectLater(vision.observe('https://fixture.invalid/picture.png',firstModel:DeepSeekModelProfile.flash,
        firstChannel:true,fallback:true,current:()async=>true),throwsA(isA<QqOperationFailure>().having((e)=>e.code,'reason','vision_primary_http_503')));
      expect(first,1);expect(qwen,0);
    } finally {vision.close();}
  });
  test('download/decode/provider failures have separate safe reasons and clean temporary files',() async {
    for(final scenario in ['size','decode','provider']) {
      var calls=0;
      final vision=QqVision(_Secure(),downloader:MockClient((r) async=>scenario=='size'
        ?http.Response.bytes([],200,headers:{'content-length':'${QqVision.maxDownloadBytes+1}'})
        :http.Response.bytes(scenario=='decode'?utf8.encode('GIF89aINVALID'):still,200)),
        visionFactory:()=>QwenVisionClient(client:MockClient((r) async {calls++;return http.Response('synthetic unavailable',503);})),
        fallbackFactory:()=>QwenVisionClient(client:MockClient((r) async {calls++;return http.Response('synthetic denied',403);})));
      try {
        await expectLater(vision.observe('https://fixture.invalid/image?token=synthetic',firstModel:DeepSeekModelProfile.fromApiName('dynamic-first'),
          fallback:scenario=='provider',current:()async=>true),throwsA(isA<QqOperationFailure>().having((e)=>e.code,'reason',
            scenario=='size'?'vision_download_size':scenario=='decode'?startsWith('vision_decode_'):'vision_fallback_http_403')));
        expect(calls,scenario=='provider'?2:0);
        expect(await Directory('${temp.path}/qq_vision_v2').list().toList(),isEmpty);
      } finally {vision.close();}
    }
  });
  test('a valid GIF larger than old 5MB limit reaches exactly one vision request',() async {
    // Six synthetic frames plus valid GIF comment extensions, not user media.
    final gif=base64Decode('R0lGODlhIAAYAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQICgAAACwAAAAAIAAYAAAILwABCBxIsKDBgwgTKlzIsKHDhxAjSpxIsaLFixgzatzIsaPHjyBDihxJsqTJjQEBACH5BAgKAAAALAAAAAAgABgAgQD/AAAAAAAAAAAAAAgvAAEIHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNq3Mixo8ePIEOKHEmypMmNAQEAIfkECAoAAAAsAAAAACAAGACBAAD/AAAAAAAAAAAACC8AAQgcSLCgwYMIEypcyLChw4cQI0qcSLGixYsYM2rcyLGjx48gQ4ocSbKkyY0BAQAh+QQICgAAACwAAAAAIAAYAIH//wAAAAAAAAAAAAAILwABCBxIsKDBgwgTKlzIsKHDhxAjSpxIsaLFixgzatzIsaPHjyBDihxJsqTJjQEBACH5BAgKAAAALAAAAAAgABgAgf8A/wAAAAAAAAAAAAgvAAEIHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNq3Mixo8ePIEOKHEmypMmNAQEAIfkECAoAAAAsAAAAACAAGACBAP//AAAAAAAAAAAACC8AAQgcSLCgwYMIEypcyLChw4cQI0qcSLGixYsYM2rcyLGjx48gQ4ocSbKkyY0BAQA7');
    final buffer=BytesBuilder(copy:false)..add(gif.sublist(0,gif.length-1));
    final comment=<int>[0x21,0xfe,255,...List.filled(255,0),0];
    while(buffer.length<6*1024*1024) {buffer.add(comment);}
    buffer.add([0x3b]);final large=buffer.takeBytes();var calls=0;
    final vision=QqVision(_Secure(),downloader:MockClient((r)async=>http.Response.bytes(large,200)),
      visionFactory:()=>QwenVisionClient(client:MockClient((r)async {calls++;return observed();})));
    try {
      final result=await vision.observe('https://fixture.invalid/large.gif',firstModel:DeepSeekModelProfile.fromApiName('dynamic-first'),fallback:false,current:()async=>true);
      expect(result.text,contains('合成图片可见'));expect(result.text,contains('动图'));expect(calls,1);
    } finally {vision.close();}
  });
  test('legacy missing reasons remain unknown instead of blaming the sender network',() {
    expect(QqFailure.visionMessage(''),contains('具体原因未记录'));
    expect(QqFailure.visionMessage('private error https://fixture.invalid/secret'),isNot(contains('https://')));
    expect(QqFailure.visionMessage('vision_download_size'),contains('下载上限'));
  });
}
