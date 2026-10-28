import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../integrations/qq_private/qq_archive_reader.dart';
import '../../integrations/qq_private/qq_failure.dart';
import '../../integrations/qq_private/qq_failure_history.dart';

class QqFailuresPage extends StatefulWidget {
  const QqFailuresPage({super.key, this.database});
  final AppDatabase? database;
  @override State<QqFailuresPage> createState() => _QqFailuresPageState();
}
class _QqFailuresPageState extends State<QqFailuresPage> {
  late Future<List<Map<String,dynamic>>> _rows;
  @override void initState() { super.initState(); _rows = _load(); }
  Future<List<Map<String,dynamic>>> _load() async {
    final db = widget.database ?? AppDatabase.instance;
    final rows = QqFailureHistory.decode(await db.getSetting(QqFailure.historyKey) ?? '[]');
    final reader = QqArchiveReader(await db.database);
    for (final row in rows) {
      final cid = row['conversation'];
      final descriptor = cid is String && cid.isNotEmpty ? await reader.descriptor(cid) : <String,Object?>{};
      row['label'] = descriptor['kind'] == 'group' ? descriptor['name'] ?? '群聊' : descriptor.isEmpty ? 'QQ操作' : '本人私聊';
    }
    return rows;
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title:const Text('QQ 最近错误'), actions:[IconButton(
      tooltip:'刷新',icon:const Icon(Icons.refresh),onPressed:() => setState(() { _rows = _load(); }))]),
    body:FutureBuilder<List<Map<String,dynamic>>>(future:_rows,builder:(context,snapshot) {
      if(snapshot.hasError)return const Center(child:Text('错误记录暂不可读取，可稍后刷新。'));
      if (!snapshot.hasData) return const Center(child:CircularProgressIndicator());
      final rows = snapshot.data!;
      if (rows.isEmpty) return const Center(child:Text('暂无错误记录。旁听和夜间休息不计入错误。'));
      return ListView(children:[const Padding(padding:EdgeInsets.all(16),child:Text('保留最近20次操作。展开可看各次尝试和最终结果。投递未知不会自动重发。')),
        for (final row in rows) ExpansionTile(
          title:Text('${row['label']} · ${QqFailureHistory.phaseName(row['phase'] as String? ?? '')}'),
          subtitle:Text('${DateTime.fromMillisecondsSinceEpoch(row['at'] as int? ?? 0).toLocal()}\n'
            '${QqFailureHistory.explanation(row['code'] as String? ?? '')} · ${QqFailureHistory.outcomeName(row['outcome'] as String? ?? '')}'),
          children:[for (final attempt in (row['attempts'] is List ? row['attempts'] as List : [row]).whereType<Map>())
            ListTile(dense:true,title:Text('${QqFailureHistory.phaseName(attempt['phase'] as String? ?? '')} · 第${attempt['attempt'] ?? 1}次'),
              subtitle:Text(QqFailureHistory.explanation(attempt['code'] as String? ?? 'operation_failed')))],
        ),
      ]);
    }),
  );
}
