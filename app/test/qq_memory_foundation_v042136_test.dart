import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qq_private_bridge/qq_private_bridge.dart';
import 'package:ai_companion_localfirst/core/ai/deepseek_client.dart';
import 'package:ai_companion_localfirst/core/ai/memory_extractor.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/automatic_memory_permit.dart';
import 'package:ai_companion_localfirst/core/database/derived_source_store.dart';
import 'package:ai_companion_localfirst/core/desire/desire_engine.dart';
import 'package:ai_companion_localfirst/core/memory/memory_brain.dart';
import 'package:ai_companion_localfirst/core/memory/memory_revision.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:ai_companion_localfirst/core/storage/secure_config.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_readonly_context.dart';

class _Config extends SecureConfig {
  _Config() : super.forTesting(const FlutterSecureStorage());
  @override Future<String?> readApiKey() async => 'test-only';
  @override Future<String> readEndpoint() async => 'https://unused.test';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    for (final key in ['post_turn_queue_enabled','daily_continuity_enabled','memory_fading_enabled',
      'memory_consolidation_enabled','relationship_continuity_enabled','personality_learning_enabled']) {
      await db.setSetting(key, '0');
    }
  });
  tearDown(() async => db.closeForTesting());
  ChatMessage message(String id, String role, String text, int at) => ChatMessage(
    id: id, role: role, content: text, createdAt: DateTime.fromMillisecondsSinceEpoch(at));
  Map<String,Object?> row(String id, {String content = '紫色珊瑚', int valid = 1,
    String semantic = 'current_fact', String status = 'active', double importance = .8,
    String subject = 'user.coral'}) => {'id':id,'kind':'user_profile','content':content,
      'importance':importance,'confidence':.95,'source':'fixture','status':status,
      'semantic_type':semantic,'source_valid':valid,'subject_key':subject,
      'tags':'','created_at':1,'updated_at':1};
  Future<MemoryItem> item(String id) async => MemoryItem.fromDb(
    (await (await db.database).query('memory_items',where:'id = ?',whereArgs:[id])).single);

  test('R1 real reply-source revocation removes derived experience from App and QQ', () async {
    final u=message('u','user','我们一起看了紫色珊瑚',1000);
    final a=message('a','assistant','一起看了紫色珊瑚',2000);
    await db.insertMessage(u); await db.insertMessage(a);
    await db.insertMemory(kind:'shared_experience',content:'共同看过紫色珊瑚',importance:.9,
      source:'conversation_turn:a@r0',sourceUserMessageId:u.id,sourceAssistantMessageId:a.id,
      sourceContextJson:jsonEncode({'dependency':'joint_basis'}));
    final sql=await db.database;
    await sql.transaction((txn) => DerivedSourceStore.revoke(txn,'a',0));
    expect((await sql.query('memory_items')).single['source_valid'],0);
    expect(await db.relevantMemories('紫色珊瑚'),isEmpty);
    expect(await db.memoryCandidatesForExtraction('紫色珊瑚'),isEmpty);
    expect(await QqReadOnlyContext(sql).build('紫色珊瑚'),isNot(contains('共同看过紫色珊瑚')));
  });

  for (final lane in ['fact','inference','history']) {
    test('R1 $lane invalid rows are excluded before candidate limits', () async {
      final sql=await db.database; final batch=sql.batch();
      final semantic=lane=='inference'?'inference':'current_fact';
      final status=lane=='history'?'superseded':'active';
      for(var i=0;i<410;i++) {batch.insert('memory_items',row('bad$i',valid:0,
        semantic:semantic,status:status,importance:1));}
      batch.insert('memory_items',row('good',semantic:semantic,status:status,importance:.1));
      await batch.commit(noResult:true);
      final found=lane=='fact'? await db.relevantMemories('紫色珊瑚',recordRecall:false):
        lane=='inference'?await db.relevantMemoryInferences('紫色珊瑚'):await db.relevantHistoricalMemories('紫色珊瑚');
      expect(found.map((m)=>m.id),['good']);
      if(lane=='fact') expect(await QqReadOnlyContext(sql).build('紫色珊瑚'),contains('紫色珊瑚'));
    });
  }

  test('R3 App and QQ reject old behavior memories while preserving real facts and QQ read-only state', () async {
    final sql=await db.database;
    await sql.insert('memory_items',row('legacy',content:'用户喜欢说话更幽默 LEGACY-ONLY',
      subject:'user.preference.communication.familiarity',importance:1));
    await sql.insert('memory_items',row('desk',content:'用户书桌是橡木 LEGIT-DESK',subject:'user.desk'));
    final app=await MemoryBrain(db).buildContext('幽默和书桌');
    expect(MemoryBrain(db).formatForPrompt(app),isNot(contains('LEGACY-ONLY')));
    final before=await sql.query('memory_items');
    final qq=await QqReadOnlyContext(sql).build('幽默和书桌');
    expect(qq,isNot(contains('LEGACY-ONLY'))); expect(qq,contains('LEGIT-DESK'));
    expect(await sql.query('memory_items'),before);
  });

  test('R2 read-only adapter uses a coherent WAL snapshot and rejects withdrawn material stamps', () async {
    final dir=await Directory.systemTemp.createTemp('qq-snapshot-');
    final file='${dir.path}/main.db';
    final writer=await AppDatabase.createForTesting(databaseFactoryFfi,path:file);
    try {
      final sql=await writer.database; await sql.rawQuery('PRAGMA journal_mode=WAL');
      await writer.setSetting('probe','old');
      await sql.insert('memory_items',row('memory'));
      final stamp=<String,Object?>{};
      await QqReadOnlyContext.readAt(file,(context) async {
        expect(await context.setting('probe'),'old');
        await writer.setSetting('probe','new');
        expect(await context.setting('probe'),'old');
        await context.build('紫色珊瑚',stamp:stamp);
      },factory:databaseFactoryFfi);
      expect(await writer.getSetting('probe'),'new');
      expect(await QqReadOnlyContext.readAt(file,(c)=>c.matchesStamp(stamp),factory:databaseFactoryFfi),isTrue);
      await sql.update('memory_items',{'source_valid':0},where:'id = ?',whereArgs:['memory']);
      expect(await QqReadOnlyContext.readAt(file,(c)=>c.matchesStamp(stamp),factory:databaseFactoryFfi),isFalse);
    } finally {await writer.closeForTesting(); await dir.delete(recursive:true);}
  });

  for(final reenable in [false,true]) {
    test('R4 real extraction rejects a reply after auto_memory off (reenable=$reenable)',() async {
      await db.setSetting('auto_memory','1');
      final u=message('u','user','我的书桌是橡木做的',1000),a=message('a','assistant','橡木书桌',2000);
      await db.insertMessage(u);await db.insertMessage(a);
      final client=DeepSeekClient(client:MockClient((request) async {
        await db.setSetting('auto_memory','0');
        if(reenable) await db.setSetting('auto_memory','1');
        return http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode({'memories':[
          {'kind':'user_profile','content':'用户的书桌是橡木做的','importance':.8,'confidence':.95,
            'subject_key':'user.desk.material','semantic':'current_fact','action':'append'}]})},'finish_reason':'stop'}]}),200,
          headers:{'content-type':'application/json; charset=utf-8'});
      }));
      try {await MemoryExtractor(db:db,client:client,desireEngine:DesireEngine(db),secureConfig:_Config())
        .extractFromTurn(user:u,assistant:a);
        expect(await db.listMemories(),isEmpty);
      } finally {client.close();}
    });
  }

  test('R4 permit survives serialization but not off/on or a restored epoch',() async {
    await db.setSetting('auto_memory','1');final sql=await db.database;
    final permit=await AutomaticMemoryPermit.capture(sql,'auto_memory');
    expect(await AutomaticMemoryPermit.decode(permit.toJson())!.matches(sql),isTrue);
    await db.setSettingsAtomically({'auto_memory':'0'});await db.setSettingsAtomically({'auto_memory':'1'});
    expect(await permit.matches(sql),isFalse);
    final fresh=await AutomaticMemoryPermit.capture(sql,'auto_memory');
    await db.setSetting('runtime_state_epoch_v1','restored');expect(await fresh.matches(sql),isFalse);
  });

  test('R4 real summary rejects off/on without marking sources covered',() async {
    await db.setSetting('memory_consolidation_enabled','1');
    for(var i=0;i<14;i++){await db.insertMessage(message('u$i','user','真实材料 $i',1000+i));}
    final client=DeepSeekClient(client:MockClient((request)async {
      await db.setSetting('memory_consolidation_enabled','0');await db.setSetting('memory_consolidation_enabled','1');
      return http.Response(jsonEncode({'choices':[{'message':{'content':jsonEncode({'summary':'不应保存','key_points':[]})},
        'finish_reason':'stop'}]}),200,headers:{'content-type':'application/json; charset=utf-8'});
    }));
    try {await MemoryExtractor(db:db,client:client,desireEngine:DesireEngine(db))
      .consolidateIfNeeded(apiKey:'test',endpoint:'https://unused.test');
      expect(await db.recentConversationSummaries(),isEmpty);
      expect(await (await db.database).query('conversation_summary_sources',where:"state = 'covered'"),isEmpty);
    }finally{client.close();}
  });

  test('R5 old source with a fresh target cannot reopen completion; newer confirmation can',() async {
    final newer=DateTime.fromMillisecondsSinceEpoch(20000),older=DateTime.fromMillisecondsSinceEpoch(10000);
    await db.insertMemory(kind:'user_profile',content:'项目已经完成',subjectKey:'user.project',importance:.8,
      confidence:.95,source:'newer',sourceObservedAt:newer,temporalScope:'ongoing',factState:'completed',
      attentionState:'closed',recallPolicy:'contextual');
    final target=(await db.listMemories()).single;
    expect(await db.insertMemory(kind:target.kind,content:'项目正在做',subjectKey:target.subjectKey,importance:.8,
      confidence:.95,source:'old-retry',sourceObservedAt:older,evidenceMode:'reinforce',targetMemoryId:target.id,
      expectedTarget:MemoryRevisionSnapshot.capture(target),factState:'ongoing'),isFalse);
    expect((await item(target.id)).factState,'completed');
    final u=message('old-u','user','项目正在做',10000),a=message('old-a','assistant','项目还在做',11000);
    await db.insertMessage(u);await db.insertMessage(a);
    expect(await db.insertMemory(kind:target.kind,content:'项目正在做',subjectKey:target.subjectKey,importance:.8,
      source:'old-change',confidence:.95,sourceObservedAt:older,evidenceMode:'replace',revisionKind:'change',
      targetMemoryId:target.id,expectedTarget:MemoryRevisionSnapshot.capture(await item(target.id)),
      sourceUserMessageId:u.id,sourceAssistantMessageId:a.id,userEvidenceQuote:u.content),isFalse);
    final newU=message('new-u','user','项目重新开始了',30000),newA=message('new-a','assistant','重新开始项目',31000);
    await db.insertMessage(newU);await db.insertMessage(newA);
    expect(await db.insertMemory(kind:target.kind,content:'项目重新开始了',subjectKey:target.subjectKey,importance:.8,
      source:'new-change',confidence:.95,sourceObservedAt:newU.createdAt,evidenceMode:'replace',revisionKind:'change',
      targetMemoryId:target.id,expectedTarget:MemoryRevisionSnapshot.capture(await item(target.id)),
      sourceUserMessageId:newU.id,sourceAssistantMessageId:newA.id,userEvidenceQuote:newU.content,factState:'ongoing'),isTrue);
    expect((await db.listMemories()).single.factState,'ongoing');
  });

  test('R2 delayed QQ reply and remaining chunks are fenced by their accepted epoch',() async {
    final dir=await Directory.systemTemp.createTemp('qq-epoch-');
    final journal=QqJournal(File('${dir.path}/journal.json'));await journal.open();
    var identity='A',sends=0;final entered=Completer<void>(),output=Completer<String>();
    final session=QqPrivateSession(journal:journal,owner:'owner',pairCode:'',pairExpires:DateTime.now(),
      bindOwner:(_)async{},allowed:()async=>true,yieldToChat:()async=>false,
      contextIdentity:()async=>identity,onStatus:(_){},
      generate:(_,__) {entered.complete();return output.future;},send:(_,__,___,____)async{sends++;});
    try {
      await session.accept({'id':'input','author':{'user_openid':'owner'},'content':'你好',
        'timestamp':DateTime.now().toUtc().toIso8601String(),'message_type':0});
      await entered.future;identity='B';output.complete('旧存档的回复');
      final until=DateTime.now().add(const Duration(seconds:3));
      while(journal.rows.single['state']!='context_invalidated'&&DateTime.now().isBefore(until)){
        await Future<void>.delayed(const Duration(milliseconds:5));}
      expect(journal.rows.single['state'],'context_invalidated');expect(sends,0);
    }finally{await session.stop();await dir.delete(recursive:true);}
  });

  for(final scenario in ['paused','restored','partial']){
    test('R2 generated journal handles $scenario without reviving old work',()async{
      final dir=await Directory.systemTemp.createTemp('qq-generated-');
      var identity='A',enabled=scenario!='paused',sends=0;
      var journal=QqJournal(File('${dir.path}/journal.json'));await journal.open();
      journal.rows.add({'id':'old','user':'输入','reply':scenario=='partial'?List.filled(1801,'字').join():'完整回复',
        'fixed':false,'state':'generated','context_identity':'A','at':DateTime.now().millisecondsSinceEpoch,'sent':0});
      await journal.save();
      if(scenario=='restored'){
        identity='B';journal=QqJournal(journal.file);await journal.open();
      }
      final session=QqPrivateSession(journal:journal,owner:'owner',pairCode:'',pairExpires:DateTime.now(),
        bindOwner:(_)async{},allowed:()async=>enabled,yieldToChat:()async=>false,
        contextIdentity:()async=>identity,onStatus:(_){},generate:(_,__)async=>throw StateError('must not regenerate'),
        send:(_,__,___,____)async{sends++;if(scenario=='partial')identity='B';});
      try{
        await session.drain();
        if(scenario=='paused'){
          expect(sends,0);expect(journal.rows.single['state'],'generated');
          enabled=true;await session.drain();expect(sends,1);expect(journal.rows.single['state'],'sent');
        }else{
          expect(journal.rows.single['state'],'context_invalidated');
          expect(sends,scenario=='partial'?1:0);expect(journal.rows.single['sent'],scenario=='partial'?1:0);
        }
      }finally{await session.stop();await dir.delete(recursive:true);}
    });
  }

  test('R5 compatible older evidence remains usable without moving the latest confirmation backwards',()async{
    final at=DateTime.fromMillisecondsSinceEpoch(20000);
    await db.insertMemory(kind:'user_profile',content:'项目已经完成',importance:.8,confidence:.95,
      subjectKey:'user.project',source:'newer',sourceObservedAt:at,factState:'completed',
      attentionState:'closed',recallPolicy:'contextual');
    final target=(await db.listMemories()).single;
    expect(await db.insertMemory(kind:target.kind,content:target.content,importance:.8,confidence:.95,
      subjectKey:target.subjectKey,source:'compatible-earlier',sourceObservedAt:DateTime.fromMillisecondsSinceEpoch(10000),
      evidenceMode:'reinforce',targetMemoryId:target.id,expectedTarget:MemoryRevisionSnapshot.capture(target)),isTrue);
    final stored=await item(target.id);expect(stored.lastEvidenceAt,at);
    expect(stored.factState,'completed');expect(stored.evidenceCount,target.evidenceCount+1);
  });
}
