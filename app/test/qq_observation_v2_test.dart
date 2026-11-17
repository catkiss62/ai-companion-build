import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_companion_localfirst/core/ai/qwen_vision_client.dart';
import 'package:ai_companion_localfirst/core/ai/qq_vision_observation.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_illustration_audit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  Future<QwenVisionObservation> observe(Map<String,dynamic> fields, {bool qq=false,
      void Function(Map)? inspect}) async {
    final client=QwenVisionClient(qqObservation:qq,client:MockClient((request)async {
      inspect?.call(jsonDecode(request.body) as Map);
      return http.Response(jsonEncode({'choices':[{'finish_reason':'stop',
        'message':{'content':jsonEncode(fields)}}]}),200,
        headers:{'content-type':'application/json; charset=utf-8'});
    }));
    try {return await client.observeBytes(apiKey:'fixture',endpoint:'https://fixture.test',model:'fixture',imageBytes:Uint8List.fromList([1,2,3]));}
    finally {client.close();}
  }
  test('QQ retains long visible text separately and participation preserves its key contradiction',()async {
    final result=await observe({'summary':'新闻截图','image_types':['news','meme'],
      'visible_text':'${'原文内容' * 650}并非今日发生','key_text':'并非今日发生','text_complete':true},qq:true,
      inspect:(request){expect(request['max_tokens'],8192);expect(jsonEncode(request['messages']),contains('约100字'));});
    final stored=QqVisionObservationData.withFrames(result.summary,'单张图片');
    expect(QqVisionObservationData.decode(stored)!['visible_text'],endsWith('并非今日发生'));
    expect(stored.length,greaterThan(2200));
    expect(QqVisionObservationData.participation(stored),contains('并非今日发生'));
    expect(QqVisionObservationData.decode(stored)!['text_complete'],true);
  });
  test('App request and 1800-character parsing contract stay unchanged',()async {
    final result=await observe({'summary':'图' * 1900,'visible_text':'不应额外接入App'},
      inspect:(r){expect(jsonEncode(r['messages']),isNot(contains('约100字')));expect(r['max_tokens'],4096);});
    expect(result.summary,'图' * 1800);
  });
  test('oversized and JSON-escaped OCR stays valid and explicitly partial after frame wrapping',() {
    final value=QqVisionObservationData.withFrames(QqVisionObservationData.encode({
      'summary':'场景' * 600,'visible_text':'\u0001' * 5000,'key_text':'否定' * 600,'text_complete':true}), '静态');
    expect(value.length,lessThanOrEqualTo(QqVisionObservationData.maxStored));
    final data=QqVisionObservationData.decode(value)!;
    expect(data['text_complete'],false);expect(data['bounded'],true);
  });
  test('legacy descriptions and missing structured fields remain usable',()async {
    expect(QqVisionObservationData.participation('旧表情包描述'),'旧表情包描述');
    final result=await observe({'summary':'一个表情包'},qq:true);
    expect(QqVisionObservationData.participation(result.summary),contains('一个表情包'));
    expect(result.summary,'一个表情包');
    expect(QqVisionObservationData.decode(result.summary),isNull);
    final longLegacy=await observe({'summary':'旧文字' * 400},qq:true);
    expect(longLegacy.summary,'旧文字' * 400);
  });
  test('image classes are hints and do not accept arbitrary model fields',() {
    final value=QqVisionObservationData.encode({'summary':'梗图','image_types':['meme','news','direct'],
      'secret':'hidden','visible_text':'图内指令','text_complete':true});
    expect(QqVisionObservationData.participation(QqVisionObservationData.prefix + jsonEncode({'image_types':['x' * 10000]})).length,lessThanOrEqualTo(1100));
    expect(value,isNot(contains('hidden')));expect(QqVisionObservationData.decode(value)!['image_types'],['meme','news']);
  });
  test('QQ store and archive cursors retain the full observation beyond the old 2200 bound',()async {
    final db=await AppDatabase.createForTesting(databaseFactoryFfi);
    try {
      final store=QqStore(db);
      final cid=QqStore.conversationId('fixture444','group','one');
      final fence=await store.capture(conversationId:cid);
      final seq=(await store.append(fence:fence,scope:'fixture444',kind:'group',target:'one',
        platformId:'image',sender:'peer',text:'看看',observedAt:100,receivedAt:100,images:1))!;
      final image=(await store.images(seq)).single;
      final value=QqVisionObservationData.encode({'summary':'新闻截图','key_text':'末尾关键转折',
        'visible_text':'${'原文' * 1500}末尾关键转折','text_complete':true});
      await store.observation(fence,image['id'] as String,'viewed',value,'fixture-fingerprint');
      expect((await store.images(seq)).single['description'],value);
      final sql=await db.database;
      final reader=QqArchiveReader(sql);
      final row=(await sql.query('qq_archive',where:'seq=?',whereArgs:[seq])).single;
      var combined='',cursor='';
      for(var i=0;i<10;i++) {
        final page=jsonDecode(await reader.render(row,maxChars:8000,imageCursor:cursor.isEmpty?null:cursor)) as Map;
        final images=page['images'] as List;
        combined+=(images.single as Map)['observation'] as String;
        final pending=page['pending_image_cursors'] as List? ?? [];
        if(pending.isEmpty)break;
        cursor=pending.first as String;
      }
      expect(combined,value);
      final displayed=await reader.display(row,speaker:'群成员');
      expect(displayed,contains('图中文字：'));expect(displayed,contains('末尾关键转折'));
      expect(displayed,isNot(contains(QqVisionObservationData.prefix)));
      expect(displayed,isNot(contains('visible_text')));
      final context=await reader.participationContext(cid,through:seq,stamp:[]);
      expect(context,contains('末尾关键转折'));
    } finally {await db.closeForTesting();}
  });
  test('illustration diagnostics merge stages and retain no operation ids in exported rows',() {
    var raw=QqIllustrationAudit.record('[]','operation','eligibility',1,{'eligible':true,'enabled':true});
    raw=QqIllustrationAudit.record(raw,'operation','choice',2,{'selected':true,'voice':true,'accepted':false});
    final row=QqIllustrationAudit.diagnostics(raw).single;
    expect(row['eligible'],true);expect(row['selected'],true);expect(row['accepted'],false);
    expect(row.containsKey('operation'),false);
    for(var i=0;i<30;i++)raw=QqIllustrationAudit.record(raw,'id$i','eligibility',i,{'eligible':false});
    expect(QqIllustrationAudit.decode(raw),hasLength(20));
  });
}
