import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/brain_work_fence.dart';
import 'package:ai_companion_localfirst/core/creative/creative_contract.dart';
import 'package:ai_companion_localfirst/core/creative/creative_store.dart';
import 'package:ai_companion_localfirst/core/creative/creative_play.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late CreativeStore store;
  late CreativePlay play;
  late String id, version;
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    store = CreativeStore(db);
    final w = await store.commission(deepThinking: true, requestId: 'request', messageId: 'commission',
      brief: '作品', requestQuote: '作品', latestText: '作品');
    id = w['id'] as String;
    version = CreativeContract.hash('<p>公开作品</p>');
    await store.write(w, {...w, 'current': version, 'versions': [version], 'status': 'ready'},
      extra: {'${CreativeContract.sourcePrefix}$version': '<p>公开作品</p>'});
    play = CreativePlay(db, id); await play.open();
  });
  tearDown(() async => db.closeForTesting());
  Future<void> save(Object? data) async { await play.event(version, jsonEncode({'kind':'save','data':data})); }
  Future<void> send(String messageId, CreativeChatSnapshot snapshot) async {
    await db.createGenerationTurn(user: ChatMessage(id: messageId, role: 'user', content: '看看现在', createdAt: DateTime.now()),
      assistantMessageId: 'a:$messageId', model: 'deepseek-flash', reasoningEffort: 'max',
      creativeContext: snapshot.data, creativeFence: snapshot.fence);
  }
  test('seventh result retains totals and IDs; ordinary chat never inherits open-page scope', () async {
    final before = await play.read();
    final turns = <String,Object?>{for(var i=1;i<=9;i++) '$i': {'choice':'paper','playerChoice':'rock','at':i}};
    turns['10'] = {'choice':'hidden-secret','at':10};
    await db.setSetting(play.stateKey, jsonEncode({...before,'turns':turns}));
    await save({'you':3,'her':6,'current_round':10});
    final snapshot = await play.captureSnapshot();
    expect(snapshot.data['public_state'], {'you':3,'her':6,'current_round':10});
    expect(snapshot.data['revealed_total'], 9);
    expect(snapshot.data['history_truncated'], true);
    expect((snapshot.data['recent_revealed'] as List).first['turn_id'], '2');
    expect(snapshot.data['latest_revealed']['turn_id'], '9');
    expect(jsonEncode(snapshot.data), isNot(contains('hidden-secret')));
    expect(await CreativePlay.chatContext(db), isEmpty);
    await send('u1', snapshot);
    final detail = await CreativePlay.chatContext(db, userMessageId: 'u1');
    expect(detail, contains('"her":6'));
    expect(detail, contains('不能当累计比分'));
    expect(await CreativePlay.chatContext(db, userMessageId: 'ordinary'), isEmpty);
  });
  test('old seven-round public save is usable without rebuilding the HTML', () async {
    final state = await play.read();
    await db.setSetting(play.stateKey, jsonEncode({...state, 'turns':{for(var i=1;i<=7;i++) '$i':
      {'choice':i%2==1?'paper':'scissors','playerChoice':'rock','at':i}},
      'public':{'you':3,'her':4,'turn':8}}));
    final snap = await play.captureSnapshot();
    expect(snap.data['public_state']['her'],4);
    expect(snap.data['revealed_total'],7);
    expect(snap.data['latest_revealed']['turn_id'],'7');
  });
  test('new sessions isolate old callbacks and reset progress, reopening keeps it', () async {
    await save({'board':['x','o'], 'next_actor':'companion'});
    final before = await play.read();
    expect((await play.open())['session_id'], before['session_id']);
    final oldPage = CreativePlay(db,id); await oldPage.open();
    final restart = await play.open(restart:true);
    expect(restart['session_id'], isNot(before['session_id']));
    expect(restart['public'], isEmpty);
    expect((await play.captureSnapshot()).data['revealed_total'],0);
    await expectLater(oldPage.event(version,jsonEncode({'kind':'save','data':{'late':true}})),throwsA(isA<BrainWorkInvalidated>()));
    await expectLater(play.event(version,jsonEncode({'kind':'save','data':{'late':true}}),sessionId:before['session_id'] as String),throwsA(isA<BrainWorkInvalidated>()));
    expect((await play.read())['public'],isEmpty);
  });
  test('static descriptions and observed text are scoped to the message; long-open pages work', () async {
    await play.event(version,jsonEncode({'kind':'describe','data':{'kind':'static','content':'树下有一封可展开的信',
      'effects':'雪花缓慢落下，点击点亮星星','resettable':false}}));
    await db.setSetting('creative_focus_v1',jsonEncode({'id':id,'at':1}));
    final snapshot=await play.captureSnapshot(observation:{'text':'圣诞快乐','animations':[{'name':'snowfall','duration':'8s'}]});
    await send('card',snapshot);
    final detail=await CreativePlay.chatContext(db,userMessageId:'card');
    expect(detail,contains('雪花缓慢落下'));
    expect(detail,contains('snowfall'));
    expect(detail,contains('不是实时看屏幕'));
    expect(await CreativePlay.chatContext(db),isEmpty);
    expect(await store.chatContext(),isNot(contains('snowfall')));
  });
  test('snapshot commits with user turn; restart before commit rejects both', () async {
    final snapshot=await play.captureSnapshot();
    await play.open(restart:true);
    await expectLater(send('stale',snapshot),throwsA(isA<BrainWorkInvalidated>()));
    expect(await db.messageById('stale'),isNull);
    expect(await db.getSetting('${CreativeContract.chatPrefix}stale'),isNull);
  });
  test('snapshot after send is immutable across restart and survives backup', () async {
    await save({'phase':'finished','score':42});
    await send('old',await play.captureSnapshot());
    await play.open(restart:true);
    final detail=await CreativePlay.chatContext(db,userMessageId:'old');
    expect(detail,contains('"score":42'));
    expect(detail,contains('发送后作品已开始新会话'));
    final backup=await db.exportAll(); await db.importAll(Map<String,dynamic>.from(backup));
    expect(await CreativePlay.chatContext(db,userMessageId:'old'),contains('"score":42'));
    await store.delete(id);
    expect(await CreativePlay.chatContext(db,userMessageId:'old'),isNot(contains('"score":42')));
  });
  test('large public and DOM data remain bounded without exposing sealed choices', () async {
    await save({'points':50,'history':List.generate(50,(i)=>{'n':i,'text':'长'*2000})});
    final snapshot=await play.captureSnapshot(observation:{'text':'雪'*12000});
    expect(snapshot.data['public_state']['points'],50);
    expect(utf8.encode(jsonEncode(snapshot.data)).length,lessThanOrEqualTo(CreativeContract.maxSnapshotBytes));
  });
  test('progress and delivery receipts stay associated when a revision replaces metadata', () async {
    final receipt='${CreativeContract.receiptPrefix}completed';
    await db.setSetting(receipt,jsonEncode({'work_id':id,'version':version,'message_id':'completed','kind':'delivered'}));
    await store.commission(deepThinking:true,requestId:'revision',messageId:'revision-message',brief:'修改',
      requestQuote:'修改',latestText:'修改',workId:id);
    expect((await store.forMessage('completed')).single['card_kind'],'delivered');
    expect((await store.forMessage('commission')).single['card_kind'],'progress');
    expect((await store.forMessage('revision-message')).single['card_kind'],'progress');
    final backup=await db.exportAll();await db.importAll(Map<String,dynamic>.from(backup));
    expect((await store.forMessage('completed')).single['id'],id);
    await store.delete(id);expect(await store.forMessage('completed'),isEmpty);
  });
}
