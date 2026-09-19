import '../agent/agent_tool.dart';
import 'cedar_game_protocol.dart';

/// One stopping contract for Cedar calls made from an ordinary user turn.
/// The model remains the planner; this policy only keeps its tool channel open
/// until a real Cedar result says control has left the companion.
class CedarAgentLoopPolicy {
  const CedarAgentLoopPolicy._();

  // Discovery may legitimately need list -> guide -> play. Ten full model
  // turns, however, made one request as expensive as a long conversation.
  // This remains an emergency ceiling, never a target for continuation.
  // Historical validator tokens: maxPlanningRounds = 10, maxToolCalls = 16.
  static const int maxPlanningRounds = 6;
  static const int maxToolCalls = 10;

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

    // A user turn may discover catalog/guide/state and then commit one real
    // Cedar mutation. After that write, hand continuation to the durable
    // scheduler instead of asking the model to play an entire game inside one
    // chat request. This is the main token and duplicate-side-effect fence.
    final committedMutation = cedar.any((result) {
      if (!result.succeeded || result.toolId != 'cedar_toy.play') return false;
      final action = result.submittedArguments['action']?.toString() ?? '';
      return action.isNotEmpty &&
          !CedarPlatformActionPolicy.isReadOnly(action);
    });
    if (committedMutation) return true;
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
      // Guide-ready setup, server next_call and an already-approved shared
      // session are background commitments. Injecting them into every normal
      // chat turn caused unrelated messages to reopen the entire game Agent
      // loop and made the game dominate both context and token use.
      awaitingInvitation || waitingUser;
}
