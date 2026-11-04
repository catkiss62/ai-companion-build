import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_failure.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_failure_history.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_sketch.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_voice_usage.dart';

class _Secure extends SecureConfig {
  _Secure():super.forTesting(const FlutterSecureStorage());
  @override Future<String?> readApiKey()async=>'fixture-key';
  @override Future<String> readEndpoint()async=>'https://fixture.invalid/chat';
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;
  const channel=MethodChannel('fixture/sketch417');
  const good='<svg><circle r="12" fill="#ff0000"/></svg>';
  const bad='<svg><circle r="12" style="fill:red"/></svg>';
  final at=DateTime(2026,11,5,12).millisecondsSinceEpoch;
  setUp(()async {FlutterSecureStorage.setMockInitialValues({});db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);});
  tearDown(()async {TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null);await db.closeForTesting();});
  Future<QqBatch> batch()async {
    final cid=QqStore.conversationId('fixture417','group','one');
    final fence=await store.capture(conversationId:cid);
    await store.append(fence:fence,scope:'fixture417',kind:'group',target:'one',platformId:'request',sender:'peer',text:'画个圆',observedAt:at,receivedAt:at,policy:'p');
    return (await store.claim(await store.capture(conversationId:cid),cid,1,at,policy:'p'))!;
  }
  http.Response output(String svg)=>http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode({'svg':svg,'description':'圆形图案'})},'finish_reason':'stop'}]}),200);
  test('one known dialect repair preserves budget and shared ownership then sends no QQ message',()async {
    final b=await batch();var calls=0,renders=0;final failures=<QqSketchFailure>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(m)async {
      renders++;if(renders==1)throw PlatformException(code:'sketch_invalid',details:{'reason':'svg_attribute'});
      expect((m.arguments as Map)['svg'],good);return Uint8List.fromList([1,2,3]);
    });
    final client=DeepSeekClient(jsonClientFactory:()=>MockClient((r)async {
      calls++;final body=jsonDecode(r.body) as Map;
      expect(body['thinking'],{'type':calls==1?'enabled':'disabled'});
      if(calls==2)expect(((body['messages'] as List).last as Map)['content'],contains('svg_attribute'));
      return output(calls==1?bad:good);
    }));
    try {
      final result=await QqSketchService(store,channel:channel).generate(b,const QqSketchChoice('圆',true),now:at,secure:_Secure(),client:client,current:()async=>true,onRepair:(f)async=>failures.add(f));
      expect(result.svg,good);expect(calls,2);expect(renders,2);expect(failures.single.stage,'sketch_render');
      expect((await db.getSetting('qq_sketch_budget_v1'))!.split(':').last,'2');
      expect(await (await db.database).query('qq_sketches'),isEmpty);
    } finally {client.close();}
  });
  test('persistent format failure stops after two requests and never resets hourly budget',()async {
    final b=await batch();var calls=0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(m)async=>throw PlatformException(code:'sketch_invalid',details:{'reason':'svg_attribute'}));
    final client=DeepSeekClient(jsonClientFactory:()=>MockClient((_)async {calls++;return output(bad);}));
    try {await expectLater(QqSketchService(store,channel:channel).generate(b,const QqSketchChoice('圆',true),now:at,secure:_Secure(),client:client,current:()async=>true),
      throwsA(isA<QqSketchFailure>().having((e)=>e.attempt,'attempt',2)));expect(calls,2);}finally{client.close();}
  });
  test('HTTP rejection does not trigger a paid format repair',()async {
    final b=await batch();var calls=0;
    final client=DeepSeekClient(jsonClientFactory:()=>MockClient((_)async {calls++;return http.Response('{}',503);}));
    try {await expectLater(QqSketchService(store,channel:channel).generate(b,const QqSketchChoice('圆',true),now:at,secure:_Secure(),client:client,current:()async=>true),
      throwsA(isA<QqSketchFailure>().having((e)=>e.code,'code','model_http_503').having((e)=>e.stage,'stage','sketch_request')));expect(calls,1);}finally{client.close();}
  });
  test('budget exhaustion before repair never makes the second paid request',()async {
    final b=await batch();await db.setSetting('qq_sketch_budget_v1','${at~/const Duration(hours:1).inMilliseconds}:3');var calls=0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(m)async=>throw PlatformException(code:'sketch_invalid',details:{'reason':'svg_attribute'}));
    final client=DeepSeekClient(jsonClientFactory:()=>MockClient((_)async {calls++;return output(bad);}));
    try {await expectLater(QqSketchService(store,channel:channel).generate(b,const QqSketchChoice('圆',true),now:at,secure:_Secure(),client:client,current:()async=>true),throwsA(isA<QqSketchFailure>().having((e)=>e.code,'code','sketch_budget')));expect(calls,1);}finally{client.close();}
  });
  test('invalidated ownership after native rejection prevents repair',()async {
    final b=await batch();var calls=0,active=true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(m)async {active=false;throw PlatformException(code:'sketch_invalid',details:{'reason':'svg_attribute'});});
    final client=DeepSeekClient(jsonClientFactory:()=>MockClient((_)async {calls++;return output(bad);}));
    try {await expectLater(QqSketchService(store,channel:channel).generate(b,const QqSketchChoice('圆',true),now:at,secure:_Secure(),client:client,current:()async=>active),throwsA(anything));expect(calls,1);}finally{client.close();}
  });
  test('safe wrapping normalization is not arbitrary SVG stripping',() {
    expect(QqSketchService.normalize('```svg\n$good\n```'),good);
    expect(QqSketchService.repairable('<svg><script>bad</script></svg>','svg_tag'),false);
    expect(QqSketchService.repairable('<svg><path','sketch_format'),false);
    expect(QqSketchService.repairable(bad,'network'),false);
  });
  test('confirmed voice usage deduplicates and strips private material',()async {
    final b=await batch();await store.sentPart(b,1,'fixture spoken words','',at,voiceLanguage:'zh',voiceProfile:'lively');
    await store.sentPart(b,1,'fixture spoken words','',at,voiceLanguage:'zh',voiceProfile:'lively');
    final raw=await db.getSetting(QqVoiceUsage.key);expect(QqVoiceUsage.decode(raw!).single['voice'],'lively');
    expect(raw,isNot(contains('spoken')));expect(raw,isNot(contains(b.cid)));
    expect(QqVoiceUsage.decode('[{"seq":1,"at":1,"voice":"lively","language":"zh","secret":"x"}]').single.containsKey('secret'),false);
  });
  test('failure metadata allows only bounded counters and enum codes',() {
    final raw=QqFailureHistory.record('[]',operation:'fixture',at:1,phase:'sketch_render',code:'svg_attribute',details:{'svg_chars':19000,'stage_elapsed_ms':2,'svg':'private','url':'secret'});
    final row=QqFailureHistory.decode(raw).single;expect(row['svg_chars'],16001);expect(row.containsKey('svg'),false);expect(raw,isNot(contains('private')));
  });
}
