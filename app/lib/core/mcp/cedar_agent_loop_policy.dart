import '../agent/agent_tool.dart';

/// One stopping contract for Cedar calls made from an ordinary user turn.
/// The model remains the planner; this policy only keeps its tool channel open
/// until a real Cedar result says control has left the companion.
class CedarAgentLoopPolicy {
  const CedarAgentLoopPolicy._();

  static const int maxPlanningRounds = 10;
  static const int maxToolCalls = 16;

  static bool isCedarResult(AgentToolResult result) =>
      result.toolId.startsWith('cedar_toy.');

  static bool shouldRetryInitialNoCall({
    required bool cedarRequested,
    required bool retryUsed,
    required int remainingCalls,
  }) =>
      cedarRequested && !retryUsed && remainingCalls > 0;

  static bool shouldFinalizeRound({
    required List<AgentToolResult> results,
    required bool proposalExecuted,
    required bool commitPendingMedia,
    required bool loopLimitReached,
  }) {
    if (commitPendingMedia || loopLimitReached) return true;
    final cedar = results.where(isCedarResult).toList(growable: false);
    if (cedar.isEmpty) return proposalExecuted;
    if (cedar.any((result) => result.continuationRecommended)) return false;

    // A successful play without a continuation signal means Cedar handed
    // control to the user/remote side or ended the activity. Failed writes and
    // non-recoverable local blocks also stop instead of replaying a side effect.
    if (cedar.any((result) => result.toolId == 'cedar_toy.play')) return true;

    // list/get_guide are discovery reads. Their executors normally mark them
    // for continuation; keep a defensive open-loop fallback for old/restored
    // results so a read can never be mistaken for completing a play request.
    return false;
  }
}

/// Server-provided continuation is authority to observe the already-created
/// activity. Local participation labels are presentation metadata and must
/// never suppress a real next_call returned by Cedar.
class CedarServerContinuationPolicy {
  const CedarServerContinuationPolicy._();

  static bool authorizesExactAction({
    required String action,
    required String continuationAction,
  }) =>
      action.trim().isNotEmpty && action.trim() == continuationAction.trim();

  static bool canObserve({
    required bool guideComplete,
    required bool phaseContinuable,
    required bool paused,
    required bool hasContinuationCall,
    required String nextActor,
  }) =>
      guideComplete &&
      phaseContinuable &&
      !paused &&
      hasContinuationCall &&
      const <String>{'user', 'shared', 'wait'}.contains(nextActor);

  static bool usesRealtimePace({
    required bool hasContinuationCall,
    required bool hasPendingRoomMessage,
    required bool companionTurn,
  }) =>
      hasContinuationCall || hasPendingRoomMessage || companionTurn;

  static bool needsUserTurnTools({
    required bool guideReady,
    required bool awaitingInvitation,
    required bool waitingUser,
    required bool hasContinuationCall,
    required bool participationActive,
  }) =>
      guideReady ||
      awaitingInvitation ||
      waitingUser ||
      hasContinuationCall ||
      participationActive;
}
