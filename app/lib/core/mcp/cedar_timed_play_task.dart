import 'dart:convert';

import '../database/app_database.dart';
import '../models/desire_state.dart';
import 'cedar_play_session_policy.dart';
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
    final pending = decode(await db.getSetting(pendingKey));
    if (pending == null || (turnId != null && pending['turnId'] != turnId))
      return;
    final assistantId = pending['assistantId']?.toString() ?? '';
    if (assistantId.isEmpty ||
        (await db.messageById(assistantId))?.isAssistant != true)
      return;
    final at = now ?? DateTime.now();
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
    await CedarPlaySessionStore(db).end('replaced_by_user_task');
    final minutes = (pending['minutes'] as num?)?.toInt() ?? 0;
    if (minutes < 1 || minutes > 30) return;
    final task = {...pending, 'startedAt': at.millisecondsSinceEpoch};
    final period = CedarPlaySession(
      gameId: session.gameId,
      startedAt: at,
      lastTickAt: at,
      taskId: pending['id'].toString(),
      limitMs: minutes * 60000,
    );
    await db.setSettingsAtomically({
      activeKey: jsonEncode(task),
      pendingKey: '',
      CedarPlaySessionStore.key: await CedarPlaySessionStore(db)
          .encoded(period),
    });
    if (session.phase == CedarActivityPhase.paused)
      await store.resumeGame(session.gameId);
    await diagnose(task, phase: 'active', terminal: false);
  }

  Future<void> recordProgress(CedarGameSession session) async {
    final task = await active();
    if (task == null ||
        task['gameId'] != session.gameId ||
        task['sessionId'] != session.id ||
        session.events.isEmpty)
      return;
    final event = session.events.last;
    if (event.kind != 'outcome' ||
        event.id == task['lastEventId'] ||
        CedarPlatformActionPolicy.isReadOnly(event.action) ||
        CedarPlatformActionPolicy.isPlatformAction(event.action))
      return;
    await db.setSetting(
      activeKey,
      jsonEncode({
        ...task,
        'progressCount': ((task['progressCount'] as num?)?.toInt() ?? 0) + 1,
        'lastEventId': event.id,
      }),
    );
  }

  Future<void> finish(
    Map<String, dynamic> task, {
    required int usedMs,
    required String reason,
    DateTime? now,
  }) async {
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
    final existing = await active();
    await db.setSettingsAtomically({
      reportsKey: jsonEncode(reports),
      if (existing?['id'] == task['id']) activeKey: '',
    });
    await diagnose(task, phase: reason, terminal: true);
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

  /// Runs on the existing recovery wake, even when the game has no due step.
  /// Old process/restore grants expire; their report remains deliverable.
  Future<void> reconcile(DateTime now) async {
    if (!await db.brainWorkAllowed() ||
        await db.isLocalLeaseHeld('chat_turn_lease'))
      return;
    await activateCommitted(now: now);
    final task = await active();
    if (task == null) return;
    final periods = CedarPlaySessionStore(db);
    final period = await periods.load();
    final session = await CedarToyActivityStore(db).load();
    String? reason;
    if (period == null || period.taskId != task['id']) {
      reason = 'runtime_interrupted';
    } else if (!period.validAt(now, period.gameId)) {
      reason = period.usedMs >= period.limitMs ? 'budget_complete' : 'expired';
    } else if (session == null ||
        session.gameId != task['gameId'] ||
        session.id != task['sessionId']) {
      reason = 'changed_game';
    } else if (!session.needsContinuation || !session.phase.continuable) {
      reason = 'finished_or_waiting_user';
    } else if (await db.getSetting('cedar_toy_enabled') == '0' ||
        await db.getSetting('cedar_toy_autonomy_enabled') == '0') {
      reason = 'game_disabled';
    }
    if (reason != null) {
      await finish(
        task,
        usedMs:
            period?.usedMs ??
            CedarPlaySession.decode(
              await db.getSetting(CedarPlaySessionStore.key),
            )?.usedMs ??
            (task['usedMs'] as num?)?.toInt() ??
            0,
        reason: reason,
        now: now,
      );
      final recordedPeriod = CedarPlaySession.decode(
        await db.getSetting(CedarPlaySessionStore.key),
      );
      if (recordedPeriod?.taskId == task['id']) await periods.end(reason);
      // Pause only this task's still-active session; never park another game
      // or cancel an atomic action now owned by a foreground user turn.
      final state = await CedarToyActivityStore(db).loadState();
      if (state.execution == null &&
          state.activeSession?.id == task['sessionId'] &&
          state.activeSession!.phase.continuable &&
          !await db.isLocalLeaseHeld('chat_turn_lease')) {
        await CedarToyActivityStore(db).pauseAndRelease();
      }
    }
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
      'contentIncluded': false,
    }),
  );
}
