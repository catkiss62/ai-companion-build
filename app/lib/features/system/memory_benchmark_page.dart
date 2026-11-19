import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/platform/android_bridge.dart';
import 'memory_benchmark.dart';

class MemoryBenchmarkPage extends StatefulWidget {
  const MemoryBenchmarkPage({super.key});
  @override
  State<MemoryBenchmarkPage> createState() => _MemoryBenchmarkPageState();
}

class _MemoryBenchmarkPageState extends State<MemoryBenchmarkPage> {
  static MemoryBenchmark? active;
  bool original = true;
  bool answers = false;
  String step = '';
  BenchmarkReport? report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await MemoryBenchmark.lastReport();
      if (!await file.exists()) return;
      final saved = jsonDecode(await file.readAsString());
      if (mounted && active == null && saved is Map<String,dynamic>) setState(()=>report=saved);
    } catch (_) { /* A new run can replace an unreadable report. */ }
  }

  Future<void> _start() async {
    if (active != null) return;
    final run = MemoryBenchmark(original:original,answers:!original && answers,
      progress:(value) { if (mounted) setState(()=>step=value); });
    setState(() { active=run; step='准备隔离测试库'; report=null; });
    try {
      final result = await run.run();
      if (mounted) setState(()=>report=result);
    } catch (_) {
      if (mounted) setState(()=>step='无法保存完整报告，请检查设备存储');
    } finally {
      active=null;
      if (mounted) setState((){});
    }
  }

  Future<void> _export() async {
    try {
      final file = await MemoryBenchmark.lastReport();
      await AndroidBridge.instance.saveDiagnosticReport(sourcePath:file.path,
        suggestedName:'memory_benchmark_${DateTime.now().millisecondsSinceEpoch}.json');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('导出失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = active != null;
    final result = report;
    final rows = (result?['rows'] as List? ?? []).whereType<Map>().toList();
    final amount = (result?['known_cny'] as num?)?.toStringAsFixed(5);
    final state = {'completed':'已完成','stopped':'已停止','running':'上次运行中断',
      'missing_key':'需要先配置第一通道 API Key','error':'运行失败，已保留部分结果'}[result?['state']];
    return PopScope(canPop:!busy, child:ListView(padding:const EdgeInsets.all(16),children:[
      RadioListTile<bool>(value:true,groupValue:original,onChanged:busy?null:(v)=>setState(()=>original=true),
        title:const Text('SeekMemory 原版测试'),subtitle:const Text('离线执行原仓库基准，再让小鲸鱼做同一套召回题。模型费用为零。')),
      RadioListTile<bool>(value:false,groupValue:original,onChanged:busy?null:(v)=>setState(()=>original=false),
        title:const Text('小鲸鱼从零模拟'),subtitle:const Text('用四轮虚构对话建立临时记忆，再测试跨周、说话人和进度更新。记忆整理会使用第一通道。')),
      if (!original) SwitchListTile(value:answers,onChanged:busy?null:(v)=>setState(()=>answers=v),
        title:const Text('同时测试模型作答'),subtitle:const Text('沿当前正文通道另行请求，报告保留实际回答，可核对是否读错记忆。')),
      FilledButton(onPressed:busy?null:_start,child:const Text('开始测试')),
      if (busy) ...[const LinearProgressIndicator(),Text(step),
        TextButton(onPressed:active!.stopped?null:()=>setState((){active!.stopped=true;step='正在停止并保存已完成结果';}),child:const Text('停止测试'))],
      if (!busy && result==null && step.isNotEmpty) Text(step),
      if (!busy && result!=null) ...[
        const Divider(), Text('${result['suite']=='seekmemory'?'SeekMemory 原版测试':'小鲸鱼从零模拟'} · ${state??'部分结果'}',style:Theme.of(context).textTheme.titleMedium),
        if (result['upstream'] case final Map reference)
          Text('上游原脚本验收　${reference['acceptance']['passed']==true?'通过':'未通过'}'),
        if (result['metrics'] case final Map metrics)
          Text('小鲸鱼进入上下文的标准片段　${metrics['injected_fragments']} / ${metrics['gold_fragments']}'),
        if (amount!=null) Text('本次已估算金额　¥$amount${(result['unknown_costs']??0)>0?'　另有用量未能计价':''}'),
        if (result['balance_after'] case final String balance) Text('结束时$balance'),
        for (final row in rows) ExpansionTile(title:Text(row['text'] as String),subtitle:Text(row['negative']==true?'无答案对照 · 查看带入资料':
          '入库 ${(row['stored_matches'] as List).length}/${(row['expect'] as List).length}　候选 ${(row['candidate_matches'] as List).length}　进入上下文 ${(row['injected_matches'] as List).length}'),
          children:[Padding(padding:const EdgeInsets.all(12),child:SelectableText([
            if (row['negative']!=true) '标准片段：${(row['expect'] as List).join('、')}',
            row['finding']?.toString() ?? '',
            '候选条数：${row['trace']['ranked_candidate_count']??0}',
            if (row['reply'] case final Map reply) '实际回答：${reply['text']}',
            '逐字命中仅作定位，改写、说话人和新旧进度可在导出报告中复核。',
          ].join('\n')))]),
        OutlinedButton.icon(onPressed:_export,icon:const Icon(Icons.file_download_outlined),label:const Text('导出本次测试报告')),
      ]
    ]));
  }
}
