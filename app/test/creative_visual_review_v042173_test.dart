import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/qwen_vision_client.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/creative/creative_worker.dart';
import 'package:ai_companion_localfirst/core/creative/creative_workspace.dart';
import 'package:ai_companion_localfirst/core/creative/creative_visual_review.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'creative_agent_test.dart' as fixture;

class _Review extends CreativeVisualReview {
  int calls=0;
  bool reject=false;
  @override Future<String> review(AppDatabase db,Uint8List bytes,String brief,Future<bool> Function() current) async {
    calls++;expect(await current(),true);expect(bytes[0],137);
    if(reject)throw const FormatException('fixture failure');
    return '主体清晰，建议提高按钮文字与背景的对比。';
  }
}
class _Vision extends QwenVisionClient {
  _Vision(this.after);
  final void Function() after;
  bool closed=false;
  @override Future<QwenVisionObservation> reviewWorkBytes({required String apiKey,required String endpoint,
    required String model,required Uint8List imageBytes,String brief=''}) async {
    after();return const QwenVisionObservation(summary:'fixture advice',model:'fixture',inputContentSha256:'fixture');
  }
  @override void close(){closed=true;super.close();}
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  final pixels=base64Decode('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAK0lEQVR42u3NQQEAQAQAMC6hYNJJdCX4bQWW1ROXXhwTCAQCgUAgEAgEWz7rPQHu8hmbmAAAAABJRU5ErkJggg==');
  test('review requires the current successful preview and real bounded pixels',() {
    final proof={'ok':true,'hash':'v1','cover':base64Encode(pixels)};
    expect(CreativeVisualBudget.pixels(proof,'v1'),pixels);
    expect(()=>CreativeVisualBudget.pixels(proof,'v2'),throwsFormatException);
    expect(()=>CreativeVisualBudget.pixels({...proof,'ok':false},'v1'),throwsFormatException);
    expect(()=>CreativeVisualBudget.pixels({...proof,'cover':''},'v1'),throwsFormatException);
  });
  test('durable reservation survives serialization without admitting a second review',() {
    final agent={'visual_review':CreativeVisualBudget.reserve('r1','h1')};
    final restored=jsonDecode(jsonEncode(agent)) as Map;
    final row=CreativeVisualBudget.prior(restored,'r1')!;
    expect(CreativeVisualBudget.feedback(row)['visual_review'],'interrupted_no_retry');
    expect(CreativeVisualBudget.prior(restored,'r2'),isNull);
  });
  test('design rules remain a stable work-only prefix without screenshot duplication',() {
    final agent=CreativeWorkspace.create('a','r');agent['verification']={'cover':base64Encode(pixels),'ok':true};
    agent['visual_review']={'request_id':'r','hash':'h','status':'done','advice':'long-review-already-in-tool-history'};
    final msgs=CreativeWorkspace.messages(agent,{'brief':'fixture','origin':'commission'});
    expect(msgs.first['content'],contains('视觉设计'));expect(msgs.first['content'],contains('普通作品无需额外识图'));
    expect(jsonEncode(msgs),isNot(contains(base64Encode(pixels))));
    expect(jsonEncode(msgs),isNot(contains('long-review-already-in-tool-history')));
  });
  test('late visual feedback is rejected and its transport closes on ownership loss',()async {
    final db=await AppDatabase.createForTesting(databaseFactoryFfi);var active=true;
    final vision=_Vision(()=>active=false);
    final service=CreativeVisualReview(factory:(_,__)=>vision,configured:(_)async=>true);
    try {await expectLater(service.review(db,pixels,'fixture',()async=>active),throwsFormatException);expect(vision.closed,true);}
    finally {await db.closeForTesting();}
  });
  test('unconfigured review cannot make a request or claim to have seen pixels',()async {
    final db=await AppDatabase.createForTesting(databaseFactoryFfi);var calls=0;
    final service=CreativeVisualReview(factory:(_,__){calls++;return _Vision((){});},configured:(_)async=>false);
    try {await expectLater(service.review(db,pixels,'fixture',()async=>true),throwsFormatException);expect(calls,0);}
    finally {await db.closeForTesting();}
  });
  test('actual vision request uses work critique mode while ordinary observation stays neutral',() async {
    var calls=0;
    QwenVisionClient makeClient()=>QwenVisionClient(requiresApiKey:false,client:MockClient((request) async {
      calls++;
      final body=jsonDecode(request.body) as Map;
      final messages=body['messages'] as List;
      final system=(messages.first as Map)['content'] as String;
      final user=(messages.last as Map)['content'] as List;
      expect(request.url.isAbsolute,true);
      expect(jsonEncode(user),contains('data:image/png;base64,'));
      if(calls==1) {
        expect(system,contains('视觉复审'));expect(system,contains('最多提出3条'));
        expect(body['max_tokens'],900);expect(jsonEncode(user),contains('只作主题资料'));
      } else {
        expect(system,contains('中性、简洁'));expect(system,isNot(contains('最多提出3条')));
        expect(body['max_tokens'],4096);
      }
      return http.Response(jsonEncode({'choices':[{'finish_reason':'stop','message':{
        'content':jsonEncode({'summary':'主体明确，按钮文字对比可以提高。'})}}]}),200,
        headers:{'content-type':'application/json; charset=utf-8'});
    }));
    final db=await AppDatabase.createForTesting(databaseFactoryFfi);
    final service=CreativeVisualReview(factory:(_,__)=>makeClient(),configured:(_)async=>true);
    try {
      expect(await service.review(db,pixels,'只作主题资料',()async=>true),contains('文字对比'));
    } finally {await db.closeForTesting();}
    final client=makeClient();
    await client.observeBytes(apiKey:'fixture',endpoint:QwenVisionClient.defaultEndpoint,
      model:QwenVisionClient.defaultModel,imageBytes:pixels);
    expect(calls,2);client.close();
  });
  for(final mode in ['review','unavailable','no_image']) {
    final unavailable=mode=='unavailable',missing=mode=='no_image';
    test('worker $mode keeps review optional and requires actual functional preview',()async {
      final db=await AppDatabase.createForTesting(databaseFactoryFfi);final store=CreativeStore(db);
      final dir=await Directory.systemTemp.createTemp('creative417_');final image=File('${dir.path}/preview.png');await image.writeAsBytes(pixels);
      final reviewer=_Review()..reject=unavailable;var requests=0;var clock=DateTime(2026,11,5,12);
      FlutterSecureStorage.setMockInitialValues({'deepseek_api_key':'fixture-key'});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CreativeWorker.preview,(m)async=>fixture.nativePreviewResult(m.arguments,{'screenshot':missing?'':image.path}));
      final id=(await store.commission(deepThinking:true,requestId:'r417',messageId:'m417',brief:'一盏灯',requestQuote:'做一盏灯',latestText:'做一盏灯'))['id'] as String;
      final runtime=CreativeWorker(db,now:()=>clock,visualReview:reviewer,clientFactory:(abort)=>DeepSeekClient(abortWhen:abort,
        streamClientFactory:()=>MockClient((r)async {
          requests++;
          final calls=requests==1?[fixture.plan(),fixture.write(fixture.repaired),fixture.previewCall()]:[
            fixture.call('work_visual_review',{'source_hash':CreativeContract.hash(fixture.repaired)},id:'review1'),
            fixture.call('work_visual_review',{'source_hash':CreativeContract.hash(fixture.repaired)},id:'review2'),fixture.call('work_finish',{})];
          return fixture.response(fixture.sse(calls));
        })));
      try {
        for(var i=0;i<4;i++) {await runtime.runOnce();if((await store.get(id))['status']=='ready')break;clock=clock.add(const Duration(hours:1));}
        final work=await store.get(id);expect(work['status'],'ready');expect(reviewer.calls,missing?0:1);expect(requests,2);
        final agent=CreativeContract.decode(await db.getSetting(CreativeWorkspace.key(id)));
        expect((agent['visual_review'] as Map)['status'],unavailable || missing?'unavailable':'done');
        expect((agent['verification'] as Map)['ok'],true);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(CreativeWorker.preview,null);
        await db.closeForTesting();await dir.delete(recursive:true);
      }
    });
  }
}
