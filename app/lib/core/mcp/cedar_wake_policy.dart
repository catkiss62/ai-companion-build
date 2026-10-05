import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../desire/daily_wake_store.dart';
import 'cedar_play_session_policy.dart';
import 'cedar_timed_play_task.dart';
import 'cedar_toy_activity.dart';

/// Blocks optional background play and its queued shares before today's wake.
/// Foreground Agent actions do not use this policy. Explicit timed tasks and
/// current shared turns retain their existing user-requested route.
abstract final class CedarWakePolicy {
  static Future<Duration> delay(
    DatabaseExecutor db,
    DateTime now, {
    String? gameId,
    String? thoughtId,
  }) async {
    final wake = await DailyWakeStore.read(db, now);
    if (!wake.beforeWake(now)) return Duration.zero;
    if (thoughtId?.startsWith('cedar-report:') == true) return Duration.zero;
    final rows = await db.query(
      'settings',
      columns: ['key', 'value'],
      where: 'key IN (?, ?, ?)',
      whereArgs: [
        CedarToyActivityStore.stateSettingKey,
        CedarPlaySessionStore.key,
        CedarTimedPlayTaskStore.activeKey,
      ],
    );
    final values = {for (final row in rows) row['key']: row['value']};
    CedarGameSession? session;
    try {
      session = CedarToyActivityState.fromJson(
        jsonDecode(
          values[CedarToyActivityStore.stateSettingKey] as String? ?? '{}',
        ),
      ).activeSession;
    } catch (_) {
      /* No current game means no requested-play exemption. */
    }
    if (session != null && (gameId == null || gameId == session.gameId)) {
      final period = CedarPlaySession.decode(
        values[CedarPlaySessionStore.key] as String?,
      );
      final task = CedarTimedPlayTaskStore.decode(
        values[CedarTimedPlayTaskStore.activeKey] as String?,
      );
      if (period != null &&
          !period.paused &&
          period.taskId.isNotEmpty &&
          period.validAt(now, session.gameId) &&
          task?['id'] == period.taskId &&
          task?['sessionId'] == session.id &&
          !now.isBefore(period.lastTickAt) &&
          now.difference(period.lastTickAt) <=
              CedarPlaySession.observedTaskGap) {
        return Duration.zero;
      }
      // Preserve an unfinished, explicitly accepted shared protocol turn.
      // Completed/paused sessions and an old viewing preference are not a
      // general permission to begin unrelated autonomous play.
      final fresh =
          !now.isBefore(session.updatedAt) &&
          now.difference(session.updatedAt) <= const Duration(minutes: 30);
      final shared =
          session.mode.supportsSharedParticipation &&
          session.invitationApproved;
      if ((session.needsContinuation &&
              (shared ||
                  session.hasPendingRoomMessage ||
                  (fresh && session.ownRoomAliases.isNotEmpty))) ||
          (shared && fresh && session.hasPendingTerminalDelivery)) {
        return Duration.zero;
      }
    }
    return wake.wakeAt.difference(now);
  }
}
