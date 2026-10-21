import 'dart:convert';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_registry.dart';
import 'package:ai_companion_localfirst/core/agent/semantic_tool_route.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/conversation_history_catalog.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/database/derived_source_store.dart';
import 'package:ai_companion_localfirst/core/history/conversation_history_reader.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String,dynamic> payload(AgentToolResult r) {
  final start = r.promptData.indexOf('{');
  if (start < 0) return {};
  // Directory results append instructions after the JSON. Decode the one line.
  return Map<String,dynamic>.from(jsonDecode(r.promptData.substring(start).split('\n').first) as Map);
}
List<Map<String,dynamic>> entries(AgentToolResult r) =>
  (payload(r)['entries'] as List? ?? []).map((x)=>Map<String,dynamic>.from(x as Map)).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late ConversationHistoryReader reader;
  final old = DateTime.utc(2025,1,2,4);
  setUp(() async {
    db = await AppDatabase.createForTesting(databaseFactoryFfi);
    reader = ConversationHistoryReader(db);
  });
  tearDown(() async {await db.closeForTesting();});
  Future<void> message(String id,String text,{DateTime? at,String role='user',
      bool roleplay=false,String reasoning=''}) => db.insertMessage(ChatMessage(
    id:id,role:role,content:text,createdAt:at??old,reasoningContent:reasoning,
    worldBookContextJson:roleplay ? const WorldBookTurnContext(roleplaySessionId:'fiction').encode() : ''));
  Future<void> memory(String id,String source) async {
    await (await db.database).insert('memory_items',{
      'id':id,'kind':'shared_experience','content':'曾经讨论蓝色贝壳',
      'importance':.8,'confidence':.8,'source':'conversation_turn:' + source,
      'source_user_message_id':source,'semantic_type':'shared_experience',
      'created_at':old.millisecondsSinceEpoch,'updated_at':old.millisecondsSinceEpoch,
    });
  }

  test('old raw detail absent from memories is searchable beyond recent caps and backfills locally',() async {
    await message('old-detail','蓝色贝壳的编号是K-735，摘要从未记录这个编号。');
    final sql = await db.database;
    final batch = sql.batch();
    for (var i=0;i<520;i++) {
      batch.insert('messages',ChatMessage(id:'new' + i.toString(),role:'user',
        content:'不相关的花盆',createdAt:old.add(Duration(days:1,minutes:i))).toDb());
    }
    await batch.commit(noResult:true);
    await sql.delete(ConversationHistoryCatalog.table);
    await db.setSetting(ConversationHistoryCatalog.readyKey,'');
    final found = await reader.search({'query':'K-735'});
    expect(found.status,AgentToolStatus.succeeded);
    expect(entries(found).single['source_id'],'old-detail');
    final read = await reader.read({'handle':entries(found).single['handle'] as String});
    expect(read.promptData,contains('K-735'));
    expect(await sql.query('memory_items'),isEmpty);
    expect(await sql.query(ConversationHistoryCatalog.table),hasLength(521));
  });

  test('literal SQL wildcard characters cannot broaden an original-text query',() async {
    await message('literal','sea_shell%proof');
    await message('other','seaxshellxproof',at:old.add(const Duration(seconds:1)));
    final found = await reader.search({'query':'sea_shell%proof'});
    expect(entries(found).map((e)=>e['source_id']),['literal']);
  });

  test('long original text is losslessly paged with bounded native arguments and no reasoning leakage',() async {
    final text = List.filled(3500,'蓝鲸🐳').join() + '最后一句也要保留';
    await message('long',text,reasoning:'PRIVATE_REASONING_DO_NOT_RETURN');
    var result = await reader.read({'source_id':'long'});
    final all = StringBuffer();
    var pages=0;
    while (true) {
      expect(result.status,AgentToolStatus.succeeded);
      expect(result.promptData,contains('历史资料'));
      expect(result.promptData,isNot(contains('PRIVATE_REASONING_DO_NOT_RETURN')));
      final data = payload(result);
      final part = data['text'] as String;
      expect(part.length,lessThanOrEqualTo(ConversationHistoryReader.pageSize));
      expect(utf8.decode(utf8.encode(part)),part);
      all.write(part);pages++;
      final cursor = data['next_cursor'] as String;
      if (cursor.isEmpty) {expect(data['complete'],true);break;}
      expect(cursor.length,lessThanOrEqualTo(500));
      expect(data['complete'],false);
      result = await reader.read({'cursor':cursor});
      expect(pages,lessThan(10));
    }
    expect(pages,greaterThan(2));
    expect(all.toString(),endsWith(text));
    expect(await (await db.database).query('memory_items'),isEmpty);
    expect(await (await db.database).query('memory_evidence'),isEmpty);
  });

  test('exact date constraints survive directory handle and original pagination',() async {
    await message('yesterday','贝壳昨天的原话');
    await message('today','贝壳今天的原话',at:old.add(const Duration(days:1)));
    final found = await reader.search({'query':'贝壳',
      'date_from':DateTime.utc(2025,1,2).toIso8601String(),
      'date_to':DateTime.utc(2025,1,3).toIso8601String()});
    expect(entries(found).single['source_id'],'yesterday');
    final result = await reader.read({'handle':entries(found).single['handle'] as String});
    expect(result.promptData,contains('昨天的原话'));
    expect(result.promptData,isNot(contains('今天的原话')));
    expect((await reader.search({'date_from':'broken'})).status,AgentToolStatus.noResult);
  });

  test('changed source or neighbouring context invalidates old handles and cursors',() async {
    await message('anchor',List.filled(8000,'长').join());
    await message('neighbor','原始前后文',at:old.add(const Duration(seconds:1)));
    final found = await reader.search({'query':'长'});
    final handle = entries(found).first['handle'] as String;
    final first = payload(await reader.read({'handle':handle}));
    await (await db.database).update('messages',{'content':'前后文已经被改写'},
      where:'id = ?',whereArgs:['neighbor']);
    expect((await reader.read({'cursor':first['next_cursor'] as String})).status,AgentToolStatus.noResult);
    expect((await reader.read({'handle':handle})).status,AgentToolStatus.noResult);
    final current = await reader.read({'source_id':'anchor'});
    expect(current.status,AgentToolStatus.succeeded);
    await (await db.database).delete('messages',where:'id = ?',whereArgs:['anchor']);
    expect((await reader.read({'source_id':'anchor'})).status,AgentToolStatus.noResult);
    expect(await (await db.database).query(ConversationHistoryCatalog.table,
      where:'message_id = ?',whereArgs:['anchor']),isEmpty);
  });

  test('fiction and unresolved sources do not escape through raw directory queries',() async {
    await message('fiction','隐藏的剧情关键词',roleplay:true);
    expect(entries(await reader.search({'query':'剧情关键词'})),isEmpty);
    expect((await reader.read({'source_id':'fiction'})).status,AgentToolStatus.noResult);
    await message('valid','真实的历史');
    final found = entries(await reader.search({'query':'真实的历史'})).single;
    await (await db.database).update('messages',{
      'worldbook_context_json':const WorldBookTurnContext(roleplaySessionId:'later').encode()},
      where:'id = ?',whereArgs:['valid']);
    expect((await reader.read({'handle':found['handle'] as String})).status,AgentToolStatus.noResult);
  });

  test('directory pages can advance through excluded material rather than losing old matches',() async {
    await message('old-valid','原始线索');
    final sql=await db.database;
    final batch=sql.batch();
    for(var i=0;i<265;i++) {
      batch.insert('messages',ChatMessage(id:'fiction' + i.toString(),role:'user',
        content:'原始线索',createdAt:old.add(Duration(minutes:i+1)),
        worldBookContextJson:const WorldBookTurnContext(roleplaySessionId:'fiction').encode()).toDb());
    }
    await batch.commit(noResult:true);
    var result=await reader.search({'query':'原始线索'});
    expect(entries(result),isEmpty);
    expect(payload(result)['next_cursor'],isNotEmpty);
    result=await reader.search({'query':'原始线索','cursor':payload(result)['next_cursor'] as String});
    expect(entries(result).single['source_id'],'old-valid');
  });

  test('old epoch and changed search conditions reject handles without leaking originals',() async {
    for(var i=0;i<20;i++) {
      await message('m' + i.toString(),'过去的贝壳',at:old.add(Duration(minutes:i)));
    }
    final found=await reader.search({'query':'贝壳'});
    final h=entries(found).first['handle'] as String;
    final cursor=payload(found)['next_cursor'] as String;
    expect(cursor,isNotEmpty);
    expect((await reader.search({'query':'花盆','cursor':cursor})).status,AgentToolStatus.noResult);
    await db.setSetting('runtime_state_epoch_v1','after-restore');
    expect((await reader.read({'handle':h})).status,AgentToolStatus.noResult);
    expect((await reader.search({'query':'贝壳','cursor':cursor})).status,AgentToolStatus.noResult);
    expect((await reader.read({})).status,AgentToolStatus.noResult);
    expect((await reader.read({'cursor':'not-base64'})).status,AgentToolStatus.noResult);
  });

  test('memory-linked evidence dates are filtered before a candidate cap',() async {
    await message('origin','老贝壳的具体细节');
    await memory('remembered','origin');
    final sql=await db.database;
    for(var i=0;i<140;i++) {
      final id='support' + i.toString();
      await message(id,'后来又谈过贝壳',at:old.add(Duration(days:i+1)));
    }
    for(final row in await sql.query('messages')) {
      final id=row['id'] as String;
      final source=(await ConversationSourceStore.captureMessage(sql,id))!;
      final evidence='e-' + id;
      await sql.insert('memory_evidence',{'id':evidence,'memory_id':'remembered',
        'source':'conversation_turn:' + id,'evidence_text':'这次确实说过',
        'observed_at':row['created_at']});
      await DerivedSourceStore.link(sql,kind:'memory_evidence',ownerId:evidence,
        sourceId:id,revision:source.revision,hash:source.contentHash,role:'user_basis');
    }
    final found=await reader.search({'memory_id':'remembered',
      'date_from':DateTime.utc(2025,1,2).toIso8601String(),
      'date_to':DateTime.utc(2025,1,3).toIso8601String()});
    expect(entries(found).single['source_id'],'origin');
    var page=await reader.search({'memory_id':'remembered'});
    expect(entries(page),hasLength(6));
    final cursor=payload(page)['next_cursor'] as String;
    expect(cursor,isNotEmpty);
    final firstIds=entries(page).map((e)=>e['source_id']).toSet();
    page=await reader.search({'memory_id':'remembered','cursor':cursor});
    expect(entries(page),isNotEmpty);
    expect(entries(page).every((e)=>!firstIds.contains(e['source_id'])),true);
  });

  test('a stage summary reads its exact manifest and rejects rewritten source versions',() async {
    await message('summary-user','原始讨论的起点');
    await message('summary-ai','原始讨论的回答',role:'assistant',at:old.add(const Duration(seconds:1)));
    final sql=await db.database;
    final user=(await ConversationSourceStore.qualifyMessage(sql,'summary-user'))!;
    final assistant=(await ConversationSourceStore.qualifyMessage(sql,'summary-ai'))!;
    await sql.insert('conversation_summaries',{'id':'summary','summary':'关于贝壳的阶段总结',
      'from_at':old.millisecondsSinceEpoch,'to_at':old.add(const Duration(seconds:1)).millisecondsSinceEpoch,
      'created_at':old.millisecondsSinceEpoch,'key_points':'贝壳',
      'source_manifest_json':jsonEncode([user.toJson(),assistant.toJson()])});
    final found=await reader.search({'query':'阶段总结'});
    final entry=entries(found).single;
    expect(entry['kind'],'summary');
    final text=await reader.read({'handle':entry['handle'] as String});
    expect(text.promptData,contains('原始讨论的起点'));
    expect(text.promptData,contains('原始讨论的回答'));
    await sql.update('messages',{'content':'重生成后的新回答'},where:'id = ?',whereArgs:['summary-ai']);
    expect((await reader.read({'handle':entry['handle'] as String})).status,AgentToolStatus.noResult);
  });

  test('legacy range-only summaries do not invent exact original associations',() async {
    await message('plain','确实保存的原话');
    await (await db.database).insert('conversation_summaries',{'id':'legacy','summary':'古老摘要的独有关键词',
      'from_at':old.millisecondsSinceEpoch,'to_at':old.millisecondsSinceEpoch,
      'created_at':old.millisecondsSinceEpoch,'key_points':''});
    expect(entries(await reader.search({'query':'古老摘要的独有关键词'})),isEmpty);
    expect((await reader.read({'source_id':'plain'})).status,AgentToolStatus.succeeded);
  });

  test('new exports include a complete Unicode-safe directory before first lookup and preserve it on restore',() async {
    final content=List.filled(130,'🐳').join();
    await message('unicode',content);
    final sql=await db.database;
    await sql.delete(ConversationHistoryCatalog.table);
    await db.setSetting(ConversationHistoryCatalog.readyKey,'');
    final backup=Map<String,dynamic>.from(await db.exportAll());
    final tables=Map<String,dynamic>.from(backup['tables'] as Map);
    expect(backup[ConversationHistoryCatalog.versionKey],1);
    final catalog=tables[ConversationHistoryCatalog.table] as List;
    expect(catalog,hasLength(1));
    expect((catalog.single as Map)['preview'],List.filled(96,'🐳').join());
    final target=await AppDatabase.createForTesting(databaseFactoryFfi);
    try {
      await target.importAll(backup);
      await target.setSetting('active_brain','1');
      await target.setSetting('transfer_lock','0');
      final exported=await target.exportAll();
      expect((exported['tables'] as Map)[ConversationHistoryCatalog.table],catalog);
      expect((await ConversationHistoryReader(target).read({'source_id':'unicode'})).promptData,contains(content));
    } finally {await target.closeForTesting();}
  });

  test('legacy backups rebuild catalog from originals and never retain a foreign directory',() async {
    await message('kept','旧存档的真实细节');
    final backup=jsonDecode(jsonEncode(await db.exportAll())) as Map<String,dynamic>;
    backup.remove(ConversationHistoryCatalog.versionKey);
    (backup['tables'] as Map).remove(ConversationHistoryCatalog.table);
    ((backup['tables'] as Map)['settings'] as List).removeWhere((r)=>r['key']==ConversationHistoryCatalog.readyKey);
    await message('foreign','目标安装原有内容',at:old.add(const Duration(days:1)));
    await db.importAll(backup);
    final rows=await (await db.database).query(ConversationHistoryCatalog.table);
    expect(rows.map((r)=>r['message_id']),['kept']);
    expect((await reader.search({'query':'真实细节'})).status,AgentToolStatus.succeeded);
    expect(entries(await reader.search({'query':'目标安装'})),isEmpty);
  });

  for(final corruption in ['missing','incomplete','wrong_preview']) {
    test('declared $corruption directory is rejected before replacing local state',() async {
      await message('sentinel','不能被坏存档覆盖');
      final backup=jsonDecode(jsonEncode(await db.exportAll())) as Map<String,dynamic>;
      final tables=backup['tables'] as Map;
      if(corruption=='missing') tables.remove(ConversationHistoryCatalog.table);
      if(corruption=='incomplete') tables[ConversationHistoryCatalog.table]=[];
      if(corruption=='wrong_preview') (tables[ConversationHistoryCatalog.table] as List).single['preview']='伪造';
      await expectLater(db.importAll(backup),throwsFormatException);
      expect((await db.messageById('sentinel'))!.content,'不能被坏存档覆盖');
    });
  }

  test('existing memory route exposes read-only history tools while casual chat remains light',() {
    final route=const SemanticToolRoute(kind:'memory',available:true);
    expect(route.toolIds,containsAll(['chat_history.search','chat_history.read']));
    final defs=AgentToolPlanner.nativeToolDefinitionsFor('核对过去说过什么',
      semanticReadAuthoritative:true,semanticToolIds:route.toolIds);
    final names=defs.map((d)=>(d['function'] as Map)['name']).toSet();
    expect(names,containsAll(['chat_history_search','chat_history_read']));
    expect(AgentToolPlanner.nativeToolDefinitionsFor('今天好累',
      semanticReadAuthoritative:true,semanticToolIds:const {}),isEmpty);
    for(final id in ['chat_history.search','chat_history.read']) {
      final tool=AgentToolRegistry.byId(id)!;
      expect(tool.risk,AgentToolRisk.readOnly);
      expect(tool.autonomousAvailable,false);
    }
  });

  test('cancelled searches and reads stop without learning writes',() async {
    await message('source','贝壳细节');
    final token=GenerationCancellationToken()..cancel();
    await expectLater(reader.search({'query':'贝壳'},cancellation:token),
      throwsA(isA<GenerationCancelledByUserException>()));
    await expectLater(reader.read({'source_id':'source'},cancellation:token),
      throwsA(isA<GenerationCancelledByUserException>()));
    expect(await (await db.database).query('memory_items'),isEmpty);
  });
}
