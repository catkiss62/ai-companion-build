import '../mcp/cedar_game_protocol.dart';
import 'agent_tool.dart';
import 'turn_execution_contract.dart';

class TurnGoalVerification {
  const TurnGoalVerification._();
  static bool foregroundWrite(AgentToolResult result) {
    if (!result.succeeded || result.toolId != 'cedar_toy.play') return false;
    final action = result.submittedArguments['action']?.toString() ?? '';
    final params = result.submittedArguments['params'];
    return action.isNotEmpty && (!CedarPlatformActionPolicy.isReadOnly(action) ||
      (params is Map && params['message']?.toString().trim().isNotEmpty == true));
  }
  static List<TurnTaskGoal> missing(List<TurnTaskGoal> goals,
      List<AgentToolResult> results, Iterable<LocalEffectReceipt> receipts) {
    return goals.where((goal) {
      if (!goal.authorized) return true;
      if (goal.slot != TurnEffectSlot.cedarForegroundWrite) {
        return !receipts.any((r) => r.effectId == goal.id && _matches(goal, r) &&
          (r.committed || (r.slot == TurnEffectSlot.cedarTimedRegistration &&
            !r.result.containsKey('cancelledReason'))));
      }
      final game = goal.target['game_id'] ?? '';
      if (game.isEmpty) return true;
      // Accepting the explicit timed task hands actual play to the existing
      // background owner. A valid staged receipt supports that handoff only,
      // never a claim that any remote game move has already happened.
      if (receipts.any((r) => r.slot == TurnEffectSlot.cedarTimedRegistration && r.turnId == goal.turnId &&
          r.result['gameId'] == game &&
          !r.result.containsKey('cancelledReason') &&
          (r.committed || r.result['stageHash'] != null))) return false;
      return !results.any((r) => foregroundWrite(r) &&
        r.submittedArguments['game'] == game);
    }).toList();
  }
  static bool _matches(TurnTaskGoal goal, LocalEffectReceipt receipt) {
    for (final entry in goal.target.entries) {
      if (const {'target_kind', 'user_control_revision'}.contains(entry.key) || entry.value.isEmpty || (goal.slot == TurnEffectSlot.creativeCommission && entry.key == 'request_id')) continue;
      final value = receipt.result[entry.key] ?? receipt.result[switch(entry.key) {
        'game_id' => 'gameId', 'session_id' => 'sessionId', 'operation' => 'action', _ => entry.key}];
      if (value != entry.value) return false;
    }
    return goal.slot != TurnEffectSlot.cedarTimedRegistration || receipt.result['minutes'] == goal.minutes;
  }
  static String describe(List<TurnTaskGoal> missing) => missing.isEmpty
    ? '本轮明确任务目标均有相应真实执行证据；定时任务登记只证明后台接管，不能说已产生游戏进度；不要把工具结果扩写成未发生的后续完成。'
    : '本轮仍未获得执行证据的目标：${missing.map((g) => g.description).join('；')}。'
      '普通开局、读指南或成功查询不等于登记了定时任务。不得承诺这些目标已经完成、开始计时或已交付；'
      '如果仍有允许的必要工具步骤，可在预算内补齐，否则自然说明具体未完成部分。';
}
