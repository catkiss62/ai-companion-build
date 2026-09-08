import 'agent_tool.dart';
import 'agent_tool_registry.dart';

enum AgentTaskVerificationState {
  directAnswer,
  supported,
  partiallySupported,
  noResult,
  failed,
  blocked,
  budgetExhausted,
  invalidPlan,
}

extension AgentTaskVerificationStateKey on AgentTaskVerificationState {
  String get key => switch (this) {
        AgentTaskVerificationState.directAnswer => 'direct_answer',
        AgentTaskVerificationState.supported => 'supported',
        AgentTaskVerificationState.partiallySupported => 'partially_supported',
        AgentTaskVerificationState.noResult => 'no_result',
        AgentTaskVerificationState.failed => 'failed',
        AgentTaskVerificationState.blocked => 'blocked',
        AgentTaskVerificationState.budgetExhausted => 'budget_exhausted',
        AgentTaskVerificationState.invalidPlan => 'invalid_plan',
      };
}

class AgentTaskVerification {
  const AgentTaskVerification({
    required this.state,
    required this.callCount,
    required this.successCount,
    required this.noResultCount,
    required this.failureCount,
    required this.blockedCount,
  });

  final AgentTaskVerificationState state;
  final int callCount;
  final int successCount;
  final int noResultCount;
  final int failureCount;
  final int blockedCount;

  bool get completionSupported => state == AgentTaskVerificationState.supported;

  String renderForFinalPrompt() => '''
【Agent v2 本地终态核验】
state=${state.key}，calls=$callCount，succeeded=$successCount，no_result=$noResultCount，failed=$failureCount，blocked=$blockedCount。
只有 succeeded 的真实 Outcome 能支持对应操作已经完成；no_result 只支持“查过但没找到”，failed/blocked 只支持如实说明失败或受阻。partially_supported 必须分别说清完成与未完成的部分；budget_exhausted/invalid_plan 表示工具循环已经关闭，不能继续假装执行。不要在正文里复述这些字段、规划轮次或调用日志。
'''.trim();
}

/// Local limits and truth checks for a single user-turn Agent loop.
///
/// This policy never grants a capability. The registry, the original user
/// text and [AgentToolRunner] remain authoritative for every real call.
class AgentTaskLoopPolicy {
  const AgentTaskLoopPolicy._();

  static const int maxPlanningRounds = 3;
  static const int maxToolCalls = 6;
  static const int maxCallsPerRound = 2;

  static int allowedCalls({
    required int planningRounds,
    required int toolCalls,
  }) {
    if (planningRounds >= maxPlanningRounds || toolCalls >= maxToolCalls) {
      return 0;
    }
    final remaining = maxToolCalls - toolCalls;
    return remaining < maxCallsPerRound ? remaining : maxCallsPerRound;
  }

  static bool containsProposal(AgentToolPlan plan) => plan.calls.any(
        (call) =>
            AgentToolRegistry.byId(call.toolId)?.risk != AgentToolRisk.readOnly,
      );

  static bool hasCommitPendingMedia(List<AgentToolResult> results) =>
      results.any(
        (result) => result.succeeded && result.terminalCommitPending,
      );

  static String callFingerprint(AgentToolCall call) {
    final keys = call.arguments.keys.toList()..sort();
    final arguments = keys
        .map((key) => '$key=${call.arguments[key]?.trim() ?? ''}')
        .join('&');
    return '${call.toolId}|$arguments';
  }

  static String planningInstruction({
    required int completedPlanningRounds,
    required int completedToolCalls,
  }) {
    final nextRound = completedPlanningRounds + 1;
    final remainingCalls = maxToolCalls - completedToolCalls;
    return '''
【Agent v2 有界任务循环 · 第 $nextRound/$maxPlanningRounds 个规划回合】
先根据用户原始目标与已有真实工具结果判断：目标已获支持就直接形成最终回答；只有还缺一个可验证步骤时才调用工具。本回合最多选择 $maxCallsPerRound 个彼此必要且不重复的工具，整轮还剩最多 $remainingCalls 次真实调用。
no_result、failed、blocked 不是成功；可以据此改用当前最小工具集合里的另一条合理路径，但不得原样重试同一工具和参数。写入、保存、发送等操作仍必须来自用户原始消息的明确意图；屏幕观察不会提供给模型选择。不要输出计划、参数、调用日志或“接下来我将”的工作汇报。
'''.trim();
  }

  static AgentTaskVerification verify(
    List<AgentToolResult> results, {
    bool budgetExhausted = false,
    bool invalidPlan = false,
  }) {
    var succeeded = 0;
    var noResult = 0;
    var failed = 0;
    var blocked = 0;
    for (final result in results) {
      switch (result.status) {
        case AgentToolStatus.succeeded:
          succeeded++;
          break;
        case AgentToolStatus.noResult:
          noResult++;
          break;
        case AgentToolStatus.failed:
          failed++;
          break;
        case AgentToolStatus.blocked:
          blocked++;
          break;
        case AgentToolStatus.requested:
        case AgentToolStatus.running:
          failed++;
          break;
      }
    }
    final state = invalidPlan
        ? AgentTaskVerificationState.invalidPlan
        : budgetExhausted
            ? AgentTaskVerificationState.budgetExhausted
            : results.isEmpty
                ? AgentTaskVerificationState.directAnswer
                : succeeded == results.length
                    ? AgentTaskVerificationState.supported
                    : succeeded > 0
                        ? AgentTaskVerificationState.partiallySupported
                        : noResult > 0 && failed == 0 && blocked == 0
                            ? AgentTaskVerificationState.noResult
                            : failed > 0
                                ? AgentTaskVerificationState.failed
                                : AgentTaskVerificationState.blocked;
    return AgentTaskVerification(
      state: state,
      callCount: results.length,
      successCount: succeeded,
      noResultCount: noResult,
      failureCount: failed,
      blockedCount: blocked,
    );
  }
}
