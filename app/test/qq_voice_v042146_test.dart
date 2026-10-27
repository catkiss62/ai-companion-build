import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/qq_archive_schema.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_admin.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_history_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_options.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_reply_delivery.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_voice.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_failure.dart';

Uint8List wav({int rate=24000,int samples=100}) {
  final data=ByteData(44+samples*2),b=data.buffer.asUint8List();
  b.setRange(0,4,ascii.encode('RIFF'));data.setUint32(4,b.length-8,Endian.little);
  b.setRange(8,16,ascii.encode('WAVEfmt '));data.setUint32(16,16,Endian.little);
  data.setUint16(20,1,Endian.little);data.setUint16(22,1,Endian.little);
  data.setUint32(24,rate,Endian.little);data.setUint32(28,rate*2,Endian.little);
  data.setUint16(32,2,Endian.little);data.setUint16(34,16,Endian.little);
  b.setRange(36,40,ascii.encode('data'));data.setUint32(40,samples*2,Endian.little);
  for(var i=44;i<b.length;i++)b[i]=i%256;
  return b;
}
class _Api extends QqApi {
  _Api():super(appId:'fixture',secret:'fixture-only');
  final sent=<Map<String,Object?>>[];QqApiException? rejection;
  @override Future<void> sendMessage({required bool group,required String target,required String messageId,
    required int sequence,String text='',String fileInfo=''})async {
    sent.add({'seq':sequence,'text':text,'media':fileInfo});
    if(fileInfo.isNotEmpty && rejection!=null){final e=rejection!;rejection=null;throw e;}
  }
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  const channel=MethodChannel('ai_companion/tts');
  final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(()=>messenger.setMockMethodCallHandler(channel,null));

  test('voice protocol has one bounded target-language transcript; actions are not archived speech',(){
    final c=QqVoiceChoice.parse('前言<qq_voice>{"language":"ja","text":"（挥手）「こんにちは。」","voice":"gentle"}</qq_voice>')!;
    expect(c.language,'ja');expect(c.text,'こんにちは。');expect(c.voice,'gentle');
    expect(QqVoiceChoice.visible('前言<qq_voice>{"language":"ja","text":"こんにちは"}</qq_voice>'),'前言');
    expect(QqVoiceChoice.visible('前言<qq_voice>{broken'),'前言');
    for(final raw in ['<qq_voice>{"language":"fr","text":"bonjour"}</qq_voice>',
      '<qq_voice>{"language":"en","text":""}</qq_voice>',
      '<qq_voice>{"language":"en","text":"${List.filled(601,'a').join()}"}</qq_voice>',
      '<qq_voice>{"language":"zh","text":"你好"}</qq_voice><qq_voice>{"language":"zh","text":"再见"}</qq_voice>']) {
      expect(QqVoiceChoice.parse(raw),isNull);
    }
  });
  for(final sample in [('zh','你好。'),('ja','おやすみなさい。'),('en','Good night.')]) {
    test('${sample.$1} export is silent and never changes App preferences or claims playback',()async {
      final calls=<MethodCall>[];
      messenger.setMockMethodCallHandler(channel,(call)async {
        calls.add(call);
        return switch(call.method){'claimVoiceExport'=>7,'generateVoiceExport'=>wav(),_=>null};
      });
      final service=QqVoiceService();
      try {
        final audio=await service.generate(QqVoiceChoice(sample.$1,sample.$2),current:()async=>true);
        expect(audio.length,244);expect(calls.map((c)=>c.method),['claimVoiceExport','generateVoiceExport','endVoiceExport']);
        expect((calls[1].arguments as Map)['language'],sample.$1);
        expect((calls.last.arguments as Map)['cancel'],false);
      } finally {service.close();}
    });
  }
  test('App busy rejects export without stopping App or making an audio request',()async {
    final methods=<String>[];
    messenger.setMockMethodCallHandler(channel,(call)async {methods.add(call.method);return null;});
    final service=QqVoiceService(claimWait:Duration.zero);
    try {await expectLater(service.generate(const QqVoiceChoice('en','Hello'),current:()async=>true),throwsA(isA<QqOperationFailure>()));
      expect(methods,['claimVoiceExport']);} finally {service.close();}
  });
  test('native preemption cancels only the old export identity',()async {
    final calls=<MethodCall>[];
    messenger.setMockMethodCallHandler(channel,(call)async {
      calls.add(call);if(call.method=='claimVoiceExport')return 11;
      if(call.method=='generateVoiceExport')throw PlatformException(code:'tts_voice_export_failed',message:'voice_export_preempted');
      return null;
    });
    final service=QqVoiceService();
    try {await expectLater(service.generate(const QqVoiceChoice('en','Hello'),current:()async=>true),throwsA(isA<QqOperationFailure>().having((e)=>e.code,'code','voice_preempted')));
      expect(calls.last.method,'endVoiceExport');expect(calls.last.arguments,{'export_id':11,'cancel':true});
      expect(calls.any((c)=>c.method=='stop'),false);} finally {service.close();}
  });
  test('timed-out late claim is released without leaking native ownership',()async {
    final pending=Completer<Object?>(),released=Completer<void>();final calls=<MethodCall>[];
    messenger.setMockMethodCallHandler(channel,(call)async {
      calls.add(call);if(call.method=='claimVoiceExport')return pending.future;
      if(call.method=='endVoiceExport' && !released.isCompleted)released.complete();return null;
    });
    final service=QqVoiceService(timeout:const Duration(milliseconds:20));
    await expectLater(service.generate(const QqVoiceChoice('en','Hello'),current:()async=>true),throwsA(isA<QqOperationFailure>()));
    pending.complete(17);await released.future.timeout(const Duration(seconds:1));
    expect(calls.last.arguments,{'export_id':17,'cancel':true});service.close();
  });
  test('WAV join preserves PCM and rejects truncated, mismatched and excessively long audio',(){
    final a=wav(samples:10),b=wav(samples:20),joined=QqVoiceWav.join([a,b]);
    expect(joined.sublist(44),[...a.sublist(44),...b.sublist(44)]);
    expect(ByteData.sublistView(joined).getUint32(4,Endian.little),joined.length-8);
    for(final audio in [[Uint8List(1)],[a,Uint8List.sublistView(b,0,b.length-1)],[a,wav(rate:16000)],
      [wav(rate:8000,samples:8000*76)]]) {
      expect(()=>QqVoiceWav.join(audio),throwsA(isA<QqOperationFailure>()));
    }
  });
  test('two complete text messages plus voice have three receipts; audio is never an image',()async {
    final api=_Api(),text=<String>[],voice=<String>[],waits=<Duration>[];
    try {
      await QqReplyDelivery(api,pause:(d)async{waits.add(d);}).send(group:true,target:'g',messageId:'m',text:'One\nTwo\nHello',
        messages:['One','Two'],fileInfo:'voice-token',voiceText:'Hello',voiceLanguage:'en',current:()async=>true,beforeSend:()async{},
        sent:(_,s,image)async{expect(image,false);text.add(s);},sentVoice:(_,s,lang)async{expect(lang,'en');voice.add(s);});
      expect(api.sent.length,3);expect(api.sent.last['text'],'');expect(text,['One','Two']);expect(voice,['Hello']);expect(waits.length,2);
    }finally{api.close();}
  });
  test('explicit voice rejection falls back once to text; uncertain delivery never does',()async {
    for(final uncertain in [false,true]) {
      final api=_Api()..rejection=QqApiException(uncertain?'network':'http_415',uncertain:uncertain);
      final receipts=<String>[];
      final send=QqReplyDelivery(api,pause:(_)async{}).send(group:false,target:'owner',messageId:'m',text:'こんにちは',messages:[],fileInfo:'voice-token',
        voiceText:'こんにちは',voiceLanguage:'ja',current:()async=>true,beforeSend:()async{},sent:(_,s,__)async{receipts.add(s);},
        sentVoice:(_,s,__)async{receipts.add('voice:$s');});
      try {if(uncertain){await expectLater(send,throwsA(isA<QqApiException>()));expect(api.sent.length,1);expect(receipts,isEmpty);}
        else{await send;expect(api.sent.length,2);expect(api.sent.last['text'],'こんにちは');expect(receipts,['こんにちは']);}}
      finally{api.close();}
    }
  });
  test('legacy QQ policy serialization stays identical until a new option is explicitly set',(){
    const old=QqOptions(core:'custom persona');
    expect(old.toJson().containsKey('voice'),false);expect(old.toJson().containsKey('echo'),false);
    expect(old.copy(publicMemory:'public').toJson().containsKey('voice'),false);
    final changed=old.copy(voiceEnabled:false,echoEnabled:false);
    expect(changed.toJson()['voice'],false);expect(changed.toJson()['echo'],false);expect(changed.core,'custom persona');
  });

  group('voice archive',(){
    late AppDatabase db;late QqStore store;const scope='voice-test';
    final cid=QqStore.conversationId(scope,'private','owner');
    setUp(()async{db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);});
    tearDown(()async=>db.closeForTesting());
    Future<QqBatch> spoken()async {
      final now=DateTime.now().millisecondsSinceEpoch;
      final seq=(await store.append(fence:await store.capture(),scope:scope,kind:'private',target:'owner',platformId:'request',sender:'owner',text:'说日语',observedAt:now,receivedAt:now))!;
      final batch=(await store.claim(await store.capture(conversationId:cid),cid,seq,now))!;
      await store.sentPart(batch,1,'おやすみなさい。','',now,voiceLanguage:'ja');await store.mark(batch,'sent');return batch;
    }
    test('text transcript and language are recalled through group/private projection and host search',()async {
      final batch=await spoken();final sql=await db.database,reader=QqArchiveReader(await db.database);
      final content=await reader.groupContext(cid,through:batch.through,includeDeliveredAfterThrough:true);
      expect(content,contains('おやすみなさい。'));expect(content,contains('outgoing_voice'));expect(content,contains('ja'));
      expect(await reader.privateContext('日语语音',scope:scope),contains('おやすみなさい。'));
      final lookup=await QqHistoryReader(sql).search('QQ私聊',scope:scope,keyword:'日语');
      expect(lookup.text,contains('おやすみなさい。'));expect(await sql.query('qq_images'),isEmpty);
      final participation=await reader.participationContext(cid,through:99999);
      expect(participation,contains('outgoing_voice_languages'));expect(participation,contains('おやすみなさい。'));
    });
    test('portable restore retains only transcript metadata; deleting a month removes it',()async {
      await spoken();final backup=jsonDecode(jsonEncode(await db.exportAll())) as Map<String,dynamic>;
      final tables=(backup['tables'] as Map).cast<String,dynamic>();
      QqArchiveSchema.validate(tables,version:AppDatabase.schemaVersion);
      expect((tables['qq_voices'] as List).single['language'],'ja');expect(jsonEncode(tables['qq_voices']),isNot(contains('wav')));
      await db.importAll(backup);final sql=await db.database;
      expect((await sql.query('qq_voices')).single['language'],'ja');
      final c=(await sql.query('qq_conversations',where:'id=?',whereArgs:[cid])).single;
      final today=DateTime.now();await QqArchiveAdmin(db).deleteRange(cid,DateTime(today.year,today.month),DateTime(today.year,today.month+1),expectedVersion:c['version'] as int);
      expect(await sql.query('qq_voices'),isEmpty);
    });
    test('invalid or duplicate voice provenance is rejected before restore',()async {
      await spoken();final backup=jsonDecode(jsonEncode(await db.exportAll())) as Map;
      final tables=(backup['tables'] as Map).cast<String,dynamic>(),voices=tables['qq_voices'] as List;
      voices.add({...voices.single as Map,'id':'duplicate'});
      expect(()=>QqArchiveSchema.validate(tables,version:66),throwsFormatException);
      voices.removeLast();(voices.single as Map)['language']='fr';
      expect(()=>QqArchiveSchema.validate(tables,version:66),throwsFormatException);
    });
    test('schema65 archive remains readable without the new table',()async {
      await spoken();final sql=await db.database;await sql.execute('DROP TABLE qq_voices');
      expect(await QqArchiveReader(sql).privateContext('QQ私聊',scope:scope),contains('おやすみなさい。'));
      expect((await QqHistoryReader(sql).search('QQ私聊',scope:scope)).text,contains('おやすみなさい。'));
    });
  });
}
