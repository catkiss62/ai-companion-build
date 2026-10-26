import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'agent_task_loop.dart';
import 'agent_tool.dart';
import '../database/app_database.dart';
import 'agent_runtime_diagnostic.dart';

/// One task owns its progress and evidence across explicit and voluntary entry.
/// Counts are a last resort; an unchanged result is not progress just because
/// a model issued another request. New negative evidence can eliminate a path.
class AgentProgressTracker {
  final _evidence = <String>{};
  final _reads = <String, AgentToolResult>{};
  int stalledRounds = 0;
  int revision = 0;
  bool get stalled => stalledRounds >= 3;

  static String _digest(String value) => sha256.convert(utf8.encode(value)).toString();
  String _key(AgentToolCall call, String state) =>
      '${AgentTaskLoopPolicy.callFingerprint(call)}|$state';

  AgentToolResult? cached(AgentToolCall call, String state) => _reads[_key(call, state)];

  static Future<String?> readState(AppDatabase db, AgentToolCall call) async {
    final id=call.toolId;
    // Evidence-bearing history and device reads need fresh provenance/clock.
    if(id.contains('history.') || id=='device_context.read' || id=='screen_observation.inspect') return null;
    if(id=='system_self.read') {
      if(call.arguments['scope']=='runtime') return _digest(jsonEncode(await AgentRuntimeDiagnostic.read(db)));
      return null;
    }
    final tables=<String>[
      if(id=='rules.read') ...['rule_layers','reference_documents','reference_items'],
      if(id=='memory.search') ...['memory_items','memory_evidence','unfinished_threads','qq_archive','qq_images','qq_notes'],
      if(id.startsWith('phone.')) ...['thoughts','public_web_knowledge','companion_browser_visits','memory_items'],
      if(id=='album.search') 'companion_album_candidates',
    ];
    final sql=await db.database;
    final data=<Object?>[
      await sql.query('settings',columns:['key','value'],
        where:"key IN ('state_generation','conversation_context_reset_at','context_reset_at','cedar_toy_activity_state_v2','cedar_toy_catalog_updated_at_v1') OR key LIKE 'qq_display_names_v1:%'",orderBy:'key'),
    ];
    for(final table in tables) {
      final columns=(await sql.rawQuery('PRAGMA table_info($table)')).map((r)=>r['name']).toSet();
      final clock=columns.contains('updated_at') ? 'updated_at' : columns.contains('created_at') ? 'created_at' : 'rowid';
      data.add(await sql.rawQuery('SELECT COUNT(*) AS n, MAX(rowid) AS r, MAX($clock) AS t ${columns.contains('version')?', SUM(version) AS versions':''} FROM $table'));
    }
    return _digest(jsonEncode(data));
  }

  void rememberRead(AgentToolCall call, String state, AgentToolResult result) {
    // Original-history reads carry final-transaction source dependencies and
    // are always executed again rather than replaying potentially stale text.
    if (result.historySources.isEmpty && result.qqEvidence==null) _reads[_key(call, state)] = result;
  }

  void record(List<AgentToolResult> results) {
    var changed = false;
    for (final result in results) {
      final signature = _digest(jsonEncode([result.toolId, result.status.key,
        result.errorCode, result.submittedArguments, result.promptData]));
      changed = _evidence.add(signature) || changed;
    }
    if (changed) { revision++; stalledRounds = 0; }
    else { stalledRounds++; }
  }

  String get prompt => stalled
      ? '连续三轮没有新的事实或目标进展。本路径结束；依据真实结果说明已完成与未完成部分，不再重复查询或假称执行成功。'
      : stalledRounds == 2
          ? '连续两轮结果没有新增信息。重新核对目标与已知证据，只有能带来新证据的另一条必要路径才继续；需要等待就交还调度。'
          : '依据新事实判断下一步；一次查询无结果也可排除一条路径。目标已完成就结束，不为用完额度继续查。';
}
