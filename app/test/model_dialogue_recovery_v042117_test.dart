import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_companion_localfirst/core/ai/generation_cancellation.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_archive_batch.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_archive_worker.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_models.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_prompt.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_repository.dart';
import 'package:ai_companion_localfirst/core/model_dialogue/model_dialogue_time.dart';
import 'package:ai_companion_localfirst/core/memory/memory_revision.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();sqfliteFfiInit();
  late AppDatabase db;
  late ModelDialogueRepository repository;
  setUp(() async {db=await AppDatabase.createForTesting(databaseFactoryFfi);repository=ModelDialogueRepository(db);});
  tearDown(() async {await db.closeForTesting();});
  Future<ModelDialogueRoom> create()=>repository.create(title:'完整对谈',topic:'跨天的讨论',
    participants:const {'deepseek':{'model':'deepseek-test'},'gemini':{'model':'gemini-test'}});
  Future<void> turn(ModelDialogueRoom room,String text) async {
    expect(await db.tryAcquireLocalLease('chat_turn_lease'),isTrue);
    final fence=(await db.captureBrainWorkFence(leaseKey:'chat_turn_lease'))!;
    final ticket=await repository.begin(roomId:room.id,fence:fence);
    expect(await repository.commit(ticket,ModelDialogueOutput(text,'continue'),GenerationCancellationToken()),isTrue);
    await db.releaseLocalLease('chat_turn_lease');
  }
  Map<String,dynamic> result({String overview='累计讨论',String gemini='',bool worth=true})=>{
    'overview':overview,'deepseek_view':'保留早期想法','gemini_view':gemini,
    'common_ground':'','open_questions':'还需讨论','user_quotes':<String>[],'worth_remembering':worth};

  test('batch cursors cover a long message and Unicode boundaries exactly once',() {
    final text='开头${'🐳'*12000}结尾';
    final messages=[ModelDialogueMessage(id:'one',roomId:'r',sequence:1,speaker:'deepseek',text:text,model:'ds',createdAt:1)];
    var cursor=0;final out=StringBuffer();var batches=0;
    while(cursor<text.length) {
      final batch=ModelDialogueArchiveBatch(messages,cursor,budget:101);
      for(final m in batch.messages){expect(utf8.decode(utf8.encode(m.text)),m.text);out.write(m.text);}
      expect(batch.end,greaterThan(cursor));cursor=batch.end;batches++;
    }
    expect(batches,greaterThan(2));expect(out.toString(),text);
  });

  test('long archive persists progress and resumes after failure without a partial public memory',() async {
    final room=await create();await turn(room,'早期关键想法${'甲'*19000}');await turn(room,'${'乙'*19000}最后结尾');await repository.end(room.id);
    var calls=0;var fail=true;final seen=StringBuffer();
    final worker=ModelDialogueArchiveWorker(db,generate:(r,batch,fence) async {
      calls++;
      if(calls==2&&fail)throw const FormatException('network_failure');
      final previous=r.data['archive_previous_summary'] as Map?;
      if(calls>1)expect(previous?['overview'],contains('早期关键想法'));
      seen.write(batch.map((m)=>m.text).join());
      return result(overview:'早期关键想法与后续讨论',gemini:batch.any((m)=>m.speaker=='gemini')?'后续观点':'',worth:calls==1);
    });
    await worker.drainOne();
    expect((await repository.roomById(room.id))!.archiveState,'pending');
    expect(await (await db.database).query('memory_items'),isEmpty);
    final key='${ModelDialogueRepository.archivePrefix}${room.id}';
    final offset=(jsonDecode((await db.getSetting(key))!) as Map)['offset'];
    await worker.drainOne();
    expect((jsonDecode((await db.getSetting(key))!) as Map)['offset'],offset);
    expect(await (await db.database).query('memory_items'),isEmpty);
    fail=false;
    // A new worker uses the durable cursor, as after leaving or restarting.
    final resumed=ModelDialogueArchiveWorker(db,generate:worker.generate);
    for(var i=0;i<4&&await db.getSetting(key)!=null;i++) {
      await resumed.drainOne(now:DateTime.now().add(const Duration(days:1)));
    }
    final saved=(await repository.roomById(room.id))!;
    expect(saved.archiveState,'remembered');expect(saved.data['archive_coverage'],containsPair('complete',true));
    expect(saved.data['archive_coverage'],containsPair('start',0));
    expect(seen.toString(),(await repository.messagesForRoom(room.id)).map((m)=>m.text).join());
    expect(await (await db.database).query('memory_items'),hasLength(1));
    await resumed.drainOne();expect(await (await db.database).query('memory_items'),hasLength(1));
  });

  test('deleting during a later archive batch removes progress and rejects late memory',() async {
    final room=await create();await turn(room,'甲'*20000);await repository.end(room.id);
    await ModelDialogueArchiveWorker(db,generate:(r,m,f) async=>result()).drainOne();
    await ModelDialogueArchiveWorker(db,generate:(r,m,f) async {
      await repository.delete(room.id);return result();
    }).drainOne();
    expect(await repository.roomById(room.id),isNull);
    expect(await db.getSetting('${ModelDialogueRepository.archivePrefix}${room.id}'),isNull);
    expect(await (await db.database).query('memory_items'),isEmpty);
  });

  test('cross-day closing retains actual message times in memory and participant prompts',() async {
    final room=await create();await turn(room,'昨天说的想法');
    final first=DateTime(2026,10,16,22).millisecondsSinceEpoch;
    final last=DateTime(2026,10,17,1).millisecondsSinceEpoch;
    final original=(await repository.messagesForRoom(room.id)).single;
    await db.setSetting('${ModelDialogueRepository.messagePrefix}${room.id}:0000000001',
      jsonEncode({...original.toJson(),'created_at':first}));
    await turn(room,'跨过零点后的回答');
    final second=(await repository.messagesForRoom(room.id)).last;
    await db.setSetting('${ModelDialogueRepository.messagePrefix}${room.id}:0000000002',
      jsonEncode({...second.toJson(),'created_at':last}));
    await repository.end(room.id);
    await ModelDialogueArchiveWorker(db,generate:(r,m,f) async {
      expect(r.data['archive_time_description'],contains(ModelDialogueTime.format(first)));
      expect(ModelDialogueArchiveWorker.transcript(m),contains(ModelDialogueTime.format(last)));
      return result(gemini:'跨天回答');
    }).drainOne();
    final memory=(await (await db.database).query('memory_items')).single;
    expect(memory['last_evidence_at'],last);expect(memory['evidence_time_known'],1);
    final context=jsonDecode(memory['source_context_json'] as String) as Map;
    expect(context['first_message_at'],first);expect(context['last_message_at'],last);
    expect(context['closed_at'],greaterThan(last));
    expect(MemorySourceContext.format(memory['source_context_json'] as String),contains('实际发言'));
    final history=await repository.messagesForRoom(room.id);
    final prompt=jsonEncode(ModelDialoguePrompt.build((await repository.roomById(room.id))!,history,'deepseek',now:DateTime(2026,10,19)));
    expect(prompt,contains(ModelDialogueTime.format(first)));expect(prompt,contains(ModelDialogueTime.format(last)));
    expect(prompt,contains('关闭、恢复和整理不代表这些内容刚刚发生'));
  });

  test('legacy archive timestamps are explicitly not treated as actual speech time',() {
    final formatted=MemorySourceContext.format(jsonEncode({'scene':'model_dialogue','created_at':123456789}));
    expect(formatted,contains('实际发言时间未保存'));
  });
}
