import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async => db=await AppDatabase.createForTesting(databaseFactoryFfi));
  tearDown(() async => db.closeForTesting());

  Future<void> seed(String id,String source,{String text='旧游戏结果',String topic='cedar_game:garden',double strength=.9}) =>
    db.upsertThought(id:id,text:text,drive:DriveKey.curiosity,kind:'fixation',strength:strength,
      source:source,topicKey:topic,actionCount:1,lastActedAt:DateTime(2026,10,10),bornAt:DateTime(2026,10,10));
  Future<bool> feed({String topic='cedar_game:garden',String text='今天聊到的新疑问',String continuity='revised'}) =>
    db.applyPostTurnThoughtEvidenceAtomic(sourceMessageId:'current-assistant',evidenceKey:'one-real-evidence',
      text:text,drive:DriveKey.curiosity,incomingStrength:.5,topicKey:topic,continuity:continuity);

  for(final source in ['mcp/cedar_game:garden:play-1791590400000000','public_web_candidate:one','mcp/other:result']) {
    test('ordinary topic evidence preserves immutable source $source',() async {
      await seed('outcome',source);
      final sql=await db.database;
      final before=(await sql.query('thoughts',where:'id = ?',whereArgs:['outcome'])).single;
      expect(await feed(),isTrue);
      final rows=await sql.query('thoughts');expect(rows,hasLength(2));
      expect(rows.singleWhere((r)=>r['id']=='outcome'),before);
      final fresh=rows.singleWhere((r)=>r['id']!='outcome');
      expect(fresh['source'],'conversation_turn:current-assistant');
      expect(fresh['action_count'],0);expect(fresh['last_acted_at'],isNull);
      expect(await feed(),isTrue);expect(await sql.query('thoughts'),hasLength(2));
      expect(await sql.query('thought_lifecycle_events'),hasLength(1));
    });
  }
  test('exact text fallback cannot revise an external result either',() async {
    await seed('external','mcp/cedar_game:one',topic:'',text:'重复正文');
    expect(await feed(topic:'',text:'重复正文'),isTrue);
    expect(await (await db.database).query('thoughts'),hasLength(2));
  });
  test('resolved ordinary topic never settles an immutable game result',() async {
    await seed('external','mcp/cedar_game:one');
    expect(await feed(continuity:'resolved'),isTrue);
    final rows=await (await db.database).query('thoughts');
    expect(rows,hasLength(1));expect(rows.single['lifecycle_state'],'active');
    expect(rows.single['text'],'旧游戏结果');
  });
  test('ordinary conversation evidence still updates its existing topic',() async {
    await seed('ordinary','conversation_turn:earlier');
    expect(await feed(),isTrue);
    final rows=await (await db.database).query('thoughts');expect(rows,hasLength(1));
    expect(rows.single['id'],'ordinary');expect(rows.single['text'],'今天聊到的新疑问');
  });
  test('external rows are excluded before the eight item context cap',() async {
    for(var n=0;n<20;n++)await seed('game-$n','mcp/cedar_game:$n');
    await seed('ordinary','conversation_turn:earlier',strength:.3);
    expect((await db.postTurnThoughtCandidates(limit:8)).map((t)=>t.id),['ordinary']);
    expect(await db.activeThoughts(limit:8),hasLength(8),reason:'ordinary pool/readiness is unchanged');
  });
  test('transfer lock still prevents ordinary evidence writes',() async {
    await db.setSetting('transfer_lock','1');expect(await feed(),isFalse);
    expect(await (await db.database).query('thoughts'),isEmpty);
  });
}
