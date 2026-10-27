import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_delivery.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_voice.dart';
import 'package:ai_companion_localfirst/core/tts/tts_text_processor.dart';

class _RealHttp extends HttpOverrides {}
class _Api extends QqApi {
  _Api():super(appId:'fixture',secret:'fixture-only');
  int calls=0;QqApiException? nextFailure;
  @override Future<void> sendMessage({required bool group,required String target,required String messageId,required int sequence,
    String text='',String fileInfo='',Future<bool> Function()? current})async {
    if(current!=null && !await current())throw QqApiException('stopped');
    calls++;if(calls>1 && nextFailure!=null)throw nextFailure!;
  }
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  for(final retry in [false,true]) {
    test('permission revoked during ${retry?'401 refresh':'cold token'} prevents a later message POST',()async {
      final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0),entered=Completer<void>(),release=Completer<void>();
      var enabled=true,tokens=0,messages=0;
      server.listen((r)async {
        await r.drain<void>();r.response.headers.contentType=ContentType.json;
        if(r.uri.path.endsWith('getAppAccessToken')) {
          tokens++;if(!retry || tokens==2){entered.complete();await release.future;}
          r.response.write(jsonEncode({'access_token':'fixture-token-$tokens','expires_in':7200}));
        } else {
          messages++;r.response.statusCode=retry?401:200;r.response.write(jsonEncode({'id':'fixture-receipt'}));
        }
        await r.response.close();
      });
      final base='http://127.0.0.1:${server.port}',api=QqApi(appId:'fixture',secret:'fixture-only',client:_RealHttp().createHttpClient(null),apiBase:base,tokenBase:base);
      try {
        final sent=api.sendMessage(group:true,target:'g',messageId:'m',sequence:1,text:'old reply',current:()async=>enabled);
        final expectation=expectLater(sent,throwsA(isA<QqApiException>().having((e)=>e.code,'code','stopped')));
        await entered.future.timeout(const Duration(seconds:3));enabled=false;release.complete();await expectation;
        expect(messages,retry?1:0);
      }finally {if(!release.isCompleted)release.complete();api.close();await server.close(force:true);}
    });
  }
  test('a response confirmed after revocation still reports delivery, never an unsent retry',()async {
    final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0);var enabled=true,messages=0;
    server.listen((r)async {
      await r.drain<void>();r.response.headers.contentType=ContentType.json;
      if(r.uri.path.endsWith('getAppAccessToken')){r.response.write(jsonEncode({'access_token':'fixture','expires_in':7200}));}
      else {messages++;enabled=false;r.response.write(jsonEncode({'id':'receipt'}));}
      await r.response.close();
    });
    final base='http://127.0.0.1:${server.port}',api=QqApi(appId:'fixture',secret:'fixture-only',client:_RealHttp().createHttpClient(null),apiBase:base,tokenBase:base);
    try {await api.sendMessage(group:true,target:'g',messageId:'m',sequence:1,text:'reply',current:()async=>enabled);expect(messages,1);}
    finally{api.close();await server.close(force:true);}
  });
  test('confirmed voice retries only its local transaction once',()async {
    final api=_Api();var archives=0,acks=0;
    try {await QqReplyDelivery(api).send(group:true,target:'g',messageId:'m',text:'Hello',messages:[],fileInfo:'voice',voiceText:'Hello',voiceLanguage:'en',
      current:()async=>true,beforeSend:()async{},confirmed:()async{acks++;},sent:(_,_,_)async{},
      sentVoice:(_,_,_)async {if(++archives==1)throw StateError('transient local failure');});
      expect(api.calls,1);expect(archives,2);expect(acks,1);
    }finally{api.close();}
  });
  for(final invalidated in [false,true]) {
    test('confirmed send and ${invalidated?'withdrawn source':'failed archive'} never become an unsent failure',()async {
      final api=_Api();var active=true,archives=0;
      try {await expectLater(QqReplyDelivery(api).send(group:true,target:'g',messageId:'m',text:'reply',fileInfo:'image',
        current:()async=>active,beforeSend:()async{},sent:(_,_,_)async {archives++;if(invalidated)active=false;throw StateError('archive failed');}),
        throwsA(isA<QqDeliveryFailure>().having((e)=>e.state,'state','sent_archive_failed').having((e)=>e.confirmed,'confirmed',1)));
        expect(api.calls,1);expect(archives,invalidated?1:2);
      }finally{api.close();}
    });
  }
  for(final uncertain in [false,true]) {
    test('partial delivery ${uncertain?'unknown':'explicit failure'} keeps confirmed messages consumed',()async {
      final api=_Api()..nextFailure=QqApiException(uncertain?'network':'http_400',uncertain:uncertain);
      final receipts=<String>[];
      try {await expectLater(QqReplyDelivery(api,pause:(_)async{}).send(group:true,target:'g',messageId:'m',text:'a\nb',messages:['a','b'],fileInfo:'',
        current:()async=>true,beforeSend:()async{},sent:(_,text,_)async {receipts.add(text);}),
        throwsA(isA<QqDeliveryFailure>().having((e)=>e.state,'state',uncertain?'send_uncertain':'partially_sent')));
        expect(api.calls,2);expect(receipts,['a']);
      }finally{api.close();}
    });
  }
  test('expired optional media keeps text and does not send the image',()async {
    final api=_Api();final receipts=<String>[];
    try {await QqReplyDelivery(api).send(group:true,target:'g',messageId:'m',text:'normal reply',fileInfo:'expired-image',
      current:()async=>true,mediaCurrent:()async=>false,beforeSend:()async{},sent:(_,text,image)async {expect(image,false);receipts.add(text);});
      expect(api.calls,1);expect(receipts,['normal reply']);
    }finally{api.close();}
  });
  test('semantic transcript preserves original terms while synthesis keeps App pronunciation aliases',(){
    const text='我用 DeepSeek，注意 token。';
    final voice=QqVoiceChoice.parse('<qq_voice>${jsonEncode({'language':'zh','text':'（挥手）「$text」'})}</qq_voice>')!;
    expect(voice.text,text);expect(QqVoiceChoice.transcript('「$text」','zh'),voice.text);
    expect(const TtsTextProcessor().process(voice.text),'我用 地铺C咳，注意 拖肯。');
  });
  test('restart preserves acknowledged receipt states and protective reply counts',()async {
    final db=await AppDatabase.createForTesting(databaseFactoryFfi),now=DateTime.now().millisecondsSinceEpoch;
    final store=QqStore(db),cid=QqStore.conversationId('fixture','group','g');
    try {
      for(final state in ['sent_archive_pending','sent_archive_failed','partially_sent']) {
        final seq=(await store.append(fence:await store.capture(),scope:'fixture',kind:'group',target:'g',platformId:state,sender:'peer',text:'hello',observedAt:now,receivedAt:now))!;
        final batch=(await store.claim(await store.capture(),cid,seq,now))!;await store.mark(batch,state,sticker:'echo:fixture:1');
      }
      await store.recover(await store.capture());expect(await store.groupRepliesSince(now-1),3);
      expect((await (await db.database).query('qq_deliveries')).map((r)=>r['state']),['sent_archive_failed','sent_archive_failed','partially_sent']);
      expect(await store.pending(cid),isEmpty);
    }finally{await db.closeForTesting();}
  });
}
