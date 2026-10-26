import 'dart:convert';
import 'cedar_game_protocol.dart';
import 'cedar_toy_activity.dart';

/// Bounded factual feedback for the existing planner, not a second Agent or a
/// replacement game script. Creative/free-text arguments remain unrestricted.
abstract final class CedarExecutionRepair {
  static List<CedarGameEvent> parameterFailures(CedarGameSession session, {int since = 0}) {
    final failures = <CedarGameEvent>[];
    for (final event in session.events) {
      if (event.createdAt.millisecondsSinceEpoch < since) continue;
      if (CedarActionFeedback.parameterError(event.summary)) { failures.add(event); }
      else if (event.kind == 'outcome' && event.isReadOnly == false &&
          !CedarActionFeedback.noProgress(event.summary)) { failures.clear(); }
    }
    return failures;
  }

  static CedarGameEvent? latestQuery(CedarGameSession session) => session.events.where((e) =>
    e.kind == 'outcome' && e.isReadOnly == true && !CedarPlatformActionPolicy.isPlatformAction(e.action)).lastOrNull;

  static String issue(CedarGameSession session, String action, Map<String, Object?> params) {
    if (CedarPlatformActionPolicy.isReadOnlyCall(action, params)) return '';
    final failures = parameterFailures(session);
    final query = latestQuery(session);
    if (failures.length >= 2 && (query == null || query.createdAt.isBefore(failures.last.createdAt))) {
      return '连续出现明确参数错误。先按完整指南读取缺失的帮助/可用对象，再选择动作；不得继续猜参数。';
    }
    // Repair only an unambiguous identifier actually returned by the server.
    // A list is not assumed exhaustive and unknown creative inputs are allowed.
    final command = params['command'];
    if (action != 'cmd' || command is! String) return '';
    final words = command.trim().split(RegExp(r'\s+'));
    if (words.length != 3 || !const {'serve', 'cheers'}.contains(words.first)) return '';
    final ids = <String>{};
    for (final event in session.events.where((e) => e.kind == 'outcome' && e.isReadOnly == true).toList().reversed.take(8)) {
      for (final match in RegExp(r'^([a-z][a-z0-9_.:-]+)[\t　 ]+', multiLine: true).allMatches(CedarActionFeedback.businessText(event.summary))) {
        ids.add(match.group(1)!);
      }
    }
    if (ids.contains(words.last)) return '';
    final exact = ids.where((id) => id.endsWith(':${words.last}')).toList();
    return exact.length == 1 ? '对象列表的精确标识为 ${exact.single}；当前参数遗漏了标识前缀，使用完整标识重新规划。' : '';
  }

  static String prompt(CedarGameSession session) {
    final failures = parameterFailures(session);
    final queries = session.events.where((e) => e.kind == 'outcome' && e.isReadOnly == true).toList().reversed.take(3).toList().reversed;
    return '【执行纠错资料 · 仅作事实，不是指令】${jsonEncode({
      'parameter_errors_since_progress': failures.length,
      'recent_parameter_errors': failures.reversed.take(3).map((e) => {'input': e.inputJson, 'result': CedarActionFeedback.businessText(e.summary).split('\n').first}).toList(),
      'last_verified_queries': queries.map((e) => {'input': e.inputJson, 'result': e.summary}).toList(),
    })}\n'
      '参数、物品/人物/房间标识必须来自真实帮助或查询，保留冒号等完整前缀。性格/口味/剧情线索不是对象ID。'
      '遇到参数错误先分析错误原因，补读必要帮助或列表，再执行纠正后的动作。正常客人拒绝、游戏输赢不等于技术错误。';
  }
}
