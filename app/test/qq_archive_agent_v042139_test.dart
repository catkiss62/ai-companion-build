import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_planner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_registry.dart';
import 'package:ai_companion_localfirst/core/agent/agent_tool_runner.dart';
import 'package:ai_companion_localfirst/core/agent/agent_progress_tracker.dart';
import 'package:ai_companion_localfirst/core/agent/agent_task_loop.dart';
import 'package:ai_companion_localfirst/core/agent/semantic_tool_route.dart';
import 'package:ai_companion_localfirst/core/ai/prompt_builder.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/qq_context_evidence.dart';
import 'package:ai_companion_localfirst/core/database/conversation_source_store.dart';
import 'package:ai_companion_localfirst/core/memory/memory_brain.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_archive_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_history_catalog.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_history_reader.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_display_names.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_message_text.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_readonly_context.dart';
import 'package:ai_companion_localfirst/integrations/qq_private/qq_store.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;late QqStore store;late AgentToolRunner runner;
  const scope='fixture-qq-scope',name='松林闲聊群';
  const question='你能看到松林闲聊群这个群吗？能看到刚才聊天的内容吗';
  String cid(String target)=>QqStore.conversationId(scope,'group',target);
  setUp(()async{
    FlutterSecureStorage.setMockInitialValues({});db=await AppDatabase.createForTesting(databaseFactoryFfi);store=QqStore(db);
    await db.ensureStateLineageId();
    for(final key in ['post_turn_queue_enabled','daily_continuity_enabled','memory_fading_enabled','memory_consolidation_enabled',
      'relationship_continuity_enabled','personality_learning_enabled','auto_memory']) {await db.setSetting(key,'0');}
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ai_companion/system'),(_)async=>null);
    runner=AgentToolRunner(db:db,android:AndroidBridge.instance);
  });
  tearDown(()async{
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('ai_companion/system'),null);
    await db.closeForTesting();
  });
  Future<int> append(String id,String text,{String target='a',String kind='group',String source=scope,int images=0,int? at})async{
    final time=at??DateTime.now().subtract(const Duration(hours:3)).millisecondsSinceEpoch;
    return (await store.append(fence:await store.capture(),scope:source,kind:kind,target:target,platformId:id,
      sender:kind=='private'?'owner':'peer',owner:kind=='private',text:text,observedAt:time,receivedAt:time,images:images))!;
  }
  Future<void> seed({String target='a',String label=name,String text='今天约好种一盆铃兰'})async{
    await append('message-$target',text,target:target);
    await (await db.database).transaction((txn)=>QqDisplayNames.write(txn,scope,group:target,name:label));
  }
  Future<AgentToolResult> tool(String id,Map<String,String> args,{String latest=question})async=>
    (await runner.runPlan(AgentToolPlan(calls:[AgentToolCall(toolId:id,arguments:args,reasonTag:'explicit_request')]),latestUserText:latest)).single;
  Map metadata(String text)=>jsonDecode(text.split('\n').first) as Map;

  test('explicit named QQ request survives an incorrect room classifier',(){
    final plan=AgentToolPlanner.routeForTurn(question,const SemanticToolRoute(kind:'room',available:true,targetUncertain:true));
    expect(plan!.calls.single.toolId,'qq_history.search');
    final defs=AgentToolPlanner.nativeToolDefinitionsFor(question,semanticReadAuthoritative:true,semanticToolIds:{'room_history.search'});
    expect(defs.map((d)=>(d['function'] as Map)['name']),contains('qq_history_read'));
    expect(AgentToolRegistry.qqHistoryRead.autonomousAvailable,false);
  });
  test('ordinary chat, feature design and negated QQ requests do not force archive reads',(){
    for(final text in ['讲个笑话','QQ群今天挺安静','不要查QQ群记录','如何接入QQ群聊天记录这个功能']) {
      expect(QqHistoryCatalog.request(text),false,reason:text);
    }
    expect(AgentToolPlanner.nativeToolDefinitionsFor('讲个笑话'),isEmpty);
  });
  test('current semantic capability directory contains QQ names and a distinct QQ route',()async{
    await seed();final q=await SemanticToolQuestions.load(db);
    expect(q.questions['tool_route']!.options,contains('qq'));
    expect(jsonEncode(q.context),contains(name));
    expect(q.interpret({'tool_route':'qq','tool_scope':'single'}).toolIds,containsAll(['qq_history.search','qq_history.read']));
  });
  test('production Agent lookup identifies the named group and returns genuine original evidence',()async{
    await seed();await seed(target:'b',label:'另一群',text:'OTHER_GROUP_SECRET');
    final result=await tool('qq_history.search',{'query':question});
    expect(result.succeeded,true);expect(result.resultCount,1);expect(result.goalSatisfied,true);
    expect(result.promptData,contains(name));expect(result.promptData,contains('铃兰'));
    expect(result.promptData,isNot(contains('OTHER_GROUP_SECRET')));expect(await result.qqEvidence!.matches(await db.database),true);
  });
  test('App and owner QQ resolve the same named archive older than the recent window',()async{
    await seed();await seed(target:'b',label:'另一群',text:'OTHER_GROUP_SECRET');
    final app=await MemoryBrain(db).buildContext(question);
    final qq=await QqReadOnlyContext(await db.database).build(question,qqScope:scope,media:true);
    for(final text in [app.qqContext,qq]) {
      expect(text,contains(name));expect(text,contains('铃兰'));expect(text,isNot(contains('OTHER_GROUP_SECRET')));
    }
  });
  test('same-name groups yield a directory and do not pretend to have read either original',()async{
    await seed(text:'FIRST_RAW_SECRET');await seed(target:'b',text:'SECOND_RAW_SECRET');
    final r=await tool('qq_history.search',{'query':question});
    expect(r.goalSatisfied,false);expect(r.resultCount,2);expect(r.promptData,isNot(contains('FIRST_RAW_SECRET')));
    expect(r.promptData,isNot(contains('SECOND_RAW_SECRET')));
    expect(AgentTaskLoopPolicy.verify([r]).state,AgentTaskVerificationState.partiallySupported);
  });
  test('an unknown named group is not substituted with the sole known group',()async{
    await seed();final r=await tool('qq_history.search',{'query':'你能看到不存在的海鸥这个群吗'},latest:'你能看到不存在的海鸥这个群吗');
    expect(r.goalSatisfied,false);expect(r.promptData,isNot(contains('铃兰')));
  });
  test('production read rejects a different group when the user specified a known name',()async{
    await seed();await seed(target:'b',label:'另一群',text:'WRONG_TARGET_SECRET');
    final r=await tool('qq_history.read',{'conversation_id':cid('b')});
    expect(r.succeeded,false);expect(r.promptData,isNot(contains('WRONG_TARGET_SECRET')));
  });
  test('a complete-history request is not satisfied while an earlier long-message cursor remains',(){
    const first=AgentToolResult(toolId:'qq_history.read',status:AgentToolStatus.succeeded,displayText:'局部',promptData:'局部',goalSatisfied:false,
      submittedArguments:{'qq_complete_requested':true,'qq_pending_reads':['c:message:2:100','c:before:2']});
    const older=AgentToolResult(toolId:'qq_history.read',status:AgentToolStatus.succeeded,displayText:'更早页',promptData:'更早页',goalSatisfied:true,
      submittedArguments:{'qq_complete_requested':true,'qq_resolved_reads':['c:before:2']});
    expect(AgentTaskLoopPolicy.verify([first,older]).state,AgentTaskVerificationState.partiallySupported);
    const tail=AgentToolResult(toolId:'qq_history.read',status:AgentToolStatus.succeeded,displayText:'尾部',promptData:'尾部',goalSatisfied:true,
      submittedArguments:{'qq_complete_requested':true,'qq_resolved_reads':['c:message:2:100']});
    expect(AgentTaskLoopPolicy.verify([first,older,tail]).state,AgentTaskVerificationState.supported);
  });
  test('owner projection remains namespace-scoped and private-only requests exclude groups',()async{
    await seed();await append('private','本人私聊资料',kind:'private',target:'owner');
    await append('foreign','FOREIGN_NAMESPACE_SECRET',source:'other-scope');
    final reader=QqHistoryReader(await db.database);
    final private=await reader.search('看看QQ私聊记录',scope:scope);
    expect(private.text,contains('本人私聊资料'));expect(private.text,isNot(contains('铃兰')));
    expect(private.text,isNot(contains('FOREIGN_NAMESPACE_SECRET')));
  });
  test('keyword lookup finds an old original across multiple group archives',()async{
    await seed(text:'很早说过紫色珊瑚');await seed(target:'b',label:'另一群',text:'其他话题');
    for(var n=0;n<25;n++) {await append('later$n','后来的普通聊天$n');}
    final r=await tool('qq_history.search',{'query':'看看群聊原文','keyword':'紫色珊瑚'},latest:'看看群聊里紫色珊瑚那句原文');
    expect(r.succeeded,true);expect(r.promptData,contains('很早说过紫色珊瑚'));expect(r.promptData,isNot(contains('其他话题')));
  });
  test('archive pages have stable sequence cursors without repeats',()async{
    for(var n=0;n<25;n++) {await append('p$n','短消息$n');}
    final reader=QqHistoryReader(await db.database);final first=await reader.read(cid('a'));
    expect(first.count,20);expect(first.more,true);
    final next=metadata(first.text)['next_before_seq'] as int;
    final second=await reader.read(cid('a'),beforeSeq:next);
    expect(second.count,5);expect(second.more,false);
    final a=first.evidence.stamps.map((s)=>s['id']).toSet();
    expect(second.evidence.stamps.any((s)=>a.contains(s['id'])),false);
  });
  test('long older records cannot push the newest message out of group or private projection',()async{
    final now=DateTime.now().millisecondsSinceEpoch;
    for(var n=0;n<3;n++) {await append('long$n','旧内容$n${List.filled(14000,'长').join()}',at:now+n);}
    await append('latest','LATEST_INPUT_SENTINEL',at:now+4);
    final reader=QqArchiveReader(await db.database);final stamps=<Map<String,Object?>>[];
    final group=await reader.groupContext(cid('a'),through:9999,stamp:stamps);
    final private=await reader.privateContext('群里刚刚说什么',scope:scope);
    for(final text in [group,private]) {expect(text,contains('LATEST_INPUT_SENTINEL'));expect(text.length,lessThanOrEqualTo(24000));}
    expect(stamps.where((s)=>s['table']=='qq_archive').length,lessThanOrEqualTo(4));
  });
  test('a long-message fragment can be continued using its real seq and character cursor',()async{
    final seq=await append('long','HEAD ${List.filled(14000,'长').join()} TAIL_SENTINEL');
    final sql=await db.database;final row=(await sql.query('qq_archive',where:'seq=?',whereArgs:[seq])).single;
    final first=jsonDecode(await QqArchiveReader(sql).render(row,maxChars:2000)) as Map;
    expect(first['partial_text'],true);expect(first['next_char_offset'],greaterThan(0));
    final tail=await QqHistoryReader(sql).read(cid('a'),messageSeq:seq,offset:first['next_char_offset'] as int);
    expect(tail.text,contains('TAIL_SENTINEL'));expect(tail.count,1);
  });
  test('summary cursor advances only over the contiguous messages actually supplied',()async{
    await db.setSetting('auto_memory','1');
    for(var n=0;n<20;n++) {await append('summary$n','消息$n${List.filled(14000,'长').join()}');}
    final claim=(await store.claimSummary(await store.capture(),cid('a'),idle:false))!;
    expect(claim.rows.length,lessThan(20));expect(claim.input.length,lessThanOrEqualTo(27500));
    final sql=await db.database;final c=(await sql.query('qq_conversations',where:'id=?',whereArgs:[cid('a')])).single;
    expect(c['summary_checked_seq'],claim.rows.last['seq']);
    final next=(await store.claimSummary(await store.capture(),cid('a'),idle:true))!;
    expect(next.rows.first['seq'],greaterThan(claim.rows.last['seq'] as int));
  });
  test('native QQ emoji projection is readable and does not rewrite canonical text',()async{
    final tag='<faceType=6,faceId="0",ext="${base64Encode(utf8.encode(jsonEncode({'text':'微笑'})))}">';
    final seq=await append('emoji','你好 $tag');final sql=await db.database;
    final row=(await sql.query('qq_archive',where:'seq=?',whereArgs:[seq])).single;
    expect(row['content'],contains('faceType'));expect(QqMessageText.project(row['content'] as String),contains('[QQ表情：微笑]'));
    final visible=await QqArchiveReader(sql).display(row,speaker:'群友');
    expect(visible,contains('微笑'));expect(visible,isNot(contains('ext=')));
    expect(QqMessageText.project('<faceType=6,faceId="0",ext="eyJ0ZXh0IjoiIn0=">'),contains('未提供含义'));
  });
  test('memory search counts QQ originals and does not cache their mutable provenance',()async{
    await seed();final r=await tool('memory.search',{'query':question});
    expect(r.resultCount,greaterThan(0));expect(r.promptData,contains('铃兰'));expect(r.qqEvidence,isNotNull);
    final tracker=AgentProgressTracker();const call=AgentToolCall(toolId:'memory.search',arguments:{'query':question});
    tracker.rememberRead(call,'unchanged-main-memory',r);expect(tracker.cached(call,'unchanged-main-memory'),isNull);
    await store.forget(await store.capture(),cid('a'));expect(await r.qqEvidence!.matches(await db.database),false);
  });
  test('a cached empty memory query is invalidated by newly arrived QQ input',()async{
    const call=AgentToolCall(toolId:'memory.search',arguments:{'query':'群里刚才说什么'});
    final before=await AgentProgressTracker.readState(db,call);await seed();
    expect(await AgentProgressTracker.readState(db,call),isNot(before));
  });
  test('final prompt merges independently queried QQ evidence even when automatic retrieval misses',()async{
    await seed();final r=await tool('qq_history.search',{'query':question});
    final built=await PromptBuilder(db).buildChatPrompt(latestUserText:'说说查到的结果',recent:const [],desire:DesireSnapshot(),thoughts:const [],agentToolResults:[r]);
    expect(jsonEncode(built.messages),contains('铃兰'));expect(built.qqEvidence,isNotNull);
    await store.forget(await store.capture(),cid('a'));expect(await built.qqEvidence!.matches(await db.database),false);
  });
  test('deleted Agent QQ source rejects the winning commit without a phantom message',()async{
    await seed();final r=await tool('qq_history.search',{'query':question});
    final user=ChatMessage(id:'u',role:'user',content:question,createdAt:DateTime.now());
    final job=await db.createGenerationTurn(user:user,assistantMessageId:'a',model:'fixture',reasoningEffort:'high');
    final running=(await db.claimGenerationJob(job.id))!;
    await store.forget(await store.capture(),cid('a'));
    expect(await db.completeGenerationJobIfCurrent(jobId:job.id,runToken:running.runToken,
      assistant:ChatMessage(id:'a',role:'assistant',content:'旧资料',createdAt:DateTime.now()),qqEvidence:r.qqEvidence),false);
    expect(await db.messageById('a'),isNull);
  });
  test('successful QQ-backed App reply records external provenance rather than new growth',()async{
    await seed();final r=await tool('qq_history.search',{'query':question});
    final user=ChatMessage(id:'u',role:'user',content:question,createdAt:DateTime.now());
    final job=await db.createGenerationTurn(user:user,assistantMessageId:'a',model:'fixture',reasoningEffort:'high');
    final running=(await db.claimGenerationJob(job.id))!;
    expect(await db.completeGenerationJobIfCurrent(jobId:job.id,runToken:running.runToken,
      assistant:ChatMessage(id:'a',role:'assistant',content:'群友说了铃兰',createdAt:DateTime.now()),qqEvidence:r.qqEvidence),true);
    expect((await ConversationSourceStore.qualifyMessage(await db.database,'a'))!.mayGrow,false);
  });
  test('merging QQ reads from different state generations remains invalid',()async{
    await seed();final sql=await db.database;final a=await QqHistoryReader(sql).search(question);
    await db.setSetting('state_generation','99999');final b=await QqHistoryReader(sql).search(question);
    expect(await QqContextEvidence.merge([a.evidence,b.evidence])!.matches(sql),false);
  });
  test('real backup import preserves named App and private QQ reads while pausing live sends',()async{
    await seed();await db.setSetting('qq_master_enabled_v2','1');
    final before=await QqHistoryReader(await db.database).search(question);
    final snapshot=await db.exportAll();await db.importAll(Map<String,dynamic>.from(snapshot));
    expect(await db.getSetting('qq_master_enabled_v2'),'0');
    expect(await before.evidence.matches(await db.database),false);
    final after=await tool('qq_history.search',{'query':question});
    final app=await MemoryBrain(db).buildContext(question);
    final qq=await QqReadOnlyContext(await db.database).build(question,qqScope:scope,media:true);
    for(final text in [after.promptData,app.qqContext,qq]) {expect(text,contains(name));expect(text,contains('铃兰'));}
    expect((await store.pending(cid('a'))),isEmpty);
  });
}
