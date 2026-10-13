import 'package:ai_companion_localfirst/core/agent/turn_execution_store.dart';
import 'package:ai_companion_localfirst/core/database/app_database.dart';
import 'package:ai_companion_localfirst/core/database/generation_attempt_fence.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_timed_play_task.dart';
import 'package:ai_companion_localfirst/core/mcp/cedar_toy_activity.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/generation_job.dart';

class StagedCedarTask {
  const StagedCedarTask(this.job, this.attempt, this.effectId, this.at);
  final GenerationJob job;
  final GenerationAttemptFence attempt;
  final String effectId;
  final DateTime at;
}

/// Exercise the production authorization and ownership path. No test flag may
/// turn an arbitrary assistant message into a committed registration ticket.
Future<StagedCedarTask> stageCedarTask(AppDatabase db, {
  required CedarGameSession session,
  required String turnId,
  required String assistantId,
  required int minutes,
  DateTime? now,
}) async {
  final at = now ?? DateTime.now();
  final pending = await db.createGenerationTurn(
    user: ChatMessage(id: turnId, role: 'user',
      content: '请玩${session.displayName}$minutes分钟。', createdAt: at),
    assistantMessageId: assistantId, model: 'deepseek-v4-flash', reasoningEffort: 'high');
  final job = (await db.claimGenerationJob(pending.id))!;
  final attempt = (await db.captureGenerationAttemptFence(job))!;
  final goal = TurnTaskGoal(turnId: turnId, slot: TurnEffectSlot.cedarTimedRegistration,
    description: '明确的指定时长任务', target: {'game_id': session.gameId, 'session_id': session.id,
      'user_control_revision': (await TurnExecutionStore(db).originalUserControlRevision(turnId))!},
    durationText: '$minutes分钟', minutes: minutes);
  if (!await TurnExecutionStore(db).saveGoals(attempt, [goal])) {
    throw StateError('test_goal_not_saved');
  }
  final result = await CedarTimedPlayTaskStore(db).stage(turnId: turnId,
      assistantId: assistantId, session: session, minutes: minutes,
      attemptFence: attempt, goalId: goal.id, effectId: goal.id, now: at);
  if (!result.canCreate && result.state != LocalEffectAdmissionState.replay) {
    throw StateError('test_task_stage_${result.state.name}');
  }
  return StagedCedarTask(job, attempt, goal.id, at);
}

Future<bool> commitCedarTask(AppDatabase db, StagedCedarTask staged, {
  String content = '好，我按你指定的时间玩，结束后告诉你。',
  bool Function()? isCancelled,
}) async {
  try {
    return await db.completeGenerationJobIfCurrent(jobId: staged.job.id,
        runToken: staged.job.runToken, generationAttempt: staged.attempt,
        turnCommitEvidence: TurnCommitEvidence(timedEffectIds: [staged.effectId]),
        isCancelled: isCancelled, assistant: ChatMessage(id: staged.job.assistantMessageId,
          role: 'assistant', content: content, createdAt: staged.at));
  } on TurnCommitRejected {
    return false;
  } on TurnCommitCancelled {
    return false;
  }
}

/// Models the winning message transaction after the final semantic verifier
/// has explicitly accepted this responsibility. Other tests omit the claim to
/// prove that message existence or unrelated content cannot acknowledge it.
Future<void> commitCedarDelivery(AppDatabase db, CedarDeliveryClaim claim, {
  required String messageId,
  String? content,
}) async {
  final now = DateTime.now();
  final pending = await db.createGenerationTurn(user: ChatMessage(
    id: 'request-$messageId', role: 'user', content: '告诉我这次具体结果。', createdAt: now),
    assistantMessageId: messageId, model: 'deepseek-v4-flash', reasoningEffort: 'high');
  final job = (await db.claimGenerationJob(pending.id))!;
  final attempt = (await db.captureGenerationAttemptFence(job))!;
  if (!await db.completeGenerationJobIfCurrent(jobId: job.id, runToken: job.runToken,
      generationAttempt: attempt, turnCommitEvidence: TurnCommitEvidence(deliveries: [claim]),
      assistant: ChatMessage(id: messageId, role: 'assistant',
        content: content ?? claim.summary, createdAt: now))) {
    throw StateError('test_delivery_not_committed');
  }
}
