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
    await store.write(w, {...w, 'current': version, 'versions': [version], 'status': 'ready',
      'title': '原版游戏', 'intro': '原版的作品说明'},
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
  test('snapshot with unavailable observation waits for already queued public save', () async {
    var saveSettled = false;
    final pending = save({'round': 7, 'phase': 'settled'}).then((_) => saveSettled = true);
    final snapshot = await play.captureSnapshot(observation: {'available': false});
    expect(saveSettled, isTrue);
    expect(snapshot.data['public_state'], {'round': 7, 'phase': 'settled'});
    await pending;
  });
  test('failed queued save does not poison later snapshot or adopt its rejected data', () async {
    final pending = save({'oversized': 'x' * 45000});
    final rejected = expectLater(pending, throwsFormatException);
    final snapshot = await play.captureSnapshot(observation: {'available': false});
    await rejected;
    expect(snapshot.data['public_state'], isEmpty);
    await save({'round': 1});
    expect((await play.captureSnapshot()).data['public_state'], {'round': 1});
  });
  test('running version keeps bound metadata through revision, reopen and newer release', () async {
    final work = await store.get(id);
    await store.write(work, {...work, 'status': 'building', 'title': '新版游戏',
      'intro': '新版的作品说明'});
    var snapshot = await play.captureSnapshot();
    expect(snapshot.data['title'], '原版游戏');
    expect(snapshot.data['intro'], '原版的作品说明');
    expect(snapshot.data['metadata_source'], 'session_version');

    const html = '<p>新版本</p>';
    final nextVersion = CreativeContract.hash(html);
    final revision = await store.get(id);
    await store.write(revision, {...revision, 'status': 'ready',
      'current': nextVersion, 'versions': [nextVersion, version]},
      extra: {'${CreativeContract.sourcePrefix}$nextVersion': html});
    await play.open();
    snapshot = await play.captureSnapshot();
    expect(snapshot.data['version'], version);
    expect(snapshot.data['title'], '原版游戏');
    expect(snapshot.data['intro'], '原版的作品说明');
    final archive = await db.exportAll();
    await db.importAll(Map<String, dynamic>.from(archive));
    final restored = CreativePlay(db, id);
    await restored.open();
    expect((await restored.captureSnapshot()).data['title'], '原版游戏');
    await restored.open(restart: true);
    snapshot = await restored.captureSnapshot();
    expect(snapshot.data['version'], nextVersion);
    expect(snapshot.data['title'], '新版游戏');
    expect(snapshot.data['intro'], '新版的作品说明');
  });
  test('legacy unbound session never adopts metadata from an unfinished or newer version', () async {
    final state = await play.read();
    state.remove('work_metadata');
    await db.setSetting(play.stateKey, jsonEncode(state));
    final work = await store.get(id);
    await store.write(work, {...work, 'status': 'building', 'title': '修改方案标题',
      'intro': '尚未实现的新版内容'});
    await play.open();
    var snapshot = await play.captureSnapshot();
    expect(snapshot.data['metadata_source'], 'catalog_only');
    expect(snapshot.data['catalog_title'], '修改方案标题');
    expect(snapshot.data['intro'], isEmpty);
    expect(snapshot.data['title'], isNot('修改方案标题'));

    const html = '<p>更新</p>';
    final newer = CreativeContract.hash(html);
    final revision = await store.get(id);
    await store.write(revision, {...revision, 'status': 'ready', 'current': newer,
      'versions': [newer, version]}, extra: {'${CreativeContract.sourcePrefix}$newer': html});
    await play.open();
    snapshot = await play.captureSnapshot();
    expect(snapshot.data['version'], version);
    expect(snapshot.data['metadata_source'], 'catalog_only');
    expect(snapshot.data['intro'], isEmpty);
  });
  test('legacy current ready version can bind its existing published metadata', () async {
    final state = await play.read();
    state.remove('work_metadata');
    await db.setSetting(play.stateKey, jsonEncode(state));
    await play.open();
    final snapshot = await play.captureSnapshot();
    expect(snapshot.data['metadata_source'], 'session_version');
    expect(snapshot.data['title'], '原版游戏');
    expect(snapshot.data['intro'], '原版的作品说明');
  });
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
  test('reverse reveals and repeated reveal retain actual order even at the same millisecond', () async {
    final state = await play.read();
    await db.setSetting(play.stateKey, jsonEncode({...state, 'turns': {
      'first': {'options': ['rock', 'paper'], 'choice': 'paper', 'at': 1},
      'second': {'options': ['rock', 'paper'], 'choice': 'rock', 'at': 2},
      'secret': {'options': ['rock', 'paper'], 'choice': 'sealed-value', 'at': 3},
    }}));
    Future<Object?> reveal(String turn, String player) => play.event(version,
      jsonEncode({'kind': 'reveal', 'data': {'turn': turn, 'playerChoice': player}}));
    await reveal('second', 'paper');
    await reveal('first', 'rock');
    final revealed = await play.read();
    final turns = revealed['turns'] as Map;
    expect(turns['second']['reveal_order'], 1);
    expect(turns['first']['reveal_order'], 2);
    turns['first']['revealed_at'] = 100;
    turns['second']['revealed_at'] = 100;
    await db.setSetting(play.stateKey, jsonEncode({...revealed,
      'turns': turns, 'saved_at': 99}));
    expect(await reveal('second', 'rock'), {'choice': 'rock', 'playerChoice': 'paper'});

    final snapshot = await play.captureSnapshot();
    expect(snapshot.data['latest_revealed']['turn_id'], 'first');
    expect((snapshot.data['recent_revealed'] as List).map((t) => t['turn_id']),
      ['second', 'first']);
    expect(snapshot.data['public_state_may_lag'], isTrue);
    expect(snapshot.data['revealed_total'], 2);
    expect(jsonEncode(snapshot.data), isNot(contains('sealed-value')));
  });
  test('legacy reveals use reveal time with choice-time fallback and stable ties', () async {
    final state = await play.read();
    await db.setSetting(play.stateKey, jsonEncode({...state, 'turns': {
      'first': {'choice': 'paper', 'playerChoice': 'rock', 'at': 1, 'revealed_at': 40},
      'second': {'choice': 'paper', 'playerChoice': 'rock', 'at': 2, 'revealed_at': 30},
      'older': {'choice': 'paper', 'playerChoice': 'rock', 'at': 20},
      'tied': {'choice': 'paper', 'playerChoice': 'rock', 'at': 20},
    }}));
    final snapshot = await play.captureSnapshot();
    expect((snapshot.data['recent_revealed'] as List).map((t) => t['turn_id']),
      ['older', 'tied', 'second', 'first']);
    expect(snapshot.data['latest_revealed']['turn_id'], 'first');
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
    await Future.wait([
      play.event(version,jsonEncode({'kind':'describe','data':{'kind':'static','content':'树下有一封可展开的信',
        'effects':'雪花缓慢落下，点击点亮星星','resettable':false}})),
      play.event(version,jsonEncode({'kind':'save','data':{'star_lit':true}})),
    ]);
    await db.setSetting('creative_focus_v1',jsonEncode({'id':id,'at':1}));
    final snapshot=await play.captureSnapshot(observation:{'text':'圣诞快乐','animations':[{'name':'snowfall','duration':'8s'}]});
    await send('card',snapshot);
    final detail=await CreativePlay.chatContext(db,userMessageId:'card');
    expect(detail,contains('雪花缓慢落下'));
    expect(detail,contains('snowfall'));
    expect(detail,contains('"star_lit":true'));
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
    // Valid saved state near the public-data limit, larger than the snapshot projection.
    await save({'history':List.generate(20,(i)=>{'n':i,'text':'长'*500}),'points':50});
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
