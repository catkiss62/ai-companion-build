import 'dart:convert';

import '../database/app_database.dart';
import '../models/desire_state.dart';
import 'cedar_game_protocol.dart';
import 'cedar_toy_activity.dart';

/// Judgement piggybacks on the existing game planner. Round eligibility and
/// delivery acknowledgements are local and require no additional model call.
class CedarLiveSharePolicy {
  CedarLiveSharePolicy(this.db);
  final AppDatabase db;
  static const key = 'cedar_live_share_v1';
  static const cadenceKey = 'cedar_live_share_cadence_v1';

  static List<CedarGameEvent> evidence(
    CedarGameSession session,
    DateTime now,
  ) => session.events
      .where(
        (event) =>
            event.kind == 'outcome' &&
            !CedarPlatformActionPolicy.isReadOnly(event.action) &&
            !CedarPlatformActionPolicy.isPlatformAction(event.action) &&
            !CedarPlatformActionPolicy.isResultSnapshot(event.action) &&
            !const {'wait', 'poll'}.contains(event.action) &&
            !now.isBefore(event.createdAt) &&
            now.difference(event.createdAt) <= const Duration(hours: 1),
      )
      .toList();

  Future<Map<String, dynamic>> _readMap(String setting) async {
    try {
      final raw = jsonDecode(await db.getSetting(setting) ?? '{}');
      return raw is Map ? raw.cast<String, dynamic>() : {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _states() => _readMap(key);

  Future<void> _save(
    CedarGameSession session,
    Map<String, dynamic> value,
  ) async {
    final states = await _states();
    states.remove(session.id);
    states[session.id] = value;
    while (states.length > 20) {
      states.remove(states.keys.first);
    }
    await db.setSetting(key, jsonEncode(states));
  }

  Future<Map<String, dynamic>> _state(CedarGameSession session) async {
    final value = (await _states())[session.id];
    return value is Map ? value.cast<String, dynamic>() : {};
  }

  Future<bool> intervalElapsed() async {
    final store = CedarToyActivityStore(db);
    final rounds = (await store.loadState()).completedPlayRounds;
    final cadence = await _readMap(cadenceKey);
    final deliveredAt = (cadence['deliveredRound'] as num?)?.toInt() ?? 0;
    return rounds - deliveredAt >=
        (await store.currentViewingPace()).shareRounds;
  }

  static bool isResultReport(String thoughtId, String source) =>
      thoughtId.startsWith('cedar-report:') ||
      source.contains(':terminal:') ||
      source.contains(':task:');

  /// Also covers pre-upgrade per-step messages that are still in the queue.
  Future<bool> deliveryAllowed(String thoughtId, String source) async =>
      isResultReport(thoughtId, source) ||
      (await db.getSetting('cedar_toy_game_share_enabled') != '0' &&
          await intervalElapsed());

  String _freshText(List<CedarGameEvent> events, Map<String, dynamic> state) {
    final sharedIndex = events.indexWhere(
      (e) => e.id == state['sharedThrough'],
    );
    return events
        .skip(sharedIndex + 1)
        .map(
          (event) =>
              '${event.action}: ${event.summary.substring(0, event.summary.length.clamp(0, 500).toInt())}',
        )
        .join('\n');
  }

  Future<String> planningContext(CedarGameSession session, DateTime now) async {
    final state = await _state(session);
    final events = evidence(session, now);
    return '【过程分享判断资料】${jsonEncode({
          'minimum_rounds': (await CedarToyActivityStore(db).currentViewingPace()).shareRounds,
          'interval_elapsed': await intervalElapsed(),
          'saved_outcomes': events.map((event) => {'id': event.id, 'action': event.action, 'at': event.createdAt.toIso8601String(), 'text': event.summary.substring(0, event.summary.length.clamp(0, 1000).toInt())}).toList(),
          'last_evaluated_event': state['evaluated'] ?? '',
          'already_shared_or_shown': state['shown'] ?? '',
          'pending_share': state['pending'] ?? '',
        })}\n'
        'share_previous_outcome只判断已保存结果中的新发现、明显变化、有趣遭遇或阶段进展。'
        '间隔未到、没有值得分享的内容或已有待发分享时填false；达到轮数也不自动播报。'
        '可把尚未分享的多步重要变化合并成一条自然感受，避免流水账和重复。'
        '不得把计划动作或尚未返回的结果当已发生；分享决定不影响下一步游戏动作。';
  }

  Future<void> noteForeground(CedarGameSession session) async {
    if (session.events.isEmpty) return;
    final state = await _state(session);
    await _save(session, {
      ...state,
      'evaluated': session.events.last.id,
      'sharedThrough': session.events.last.id,
      'shown': session.lastOutcome.substring(
        0,
        session.lastOutcome.length.clamp(0, 2500).toInt(),
      ),
    });
  }

  /// Call only after the assistant message has committed. Recovered duplicate
  /// acknowledgements must not move the interval's start to a later round.
  Future<void> noteDelivered(String thoughtId) async {
    final thought = await db.thoughtById(thoughtId);
    if (thought == null ||
        await db.messageById('cedar-share:$thoughtId') == null)
      return;
    if (isResultReport(thoughtId, thought.source)) {
      await _noteReportDelivered(thought.source, thought.bornAt);
      return;
    }
    final cadence = await _readMap(cadenceKey);
    final delivered =
        (cadence['deliveredIds'] as List?)?.cast<String>() ?? <String>[];
    if (!delivered.contains(thoughtId)) {
      delivered.add(thoughtId);
      await db.setSetting(
        cadenceKey,
        jsonEncode({
          'deliveredRound': (await CedarToyActivityStore(
            db,
          ).loadState()).completedPlayRounds,
          'deliveredIds': delivered
              .skip((delivered.length - 32).clamp(0, delivered.length).toInt())
              .toList(),
        }),
      );
    }
    final states = await _states();
    for (final entry in states.entries) {
      if (entry.value is! Map || entry.value['pending'] != thoughtId) continue;
      final state = Map<String, dynamic>.from(entry.value);
      state['shown'] = state['pendingEvidence'] ?? '';
      state['sharedThrough'] = state['pendingThrough'] ?? '';
      state['pending'] = '';
      states[entry.key] = state;
      await db.setSetting(key, jsonEncode(states));
      break;
    }
  }

  // The result report settles earlier progress for its game. A report delayed
  // by a user turn must never consume newer events from a resumed game.
  Future<void> _noteReportDelivered(String source, DateTime through) async {
    final store = CedarToyActivityStore(db);
    for (final session in (await store.loadState()).sessions.values) {
      if (!source.startsWith('mcp/cedar_game:${session.gameId}:')) continue;
      final cleared = <String>{};
      for (final id in await store.pendingDirectShares()) {
        final old = await db.thoughtById(id);
        if (old != null &&
            !isResultReport(id, old.source) &&
            old.source.startsWith('mcp/cedar_game:${session.gameId}:') &&
            !old.bornAt.isAfter(through)) {
          await store.removeDirectShare(id);
          cleared.add(id);
        }
      }
      final state = await _state(session);
      // Thought rows store milliseconds; saved game events can retain
      // microseconds. Include the entire recorded report millisecond so its
      // last outcome is not offered again due only to timestamp truncation.
      final events = evidence(
        session,
        through.add(const Duration(microseconds: 999)),
      );
      final previousIndex = session.events.indexWhere(
        (e) => e.id == state['sharedThrough'],
      );
      final reportIndex = events.isEmpty
          ? -1
          : session.events.indexWhere((e) => e.id == events.last.id);
      await _save(session, {
        ...state,
        if (reportIndex >= 0 && reportIndex >= previousIndex)
          'sharedThrough': events.last.id,
        if (cleared.contains(state['pending'])) 'pending': '',
      });
    }
  }

  /// Freeze a fresh aggregation immediately before generation, preserving the
  /// Thought lifecycle. Later rounds remain unshared until the next interval.
  Future<void> refreshPending(String thoughtId) async {
    final thought = await db.thoughtById(thoughtId);
    if (thought == null || isResultReport(thoughtId, thought.source)) return;
    final store = CedarToyActivityStore(db);
    final sessions = (await store.loadState()).sessions.values;
    for (final session in sessions) {
      if (!thought.source.startsWith('mcp/cedar_game:${session.gameId}:'))
        continue;
      final events = evidence(session, DateTime.now());
      if (events.isEmpty) return;
      final state = await _state(session);
      if ((state['pending']?.toString() ?? '').isNotEmpty &&
          state['pending'] != thoughtId)
        return;
      final text = _freshText(events, state);
      if (text.isEmpty) return;
      final database = await db.database;
      final changed = await database.update(
        'thoughts',
        {'text': '我在“${session.displayName}”有这些已经确认的游戏进展：\n$text'},
        where: 'id = ? AND action_count = 0 AND last_acted_at IS NULL',
        whereArgs: [thoughtId],
      );
      if (changed == 0) return;
      await _save(session, {
        ...state,
        'pending': thoughtId,
        'pendingEvidence': text,
        'pendingThrough': events.last.id,
      });
      // Consolidate obsolete per-step entries left by the previous release.
      for (final queued in await store.pendingDirectShares()) {
        if (queued == thoughtId) continue;
        final old = await db.thoughtById(queued);
        if (old != null &&
            !isResultReport(queued, old.source) &&
            old.source.startsWith('mcp/cedar_game:${session.gameId}:')) {
          await store.removeDirectShare(queued);
        }
      }
      return;
    }
  }

  Future<void> offer(
    CedarGameSession session, {
    required bool share,
    required DateTime now,
  }) async {
    if (await db.getSetting('cedar_toy_game_share_enabled') == '0') return;
    final events = evidence(session, now);
    if (events.isEmpty) return;
    var state = await _state(session);
    final pending = state['pending']?.toString() ?? '';
    if (pending.isNotEmpty) {
      if (await db.messageById('cedar-share:$pending') != null) {
        await noteDelivered(pending);
        state = await _state(session);
      } else {
        final queued = await db.thoughtById(pending);
        if (queued != null &&
            queued.actionCount == 0 &&
            queued.lastActedAt == null &&
            const {'active', 'fixation'}.contains(queued.lifecycleState))
          return;
        // A lifecycle-expired queue entry is not a delivered message. Keep
        // its evidence available for the next eligible share.
        await CedarToyActivityStore(db).removeDirectShare(pending);
        state = {...state, 'pending': ''};
        await _save(session, state);
      }
    }
    // Do not mark evidence evaluated while its interval is closed: a notable
    // earlier discovery must still be available when five/ten rounds accrue.
    if (!await intervalElapsed()) return;
    final latest = events.last;
    if (state['evaluated'] == latest.id && !share) return;
    state['evaluated'] = latest.id;
    final text = _freshText(events, state);
    if (!share || text.isEmpty || text == state['shown']) {
      await _save(session, state);
      return;
    }
    final thoughtId = 'cedar-${latest.id}';
    final old = await db.thoughtById(thoughtId);
    if (old?.lastActedAt != null || (old?.actionCount ?? 0) > 0) {
      await _save(session, state);
      return;
    }
    if (old == null) {
      await db.upsertThought(
        id: thoughtId,
        text: '我在“${session.displayName}”有这些已经确认的游戏进展：\n$text',
        drive: DriveKey.curiosity,
        kind: 'flit',
        strength: .84,
        source: 'mcp/cedar_game:${session.gameId}:${latest.id}',
        topicKey: 'cedar_game:${session.gameId}',
      );
    }
    await CedarToyActivityStore(db).queueDirectShare(thoughtId);
    await _save(session, {
      ...state,
      'pending': thoughtId,
      'pendingEvidence': text,
      'pendingThrough': latest.id,
    });
  }
}
