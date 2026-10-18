import 'dart:convert';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/natural_chat_migration.dart';
import 'package:ai_companion_localfirst/core/database/brain_work_fence.dart';
import 'package:ai_companion_localfirst/core/history/room_history_reader.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_repository.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_models.dart';
import 'package:ai_companion_localfirst/core/immersive/immersive_room_repository.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_natural_chat_v042115.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;
  setUp(() async {db=await AppDatabase.createForTesting(databaseFactoryFfi);
    await migrateNaturalChatV042115(await db.database);});
  tearDown(()async{await db.closeForTesting();});
  Future<ModelDialogueRoom> seed({String title='花园讨论',List<String> texts=const ['留一个空盆','我觉得应该多种花'],bool ended=true}) async {
    final repo=ModelDialogueRepository(db);
    final r=await repo.create(title:title,topic:'花园',participants:const {});
    await db.setSetting('${ModelDialogueRepository.roomPrefix}${r.id}',jsonEncode({...r.data,'status':ended?'ended':'paused','ended_at':1000}));
    for(var i=0;i<texts.length;i++) {
      final m=ModelDialogueMessage(id:'m$i',roomId:r.id,sequence:i,speaker:i.isEven?'deepseek':'gemini',text:texts[i],model:'test',createdAt:1000+i);
      await db.setSetting('${ModelDialogueRepository.messagePrefix}${r.id}:${i.toString().padLeft(10,'0')}',jsonEncode(m.toJson()));
    }
    return r;
  }
  String handle(AgentToolResult result)=>RegExp(r'handle=([^\n]+)').firstMatch(result.promptData)!.group(1)!;
  Map<String,dynamic> body(AgentToolResult result)=>jsonDecode(result.promptData.split('\n').last) as Map<String,dynamic>;

  test('approved natural chat is installed enabled once and remains user editable/deletable',()async{
    final sql=await db.database;
    var rows=await sql.query('reference_documents',where:'name = ?',whereArgs:['对话活人感']);
    expect(rows.length,1);expect(rows.single['enabled'],1);expect(rows.single['activation_mode'],'always');
    expect(rows.single['raw_content'],worldBookNaturalChatV042115);
    await sql.update('reference_documents',{'raw_content':'我的编辑','enabled':0},where:'id = ?',whereArgs:[rows.single['id']]);
    await migrateNaturalChatV042115(sql);
    rows=await sql.query('reference_documents',where:'name = ?',whereArgs:['对话活人感']);
    expect(rows.single['raw_content'],'我的编辑');expect(rows.single['enabled'],0);
    await sql.delete('reference_documents',where:'name = ?',whereArgs:['对话活人感']);
    await migrateNaturalChatV042115(sql);
    expect(await sql.query('reference_documents',where:'name = ?',whereArgs:['对话活人感']),isEmpty);
  });
  test('upgrading preserves a separately edited imported world book',()async{
    final sql=await db.database;
    await sql.delete('settings',where:'key = ?',whereArgs:['worldbook_natural_chat_v042115_applied']);
    await sql.update('reference_documents',{'raw_content':'用户新版本','enabled':0},where:'name = ?',whereArgs:['对话活人感']);
    await migrateNaturalChatV042115(sql);
    final rows=await sql.query('reference_documents',where:'name = ?',whereArgs:['对话活人感']);
    expect(rows.length,1);expect(rows.single['raw_content'],'用户新版本');expect(rows.single['enabled'],0);
  });
  test('recall requests route locally while ordinary and feature discussions have no tool schema',(){
    expect(AgentToolPlanner.routeLocally('上次模型对谈具体说了什么？')!.calls.single.toolId,'room_history.read');
    expect(AgentToolPlanner.routeLocally('Gemini当时为什么不同意？')!.calls.single.arguments['kind'],'model_dialogue');
    for(final text in ['今天好累','我要创建模型对谈房间','模型对谈的功能应该怎么设计？','不要查看沉浸房间记录','如果回看模型对谈会怎样']) {
      expect(AgentToolPlanner.routeLocally(text),isNull,reason:text);
      expect(AgentToolPlanner.nativeToolDefinitionsFor(text),isEmpty,reason:text);
    }
    final tools=AgentToolPlanner.nativeToolDefinitionsFor('上次模型对谈说了什么？');
    expect(tools.length,2);
  });
  test('old ended rooms without archived memories are readable and attribution is retained',()async{
    final r=await seed();final sql=await db.database;
    final before=jsonEncode(await sql.query('memory_items'));
    final result=await RoomHistoryReader(db).read({'kind':'model_dialogue','view':'transcript'});
    expect(result.status,AgentToolStatus.succeeded);
    expect(result.promptData,contains('DeepSeek'));expect(result.promptData,contains('Gemini'));expect(result.promptData,contains('留一个空盆'));
    expect(jsonEncode(await sql.query('memory_items')),before);
    expect(handle(result),isNotEmpty);expect(r.id,isNotEmpty);
  });
  test('search finds original content absent from the room summary',()async{
    await seed(texts:['晚上的流星雨真漂亮']);
    final result=await RoomHistoryReader(db).search({'query':'流星雨'});
    expect(result.status,AgentToolStatus.succeeded);expect(result.resultCount,1);
    expect((await RoomHistoryReader(db).search({'query':'不存在的内容'})).status,AgentToolStatus.noResult);
  });
  test('active and deleted rooms are not exposed and stale handles fail',()async{
    final r=await seed();final reader=RoomHistoryReader(db);
    final h=handle(await reader.read({'kind':'model_dialogue'}));
    await ModelDialogueRepository(db).delete(r.id);
    expect((await reader.read({'handle':h})).status,AgentToolStatus.noResult);
    await seed(ended:false);
    expect((await reader.search({})).status,AgentToolStatus.noResult);
  });
  test('long transcript pagination covers every character exactly once',()async{
    await seed(texts:List.generate(5,(i)=>'$i${'字'*4100}'));
    final reader=RoomHistoryReader(db);var result=await reader.read({'kind':'model_dialogue','view':'transcript'});
    var b=body(result);var end=0;var total=0;final h=handle(result);
    for(var i=0;i<10;i++) {
      expect(b['start'],end);expect((b['start_message'] as Map)['speaker'],isNotEmpty);
      expect((b['text'] as String).length,lessThanOrEqualTo(6500));
      total+=(b['text'] as String).length;end=b['end'] as int;
      if(b['more']==false)break;
      result=await reader.read({'handle':h,'view':'transcript','cursor':b['next_cursor'] as String});b=body(result);
    }
    expect(total,b['total_characters']);expect(b['more'],false);
  });
  test('keyword lookup includes neighboring attribution and missing keyword has no invented evidence',()async{
    await seed(texts:['开头','留空盆有道理','但是我不同意，因为还可以种薄荷','结尾']);
    final reader=RoomHistoryReader(db);final r=await reader.read({'kind':'model_dialogue','view':'transcript','query':'不同意'});
    expect(r.promptData,contains('留空盆'));expect(r.promptData,contains('Gemini'));expect(r.promptData,contains('DeepSeek'));
    expect((await reader.read({'kind':'model_dialogue','view':'transcript','query':'不存在'})).status,AgentToolStatus.noResult);
  });
  test('restore identity invalidates handles and cursors',()async{
    await seed(texts:['字'*10000]);final reader=RoomHistoryReader(db);
    final r=await reader.read({'kind':'model_dialogue','view':'transcript'});final h=handle(r);final c=body(r)['next_cursor'] as String;
    await db.setSetting('runtime_state_epoch_v1','new-runtime');
    expect((await reader.read({'handle':h})).status,AgentToolStatus.noResult);
    expect((await reader.read({'kind':'model_dialogue','view':'transcript','cursor':c})).status,AgentToolStatus.noResult);
  });
  test('details progressively cover long rooms, cache results and do not write memories',()async{
    await seed(texts:['字'*20000]);var calls=0;
    final reader=RoomHistoryReader(db,generateDetail:(r,old,source,cancelled)async{expect(source,contains('本批起点消息：'));expect(source,contains('DeepSeek'));calls++;return '$old 第$calls批已整理';});
    final before=jsonEncode(await (await db.database).query('memory_items'));
    var r=await reader.read({'kind':'model_dialogue','view':'detail'});expect(body(r)['complete'],false);
    final cursor=body(r)['next_cursor'] as String;expect(cursor,isNotEmpty);
    r=await reader.read({'kind':'model_dialogue','view':'detail','cursor':cursor});expect(body(r)['complete'],true);
    await reader.read({'kind':'model_dialogue','view':'detail'});expect(calls,2);
    expect(jsonEncode(await (await db.database).query('memory_items')),before);
  });
  test('deletion while detailed summary is generating rejects late writes and results',()async{
    final room=await seed();final reader=RoomHistoryReader(db,generateDetail:(r,old,source,cancelled)async{
      await ModelDialogueRepository(db).delete(room.id);return '不得写入';
    });
    await expectLater(reader.read({'kind':'model_dialogue','view':'detail'}),throwsA(isA<BrainWorkInvalidated>()));
    expect(await db.getSetting('${RoomHistoryReader.cachePrefix}model_dialogue:${room.id}'),isNull);
  });
  test('restore during detail generation rejects its late cache and result',()async{
    final room=await seed();final reader=RoomHistoryReader(db,generateDetail:(r,old,source,cancelled)async{
      await db.setSetting('runtime_state_epoch_v1','restored-runtime');return '旧运行结果';
    });
    await expectLater(reader.read({'kind':'model_dialogue','view':'detail'}),throwsA(isA<BrainWorkInvalidated>()));
    expect(await db.getSetting('${RoomHistoryReader.cachePrefix}model_dialogue:${room.id}'),isNull);
  });
  test('cancelled detail generation never writes the cache',()async{
    final room=await seed();final token=GenerationCancellationToken();
    final reader=RoomHistoryReader(db,generateDetail:(r,old,source,cancelled)async{token.cancel();return '取消后的文字';});
    await expectLater(reader.read({'kind':'model_dialogue','view':'detail'},cancellation:token),throwsA(isA<GenerationCancelledByUserException>()));
    expect(await db.getSetting('${RoomHistoryReader.cachePrefix}model_dialogue:${room.id}'),isNull);
  });
  test('immersive original text keeps fiction and historical form context; delete removes detail cache',()async{
    final repo=ImmersiveRoomRepository(db);final room=await repo.createRoom(title:'海边约定',openingScene:'海边',inheritCurrentChat:false);
    final sql=await db.database;
    await sql.insert('immersive_messages',{'id':'im1','room_id':room.id,'role':'user','content':'我们明天再看海','reasoning_content':'','created_at':1000,'form_context_json':'{"form":"q"}'});
    await repo.endRoomLocally(room.id);
    final reader=RoomHistoryReader(db,generateDetail:(r,old,source,cancelled)async=>'海边约定');
    final result=await reader.read({'kind':'immersive','view':'transcript'});
    expect(result.promptData,contains('小豆丁'));expect(result.promptData,contains('虚构'));expect(result.promptData,contains('我们明天再看海'));
    await reader.read({'kind':'immersive','view':'detail'});
    expect(await db.getSetting('${RoomHistoryReader.cachePrefix}immersive:${room.id}'),isNotNull);
    await repo.deleteRoom(room.id);
    expect(await db.getSetting('${RoomHistoryReader.cachePrefix}immersive:${room.id}'),isNull);
  });
}
