import 'dart:convert';

import '../database/app_database.dart';
import '../models/desire_state.dart';
import 'cedar_play_session_policy.dart';
import 'cedar_play_transition_log.dart';
import 'cedar_game_protocol.dart';
import 'cedar_toy_activity.dart';

/// A user-authorized task is metadata for the existing Cedar continuation
/// owner. It never starts a second game loop or resets a server play limit.
class CedarTimedPlayTaskStore {
  CedarTimedPlayTaskStore(this.db);
  final AppDatabase db;
  static const pendingKey = 'cedar_timed_play_pending_v1';
  static const activeKey = 'cedar_timed_play_active_v1';
  static const reportsKey = 'cedar_timed_play_reports_v1';
  static const diagnosticKey = 'cedar_timed_play_diagnostic_v1';
  static const leaseKey = 'cedar_timed_play_task_lease_v1';

  static Map<String, dynamic>? decode(String? raw) {
    try {
      final value = jsonDecode(raw ?? '');
      return value is Map ? value.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  /// This parses only a model-selected verbatim duration, never game intent.
  /// The semantic planner must first decide that the user requests work now.
  static int? durationMinutes(String durationText, String userText) {
    final text = durationText.trim();
    if (text.isEmpty || !userText.contains(text)) return null;
    if (const {'半小时', '半个小时', 'half an hour'}.contains(text.toLowerCase())) {
      return 30;
    }
    final match = RegExp(
      r'^(\d{1,3}|[一二两三四五六七八九十]{1,3})\s*(分钟|分|minutes?|mins?)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final raw = match.group(1)!;
    const digits = {
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    int? count = int.tryParse(raw);
    if (count == null && raw.contains('十')) {
      final parts = raw.split('十');
      if (parts.length == 2) {
        final tens = parts.first.isEmpty ? 1 : digits[parts.first];
        final units = parts.last.isEmpty ? 0 : digits[parts.last];
        if (tens != null && units != null) count = tens * 10 + units;
      }
    }
    count ??= digits[raw];
    return count != null && count >= 1 && count <= 30 ? count : null;
  }

  static bool hasDuration(String userText) =>
      RegExp(
            r'半(?:个)?小时|\d{1,3}\s*(?:分钟|minutes?|mins?)|[一二两三四五六七八九十]{1,3}分钟|half an hour',
            caseSensitive: false,
          )
          .allMatches(userText)
          .any((match) => durationMinutes(match.group(0)!, userText) != null);

  Future<Map<String, dynamic>?> active() async =>
      decode(await db.getSetting(activeKey));

  Future<void> stage({
    required String turnId,
    required String assistantId,
    required CedarGameSession session,
    required int minutes,
  }) async {
    await db.setSetting(
      pendingKey,
      jsonEncode({
        'id': 'cedar-task:$turnId',
        'turnId': turnId,
        'assistantId': assistantId,
        'gameId': session.gameId,
        'sessionId': session.id,
        'title': session.displayName,
        'minutes': minutes,
        'requestedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Commit and recovery use the same admission. A stopped/failed reply has
  /// no committed assistant ID and therefore cannot leave a hidden play grant.
  Future<void> activateCommitted({String? turnId, DateTime? now}) async {
    if (!await db.brainWorkAllowed() ||
        !await db.tryAcquireLocalLease(leaseKey, holdFor: const Duration(seconds: 30))) return;
    try { await _activateCommitted(turnId: turnId, now: now); }
    finally { await db.releaseLocalLease(leaseKey); }
  }

  Future<void> _activateCommitted({String? turnId, DateTime? now}) async {
    final pendingRaw = await db.getSetting(pendingKey) ?? '';
    final pending = decode(pendingRaw);
    if (pending == null || (turnId != null && pending['turnId'] != turnId))
      return;
    final assistantId = pending['assistantId']?.toString() ?? '';
    if (assistantId.isEmpty ||
        (await db.messageById(assistantId))?.isAssistant != true)
      return;
    final at = now ?? DateTime.now();
    final requested = DateTime.fromMillisecondsSinceEpoch(
      (pending['requestedAt'] as num?)?.toInt() ?? 0,
    );
    if (at.isBefore(requested) ||
        at.difference(requested) > const Duration(hours: 2) ||
        at.year != requested.year ||
        at.month != requested.month ||
        at.day != requested.day) {
      await finish(pending, usedMs: 0, reason: 'expired_before_start', now: at);
      await db.setSetting(pendingKey, '');
      return;
    }
    final existing = await active();
    if (existing?['id'] == pending['id']) {
      await db.setSetting(pendingKey, '');
      return;
    }
    final store = CedarToyActivityStore(db);
    final session = await store.load();
    if (session == null ||
        session.gameId != pending['gameId'] ||
        session.id != pending['sessionId'] ||
        !session.guideComplete ||
        !session.phase.continuable ||
        await db.getSetting('cedar_toy_enabled') == '0' ||
        await db.getSetting('cedar_toy_autonomy_enabled') == '0') {
      await finish(pending, usedMs: 0, reason: 'cannot_start', now: at);
      await db.setSetting(pendingKey, '');
      return;
    }
    // Replacing a task keeps the old result report; it does not silently
    // extend its budget or erase its actual progress.
    if (!await CedarPlaySessionStore(db).end('replaced_by_user_task')) return;
    final minutes = (pending['minutes'] as num?)?.toInt() ?? 0;
    if (minutes < 1 || minutes > 30) return;
    final task = {...pending, 'startedAt': at.millisecondsSinceEpoch, 'usedMs': 0};
    final period = CedarPlaySession(
      gameId: session.gameId,
      startedAt: at,
      lastTickAt: at,
      taskId: pending['id'].toString(),
      limitMs: minutes * 60000,
    );
    final activeRaw = await db.getSetting(activeKey) ?? '';
    if (!await db.brainWorkAllowed()) return;
    final committed = await db.setSettingsAtomically({
      activeKey: jsonEncode(task),
      pendingKey: '',
      CedarPlaySessionStore.key: await CedarPlaySessionStore(db)
          .encoded(period),
    }, expectedSettings: {pendingKey: pendingRaw, activeKey: activeRaw});
    if (!committed) return;
    if (session.phase == CedarActivityPhase.paused)
      await store.resumeGame(session.gameId);
    await diagnose(task, phase: 'active', terminal: false);
  }

  Future<void> recordProgress(CedarGameSession session) async {
    if (session.events.isEmpty) return;
    final event = session.events.last;
    if (event.kind != 'outcome' || CedarPlatformActionPolicy.isReadOnly(event.action) ||
        CedarPlatformActionPolicy.isResultSnapshot(event.action) ||
        CedarPlatformActionPolicy.isPlatformAction(event.action)) return;
    for (var retry = 0; retry < 3; retry++) {
      final raw = await db.getSetting(activeKey) ?? '';
      final task = decode(raw);
      if (task == null || task['gameId'] != session.gameId ||
          task['sessionId'] != session.id || task['lastEventId'] == event.id) return;
      if (await db.setSettingsAtomically({activeKey: jsonEncode({...task,
          'progressCount': ((task['progressCount'] as num?)?.toInt() ?? 0) + 1,
          'lastEventId': event.id})}, expectedSettings: {activeKey: raw})) return;
    }
  }

  Future<bool> finish(
    Map<String, dynamic> task, {
    required int usedMs,
    required String reason,
    DateTime? now,
    bool onlyIfActive = false,
    Map<String, String> expectedSettings = const {},
  }) async {
    final activeRaw = await db.getSetting(activeKey) ?? '';
    final existing = decode(activeRaw);
    if (onlyIfActive && existing?['id'] != task['id']) return false;
    final reportsRaw = await db.getSetting(reportsKey) ?? '';
    final reports = await pendingReports();
    if (!reports.any((entry) => entry['id'] == task['id'])) {
      final session = await CedarToyActivityStore(db)
          .loadSession(task['gameId'].toString());
      final started =
          (task['startedAt'] as num?)?.toInt() ??
          (task['requestedAt'] as num?)?.toInt() ??
          0;
      final events = session != null && session.id == task['sessionId']
          ? session.events
                .where(
                  (event) =>
                      event.kind == 'outcome' &&
                      event.createdAt.millisecondsSinceEpoch >= started &&
                      !CedarPlatformActionPolicy.isReadOnly(event.action) &&
                      !CedarPlatformActionPolicy.isPlatformAction(event.action),
                )
                .toList()
          : <CedarGameEvent>[];
      reports.add({
        ...task,
        'usedMs': usedMs,
        'reason': reason,
        'finishedAt': (now ?? DateTime.now()).millisecondsSinceEpoch,
        'progressCount': task['progressCount'] ?? events.length,
        'outcomes': events.reversed
            .take(3)
            .map(
              (event) => {
                'action': event.action,
                'text': event.summary.substring(
                  0,
                  event.summary.length.clamp(0, 1500).toInt(),
                ),
              },
            )
            .toList()
            .reversed
            .toList(),
        'terminalKey': session?.pendingTerminalKey ?? '',
      });
    }
    final committed = await db.setSettingsAtomically({
      reportsKey: jsonEncode(reports),
      if (existing?['id'] == task['id']) activeKey: '',
    }, expectedSettings: {...expectedSettings, activeKey: activeRaw, reportsKey: reportsRaw});
    if (!committed) return false;
    await diagnose({...task, 'usedMs': usedMs}, phase: reason, terminal: true);
    await CedarPlayTransitionLog(db).record(source: 'task_finish', reason: reason,
        before: 'active', after: 'terminal', at: now);
    return true;
  }

  Future<List<Map<String, dynamic>>> pendingReports() async {
    try {
      final raw = jsonDecode(await db.getSetting(reportsKey) ?? '[]');
      return raw is List
          ? raw
                .whereType<Map>()
                .map((value) => value.cast<String, dynamic>())
                .toList()
          : [];
    } catch (_) {
      return [];
    }
  }

  /// Durable user intent survives process/snapshot loss; its execution grant
  /// does not. Reconciliation runs only on the existing owner and action lease.
  Future<void> reconcile(DateTime now) async {
    if (!await db.brainWorkAllowed() || await db.isLocalLeaseHeld('chat_turn_lease')) return;
    await activateCommitted(now: now);
    if (!await db.tryAcquireLocalLease(leaseKey, holdFor: const Duration(seconds: 30))) return;
    var actionOwned = false;
    try {
      if (!await db.brainWorkAllowed() || await db.isLocalLeaseHeld('chat_turn_lease')) return;
      actionOwned = await db.tryAcquireLocalLease('cedar_toy_action_lease_until',
          holdFor: const Duration(seconds: 30));
      if (!actionOwned) return; // A live network action remains the sole writer.
      await _reconcileLocked(now);
    } finally {
      try {
        if (actionOwned) await db.releaseLocalLease('cedar_toy_action_lease_until');
      } finally { await db.releaseLocalLease(leaseKey); }
    }
  }

  Future<void> _reconcileLocked(DateTime now) async {
    final task = await active();
    if (task == null) return;
    final periods = CedarPlaySessionStore(db);
    final raw = await db.getSetting(CedarPlaySessionStore.key) ?? '';
    var period = await periods.load();
    final recorded = CedarPlaySession.decode(raw);
    final store = CedarToyActivityStore(db);
    var state = await store.loadState();
    // We acquired the action lease, so any surviving execution belongs to a
    // dead/finished owner. Never restore that old execution fence.
    if (state.execution != null) {
      await store.cancelExecution(reason: 'task_runtime_recovery');
      state = await store.loadState();
    }
    final session = state.sessions[task['gameId']];
    final controls = <String, String>{
      for (final key in ['active_brain', 'transfer_lock', 'chat_turn_lease',
        CedarToyActivityStore.executionFenceSettingKey])
        key: await db.getSetting(key) ?? '',
    };
    if (!await db.brainWorkAllowed() || await db.isLocalLeaseHeld('chat_turn_lease')) return;
    final limit = ((task['minutes'] as num?)?.toInt() ?? 0) * 60000;
    final taskUsed = (task['usedMs'] as num?)?.toInt() ?? 0;
    final recordedUsed = recorded?.taskId == task['id'] &&
        recorded?.gameId == task['gameId'] ? recorded!.usedMs : 0;
    var used = taskUsed > recordedUsed ? taskUsed : recordedUsed;
    used = used.clamp(0, CedarPlaySession.budgetMs).toInt();
    String? reason;
    if (limit < 60000 || limit > CedarPlaySession.budgetMs) {
      reason = 'cannot_start';
    } else if (used >= limit) {
      reason = 'budget_complete';
    } else if (session == null || session.id != task['sessionId'] ||
        (state.activeGameId.isNotEmpty && state.activeGameId != session.gameId)) {
      reason = 'changed_game';
    } else if (session.phase == CedarActivityPhase.completed || session.nextActor == 'finished') {
      reason = 'game_finished';
    } else if (session.phase == CedarActivityPhase.failed) {
      reason = 'game_failed';
    } else if (await db.getSetting('cedar_toy_enabled') == '0' ||
        await db.getSetting('cedar_toy_autonomy_enabled') == '0') {
      reason = 'game_disabled';
    } else if (session.phase == CedarActivityPhase.paused &&
        session.pauseSource != 'remote_wait_unroutable') {
      // Local Pause retains its existing Stop contract and neutral report.
      // It is never recovered as an accidental runtime interruption.
      reason = 'finished_or_waiting_user';
    }
    if (reason != null) {
      if (!await db.brainWorkAllowed() || await db.isLocalLeaseHeld('chat_turn_lease')) return;
      if (!await finish(task, usedMs: used, reason: reason, now: now,
          onlyIfActive: true, expectedSettings: {...controls,
            CedarPlaySessionStore.key: raw})) return;
      await db.setSettingsAtomically({CedarPlaySessionStore.key: '',
        'cedar_toy_play_session_end_reason': reason},
          expectedSettings: {CedarPlaySessionStore.key: raw});
      state = await store.loadState();
      if (state.execution == null && state.activeSession?.id == task['sessionId'] &&
          state.activeSession!.phase.continuable &&
          !await db.isLocalLeaseHeld('chat_turn_lease')) {
        await store.pauseAndRelease(source: reason);
      }
      return;
    }
    final current = session!;
    final waiting = !current.needsContinuation;
    if (period == null || period.taskId != task['id'] || period.gameId != current.gameId ||
        now.isBefore(period.lastTickAt.subtract(CedarPlaySession.observedTaskGap))) {
      period = CedarPlaySession(gameId: current.gameId,
          startedAt: DateTime.fromMillisecondsSinceEpoch(
              (task['startedAt'] as num?)?.toInt() ?? now.millisecondsSinceEpoch),
          lastTickAt: now, usedMs: used, paused: waiting,
          taskId: task['id'].toString(), limitMs: limit);
      if (!await db.brainWorkAllowed() || await db.isLocalLeaseHeld('chat_turn_lease')) return;
      if (!await periods.save(period, expectedRaw: raw, expectedSettings: controls)) return;
      await CedarPlayTransitionLog(db).record(source: 'task_recovery',
          reason: raw.isEmpty ? 'snapshot_clock_rebuilt' : 'runtime_clock_rebuilt',
          before: 'interrupted', after: waiting ? 'waiting' : 'active', at: now);
    } else {
      // Checkpoint even when the next two-minute game step is not due.
      // Waiting for a human or an unroutable server response pauses the clock
      // without inventing a terminal game result or a new move.
      if (!await periods.save(period.tick(now, pause: waiting), expectedSettings: controls)) return;
    }
    final saved = await periods.load();
    if (saved != null && saved.usedMs >= saved.limitMs) {
      // Finish on this wake rather than waiting for another game/model call.
      await _reconcileLocked(now);
      return;
    }
    await diagnose({...task, 'usedMs': saved?.usedMs ?? used},
        phase: waiting ? 'waiting' : 'active', terminal: false);
  }

  Future<String?> queueReport() async {
    final reports = await pendingReports();
    if (reports.isEmpty) return null;
    final task = reports.first;
    final thoughtId = 'cedar-report:${task['id']}';
    if (await db.messageById('cedar-share:$thoughtId') != null) {
      await acknowledge(task['id'].toString());
      return null;
    }
    if (await db.thoughtById(thoughtId) == null) {
      await db.upsertThought(
        id: thoughtId,
        text: '【用户指定时长的游戏任务回报】${jsonEncode(task)}',
        drive: DriveKey.curiosity,
        kind: 'flit',
        lifecycleState: 'task_report',
        bornAt: DateTime.fromMillisecondsSinceEpoch(
          (task['finishedAt'] as num).toInt(),
        ),
        strength: .96,
        source: 'mcp/cedar_game:${task['gameId']}:task:${task['id']}',
        topicKey: 'cedar_game:${task['gameId']}',
      );
    }
    return thoughtId;
  }

  Future<void> acknowledge(String id) async {
    final reports = await pendingReports();
    final matched = reports.where((value) => value['id'] == id).firstOrNull;
    if (matched == null) return;
    final terminal = matched['terminalKey']?.toString() ?? '';
    if (terminal.isNotEmpty)
      await CedarToyActivityStore(db).markTerminalDelivered(
        gameId: matched['gameId'].toString(),
        terminalKey: terminal,
      );
    reports.removeWhere((value) => value['id'] == id);
    await db.setSetting(reportsKey, jsonEncode(reports));
  }

  Future<void> diagnose(
    Map<String, dynamic> task, {
    required String phase,
    required bool terminal,
  }) async => db.setSetting(
    diagnosticKey,
    jsonEncode({
      'feature': 'cedar_timed_play',
      'execution_id': task['id'],
      'trigger_source': 'committed_user_turn',
      'continuation_owner': 'CedarToyAutonomyEngine.continueDue',
      'phase': phase,
      'planning_rounds': 0,
      'tool_calls': 0,
      'committed_mutations': 0,
      'continuation_requested': !terminal,
      'terminal': terminal,
      'preempt': phase == 'runtime_interrupted',
      'late_write': false,
      'usage_lane': 'cedar_background_plan',
      'duration_minutes': task['minutes'],
      'used_ms': (task['usedMs'] as num?)?.toInt() ?? 0,
      'clock_policy': '30s_recovery_checkpoint_45s_execution_heartbeat',
      'runtime_grant_restorable': false,
      'committed_task_resumable': true,
      'contentIncluded': false,
    }),
  );
}
