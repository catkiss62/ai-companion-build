import '../database/app_database.dart';
import '../agent/turn_execution_store.dart';
import 'cedar_play_session_policy.dart';
import 'cedar_timed_play_task.dart';
import 'cedar_toy_activity.dart';

/// Read-only projection. Opening the activity window never grants play time
/// or runs recovery, and an absent runtime clock is not a running game.
class CedarTaskPresentation {
  const CedarTaskPresentation(this.label, this.detail, {this.historical=false});
  final String label;
  final String detail;
  final bool historical;

  static String duration(int milliseconds) {
    final seconds = (milliseconds.clamp(0, CedarPlaySession.budgetMs) / 1000).ceil();
    return '${seconds ~/ 60}分${(seconds % 60).toString().padLeft(2, '0')}秒';
  }

  static CedarTaskPresentation? project({
    required String gameId,
    required CedarGameSession? session,
    required Map<String, dynamic>? pending,
    required Map<String, dynamic>? active,
    required CedarPlaySession? clock,
    required List<Map<String, dynamic>> reports,
    required bool brainAllowed,
    required bool chatBusy,
    required DateTime now,
    Map<String, dynamic>? diagnostic,
    LocalEffectReceipt? pendingReceipt,
  }) {
    bool matches(Map<String, dynamic>? task) => task != null &&
        task['gameId'] == gameId && (session == null || task['sessionId'] == session.id);
    if (matches(pending) && pendingReceipt?.result.containsKey('activationState') != true) {
      final ticket = pending!['commitTicket'];
      final committed = pendingReceipt?.committed == true && ticket is Map &&
          pendingReceipt!.effectId == pending['effectId'] &&
          pendingReceipt.payloadHash == pending['payloadHash'] &&
          pendingReceipt.result['stageHash'] == pending['stageHash'] &&
          CedarTimedPlayTaskStore.stageHash(pending) == pending['stageHash'] &&
          ticket['effectId'] == pendingReceipt.effectId &&
          ticket['messageId'] == pendingReceipt.messageId &&
          ticket['messageHash'] == pendingReceipt.messageHash &&
          ticket['messageRevision'] == pendingReceipt.messageRevision;
      return CedarTaskPresentation(committed ? '已登记 · 待启动' : '待回复提交',
          '计划${pending['minutes']}分钟；${committed ? '已接受任务，等待执行器启动。' : '本轮回复尚未正式提交，计时未开始。'}');
    }
    if (matches(active)) {
      final task = active!;
      final limit = ((task['minutes'] as num?)?.toInt() ?? 0) * 60000;
      var used = (task['usedMs'] as num?)?.toInt() ?? 0;
      final validClock = clock != null && clock.taskId == task['id'] &&
          clock.gameId == gameId;
      if (validClock && clock.usedMs > used) used = clock.usedMs;
      final remaining = (limit - used).clamp(0, limit.clamp(0, CedarPlaySession.budgetMs)).toInt();
      final timing = '有效剩余 ${duration(remaining)} · 已计时 ${duration(used)}';
      if((task['blockReason']?.toString() ?? '').isNotEmpty || diagnostic?['phase']=='blocked') {
        return CedarTaskPresentation('推进受阻 · 暂停计时',
          '$timing\n正在核对旧操作或等待执行条件恢复；连续失败会如实结束并回报。');
      }
      if (session?.phase == CedarActivityPhase.paused &&
          session?.pauseSource != 'remote_wait_unroutable') {
        return CedarTaskPresentation('已停止 · 待整理结果',
            '已计时 ${duration(used)}；本次剩余时长不再继续。');
      }
      if (remaining == 0 || session?.phase == CedarActivityPhase.completed ||
          session?.phase == CedarActivityPhase.failed || session?.nextActor == 'finished') {
        return CedarTaskPresentation('已结束 · 待整理结果', '已计时 ${duration(used)}');
      }
      if (!brainAllowed || chatBusy) {
        return CedarTaskPresentation('暂缓推进', '$timing\n当前等待恢复可用状态。');
      }
      if (!validClock || now.isBefore(clock.lastTickAt) ||
          now.difference(clock.lastTickAt) > CedarPlaySession.observedTaskGap) {
        return CedarTaskPresentation('恢复中', '$timing\n离线或中断时间不计入游玩时长。');
      }
      if (clock.paused || session?.needsContinuation != true) {
        return CedarTaskPresentation('等待继续', '$timing\n等待你的操作或游戏返回，此时不计时。');
      }
      if (((task['progressCount'] as num?)?.toInt() ?? 0) == 0) {
        return CedarTaskPresentation('待启动 · 已开始计时', '$timing\n尚未记录本次任务的首次游戏推进。');
      }
      return CedarTaskPresentation('正在玩', '$timing\n按最近一次有效计时更新。');
    }
    final report = reports.where(matches).lastOrNull;
    if (report != null) {
      return CedarTaskPresentation('已结束 · 待回报',
          '实际计时 ${duration((report['usedMs'] as num?)?.toInt() ?? 0)}；结果尚待送达。');
    }
    // Delivered historical tasks belong to history, not the current timer.
    // The last diagnostic survives indefinitely and is never a running task.
    if (diagnostic?['terminal'] == true && diagnostic?['game_id'] == gameId &&
        diagnostic?['session_id'] == session?.id) {
      return CedarTaskPresentation('上一时长任务已结束',
          '实际计时 ${duration((diagnostic?['used_ms'] as num?)?.toInt() ?? 0)}；本次任务不再续计。',historical:true);
    }
    return null;
  }

  static Future<CedarTaskPresentation?> load(AppDatabase db,
      CedarGameSession session, {DateTime? now}) async {
    final tasks = CedarTimedPlayTaskStore(db);
    final pending = CedarTimedPlayTaskStore.decode(await db.getSetting(CedarTimedPlayTaskStore.pendingKey));
    return project(gameId: session.gameId, session: session,
        pending: pending,
        pendingReceipt: pending == null ? null : await TurnExecutionStore(db).readEffect(
            pending['turnId']?.toString() ?? '', TurnEffectSlot.cedarTimedRegistration),
        active: await tasks.active(), clock: await CedarPlaySessionStore(db).load(),
        reports: await tasks.pendingReports(), brainAllowed: await db.brainWorkAllowed(),
        diagnostic: CedarTimedPlayTaskStore.decode(await db.getSetting(CedarTimedPlayTaskStore.diagnosticKey)),
        chatBusy: await db.isLocalLeaseHeld('chat_turn_lease'), now: now ?? DateTime.now());
  }
}
