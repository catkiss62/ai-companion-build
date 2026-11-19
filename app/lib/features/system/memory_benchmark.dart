import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/agent/agent_self_reader.dart';
import '../../core/ai/deepseek_balance.dart';
import '../../core/ai/deepseek_client.dart';
import '../../core/ai/final_reply_route.dart';
import '../../core/ai/third_channel_config.dart';
import '../../core/ai/final_reply_failure_policy.dart';
import '../../core/ai/first_channel_model.dart';
import '../../core/ai/memory_extractor.dart';
import '../../core/ai/prompt_builder.dart';
import '../../core/database/app_database.dart';
import '../../core/desire/desire_engine.dart';
import '../../core/diagnostics/daily_spend.dart';
import '../../core/diagnostics/daily_balance_spend.dart';
import '../../core/memory/local_semantic_index.dart';
import '../../core/memory/memory_maintenance_engine.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/desire_state.dart';
import '../../core/storage/secure_config.dart';

part 'official_memory_exam.dart';

typedef BenchmarkReport = Map<String, dynamic>;

class MemoryBenchmark {
  MemoryBenchmark({required this.answers, required this.progress, this.directory, this.factory});
  final Directory? directory;
  final DatabaseFactory? factory;
  final bool answers;
  final void Function(String) progress;
  bool stopped = false;
  final rows = <BenchmarkReport>[];
  final attempts = <String, BenchmarkReport>{};
  final usage = <BenchmarkReport>[];
  final externalCalls = <String>[];
  late final BenchmarkReport report = {
    'schema': 1, 'app_version':AgentSelfReader.buildLabel, 'suite': 'companion',
    'started': DateTime.now().toUtc().toIso8601String(),
    'rows': rows, 'usage': usage, 'external_calls': externalCalls,
  };
  void _check() { if (stopped) throw const _Stopped(); }

  static final anchor = DateTime(2026, 10, 30, 12);
  static const turns = [
    (19, '我把《杀不死》看到第六集了。', '好，我记住你看到第六集了。'),
    (22, '说起《杀不死》，我最喜欢的是仓库追逐那段。', '仓库追逐那段确实紧张。'),
    (27, '纠正一下，《杀不死》我已经看到第十集了。', '收到，进度更新到第十集。'),
    (29, '今天有点晚了。', '我明天要赶早班车，我先去休息。'),
  ];
  static const companionQueries = [
    {'text':'我那部剧现在看到哪里了？','expect':['第十集'],'obsolete':['第六集']},
    {'text':'上周咱们说的那部剧，我最喜欢哪段？','expect':['仓库追逐']},
    {'text':'昨天谁先说要休息，为什么？','expect':['早班车'],'speaker':'assistant','source_id':'a3'},
    {'text':'我家的猫叫什么名字？','expect':<String>[]},
  ];

  static Future<File> lastReport() async =>
      File('${(await getApplicationSupportDirectory()).path}/memory_benchmark_last.json');

  Future<void> _save() async {
    final file = directory == null ? await lastReport() : File('${directory!.path}/report.json');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(const JsonEncoder.withIndent('  ').convert(report), flush:true);
    await temp.rename(file.path);
  }

  String? _initialAccount;
  Future<String> _balance(AppDatabase db, bool first) async {
    try {
      return await DeepSeekBalance.display(db:db,onSample:(account,balances,at) {
        if (first) _initialAccount=account;
        report[first?'account_start':'account_end'] = {'at':at.toUtc().toIso8601String(),
          'units_per_currency':DailyBalanceSpend.scale,'balances':Map.of(balances)};
        if (!first && _initialAccount!=null) {
          report['same_balance_account'] = _initialAccount==account;
          final start=report['account_start']['balances'] as Map;
          if (_initialAccount==account) {
            report['account_change_units'] = {for(final entry in balances.entries)
              if(start[entry.key] is int) entry.key:entry.value-(start[entry.key] as int)};
          }
        }
      });
    } catch (_) { return 'DeepSeek 余额：暂时无法查询'; }
  }

  DeepSeekClient _client({Future<void> Function(String,BenchmarkReport)? meter}) => DeepSeekClient(abortWhen:() async => stopped,
          runCostRecorder:(event) async {
            final id = event['id'].toString();
            final amount = DailySpend.estimate(event);
            if (attempts[id]?['cny'] != null && amount == null) return;
            final raw = event['usage'];
            attempts[id] = {'model':event['model'],'lane':event['lane'],'cny':amount,
              'at':event['at'],'price_version':DailySpend.priceVersion,
              'usage':{if(raw is Map) for(final k in ['prompt_tokens','completion_tokens',
                'prompt_cache_hit_tokens','prompt_cache_miss_tokens']) if(raw[k] is num) k:raw[k]}};
            await meter?.call(id,attempts[id]!);
          },
          onUsage:(event) async => usage.add({'lane':event.lane,'provider':event.provider,
            'input':event.inputTokens,'output':event.outputTokens}));

  Future<BenchmarkReport> run() async {
    Directory? scratch;
    LocalSemanticIndex? index;
    AppDatabase? db;
    DeepSeekClient? client;
    report['state'] = 'running';
    try {
      await _save();
      report['clock'] = anchor.toIso8601String();
      if ((await SecureConfig.instance.readApiKey() ?? '').trim().isEmpty) {
        throw const _MissingKey();
      }
      _check();
      scratch = await (directory ?? await getTemporaryDirectory()).createTemp('memory-benchmark-');
      final runDirectory = scratch;
      index = LocalSemanticIndex(cacheFile: () async => File('${runDirectory.path}/vectors.json'));
      final isolated = await AppDatabase.simulation(factory ?? databaseFactory, index);
      db = isolated;
      List queries;
      {
        for (final key in ['deepseek_model','model','deepseek_reasoning_effort','reasoning_effort']) {
          final value = await AppDatabase.instance.getSetting(key);
          if (value != null) await isolated.setSetting(key, value);
        }
        report['balance_before'] = await _balance(isolated,true);
        client = _client();
        final extractor = MemoryExtractor(db:isolated,client:client,desireEngine:DesireEngine(isolated));
        final evidence = <BenchmarkReport>[];
        report['turns'] = evidence;
        for (var i=0;i<turns.length;i++) {
          _check();
          progress('正在整理第 ${i+1} / ${turns.length} 轮合成对话');
          final turn = turns[i];
          final when = DateTime(2026,10,turn.$1,12);
          final user = ChatMessage(id:'u$i',role:'user',content:turn.$2,createdAt:when);
          final assistant = ChatMessage(id:'a$i',role:'assistant',content:turn.$3,createdAt:when.add(const Duration(seconds:3)));
          await isolated.insertMessage(user);
          await isolated.insertMessage(assistant);
          evidence.add({'day':turn.$1,'user':user.content,'assistant':assistant.content,'user_id':user.id,'assistant_id':assistant.id});
          await extractor.extractSimulationTurn(user,assistant);
          await _checkpoint();
        }
        queries = companionQueries;
      }
      final items = await isolated.listMemories(limit:200);
      final stored = items.map((e)=>{'id':e.id,'actor':e.actorKey,'text':e.content,'user':e.sourceUserMessageId,
        'assistant':e.sourceAssistantMessageId,'status':e.status,'revision_of':e.revisionOf}).toList();
      report['memories'] = stored;
      _check();
      await index.search(queries.first['text'] as String,items);
      await index.waitForIndex();
      for (var i=0;i<queries.length;i++) {
        _check();
        progress('小鲸鱼召回 ${i+1} / ${queries.length}');
        final question = Map<String,dynamic>.from(queries[i] as Map);
        final text = question['text'] as String;
        final query = ChatMessage(id:'q$i',role:'user',content:text,createdAt:anchor);
        final built = await PromptBuilder(isolated).buildChatPrompt(latestUserText:text,recent:[query],
          desire:DesireSnapshot(),thoughts:[],now:anchor,nsfwActive:false,nsfwReferenceActive:false);
        final trace = built.recallTrace!.snapshot(built.messages,'benchmark');
        final candidates = (trace['ranked_candidates'] as List).whereType<Map>().toList();
        final sections = (trace['request_sections'] as List).whereType<Map>().where((s)=>s['text'] is String).toList();
        final expected = List<String>.from(question['expect']);
        List<String> found(Iterable<Map> records) {
          final haystack = records.map((e)=>e['text']).join('\n').toLowerCase();
          return expected.where((e)=>haystack.contains(e.toLowerCase())).toList();
        }
        final row = <String,dynamic>{'id':'q$i', ...question, 'stored_matches':found(stored),
          'candidate_matches':found(candidates),'injected_matches':found(sections),'trace':trace,
          'index':index.status, 'negative':expected.isEmpty,
          'negative_has_candidates':expected.isEmpty && candidates.isNotEmpty,
          'negative_has_context':expected.isEmpty && sections.isNotEmpty,
          'possible_obsolete_context':[
            for (final term in (question['obsolete'] as List? ?? []))
              if (sections.any((section)=>(section['text'] as String).contains(term as String))) term,
          ]};
        final injected = (row['injected_matches'] as List).length;
        row['finding'] = expected.isEmpty
          ? (sections.isEmpty ? '无答案对照：未带入召回资料' : '无答案对照：已带入资料，复核相关性')
          : injected==expected.length ? '预期片段已进入上下文'
          : (row['stored_matches'] as List).length<expected.length ? '优先复核入库、改写或更新'
          : (row['candidate_matches'] as List).length<expected.length ? '优先复核召回排序'
          : '优先复核上下文筛选或截断';
        rows.add(row);
        if (answers) {
          _check();
          final reply = await _reply(client!,isolated,built.messages);
          row['reply'] = reply;
          row['reply_literal_matches'] = found([{'text':reply['text']}]);
        }
        await _checkpoint();
      }
      report['state'] = 'completed';
    } on _Stopped {
      report['state'] = 'stopped';
    } on _MissingKey {
      report['state'] = 'missing_key';
    } catch (error) {
      report['state'] = stopped ? 'stopped' : 'error';
      report['error_type'] = error.runtimeType.toString();
      if (error is PlatformException) report['platform_code'] = error.code;
    } finally {
      client?.close();
      try {
        if (db != null) report['balance_after'] = await _balance(db,false);
      } finally {
        try { await index?.waitForIndex(); } finally {
          try { await db?.close(); } finally {
            if (scratch != null && await scratch.exists()) await scratch.delete(recursive:true);
          }
        }
        await _checkpoint();
      }
    }
    return report;
  }

  Future<void> _checkpoint() async {
    report['attempts'] = attempts.values.toList();
    final answerable = rows.where((r)=>r['negative']==false).toList();
    int count(String key)=>answerable.fold<int>(0,(sum,row)=>sum+(row[key] as List).length);
    report['metrics'] = {'answerable':answerable.length,'gold_fragments':count('expect'),
      'stored_fragments':count('stored_matches'),'candidate_fragments':count('candidate_matches'),
      'injected_fragments':count('injected_matches'),
      'negative_with_candidates':rows.where((r)=>r['negative_has_candidates']==true).length,
      'negative_with_context':rows.where((r)=>r['negative_has_context']==true).length};
    report['known_cny'] = attempts.values.fold<double>(0,(s,e)=>s+(e['cny'] as double? ?? 0));
    report['unknown_costs'] = attempts.values.where((e)=>e['cny']==null).length + externalCalls.length;
    await _save();
  }

  Future<BenchmarkReport> _reply(DeepSeekClient client, AppDatabase db,List<Map<String,Object?>> messages) async {
    final config = SecureConfig.instance;
    final provider = await config.readChatProvider();
    final route = FinalReplyRoute(secondChannelEnabled:provider.isGeminiRelay);
    final model = await FirstChannelModel.read(db);
    var writerModel=model.apiName;
    Future<String> request(bool second) async {
      _check();
      final key = await (second ? config.readFinalReplyApiKey() : config.readApiKey());
      final buffer = StringBuffer();
      writerModel=second ? await config.readFinalReplyModel() : model.apiName;
      var terminal = false;
      var finish = '';
      await for (final part in client.streamChat(apiKey:key ?? '',endpoint:await (second ? config.readFinalReplyEndpoint():config.readEndpoint()),
          model:model,effort:await FirstChannelModel.readEffort(db),messages:messages,thinking:second,
          modelName:second ? writerModel:null,requestProvider:second ? provider:null,
          thirdChannelSecure:config,thirdChannelCurrent:() async => !stopped,finalReplyRoute:route,usageLane:'memory_benchmark_reply')) {
        _check();
        buffer.write(part.content);
        terminal = terminal || part.done || part.finishReason != null;
        finish = part.finishReason ?? finish;
      }
      final text = buffer.toString().trim();
      final failure = FinalReplyFailurePolicy.incompleteResponseFailure(sawTerminalSignal:terminal,finishReason:finish,content:text);
      if (failure != null) throw failure;
      if (text.isEmpty || route.thirdChannelIncomplete) throw StateError('未完成正文');
      return text;
    }
    String? text;
    try {
      if (route.useSecondChannel) {
        try { text = await request(true); } catch (e) { _check(); if (route.thirdChannelIncomplete) rethrow; route.recordFailure(e); }
      }
      text ??= await request(false);
      return {'text':text,'provider':route.currentProvider,'model':route.usedThirdChannel?ThirdChannelConfig.model:writerModel,'third_used':route.usedThirdChannel};
    } finally {
      if (route.thirdAttempted) externalCalls.add('第三通道：价格未核实');
    }
  }
}

class _Stopped implements Exception { const _Stopped(); }
class _MissingKey implements Exception { const _MissingKey(); }
