import 'package:flutter/material.dart';
import '../../core/platform/android_bridge.dart';
import 'memory_benchmark.dart';

class OfficialMemoryExamPage extends StatefulWidget {
  const OfficialMemoryExamPage({super.key});
  @override
  State<OfficialMemoryExamPage> createState()=>_OfficialMemoryExamState();
}
class _OfficialMemoryExamState extends State<OfficialMemoryExamPage>{
  String suite='demo';
  Map<String,dynamic> status={};
  String stage='';
  bool busy=false,loading=true,stopping=false;
  OfficialMemoryExam? active;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async{
    final selected=suite;
    final value=await OfficialMemoryExam(selected,(_){}).status();
    if(mounted && selected==suite) setState((){status=value;loading=false;});
  }
  Future<void> _run({required bool fresh}) async{
    if(busy||loading) return;
    final run=OfficialMemoryExam(suite,(value){if(mounted)setState(()=>stage=value);});
    if(fresh && status.isNotEmpty){
      final yes=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
        title:const Text('重新开始这张卷？'),content:const Text('将替换这张卷上次的隔离进度和报告。需要保留时，可先导出。'),
        actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('返回')),
          FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('重新开始'))]));
      if(yes!=true || !mounted) return;
    }
    setState((){active=run;busy=true;stopping=false;stage='准备评测';});
    try{await run.run(fresh:fresh);}
    catch(_){if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('无法启动，请检查第一通道 API Key 和本机存储')));}
    finally{if(mounted){setState((){busy=false;active=null;});await _load();}}
  }
  Future<void> _export() async{
    try{
      final file=await OfficialMemoryExam(suite,(_){}).export();
      await AndroidBridge.instance.saveDiagnosticReport(sourcePath:file.path,
        suggestedName:'chat-memory-1.0-$suite-${DateTime.now().millisecondsSinceEpoch}.json.gz');
    }catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('报告导出失败')));}
  }
  Widget _score(String label, int passed, int total, {bool bar = false}) {
    if (total == 0) return Text('$label · 暂无已判题目');
    final rate = passed / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$label  $passed/$total · ${(rate * 100).toStringAsFixed(1)}%'),
      if (bar) Padding(padding: const EdgeInsets.symmetric(vertical: 6),
        child: LinearProgressIndicator(value: rate)),
    ]);
  }

  List<Widget> _groupRows(String kind, Map values) {
    final entries = values.entries.toList();
    int compareLabel(MapEntry a, MapEntry b) => a.key.toString().compareTo(b.key.toString());
    double rate(MapEntry e) => e.value['total'] == 0 ? 0 : e.value['passed'] / e.value['total'];
    if (kind == 'content_tags') {
      entries.sort((a,b) {
        final cmp = rate(a).compareTo(rate(b));
        return cmp == 0 ? compareLabel(a,b) : cmp;
      });
    } else if (kind == 'interval_days') {
      entries.sort((a,b) => int.parse(a.key.toString()).compareTo(int.parse(b.key.toString())));
    }
    return [for (final e in entries) Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: _score(kind == 'interval_days' ? (e.key.toString() == '0' ? '当天' : '隔 ${e.key} 天') : e.key.toString(),
        e.value['passed'] as int, e.value['total'] as int, bar: kind == 'interval_days'),
    )];
  }
  @override
  Widget build(BuildContext context){
    final run=OfficialMemoryExam(suite,(_){});
    final summary=status['summary'] as Map? ?? {};
    final complete=status['state']=='completed';
    final state={'completed':'已完成','paused':'已暂停','running':'上次运行中断','error':'中断，可继续'}[status['state']];
    return PopScope(canPop:!busy,child:Scaffold(appBar:AppBar(title:const Text('原版聊天记忆评测 1.0')),body:ListView(
      padding:const EdgeInsets.all(16),children:[
        SegmentedButton<String>(segments:const [ButtonSegment(value:'demo',label:Text('示例卷 108 题')),
          ButtonSegment(value:'formal',label:Text('正式卷 714 题'))],selected:{suite},onSelectionChanged:busy?null:(v){
          setState((){suite=v.single;loading=true;status={};stage='';});_load();}),
        const SizedBox(height:16),Text(suite=='demo'?'1 个人物，27 组事实，每组在 4 个时间点提问。':'6 个人物独立建立记忆，每道题只开放指定截止轮之前的历史。'),
        const SizedBox(height:8),Text('首次完整运行最多整理 ${run.turnLimit} 轮历史，另外有 ${run.total} 次正文作答和 ${run.total} 次语义判分，重试可能增加调用。整理和裁判走第一通道，作答沿当前正文通道。'),
        const SizedBox(height:8),const Text('只使用原卷的合成历史。可以暂停并继续，已保存的回答会直接进入判分。'),
        const SizedBox(height:16),
        if(busy)...[const LinearProgressIndicator(),Text(stopping?'正在保存进度':stage),
          TextButton(onPressed:stopping?null:(){setState(()=>stopping=true);active?.stop();},child:const Text('暂停'))]
        else ...[
          if(!complete) FilledButton(onPressed:loading?null:()=>_run(fresh:false),child:Text(status.isEmpty?'开始本卷（会产生 API 费用）':'继续本卷')),
          if(status.isNotEmpty)...[
            Text('${state??'已保存'} · 已整理 ${status['turns']} 轮 · 已答 ${status['answered']} / ${run.total}'),
            _score(complete ? '总通过率' : '已判题目通过率', summary['passed'] as int? ?? 0, status['judged'] as int? ?? 0, bar: true),
            if(status['error']!=null)Text('上次停在 ${status['stage']}（${status['error']}）'),
            Text('已估算 ¥${((status['cny']??0) as num).toStringAsFixed(5)}'
              '${(status['unknown']??0)>0?'，另有 ${status['unknown']} 笔未计价':''}'),
            if(status['balance_after'] case final String b) Text(b),
            if(summary['groups'] case final Map groups)
              for(final group in groups.entries) ExpansionTile(
                title:Text({'persona':'按人物','content_tags':'按考点','interval_days':'按间隔天数'}[group.key]??group.key.toString()),
                children:_groupRows(group.key.toString(),group.value as Map)),
            OutlinedButton(onPressed:_export,child:const Text('导出报告和逐题证据（压缩 JSON）')),
            TextButton(onPressed:()=>_run(fresh:true),child:const Text('重新开始本卷')),
          ],
        ],
    ])));
  }
}
