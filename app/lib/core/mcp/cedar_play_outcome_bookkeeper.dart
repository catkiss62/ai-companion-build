import 'dart:convert';

import '../database/app_database.dart';
import '../desire/desire_satisfaction_ledger.dart';
import '../desire/fatigue_affect_controller.dart';
import '../models/desire_state.dart';
import 'cedar_game_protocol.dart';
import 'cedar_solo_episode_policy.dart';
import 'cedar_toy_activity.dart';
import 'mcp_protocol.dart';

enum CedarPlayBookkeepingOrigin { userTurn, autonomous }

/// Owns the durable consequences of a real Cedar outcome, regardless of
/// whether the move came from the foreground Agent or the background clock.
/// The remote write is already committed when this runs, so every local write
/// is best-effort and must never cause the move to be replayed.
class CedarPlayOutcomeBookkeeper {
  const CedarPlayOutcomeBookkeeper(this.db);

  static const soloEpisodeKey = 'cedar_toy_solo_episode_v1';
  static const antiAddictionKey = 'cedar_toy_last_anti_addiction_v1';

  final AppDatabase db;

  static CedarSoloEpisodeState episodeForOutcome({
    required CedarSoloEpisodeState stored,
    required DateTime now,
    required bool isStateChange,
    required CedarPlayBookkeepingOrigin origin,
  }) {
    final due = CedarSoloEpisodePolicy.checkpointIfDue(stored, now);
    return origin == CedarPlayBookkeepingOrigin.userTurn &&
            isStateChange &&
            due.checkpointPending
        ? CedarSoloEpisodePolicy.start(stored.gameId, now)
        : stored;
  }

  Future<CedarSoloEpisodeState?> loadSoloEpisode() async {
    final raw = await db.getSetting(soloEpisodeKey) ?? '';
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final state = CedarSoloEpisodeState.fromJson(decoded);
      return state.gameId.trim().isEmpty ? null : state;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSoloEpisode(CedarSoloEpisodeState state) =>
      db.setSetting(soloEpisodeKey, jsonEncode(state.toJson()));

  Future<void> clearSoloEpisode() => db.setSetting(soloEpisodeKey, '');

  Future<CedarSoloEpisodeState> currentSoloEpisode({
    required CedarGameSession session,
    required DateTime now,
  }) async =>
      CedarSoloEpisodePolicy.ensureCurrent(
        current: await loadSoloEpisode(),
        gameId: session.gameId,
        now: now,
      );

  Future<void> record({
    required DateTime now,
    required CedarGameSession session,
    required String action,
    required McpToolOutcome outcome,
    required CedarPlayBookkeepingOrigin origin,
  }) async {
    final successfulStateChange =
        !outcome.isError && CedarSoloEpisodePolicy.isStateChangingAction(action);
    final realtime = (session.mode.supportsSharedParticipation &&
            session.invitationApproved) ||
        session.hasPendingRoomMessage ||
        session.ownRoomAliases.isNotEmpty;
    if (realtime || !session.phase.continuable) {
      await _bestEffort(clearSoloEpisode);
    } else {
      await _bestEffort(() async {
        final stored = await currentSoloEpisode(session: session, now: now);
        // A foreground instruction may resume from an old autonomous rest
        // checkpoint, but subsequent moves in the same foreground turn must
        // keep accumulating in that fresh episode instead of resetting it.
        final current = episodeForOutcome(
          stored: stored,
          now: now,
          isStateChange: successfulStateChange,
          origin: origin,
        );
        final signal = CedarAntiAddictionParser.inspect(outcome, now: now);
        final next = CedarSoloEpisodePolicy.recordOutcome(
          state: current,
          now: now,
          action: action,
          succeeded: !outcome.isError,
          antiAddiction: signal,
        );
        await saveSoloEpisode(next);
        await db.setSetting(
          antiAddictionKey,
          jsonEncode(<String, Object?>{
            'level': signal.level.name,
            'source': signal.source,
            'allowSelfReset': signal.allowSelfReset,
            'resumeAt': signal.resumeAt?.millisecondsSinceEpoch ?? 0,
            'checkpointPending': next.checkpointPending,
            'origin': origin.name,
            'at': now.millisecondsSinceEpoch,
          }),
        );
      });
    }

    if (!successfulStateChange) return;
    await _bestEffort(() async {
      final desire = await db.loadDesire();
      await FatigueAffectController(db).recordAutonomousExertion(
        bodyFatigue: desire.drives[DriveKey.fatigue] ?? 0.0,
        source: origin == CedarPlayBookkeepingOrigin.userTurn
            ? 'cedar_game_user_turn'
            : 'cedar_game_step',
        now: now,
        weight: 0.45,
      );
    });
    await _bestEffort(() => DesireSatisfactionLedgerController(db).record(
          drive: DriveKey.curiosity,
          action: 'play_game',
          source: 'mcp/cedar_game:${session.gameId}',
          now: now,
        ));
  }

  Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // A bookkeeping failure cannot make a committed remote mutation retry.
    }
  }
}
