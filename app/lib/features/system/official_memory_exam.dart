part of 'memory_benchmark.dart';

/// Private journal, separate from the companion database, transfer and cloud.
class OfficialMemoryExam {
  OfficialMemoryExam(this.suite,this.progress):assert(suite=='demo'||suite=='formal');
  final String suite;
  final void Function(String) progress;
  late final session = MemoryBenchmark(answers:true,progress:progress);
  static bool occupied = false;
  void stop() => session.stopped=true;
  static const channel=MethodChannel('ai_companion/chat_memory_exam');
  int get total=>suite=='demo'?108:714;
  int get turnLimit=>suite=='demo'?299:2240;
  String get name=>suite=='demo'?'示例卷 108 题':'正式卷 714 题';
  String stage='';
  Future<Map<String,dynamic>> native(String command,[Map<String,dynamic> fields=const {}]) async =>
    jsonDecode((await channel.invokeMethod<String>(command,jsonEncode({'suite':suite,...fields})))!) as Map<String,dynamic>;
  Future<Directory> _root() async => Directory('${(await getApplicationSupportDirectory()).path}/chat-exam-v1/$suite');
  Future<Database> _openJournal(Directory dir) async {
    await dir.create(recursive:true);
    return databaseFactory.openDatabase('${dir.path}/journal.sqlite',options:OpenDatabaseOptions(singleInstance:false,version:1,
      onCreate:(db,_) async { await db.execute('CREATE TABLE records (key TEXT PRIMARY KEY, value TEXT NOT NULL)'); }));
  }
  Future<void> put(DatabaseExecutor db,String key,dynamic value) async {
    await db.insert('records',{'key':key,'value':jsonEncode(value)},conflictAlgorithm:ConflictAlgorithm.replace);
  }
  Future<dynamic> get(Database db,String key) async {
    final rows=await db.query('records',columns:['value'],where:'key=?',whereArgs:[key]);
    return rows.isEmpty?null:jsonDecode(rows.single['value'] as String);
  }
  Future<List<Map<String,dynamic>>> records(Database db,String prefix) async {
    final rows=await db.query('records',columns:['value'],where:'key LIKE ?',whereArgs:['$prefix:%'],orderBy:'key');
    return [for(final row in rows) jsonDecode(row['value'] as String) as Map<String,dynamic>];
  }
  Future<int> count(Database db,String prefix) async => Sqflite.firstIntValue(await db.rawQuery(
    'SELECT COUNT(*) FROM records WHERE key LIKE ?', ['$prefix:%']))??0;
  Future<Map<String,dynamic>> status() async {
    final dir=await _root();
    if(!await File('${dir.path}/journal.sqlite').exists()) return {};
    final db=await _openJournal(dir);
    try {
      final state=await _status(db);
      if ((state['summary']?['scored']??0)!=state['judged']) {
        final scored=await records(db,'judge');
        state['summary']=await native('summary',{'judgments':[for(final v in scored)v['judgment']]});
      }
      return state;
    } finally {await db.close();}
  }
  Future<Map<String,dynamic>> _status(Database db) async {
    final money=await records(db,'cost');
    final unknown=money.where((e)=>e['cny']==null).length;
    return {'state':await get(db,'state'),'stage':await get(db,'stage'),'id':await get(db,'run_id'),
      'answered':await count(db,'answer'),'judged':await count(db,'judge'),'turns':await get(db,'turns')??0,
      'summary':await get(db,'summary'),'balance_before':await get(db,'balance_before'),'balance_after':await get(db,'balance_after'),
      'cny':money.fold<double>(0,(sum,e)=>sum+(e['cny'] as num? ?? 0).toDouble()),
      'unknown':unknown, 'error':await get(db,'error')};
  }
  static DateTime wallClock(String upstream) {
    // The corpus is UTC+08. Reproduce its wall clock even on a phone abroad.
    final match=RegExp(r'^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(?:\.\d+)?\+08:00$').firstMatch(upstream);
    if(match==null) throw FormatException('题库时间格式无效');
    return DateTime.parse(match.group(1)!);
  }

  Future<void> run({bool fresh=false}) async {
    if(occupied) throw StateError('已有测试在运行');
    occupied=true;
    Database? journal;
    AppDatabase? live;
    DeepSeekClient? client;
    LocalSemanticIndex? index;
    try {
      if((await SecureConfig.instance.readApiKey()??'').trim().isEmpty) throw const _MissingKey();
      final root=await _root();
      if(fresh && await root.exists()) await root.delete(recursive:true);
      final log=await _openJournal(root);
      journal=log;
      session.stopped=false;
      if(await get(log,'run_id')==null) {
        await put(log,'run_id',const Uuid().v4());
        await put(log,'started',DateTime.now().toUtc().toIso8601String());
      }
      await put(log,'state','running');
      await put(log,'error',null);
      stage='核对上游题目和历史';
      progress(stage);
      final data=await native('inputs');
      final questions=List<Map>.from(data['questions'] as List);
      if(questions.length!=total || questions.map((q)=>q['id']).toSet().length!=total) throw StateError('题库不完整');
      await put(log,'source',data['provenance']);
      final histories=data['histories'] as Map;
      questions.sort((a,b) {
        final p=(a['persona'] as String).compareTo(b['persona'] as String);
        if(p!=0) return p;
        final t=(a['cutoff_turn'] as int).compareTo(b['cutoff_turn'] as int);
        if(t!=0) return t;
        final d=(a['now'] as String).compareTo(b['now'] as String);
        return d!=0?d:(a['id'] as String).compareTo(b['id'] as String);
      });
      final transport=session._client(meter:(id,event)=>put(log,'cost:$id',{'id':id,...event}));
      client=transport;
      final config=SecureConfig.instance;
      final deferred = <String>[];
      for(final person in histories.keys.cast<String>().toList()..sort()){
        final exam=questions.where((q)=>q['persona']==person).toList();
        final history=histories[person] as List;
        final home=Directory('${root.path}/$person');
        await home.create(recursive:true);
        final memoryIndex=LocalSemanticIndex(cacheFile:()async=>File('${home.path}/vectors.json'));
        index=memoryIndex;
        AppDatabase? personDb;
        Future<AppDatabase> openPerson() async {
          if(personDb!=null) return personDb!;
          final db=await AppDatabase.simulation(databaseFactory,memoryIndex,directory:home);
          personDb=db;
          live=db;
          return db;
        }
        final initial=await openPerson();
        for(final k in ['deepseek_model','model','deepseek_reasoning_effort','reasoning_effort']){
          final setting=await AppDatabase.instance.getSetting(k);
          if(setting!=null) await initial.setSetting(k,setting);
        }
        if(await get(log,'balance_before')==null){
          await put(log,'balance_before',await session._balance(initial,true));
          await put(log,'initial_account',session._initialAccount);
          await put(log,'account_start',session.report['account_start']);
        } else {
          session._initialAccount=await get(log,'initial_account') as String?;
          session.report['account_start']=await get(log,'account_start');
        }
        var cursor=int.tryParse(await initial.getSetting('fixed_exam_last_turn')??'0')??0;
        await initial.retryFailedPostTurnJobsManually();
        for(final q in exam){
          session._check();
          final id=q['id'] as String;
          if(await get(log,'judge:$id')!=null) continue;
          final cutoff=q['cutoff_turn'] as int;
          Map<String,dynamic>? answer=await get(log,'answer:$id') as Map<String,dynamic>?;
          if(answer==null){
            if(cutoff<cursor) throw StateError('历史超过题目截止轮');
            final db=await openPerson();
            final extractor=MemoryExtractor(db:db,client:transport,desireEngine:DesireEngine(db));
            while(cursor<cutoff){
              session._check();
              final turn=history[cursor] as Map;
              final n=cursor+1;
              if(turn['轮次']!=n) throw StateError('原始轮次不连续');
              stage='$person · 写入第 $n 轮（本题截止 $cutoff）';
              progress(stage);await put(log,'stage',stage);
              final time=wallClock(turn['逻辑时间'] as String);
              db.setSimulationTime(time);
              final user=ChatMessage(id:'$person-u$n',role:'user',content:turn['用户消息'] as String,createdAt:time);
              final assistant=ChatMessage(id:'$person-a$n',role:'assistant',content:turn['助手回复'] as String,
                createdAt:time.add(const Duration(milliseconds:1)));
              await extractor.ingestExamTurn(user,assistant);
              await extractor.dailyContinuity.maybeRefresh(now:time);
              await extractor.memoryMaintenance.maybeRun(at:time);
              cursor=n;
              await db.setSetting('fixed_exam_last_turn','$cursor');
              await put(log,'cursor:$person',{'person':person,'turn':cursor});
              final cursors=await records(log,'cursor');
              await put(log,'turns',cursors.fold<int>(0,(sum,c)=>sum+(c['turn'] as int)));
            }
            await memoryIndex.waitForIndex();
            await db.close();personDb=null;live=null;
            // Every question gets a disposable copy at precisely its cutoff.
            // Even internal retrieval counters cannot influence the next item.
            final scratch=Directory('${root.path}/question');
            if(await scratch.exists()) await scratch.delete(recursive:true);
            await scratch.create();
            await File('${home.path}/simulation.sqlite').copy('${scratch.path}/simulation.sqlite');
            final probe=await AppDatabase.simulation(databaseFactory,memoryIndex,directory:scratch);
            try {
              stage='$person · 作答 $id';progress(stage);await put(log,'stage',stage);
              final now=wallClock(q['now'] as String);
              probe.setSimulationTime(now);
              await MemoryMaintenanceEngine(probe).maybeRun(at:now);
              final text=q['question'] as String;
              final recent=await probe.recentMessagesForPrompt(limit:12);
              final query=ChatMessage(id:'exam-$id',role:'user',content:text,createdAt:now);
              await memoryIndex.search(text,await probe.listMemories());
              await memoryIndex.waitForIndex();
              final built=await PromptBuilder(probe).buildChatPrompt(latestUserText:text,recent:[...recent,query],
                desire:await probe.loadDesire(),thoughts:await probe.currentThoughtsForPresentation(limit:6),now:now,
                nsfwActive:false,nsfwReferenceActive:false);
              final prev=session.externalCalls.length;
              try {
                final reply=await session._reply(transport,probe,built.messages);
                answer={'id':id,'persona':person,'now':q['now'],'cutoff_turn':cutoff,'question':text,
                  'answer':reply['text'],'provider':reply['provider'],'model':reply['model'],'recent_turns':recent.length~/2,
                  'trace':built.recallTrace?.snapshot(built.messages,'exam'),'semantic_index':memoryIndex.status};
                await put(log,'answer:$id',answer);
              } finally {
                for(final detail in session.externalCalls.skip(prev)){
                  await put(log,'cost:${const Uuid().v4()}',{'lane':detail,'cny':null});
                }
              }
            } finally {
              await memoryIndex.waitForIndex();
              await probe.close();await scratch.delete(recursive:true);
            }
          }
          session._check();
          stage='$person · 按原判据审核 $id';progress(stage);await put(log,'stage',stage);
          final materials=await native('packet',{'id':id,'answer':answer['answer']});
          final packet=materials['packet'] as Map;
          final db=await openPerson();
          final model=await FirstChannelModel.read(db);
          final pendingKey = 'pending:$id';
          final cached = (await get(log, pendingKey) as Map?) ?? const {};
          final countRequired = (packet['rubric']['required'] as List).length;
          final hashes = {
            for (final key in ['id', 'answer_sha256', 'rubric_sha256']) key: packet[key]
          };
          final samePacket = hashes.entries.every((entry) => cached[entry.key] == entry.value);
          final previousError = samePacket ? cached['validation_error'] : null;
          final reuse = samePacket && previousError == null;
          final raw = reuse ? Map<String, dynamic>.from(cached['raw'] as Map)
              : await transport.jsonCompletion(apiKey:await config.readApiKey()??'',endpoint:await config.readEndpoint(),
                  model:model,thinking:false,maxTokens:2500,usageLane:'memory_benchmark_judge',
                  messages:[{'role':'system','content':
                    "${materials['instruction']}\n本接口由程序填写题号和两个哈希。只输出语义判断。"
                    "required 必须恰有 $countRequired 个布尔值，每个原卷数组元素对应一个判断；同一项内的分号不能拆项。"
                    "${previousError == null ? '' : '上次未通过格式校验：$previousError'}"},
                    {'role':'user','content':jsonEncode(packet)}]);
          final attempt = {...hashes, 'raw':raw, 'model':reuse ? cached['model'] : model.apiName};
          if (!reuse) await put(log, pendingKey, attempt);
          final review = {...raw, ...hashes};
          Map<String,dynamic> judgment;
          try {
            judgment = await native('score', {'packet':packet,'review':review});
          } on PlatformException catch (error) {
            final detail = error.message ?? error.code;
            if (error.code != 'benchmark_failed' ||
                !RegExp(r'Invalid required decisions|All error flags must be booleans|All detail fields must be lists|Non-empty reason required').hasMatch(detail)) {
              rethrow;
            }
            await put(log, pendingKey, {...attempt,'validation_error':detail});
            deferred.add(id);
            continue;
          }
          await log.transaction((txn) async {
            await put(txn,'judge:$id',{'id':id,'model':attempt['model'],'rubric':packet['rubric'],'facts':packet['facts'],'sources':packet['sources'],'review':review,'judgment':judgment});
            await txn.delete('records',where:'key=?',whereArgs:[pendingKey]);
          });
        }
        await memoryIndex.waitForIndex();
        if(personDb!=null) await personDb!.close();
        live=null;index=null;
      }
      if (deferred.isEmpty) {
        await put(log,'state','completed');
      } else {
        await put(log,'stage','待补判 ${deferred.length} 题（${deferred.first}）');
        await put(log,'error','裁判格式未通过校验，继续本卷可补判');
        await put(log,'state','error');
      }
    } catch(error){
      if(journal==null) rethrow;
      await put(journal,'state',session.stopped?'paused':'error');
      await put(journal,'error',session.stopped ? null : error is PlatformException ? '${error.code} · ${error.message ?? error.runtimeType}' : error.runtimeType.toString());
    } finally {
      try {
        client?.close();await index?.waitForIndex();
        if(journal!=null){
          final j=journal;
          try {
            final scored=await records(j,'judge');
            await put(j,'summary',await native('summary',{'judgments':[for(final v in scored)v['judgment']]}));
            final accountDb=live??await AppDatabase.simulation(databaseFactory,LocalSemanticIndex(enabled:false));
            try {
              await put(j,'balance_after',await session._balance(accountDb,false));
              await put(j,'account_end',session.report['account_end']);
              await put(j,'account_change_units',session.report['account_change_units']);
            } finally {if(live==null) await accountDb.close();}
          } finally {await j.close();}
        }
      } finally {try {await live?.close();} finally {occupied=false;}}
    }
  }

  Future<File> export() async {
    final dir=await _root();
    final db=await _openJournal(dir);
    try{
      final file=File('${dir.path}/chat-memory-$suite.json.gz');
      final output=<String,dynamic>{'schema':1,'suite':suite,'edition':'1.0',
        'revision':await get(db,'source'),'app':AgentSelfReader.buildLabel,'started':await get(db,'started'),
        'status':await _status(db),'account_start':await get(db,'account_start'),
        'account_end':await get(db,'account_end'),'account_change_units':await get(db,'account_change_units'),
        'configuration':{'history':'native post-turn extraction; no hidden answers','recent_turns_max':6,
          'exam_timezone':'+08:00','maintenance':['native post-turn extraction','daily continuity','memory fading at logical time'],
          'dream_replayed':false,'background_jobs_replayed':false,
          'writer':'configured app route','judge':'configured first channel; author-side semantic review'},
        'answers':await records(db,'answer'),'reviews':await records(db,'judge'),'pending_reviews':await records(db,'pending'),'costs':await records(db,'cost')};
      await file.writeAsBytes(gzip.encode(utf8.encode(jsonEncode(output))),flush:true);
      return file;
    }finally{await db.close();}
  }
}
