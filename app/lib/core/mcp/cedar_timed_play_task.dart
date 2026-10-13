import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../database/generation_attempt_fence.dart';
import '../agent/turn_execution_store.dart';
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

  static Map<String, Object?> registrationPayload({required String gameId,
      required String sessionId, required int minutes, required String goalId}) =>
      {'gameId': gameId, 'sessionId': sessionId, 'minutes': minutes, 'goalId': goalId};

  static String stageHash(Map<String, dynamic> pending) => turnPayloadHash({
    for (final entry in pending.entries)
      if (entry.key != 'stageHash' && entry.key != 'commitTicket') entry.key: entry.value,
  });

  /// A resume accepted in this same user turn may advance its original
  /// control epoch once. Later UI control, a different target, or an unrelated
  /// turn cannot be used as fresh authorization for this timer.
  static Future<bool> _userControlAuthorized(DatabaseExecutor txn, {
    required String turnId, required String gameId, required String sessionId,
    required String originalRevision, required String currentRevision,
  }) async {
    if (originalRevision == currentRevision) return true;
    final receipt = await TurnExecutionStore.readEffectInTransaction(txn,
        turnId: turnId, slot: TurnEffectSlot.cedarControl);
    return receipt != null && receipt.committed &&
        receipt.payloadHash == turnPayloadHash({'operation': 'resume', 'gameId': gameId, 'sessionId': sessionId}) &&
        receipt.result['operation'] == 'resume' && receipt.result['gameId'] == gameId &&
        receipt.result['sessionId'] == sessionId &&
        receipt.result['previousUserControlRevision'] == originalRevision &&
        receipt.result['userControlRevision'] == currentRevision;
  }

  Future<LocalEffectAdmission> stage({
    required String turnId,
    required String assistantId,
    required CedarGameSession session,
    required int minutes,
    GenerationAttemptFence? attemptFence,
    String goalId = '',
    String effectId = '',
    bool Function()? isCancelled,
    DateTime? now,
  }) async {
    final expectedId = turnEffectId(turnId, TurnEffectSlot.cedarTimedRegistration);
    if (attemptFence == null || attemptFence.userSource == null ||
        turnId != attemptFence.userMessageId || assistantId != attemptFence.assistantMessageId ||
        (goalId.isNotEmpty && goalId != expectedId) ||
        (effectId.isNotEmpty && effectId != expectedId) || minutes < 1 || minutes > 30) {
      return const LocalEffectAdmission(LocalEffectAdmissionState.blocked);
    }
    final payload = registrationPayload(gameId: session.gameId,
        sessionId: session.id, minutes: minutes, goalId: expectedId);
    final handle = await db.database;
    try {
      return await handle.transaction((txn) async {
        final admission = await TurnExecutionStore.inspectLocalInTransaction(txn,
            attempt: attemptFence, slot: TurnEffectSlot.cedarTimedRegistration,
            payload: payload, isCancelled: isCancelled);
        if (admission.state == LocalEffectAdmissionState.replay && admission.receipt!.committed) {
          return admission;
        }
        if (!admission.canCreate && admission.state != LocalEffectAdmissionState.replay) return admission;
        final previous = await TurnExecutionStore.readEffectInTransaction(txn,
            turnId: turnId, slot: TurnEffectSlot.cedarTimedRegistration);
        if (previous?.result.containsKey('cancelledReason') == true) {
          return LocalEffectAdmission(LocalEffectAdmissionState.blocked, previous);
        }
        final goals = await TurnExecutionStore.readGoalsInTransaction(txn, attempt: attemptFence);
        final controlRevision = await BrainWorkFence.value(txn, CedarToyActivityStore.controlRevisionKey);
        final userControlRevision = await BrainWorkFence.value(txn, CedarToyActivityStore.userControlRevisionKey);
        final originalUserControlRevision = await TurnExecutionStore.originalUserControlRevisionInTransaction(txn, turnId);
        if (originalUserControlRevision == null || !await _userControlAuthorized(txn, turnId: turnId,
            gameId: session.gameId, sessionId: session.id, originalRevision: originalUserControlRevision,
            currentRevision: userControlRevision)) {
          return const LocalEffectAdmission(LocalEffectAdmissionState.blocked);
        }
        if (!goals.any((goal) => goal.authorized && goal.id == expectedId &&
            goal.target.containsKey('user_control_revision') && goal.target['user_control_revision'] == originalUserControlRevision &&
            goal.minutes == minutes && goal.target['game_id'] == session.gameId &&
            ((goal.target['session_id'] ?? '').isEmpty || goal.target['session_id'] == session.id))) {
          return const LocalEffectAdmission(LocalEffectAdmissionState.blocked);
        }
        final state = await CedarToyActivityStore.readStateInTransaction(txn);
        final current = state.activeSession;
        if (current == null || current.id != session.id || current.gameId != session.gameId ||
            !current.guideComplete || !current.phase.continuable || current.mode.requiresInvitation ||
            state.execution != null || await BrainWorkFence.value(txn, 'cedar_toy_enabled') == '0' ||
            await BrainWorkFence.value(txn, 'cedar_toy_autonomy_enabled') == '0' ||
            decodeReports(await BrainWorkFence.value(txn, reportsKey)).length >= 16) {
          return const LocalEffectAdmission(LocalEffectAdmissionState.blocked);
        }
        final oldPending = decode(await BrainWorkFence.value(txn, pendingKey));
        if (admission.state == LocalEffectAdmissionState.replay) {
          return oldPending?['effectId'] == expectedId && oldPending?['runToken'] == attemptFence.runToken &&
              oldPending?['stageHash'] == admission.receipt!.result['stageHash']
              ? admission : const LocalEffectAdmission(LocalEffectAdmissionState.blocked);
        }
        if (oldPending != null && oldPending['effectId'] != expectedId && oldPending['commitTicket'] is Map) {
          return const LocalEffectAdmission(LocalEffectAdmissionState.blocked);
        }
        final at = now ?? DateTime.now();
        final pending = <String, dynamic>{
          'id': 'cedar-task:$turnId', 'turnId': turnId, 'assistantId': assistantId,
          'gameId': current.gameId, 'sessionId': current.id, 'title': current.displayName,
          'minutes': minutes, 'requestedAt': at.millisecondsSinceEpoch,
          'goalId': expectedId, 'effectId': expectedId, 'payloadHash': turnPayloadHash(payload),
          'jobId': attemptFence.jobId, 'runToken': attemptFence.runToken,
          'userSourceHash': attemptFence.userSource!.contentHash,
          'brainIdentity': attemptFence.brainFence.identity,
          'controlRevision': controlRevision,
          'userControlRevision': userControlRevision,
          'originalUserControlRevision': originalUserControlRevision,
        };
        pending['stageHash'] = stageHash(pending);
        final receipt = LocalEffectReceipt(turnId: turnId,
          slot: TurnEffectSlot.cedarTimedRegistration, payloadHash: turnPayloadHash(payload),
          state: LocalEffectState.staged, runToken: attemptFence.runToken,
          createdAt: at.millisecondsSinceEpoch,
          result: {'taskId': pending['id'], 'gameId': current.gameId, 'sessionId': current.id,
            'minutes': minutes, 'stageHash': pending['stageHash']});
        await TurnExecutionStore.writeEffectInTransaction(txn, receipt);
        await CedarToyActivityStore.writeSettingsInTransaction(txn, {pendingKey: jsonEncode(pending)});
        requireTurnNotCancelled(isCancelled);
        return LocalEffectAdmission(LocalEffectAdmissionState.create, receipt);
      });
    } on TurnCommitCancelled {
      return const LocalEffectAdmission(LocalEffectAdmissionState.staleAttempt);
    }
  }

  static Future<bool> _stageStillCurrent(DatabaseExecutor txn,
      Map<String, dynamic> pending, GenerationAttemptFence attempt) async {
    if (!await attempt.matches(txn) || attempt.userSource == null ||
        pending['turnId'] != attempt.userMessageId || pending['assistantId'] != attempt.assistantMessageId ||
        pending['jobId'] != attempt.jobId || pending['userSourceHash'] != attempt.userSource!.contentHash ||
        pending['stageHash'] != stageHash(pending) ||
        pending['controlRevision'] != await BrainWorkFence.value(txn, CedarToyActivityStore.controlRevisionKey) ||
        pending['userControlRevision'] != await BrainWorkFence.value(txn, CedarToyActivityStore.userControlRevisionKey)) return false;
    final originalRevision = await TurnExecutionStore.originalUserControlRevisionInTransaction(txn, attempt.userMessageId);
    if (originalRevision == null || originalRevision != pending['originalUserControlRevision'] ||
        !await _userControlAuthorized(txn, turnId: attempt.userMessageId,
          gameId: pending['gameId'] as String, sessionId: pending['sessionId'] as String,
          originalRevision: originalRevision, currentRevision: pending['userControlRevision'] as String)) return false;
    final identity = pending['brainIdentity'];
    if (identity is! Map || identity.isEmpty) return false;
    for (final entry in identity.entries) {
      if (entry.key is! String || entry.value is! String ||
          await BrainWorkFence.value(txn, entry.key as String) != entry.value) return false;
    }
    final state = await CedarToyActivityStore.readStateInTransaction(txn);
    final session = state.activeSession;
    if (session == null || session.id != pending['sessionId'] || session.gameId != pending['gameId'] ||
        !session.guideComplete || !session.phase.continuable || session.mode.requiresInvitation ||
        state.execution != null || await BrainWorkFence.value(txn, 'cedar_toy_enabled') == '0' ||
        await BrainWorkFence.value(txn, 'cedar_toy_autonomy_enabled') == '0') return false;
    final goals = await TurnExecutionStore.readGoalsInTransaction(txn, attempt: attempt);
    return goals.any((goal) => goal.authorized && goal.id == pending['goalId'] &&
        goal.target.containsKey('user_control_revision') && goal.target['user_control_revision'] == originalRevision &&
        goal.minutes == pending['minutes'] && goal.target['game_id'] == pending['gameId'] &&
        ((goal.target['session_id'] ?? '').isEmpty || goal.target['session_id'] == pending['sessionId']));
  }

  Future<TimedRegistrationHandoff?> prepareConfirmationHandoff(GenerationAttemptFence attempt) async {
    final handle = await db.database;
    return handle.transaction((txn) async {
      final rows = await txn.query('generation_jobs', columns: ['resume_reason'],
          where: 'id = ?', whereArgs: [attempt.jobId], limit: 1);
      if (rows.isEmpty || rows.first['resume_reason'] != 'user_confirmed_incomplete_reply') return null;
      final pending = decode(await BrainWorkFence.value(txn, pendingKey));
      if (pending == null || !await _stageStillCurrent(txn, pending, attempt)) return null;
      final receipt = await TurnExecutionStore.readEffectInTransaction(txn,
          turnId: attempt.userMessageId, slot: TurnEffectSlot.cedarTimedRegistration);
      if (receipt == null || receipt.committed || receipt.runToken != pending['runToken'] ||
          receipt.payloadHash != pending['payloadHash'] || receipt.result['stageHash'] != pending['stageHash']) return null;
      return TimedRegistrationHandoff(effectId: receipt.effectId, fromRunToken: receipt.runToken,
          payloadHash: receipt.payloadHash, stageHash: pending['stageHash'] as String);
    });
  }

  /// Called before the generation job loses its running token, in the exact
  /// transaction that inserts the committed assistant message.
  static Future<bool> commitStagedInTransaction(DatabaseExecutor txn, {
    required GenerationAttemptFence attempt,
    required TurnCommitEvidence evidence,
    required String messageId,
    required String messageHash,
    required int messageRevision,
    bool Function()? isCancelled,
  }) async {
    requireTurnNotCancelled(isCancelled);
    if (evidence.timedEffectIds.isEmpty) return true;
    final effectId = turnEffectId(attempt.userMessageId, TurnEffectSlot.cedarTimedRegistration);
    if (evidence.timedEffectIds.length != 1 || evidence.timedEffectIds.single != effectId ||
        messageId != attempt.assistantMessageId || messageHash.isEmpty) return false;
    final receipt = await TurnExecutionStore.readEffectInTransaction(txn,
        turnId: attempt.userMessageId, slot: TurnEffectSlot.cedarTimedRegistration);
    if (receipt == null) return false;
    if (receipt.committed) return true; // Already accepted independent work, never recharge.
    final pending = decode(await BrainWorkFence.value(txn, pendingKey));
    if (pending == null || pending['effectId'] != effectId || pending['runToken'] != receipt.runToken ||
        pending['payloadHash'] != receipt.payloadHash ||
        pending['stageHash'] != receipt.result['stageHash'] || !await _stageStillCurrent(txn, pending, attempt)) return false;
    if (receipt.runToken != attempt.runToken) {
      final handoff = evidence.timedHandoff;
      final rows = await txn.query('generation_jobs', columns: ['resume_reason'],
          where: 'id = ?', whereArgs: [attempt.jobId], limit: 1);
      if (handoff == null || rows.isEmpty || rows.first['resume_reason'] != 'user_confirmed_incomplete_reply' ||
          handoff.effectId != effectId || handoff.fromRunToken != receipt.runToken ||
          handoff.payloadHash != receipt.payloadHash || handoff.stageHash != pending['stageHash']) return false;
    } else if (pending['runToken'] != attempt.runToken) { return false; }
    final committed = receipt.commit(messageId: messageId,
        messageHash: messageHash, messageRevision: messageRevision);
    await TurnExecutionStore.writeEffectInTransaction(txn, committed);
    await CedarToyActivityStore.writeSettingsInTransaction(txn, {pendingKey: jsonEncode({...pending,
      'commitTicket': {'effectId': effectId, 'messageId': messageId, 'messageHash': messageHash,
        'messageRevision': messageRevision, 'committedRunToken': attempt.runToken},
    })});
    requireTurnNotCancelled(isCancelled);
    return true;
  }

  /// A newer local control can cancel an accepted-but-not-yet-activated task.
  /// Preserve its neutral report, while an uncommitted stage grants nothing.
  static Future<void> cancelPendingInTransaction(DatabaseExecutor txn, {
    required String reason, required DateTime now,
  }) async {
    final pending = decode(await BrainWorkFence.value(txn, pendingKey));
    if (pending == null) return;
    final ticket = pending['commitTicket'];
    final receipt = await TurnExecutionStore.readEffectInTransaction(txn,
        turnId: pending['turnId']?.toString() ?? '', slot: TurnEffectSlot.cedarTimedRegistration);
    if (receipt != null && !receipt.committed && receipt.effectId == pending['effectId'] &&
        receipt.runToken == pending['runToken'] && receipt.result['stageHash'] == pending['stageHash']) {
      await TurnExecutionStore.writeEffectInTransaction(txn, LocalEffectReceipt(
        turnId: receipt.turnId, slot: receipt.slot, payloadHash: receipt.payloadHash,
        state: receipt.state, runToken: receipt.runToken, createdAt: receipt.createdAt,
        result: {...receipt.result, 'cancelledReason': reason, 'cancelledAt': now.millisecondsSinceEpoch},
      ));
    }
    if (ticket is Map && receipt != null && receipt.committed &&
        !receipt.result.containsKey('activationState') &&
        receipt.effectId == pending['effectId'] && receipt.payloadHash == pending['payloadHash'] &&
        receipt.result['stageHash'] == pending['stageHash'] && stageHash(pending) == pending['stageHash'] &&
        ticket['messageId'] == receipt.messageId && ticket['messageHash'] == receipt.messageHash &&
        ticket['messageRevision'] == receipt.messageRevision) {
      final active = decode(await BrainWorkFence.value(txn, activeKey));
      if (active?['id'] != pending['id']) {
        await finishInTransaction(txn, pending, usedMs: 0, reason: reason, now: now);
      }
    }
    await CedarToyActivityStore.writeSettingsInTransaction(txn, {pendingKey: ''});
  }

  Future<void> activateCommitted({String? turnId, DateTime? now}) async {
    if (!await db.brainWorkAllowed() ||
        !await db.tryAcquireLocalLease(leaseKey, holdFor: const Duration(seconds: 30))) return;
    try { await _activateCommitted(turnId: turnId, now: now); }
    finally { await db.releaseLocalLease(leaseKey); }
  }

  Future<void> _activateCommitted({String? turnId, DateTime? now}) async {
    // Capture ownership before the platform runtime-epoch await. The pending
    // registration and controls are re-read only inside the final transaction.
    final fence = await db.captureBrainWorkFence(leaseKey: leaseKey);
    if (fence == null) return;
    final pendingRaw = await db.getSetting(pendingKey) ?? '';
    final pending = decode(pendingRaw);
    if (pending == null || pending['commitTicket'] is! Map ||
        (turnId != null && pending['turnId'] != turnId)) return;
    final at = now ?? DateTime.now();
    final minutes = (pending['minutes'] as num?)?.toInt() ?? 0;
    if (minutes < 1 || minutes > 30) return;
    final encodedPeriod = await CedarPlaySessionStore(db).encoded(CedarPlaySession(
      gameId: pending['gameId'].toString(), startedAt: at, lastTickAt: at,
      taskId: pending['id'].toString(), limitMs: minutes * 60000,
    ));
    final handle = await db.database;
    await handle.transaction((txn) async {
      if (!await fence.matches(txn) || await BrainWorkFence.value(txn, pendingKey) != pendingRaw) return;
      final receipt = await TurnExecutionStore.readEffectInTransaction(txn,
          turnId: pending['turnId'].toString(), slot: TurnEffectSlot.cedarTimedRegistration);
      final ticket = pending['commitTicket'] as Map;
      if (receipt == null || !receipt.committed || receipt.effectId != pending['effectId'] ||
          receipt.payloadHash != pending['payloadHash'] || receipt.result['stageHash'] != pending['stageHash'] ||
          stageHash(pending) != pending['stageHash'] || ticket['effectId'] != receipt.effectId ||
          ticket['messageId'] != receipt.messageId || ticket['messageHash'] != receipt.messageHash ||
          ticket['messageRevision'] != receipt.messageRevision) return;
      final identity = pending['brainIdentity'];
      if (identity is! Map || identity.isEmpty) return;
      for (final entry in identity.entries) {
        if (entry.key is! String || entry.value is! String ||
            await BrainWorkFence.value(txn, entry.key as String) != entry.value) return;
      }
      final existing = decode(await BrainWorkFence.value(txn, activeKey));
      if (existing?['id'] == pending['id'] || receipt.result.containsKey('activationState')) {
        await CedarToyActivityStore.writeSettingsInTransaction(txn, {pendingKey: ''});
        return;
      }
      final state = await CedarToyActivityStore.readStateInTransaction(txn);
      final session = state.activeSession;
      final requested = DateTime.fromMillisecondsSinceEpoch((pending['requestedAt'] as num?)?.toInt() ?? 0);
      final expired = at.isBefore(requested) || at.difference(requested) > const Duration(hours: 2) ||
          at.year != requested.year || at.month != requested.month || at.day != requested.day;
      final allowed = session != null && session.id == pending['sessionId'] && session.gameId == pending['gameId'] &&
          session.guideComplete && session.phase.continuable && !session.mode.requiresInvitation && state.execution == null &&
          pending['controlRevision'] == await BrainWorkFence.value(txn, CedarToyActivityStore.controlRevisionKey) &&
          pending['userControlRevision'] == await BrainWorkFence.value(txn, CedarToyActivityStore.userControlRevisionKey) &&
          await BrainWorkFence.value(txn, 'cedar_toy_enabled') != '0' &&
          await BrainWorkFence.value(txn, 'cedar_toy_autonomy_enabled') != '0';
      if (expired || !allowed) {
        await finishInTransaction(txn, pending, usedMs: 0,
            reason: expired ? 'expired_before_start' : 'cannot_start', now: at);
        await CedarToyActivityStore.writeSettingsInTransaction(txn, {pendingKey: ''});
      } else {
        if (existing != null) {
          final period = CedarPlaySession.decode(await BrainWorkFence.value(txn, CedarPlaySessionStore.key));
          final taskUsed = (existing['usedMs'] as num?)?.toInt() ?? 0;
          final periodUsed = period?.taskId == existing['id'] ? period?.usedMs ?? 0 : 0;
          await finishInTransaction(txn, existing, usedMs: periodUsed > taskUsed ? periodUsed : taskUsed,
              reason: 'replaced_by_user_task', now: at, onlyIfActive: true);
        }
        await CedarToyActivityStore.writeSettingsInTransaction(txn, {
          activeKey: jsonEncode({...pending, 'startedAt': at.millisecondsSinceEpoch, 'usedMs': 0}),
          diagnosticKey: jsonEncode(diagnostic(pending, phase: 'active', terminal: false)),
          pendingKey: '', CedarPlaySessionStore.key: encodedPeriod,
          if (session!.phase == CedarActivityPhase.paused)
            ...CedarToyActivityStore.stateSettingValues(state.copyWith(
              sessions: Map<String, CedarGameSession>.from(state.sessions)
                ..[session.gameId] = CedarToyActivityStore.resumedSession(session, at), updatedAt: at)),
        });
      }
      if (!expired && allowed) {
        await TurnExecutionStore.writeEffectInTransaction(txn, LocalEffectReceipt(
          turnId: receipt.turnId, slot: receipt.slot, payloadHash: receipt.payloadHash,
          state: receipt.state, runToken: receipt.runToken, createdAt: receipt.createdAt,
          messageId: receipt.messageId, messageHash: receipt.messageHash, messageRevision: receipt.messageRevision,
          result: {...receipt.result, 'activationState': 'active', 'activationAt': at.millisecondsSinceEpoch},
        ));
      }
    });
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
    final fence = await db.captureBrainWorkFence();
    if (fence == null) return false;
    final handle = await db.database;
    final committed = await handle.transaction((txn) async {
      if (!await fence.matches(txn)) return false;
      for (final guard in expectedSettings.entries) {
        if (await BrainWorkFence.value(txn, guard.key) != guard.value) return false;
      }
      return finishInTransaction(txn, task, usedMs: usedMs, reason: reason,
          now: now ?? DateTime.now(), onlyIfActive: onlyIfActive);
    });
    if (!committed) return false;
    await diagnose({...task, 'usedMs': usedMs}, phase: reason, terminal: true);
    await CedarPlayTransitionLog(db).record(source: 'task_finish', reason: reason,
        before: 'active', after: 'terminal', at: now);
    return true;
  }

  static List<Map<String, dynamic>> decodeReports(String? raw) {
    try {
      final value = jsonDecode(raw ?? '[]');
      return value is List
          ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
          : [];
    } catch (_) { return []; }
  }

  /// Caller owns the surrounding transaction and its original work/attempt
  /// fence. Task, latest report queue and optional runtime end are one write.
  static Future<bool> finishInTransaction(
    DatabaseExecutor txn,
    Map<String, dynamic> task, {
    required int usedMs,
    required String reason,
    required DateTime now,
    bool onlyIfActive = false,
    bool endPeriod = false,
  }) async {
    final existing = decode(await BrainWorkFence.value(txn, activeKey));
    if (onlyIfActive && existing?['id'] != task['id']) return false;
    final current = existing?['id'] == task['id'] ? existing! : task;
    final reports = decodeReports(await BrainWorkFence.value(txn, reportsKey));
    if (!reports.any((entry) => entry['id'] == current['id'])) {
      final state = await CedarToyActivityStore.readStateInTransaction(txn);
      final session = state.sessions[current['gameId']];
      final started = (current['startedAt'] as num?)?.toInt();
      final events = started != null && session != null && session.id == current['sessionId']
          ? session.events.where((event) => event.kind == 'outcome' &&
              event.createdAt.millisecondsSinceEpoch >= started &&
              !CedarPlatformActionPolicy.isReadOnly(event.action) &&
              !CedarPlatformActionPolicy.isPlatformAction(event.action)).toList()
          : <CedarGameEvent>[];
      reports.add({
        ...reportFields(current),
        'usedMs': usedMs,
        'reason': reason,
        'finishedAt': now.millisecondsSinceEpoch,
        'progressCount': started == null ? 0 : current['progressCount'] ?? events.length,
        'outcomes': events.reversed.take(3).map((event) => {
          'action': event.action,
          'text': event.summary.substring(0, event.summary.length.clamp(0, 1500).toInt()),
        }).toList().reversed.toList(),
        'terminalKey': started != null && session?.id == current['sessionId'] ? session?.pendingTerminalKey ?? '' : '',
      });
    }
    await CedarToyActivityStore.writeSettingsInTransaction(txn, {
      reportsKey: jsonEncode(reports),
      diagnosticKey: jsonEncode(diagnostic({...current, 'usedMs': usedMs}, phase: reason, terminal: true)),
      if (existing?['id'] == current['id']) activeKey: '',
      if (endPeriod) CedarPlaySessionStore.key: '',
      if (endPeriod) 'cedar_toy_play_session_end_reason': reason,
    });
    final receipt = await TurnExecutionStore.readEffectInTransaction(txn,
        turnId: current['turnId']?.toString() ?? '', slot: TurnEffectSlot.cedarTimedRegistration);
    if (receipt != null && receipt.committed && receipt.result['taskId'] == current['id'] &&
        receipt.result['activationState'] != 'ended') {
      await TurnExecutionStore.writeEffectInTransaction(txn, LocalEffectReceipt(
        turnId: receipt.turnId, slot: receipt.slot, payloadHash: receipt.payloadHash,
        state: receipt.state, runToken: receipt.runToken, createdAt: receipt.createdAt,
        messageId: receipt.messageId, messageHash: receipt.messageHash, messageRevision: receipt.messageRevision,
        result: {...receipt.result, 'activationState': 'ended', 'endedAt': now.millisecondsSinceEpoch,
          'endReason': reason, 'usedMs': usedMs},
      ));
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> pendingReports() async =>
      decodeReports(await db.getSetting(reportsKey));

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
        await store.pauseCompletedTask(sessionId: task['sessionId'].toString(),
            source: reason, expectedSettings: {...controls, activeKey: ''});
      }
      return;
    }
    final current = session!;
    final waiting = !current.needsContinuation;
    if (period == null || period.taskId != task['id'] || period.gameId != current.gameId ||
        period.limitMs != limit || period.usedMs < used ||
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

  Future<String?> queueReport({Set<String> excludedReportIds = const {}}) async {
    final reports = (await pendingReports())
        .where((report) => !excludedReportIds.contains(report['id']?.toString() ?? '')).toList();
    if (reports.isEmpty) return null;
    final task = reports.first;
    final thoughtId = 'cedar-report:${task['id']}';
    if (await db.messageById('cedar-share:$thoughtId') != null &&
        await acknowledge(task['id'].toString())) {
      return null;
    }
    if (await db.thoughtById(thoughtId) == null) {
      await db.upsertThought(
        id: thoughtId,
        text: '【用户指定时长的游戏任务回报】${jsonEncode(reportFields(task))}',
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

  static Map<String, dynamic> reportFields(Map<String, dynamic> task) => {
    for (final key in const ['id', 'turnId', 'gameId', 'sessionId', 'title', 'minutes',
      'requestedAt', 'startedAt', 'usedMs', 'reason', 'finishedAt', 'progressCount', 'outcomes', 'terminalKey'])
      if (task.containsKey(key)) key: task[key],
  };

  static CedarDeliveryClaim reportClaim(Map<String, dynamic> report) => CedarDeliveryClaim(
    kind: CedarDeliveryKind.timedReport, gameId: report['gameId']?.toString() ?? '',
    sessionId: report['sessionId']?.toString() ?? '', reportId: report['id']?.toString() ?? '',
    terminalKey: report['terminalKey']?.toString() ?? '', summary: jsonEncode(reportFields(report)));

  Future<bool> acknowledge(String id, {CedarDeliveryReceipt? receipt}) async {
    final fence = await db.captureBrainWorkFence();
    if (fence == null) return false;
    final handle = await db.database;
    return handle.transaction((txn) async {
      if (!await fence.matches(txn)) return false;
      final reports = decodeReports(await BrainWorkFence.value(txn, reportsKey));
      final matched = reports.where((value) => value['id'] == id).firstOrNull;
      if (matched == null) return false;
      final claim = reportClaim(matched);
      final proof = receipt ?? await TurnExecutionStore.readDeliveryInTransaction(txn, claim);
      if (proof == null || proof.claim.resultHash != claim.resultHash ||
          !await TurnExecutionStore.deliveryMatchesInTransaction(txn, proof)) return false;
      if (claim.terminalKey.isNotEmpty) {
        await CedarToyActivityStore.clearTerminalInTransaction(txn, gameId: claim.gameId,
            sessionId: claim.sessionId, terminalKey: claim.terminalKey);
      }
      reports.removeWhere((value) => value['id'] == id);
      await CedarToyActivityStore.writeSettingsInTransaction(txn, {reportsKey: jsonEncode(reports)});
      return true;
    });
  }

  Future<void> diagnose(Map<String, dynamic> task, {
    required String phase, required bool terminal,
  }) async => db.setSetting(diagnosticKey,
      jsonEncode(diagnostic(task, phase: phase, terminal: terminal)));

  static Map<String, Object?> diagnostic(Map<String, dynamic> task, {
    required String phase, required bool terminal,
  }) => {
      'feature': 'cedar_timed_play',
      'execution_id': task['id'],
      'game_id': task['gameId'],
      'session_id': task['sessionId'],
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
  };
}
