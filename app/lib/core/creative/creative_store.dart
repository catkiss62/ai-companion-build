import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../database/generation_attempt_fence.dart';
import '../agent/turn_execution_store.dart';
import 'creative_control.dart';
import 'creative_contract.dart';
import 'creative_workspace.dart';
import 'creative_autonomy_policy.dart';
import 'creative_share.dart';
import 'creative_facts.dart';

class CreativeStore {
  CreativeStore(this.db, {this.beforeLocalCommit});
  final AppDatabase db;
  /// Test scheduling seam. Admission and all real SQLite writes still run;
  /// production callers leave this unset.
  @visibleForTesting
  final Future<void> Function(Transaction txn)? beforeLocalCommit;
  static String key(String id) => '${CreativeContract.metaPrefix}$id';
  Future<Map<String, dynamic>> get(String id) async => CreativeContract.decode(await db.getSetting(key(id)));

  Future<List<Map<String, dynamic>>> list({bool pendingOnly = false, bool includePrivate = false}) async {
    final handle = await db.database;
    final keys = await handle.query('settings', columns: ['key'],
        where: pendingOnly ? 'key LIKE ? AND (value LIKE ? OR value LIKE ? OR value LIKE ?)' : 'key LIKE ?',
        whereArgs: ['${CreativeContract.metaPrefix}%', if (pendingOnly) ...['%"status":"queued"%', '%"status":"building"%', '%"status":"checking"%']]);
    final works = <Map<String, dynamic>>[];
    for (final row in keys) {
      final work = CreativeContract.decode(await db.getSetting(row['key'] as String));
      if (work.isNotEmpty && work['status'] != 'deleted' &&
          (includePrivate || CreativeAutonomyPolicy.visible(work)) &&
          (!pendingOnly || CreativeContract.active.contains(work['status']))) works.add(work);
    }
    works.sort((a, b) => (b['updated'] as int).compareTo(a['updated'] as int));
    return works;
  }

  Future<List<Map<String, dynamic>>> forMessage(String messageId) async {
    final receipt = CreativeContract.decode(await db.getSetting('${CreativeContract.receiptPrefix}$messageId'));
    if (receipt.isNotEmpty) {
      final work = await get(receipt['work_id'] as String);
      if (!CreativeAutonomyPolicy.visible(work)) return [];
      final completed = receipt['completed'] == true ||
          (work['request_id'] is String && receipt['request_id'] == work['request_id'] && work['completed_request'] == work['request_id']) ||
          (!receipt.containsKey('request_id') && work['message_id'] == messageId && work['status'] == 'ready');
      return [{...work, 'card_kind': receipt['kind'], 'delivered_version': receipt['version'],
        'record_completed': completed}];
    }
    // Legacy cards retain their existing association without inventing messages.
    return (await list()).where((w) => w['message_id'] == messageId || w['completion_message_id'] == messageId)
        .map((w) => {...w, 'card_kind': w['completion_message_id'] == messageId ? 'delivered' : 'progress',
          'record_completed': w['status'] == 'ready'}).toList();
  }

  Future<bool> write(Map<String, dynamic> before, Map<String, dynamic> after,
      {Map<String, String> extra = const {}, BrainWorkFence? fence}) async {
    final owned = fence ?? await db.captureBrainWorkFence();
    if (owned == null) return false;
    final id = after['id'] as String;
    return db.setSettingsAtomically({key(id): jsonEncode(after), ...extra},
        expectedSettings: {key(id): before.isEmpty ? '' : jsonEncode(before)}, workFence: owned);
  }

  /// Compatibility entry for trusted local callers. Chat tools must use the
  /// typed entry below with the original generation attempt.
  Future<Map<String, dynamic>> commission({required bool deepThinking,
      required String requestId, required String messageId, required String brief,
      required String requestQuote, required String latestText, String workId = '',
      String userMessageId = '', String interaction = 'unspecified'}) async {
    final result = await _commission(deepThinking: deepThinking, requestId: requestId,
      messageId: messageId, brief: brief, requestQuote: requestQuote, latestText: latestText,
      workId: workId, userMessageId: userMessageId, interaction: interaction);
    if (result.isSuccess) return result.work;
    if (result.status == CreativeCommissionStatus.staleAttempt) throw const BrainWorkInvalidated();
    throw FormatException(switch (result.status) {
      CreativeCommissionStatus.targetMissing => '找不到要修改的作品',
      CreativeCommissionStatus.targetBusy => '这件作品正在制作，请先停止或等它完成',
      _ => '本回合已有不同的制作委托；没有另建作品或改写原委托',
    });
  }

  Future<CreativeCommissionResult> commissionResult({required bool deepThinking,
      required String requestId, required String messageId, required String brief,
      required String requestQuote, required String latestText,
      required GenerationAttemptFence attemptFence, bool Function()? isCancelled,
      String? expectedRequestId,
      String workId = '', String userMessageId = '', String interaction = 'unspecified'}) =>
      _commission(deepThinking: deepThinking, requestId: requestId, messageId: messageId,
        brief: brief, requestQuote: requestQuote, latestText: latestText, workId: workId,
        userMessageId: userMessageId.isEmpty ? attemptFence.userMessageId : userMessageId,
        interaction: interaction, attemptFence: attemptFence, isCancelled: isCancelled,
        expectedRequestId: expectedRequestId);

  Future<CreativeCommissionResult> _commission({required bool deepThinking,
      required String requestId, required String messageId, required String brief,
      required String requestQuote, required String latestText, required String workId,
      required String userMessageId, required String interaction,
      GenerationAttemptFence? attemptFence, bool Function()? isCancelled,
      String? expectedRequestId}) async {
    if (!deepThinking || requestId.isEmpty || messageId.isEmpty ||
        requestQuote.trim().isEmpty || !latestText.contains(requestQuote) || brief.trim().isEmpty) {
      throw const FormatException('本轮未授权制作；需要在深度思考中明确委托');
    }
    final fence = attemptFence?.brainFence ?? await db.captureBrainWorkFence();
    if (fence == null) return const CreativeCommissionResult(CreativeCommissionStatus.staleAttempt);
    final handle = await db.database;
    try {
      return await handle.transaction((txn) async {
        requireTurnNotCancelled(isCancelled);
        var id = workId.isEmpty ? CreativeContract.hash(requestId).substring(0, 24) : workId;
        var before = CreativeContract.decode(await BrainWorkFence.value(txn, key(id)));
        if (before.isEmpty && workId.isEmpty && attemptFence != null) {
          // Previous releases used the job ID as request identity. Preserve
          // that registered work instead of creating a second stable-slot ID.
          final legacyId = CreativeContract.hash(attemptFence.jobId).substring(0, 24);
          final legacy = CreativeContract.decode(await BrainWorkFence.value(txn, key(legacyId)));
          if (legacy['request_id'] == attemptFence.jobId) { id = legacyId; before = legacy; }
        }
        final previous = workId.isEmpty ? <String, dynamic>{}
            : CreativeContract.decode(await BrainWorkFence.value(txn, CreativeWorkspace.key(id)));
        final priorEffect = attemptFence == null ? null : await TurnExecutionStore.readEffectInTransaction(
          txn, turnId: attemptFence.userMessageId, slot: TurnEffectSlot.creativeCommission);
        final previousPlan = previous['plan'] as Map? ?? const {};
        final inherited = priorEffect?.result['interaction'] ??
          (before['request_id'] == requestId || before['request_id'] == attemptFence?.jobId
            ? before['commission_interaction'] : null) ??
          ({'companion', 'local'}.contains(before['interaction']) ? before['interaction'] : previousPlan['interaction']);
        final effectiveInteraction = {'companion', 'local'}.contains(interaction) ? interaction
          : {'companion', 'local'}.contains(inherited) ? inherited : 'unspecified';
        String normalize(String value) => value.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
        final payload = <String, Object?>{'work_id': workId,
          'target_request_id': expectedRequestId ?? '', 'brief': normalize(brief),
          'interaction': effectiveInteraction, 'request_quote': normalize(requestQuote),
          'user_message_id': userMessageId, 'source_text': normalize(latestText)};
        final payloadHash = turnPayloadHash(payload);
        if (attemptFence != null) {
          final admission = await TurnExecutionStore.inspectLocalInTransaction(txn,
            attempt: attemptFence, slot: TurnEffectSlot.creativeCommission,
            payload: payload, isCancelled: isCancelled);
          if (admission.state == LocalEffectAdmissionState.conflict) {
            return const CreativeCommissionResult(CreativeCommissionStatus.conflict);
          }
          if (admission.state == LocalEffectAdmissionState.replay) {
            final facts = admission.receipt!.result;
            final existing = CreativeContract.decode(await BrainWorkFence.value(txn, key(facts['work_id'] as String)));
            // An old accepted request remains a fact even after a later
            // revision. Do not describe that later revision as this replay.
            final work = existing['request_id'] == facts['request_id'] ? existing : <String, dynamic>{
              'id': facts['work_id'], 'request_id': facts['request_id'],
              'status': existing['status'] == 'deleted' ? 'deleted' : 'superseded',
              'interaction': facts['interaction']};
            return CreativeCommissionResult(CreativeCommissionStatus.replayed, work);
          }
          if (admission.state == LocalEffectAdmissionState.staleAttempt ||
              attemptFence.userMessageId != userMessageId ||
              attemptFence.assistantMessageId != messageId) {
            return const CreativeCommissionResult(CreativeCommissionStatus.staleAttempt);
          }
          final source = await txn.query('messages', columns: ['content'],
            where: 'id = ? AND role = ?', whereArgs: [userMessageId, 'user'], limit: 1);
          if (source.isEmpty || source.first['content'] != latestText) {
            return const CreativeCommissionResult(CreativeCommissionStatus.staleAttempt);
          }
        } else if (!await fence.matches(txn)) {
          return const CreativeCommissionResult(CreativeCommissionStatus.staleAttempt);
        }
        if (attemptFence != null) {
          // Upgrades may have a registered work/card but no stable effect
          // receipt yet. Look for the whole turn before admitting any new
          // target, including older revisions whose IDs are not hash(jobId).
          final rows = await txn.query('settings', columns: ['key', 'value'],
            where: 'key LIKE ? OR key LIKE ?',
            whereArgs: ['${CreativeContract.metaPrefix}%', '${CreativeContract.receiptPrefix}%']);
          for (final row in rows) {
            final saved = CreativeContract.decode(row['value'] as String?);
            final meta = (row['key'] as String).startsWith(CreativeContract.metaPrefix);
            final sameTurn = saved['request_id'] == attemptFence.jobId ||
              saved['request_id'] == requestId ||
              (meta && saved['user_message_id'] == attemptFence.userMessageId) ||
              (!meta && saved['message_id'] == attemptFence.assistantMessageId);
            if (!sameTurn) continue;
            final savedId = saved[meta ? 'id' : 'work_id'];
            if (savedId != id || saved['request_id'] != before['request_id'] ||
                (before['request_id'] != requestId && before['request_id'] != attemptFence.jobId)) {
              // A different or superseded old registration cannot authorize
              // another work. Keep the historical fact without guessing its
              // missing payload or changing either target.
              return const CreativeCommissionResult(CreativeCommissionStatus.conflict);
            }
          }
        }
        if (before['request_id'] == requestId ||
            (attemptFence != null && before['request_id'] == attemptFence.jobId)) {
          final savedHash = before['commission_payload_hash'];
          // Old truncated fields cannot prove equality for oversized input.
          final legacySame = savedHash == null && brief.length <= 8000 && requestQuote.length <= 2000 &&
            latestText.length <= 12000 && before['brief'] == normalize(brief) &&
            before['request_quote'] == requestQuote && before['original_request'] == latestText &&
            (before['user_message_id'] ?? '') == userMessageId &&
            (before['interaction'] ?? 'unspecified') == effectiveInteraction;
          if (savedHash == payloadHash || legacySame) {
            if (attemptFence != null) {
              // Claim the same stable slot for a proven older registration.
              // Otherwise a second target could bypass this legacy replay.
              await TurnExecutionStore.writeEffectInTransaction(txn, LocalEffectReceipt(
                turnId: attemptFence.userMessageId, slot: TurnEffectSlot.creativeCommission,
                payloadHash: payloadHash, state: LocalEffectState.committed,
                result: {'work_id': id, 'request_id': before['request_id'],
                  'interaction': effectiveInteraction, 'status': 'accepted'},
                runToken: attemptFence.runToken,
                createdAt: before['updated'] as int? ?? DateTime.now().millisecondsSinceEpoch));
              if (beforeLocalCommit != null) await beforeLocalCommit!(txn);
              requireTurnNotCancelled(isCancelled);
            }
            return CreativeCommissionResult(CreativeCommissionStatus.replayed, before);
          }
          return const CreativeCommissionResult(CreativeCommissionStatus.conflict);
        }
        if (workId.isNotEmpty && !CreativeAutonomyPolicy.visible(before)) {
          return const CreativeCommissionResult(CreativeCommissionStatus.targetMissing);
        }
        if (attemptFence != null && workId.isNotEmpty &&
            (expectedRequestId == null || expectedRequestId.isEmpty || before['request_id'] != expectedRequestId)) {
          return const CreativeCommissionResult(CreativeCommissionStatus.conflict);
        }
        if (CreativeContract.active.contains(before['status'])) {
          return const CreativeCommissionResult(CreativeCommissionStatus.targetBusy);
        }
        final model = await BrainWorkFence.value(txn, 'creative_work_model');
        final effort = await BrainWorkFence.value(txn, 'creative_work_effort');
        final now = DateTime.now().millisecondsSinceEpoch;
        final after = <String, dynamic>{...before,
          'schema': 1, 'id': id, 'origin': 'commission', 'visibility': 'shared',
          'request_id': requestId, 'message_id': messageId, 'user_message_id': userMessageId,
          if (attemptFence != null) 'job_id': attemptFence.jobId,
          'commission_payload_hash': payloadHash, 'commission_interaction': effectiveInteraction,
          'request_quote': CreativeContract.clip(requestQuote, 2000),
          'original_request': CreativeContract.clip(latestText, 12000), 'interaction': effectiveInteraction,
          'brief': CreativeContract.clip(normalize(brief), 8000), 'title': before['title'] ?? '新的小作品',
          'intro': before['intro'] ?? '', 'status': 'queued', 'attempts': 0, 'updated': now,
          'model': model.isEmpty ? 'deepseek-flash' : model, 'effort': effort.isEmpty ? 'max' : effort,
          'note': '等待后台制作', 'draft': workId.isEmpty ? '' : before['draft'] ?? '', 'errors': <Object?>[],
          'retry_at': 0, 'agent_step': 0, 'agent_trace': <Object?>[], 'model_turns': 0,
          'tool_calls': 0, 'committed_mutations': 0, 'late_result_dropped': 0, 'preempt': '',
          'versions': before['versions'] ?? <Object?>[],
        };
        var nextWorkspace = '';
        if (workId.isNotEmpty && previous.isNotEmpty) {
          final next = CreativeWorkspace.create(id, requestId);
          next['files'] = CreativeWorkspace.files(previous);
          CreativeWorkspace.validate(next, id);
          nextWorkspace = jsonEncode(next);
        }
        after.remove('completion_message_id'); after.remove('completed_request'); after.remove('completed_at');
        final previousReceiptKey = '${CreativeContract.receiptPrefix}${before['message_id']}';
        final previousReceipt = CreativeContract.decode(await BrainWorkFence.value(txn, previousReceiptKey));
        final values = <String, String>{key(id): jsonEncode(after), CreativeWorkspace.key(id): nextWorkspace,
          '${CreativeContract.noticePrefix}$id': '',
          if (before['message_id'] is String && (before['message_id'] as String).isNotEmpty && before['message_id'] != messageId)
            previousReceiptKey: jsonEncode({...previousReceipt, 'message_id': before['message_id'],
              'work_id': id, 'version': previousReceipt['version'] ?? before['current'] ?? '', 'kind': 'progress',
              'request_id': before['request_id'], 'completed': previousReceipt['completed'] == true ||
                (before['request_id'] is String && before['completed_request'] == before['request_id']) || before['status'] == 'ready'}),
          if (before['completion_message_id'] is String)
            '${CreativeContract.receiptPrefix}${before['completion_message_id']}': jsonEncode({'message_id': before['completion_message_id'],
              'work_id': id, 'version': before['current'] ?? '', 'kind': 'delivered'}),
          '${CreativeContract.receiptPrefix}$messageId': jsonEncode({'message_id': messageId,
            'work_id': id, 'version': '', 'kind': 'progress', 'request_id': requestId, 'completed': false})};
        for (final entry in values.entries) {
          await txn.insert('settings', {'key': entry.key, 'value': entry.value}, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (attemptFence != null) {
          await TurnExecutionStore.writeEffectInTransaction(txn, LocalEffectReceipt(
            turnId: attemptFence.userMessageId, slot: TurnEffectSlot.creativeCommission,
            payloadHash: payloadHash, state: LocalEffectState.committed,
            result: {'work_id': id, 'request_id': requestId, 'interaction': effectiveInteraction, 'status': 'accepted'},
            runToken: attemptFence.runToken, createdAt: now));
        }
        if (beforeLocalCommit != null) await beforeLocalCommit!(txn);
        requireTurnNotCancelled(isCancelled);
        return CreativeCommissionResult(CreativeCommissionStatus.accepted, after);
      });
    } on TurnCommitCancelled {
      return const CreativeCommissionResult(CreativeCommissionStatus.staleAttempt);
    }
  }

  Future<String> originalRequest(Map<String, dynamic> work) async {
    if (CreativeAutonomyPolicy.autonomous(work)) return '';
    final saved = (work['original_request'] ?? work['request_quote']) as String? ?? '';
    if (saved.isNotEmpty) return saved;
    // +339 cards can reference the assistant message rather than the user.
    // Resolve only that exact turn, never inject the whole recent conversation.
    final handle = await db.database;
    final anchor = await handle.query('messages', columns: ['role', 'content', 'created_at'],
      where: 'id = ?', whereArgs: [work['user_message_id'] ?? work['message_id']], limit: 1);
    if (anchor.isEmpty) return '';
    if (anchor.first['role'] == 'user') return CreativeContract.clip(anchor.first['content'], 12000);
    final user = await handle.query('messages', columns: ['content'],
      where: 'role = ? AND created_at <= ?', whereArgs: ['user', anchor.first['created_at']],
      orderBy: 'created_at DESC', limit: 1);
    return user.isEmpty ? '' : CreativeContract.clip(user.first['content'], 12000);
  }

  Future<CreativeControlTarget?> captureControlTarget(Map<String, dynamic> work,
      {BrainWorkFence? fence}) async {
    final identity = fence ?? await db.captureBrainWorkFence();
    if (identity == null || work['id'] is! String || work['request_id'] is! String) return null;
    return CreativeControlTarget(workId: work['id'] as String,
      requestId: work['request_id'] as String, brainFence: identity);
  }

  Future<CreativeControlResult> stopTarget(CreativeControlTarget target,
      {GenerationAttemptFence? attemptFence, bool Function()? isCancelled}) =>
      _control(target, 'stop', attemptFence: attemptFence, isCancelled: isCancelled);

  Future<CreativeControlResult> resumeTarget(CreativeControlTarget target,
      {bool privatePermission = false, GenerationAttemptFence? attemptFence,
      bool Function()? isCancelled}) => _control(target, 'resume',
        privatePermission: privatePermission, attemptFence: attemptFence, isCancelled: isCancelled);

  Future<CreativeControlResult> deleteTarget(CreativeControlTarget target,
      {GenerationAttemptFence? attemptFence, bool Function()? isCancelled}) async {
    final result = await _control(target, 'delete', attemptFence: attemptFence, isCancelled: isCancelled);
    if (result.applied) await collectUnusedSources();
    return result;
  }

  Future<CreativeControlResult> _control(CreativeControlTarget target, String action,
      {bool privatePermission = false, GenerationAttemptFence? attemptFence,
      bool Function()? isCancelled}) async {
    final handle = await db.database;
    try {
      return await handle.transaction((txn) async {
        final payload = {'work_id': target.workId, 'request_id': target.requestId, 'action': action};
        if (attemptFence != null) {
          final admission = await TurnExecutionStore.inspectLocalInTransaction(txn,
            attempt: attemptFence, slot: TurnEffectSlot.creativeControl,
            payload: payload, isCancelled: isCancelled);
          if (admission.state == LocalEffectAdmissionState.replay) {
            final current = CreativeContract.decode(await BrainWorkFence.value(txn, key(target.workId)));
            return CreativeControlResult(CreativeControlStatus.replayed, current);
          }
          if (admission.state == LocalEffectAdmissionState.conflict) {
            return const CreativeControlResult(CreativeControlStatus.conflict);
          }
          if (admission.state == LocalEffectAdmissionState.staleAttempt) {
            return const CreativeControlResult(CreativeControlStatus.staleTarget);
          }
        }
        Future<CreativeControlResult> settled(CreativeControlStatus status, Map<String, dynamic> work) async {
          if (attemptFence != null) {
            await TurnExecutionStore.writeEffectInTransaction(txn, LocalEffectReceipt(
              turnId: attemptFence.userMessageId, slot: TurnEffectSlot.creativeControl,
              payloadHash: turnPayloadHash(payload), state: LocalEffectState.committed,
              result: {...payload, 'status': status.name}, runToken: attemptFence.runToken,
              createdAt: DateTime.now().millisecondsSinceEpoch));
          }
          if (beforeLocalCommit != null) await beforeLocalCommit!(txn);
          requireTurnNotCancelled(isCancelled);
          return CreativeControlResult(status, work);
        }
        if (!await target.brainFence.matches(txn) ||
            (attemptFence != null && !await attemptFence.matches(txn)) ||
            isCancelled?.call() == true) {
          return const CreativeControlResult(CreativeControlStatus.staleTarget);
        }
        final before = CreativeContract.decode(await BrainWorkFence.value(txn, key(target.workId)));
        if (before['request_id'] != target.requestId || target.requestId.isEmpty) {
          return const CreativeControlResult(CreativeControlStatus.staleTarget);
        }
        if ((!privatePermission && !CreativeAutonomyPolicy.visible(before)) || before['status'] == 'deleted') {
          return CreativeControlResult(CreativeControlStatus.unavailable, before);
        }
        final extra = <String, String>{};
        Map<String, dynamic> after;
        if (action == 'delete') {
          after = {'schema': 1, 'id': target.workId, 'status': 'deleted',
            'request_id': before['request_id'], 'message_id': before['message_id'],
            'commission_payload_hash': before['commission_payload_hash'],
            'commission_interaction': before['commission_interaction'],
            'updated': DateTime.now().millisecondsSinceEpoch};
          for (final prefix in [CreativeContract.playPrefix, CreativeWorkspace.prefix,
            CreativeContract.noticePrefix, CreativeContract.playTracePrefix]) {
            extra['$prefix${target.workId}'] = '';
          }
        } else {
          if (before['status'] == 'ready') {
            return settled(CreativeControlStatus.alreadyFinished, before);
          }
          if (action == 'stop') {
            if (before['status'] == 'paused') return settled(CreativeControlStatus.alreadyPaused, before);
            if (!CreativeContract.active.contains(before['status'])) {
              return CreativeControlResult(CreativeControlStatus.unavailable, before);
            }
            after = {...before, 'status': 'paused', 'note': '已暂停', 'preempt': 'user_stop',
              'updated': DateTime.now().millisecondsSinceEpoch};
          } else {
            if (!{'paused', 'failed'}.contains(before['status'])) {
              return CreativeControlResult(CreativeControlStatus.unavailable, before);
            }
            final agent = CreativeContract.decode(await BrainWorkFence.value(txn, CreativeWorkspace.key(target.workId)));
            if (agent.isNotEmpty && agent['request_id'] == target.requestId) {
              agent['failures'] = 0; agent['next_at'] = 0;
              extra[CreativeWorkspace.key(target.workId)] = jsonEncode(agent);
            }
            final model = await BrainWorkFence.value(txn, 'creative_work_model');
            final effort = await BrainWorkFence.value(txn, 'creative_work_effort');
            after = {...before, 'status': 'queued', 'attempts': 0, 'retry_at': 0, 'preempt': '',
              'model': model.isNotEmpty ? model : before['model'] ?? 'deepseek-flash',
              'effort': effort.isNotEmpty ? effort : before['effort'] ?? 'max',
              'updated': DateTime.now().millisecondsSinceEpoch, 'note': '等待继续制作'};
          }
        }
        for (final entry in {key(target.workId): jsonEncode(after), ...extra}.entries) {
          await txn.insert('settings', {'key': entry.key, 'value': entry.value},
            conflictAlgorithm: ConflictAlgorithm.replace);
        }
        // Stop may arrive while the transaction was queued or awaiting its
        // writes. Throwing here rolls back every change, including the card.
        return settled(action == 'delete'
          ? CreativeControlStatus.deleted : CreativeControlStatus.applied, after);
      });
    } on TurnCommitCancelled {
      return const CreativeControlResult(CreativeControlStatus.staleTarget);
    }
  }

  // Immediate trusted callers capture the current target. UI menus and Agent
  // routes use the explicit target APIs so delayed intent cannot switch works.
  Future<void> stop(String id) async {
    final target = await captureControlTarget(await get(id));
    if (target != null) await stopTarget(target);
  }
  Future<void> resume(String id, {bool privatePermission = false}) async {
    final target = await captureControlTarget(await get(id));
    if (target != null) await resumeTarget(target, privatePermission: privatePermission);
  }
  Future<void> delete(String id) async {
    final target = await captureControlTarget(await get(id));
    if (target != null) await deleteTarget(target);
  }


  Future<void> setAutonomyEnabled(bool enabled) async {
    // Compare-and-swap keeps rapid overlapping toggles from sharing an epoch.
    while (true) {
      final raw = await db.getSetting(CreativeAutonomyPolicy.epochKey) ?? '';
      final epoch = int.tryParse(raw) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (await db.setSettingsAtomically({CreativeAutonomyPolicy.enabledKey: enabled ? '1' : '0',
        CreativeAutonomyPolicy.epochKey: '${now > epoch ? now : epoch + 1}'},
        expectedSettings: {CreativeAutonomyPolicy.epochKey: raw})) return;
    }
  }

  Future<void> resumeAutonomous() async {
    if (await db.getSetting(CreativeAutonomyPolicy.enabledKey) != '1') return;
    final state = CreativeContract.decode(await db.getSetting(CreativeAutonomyPolicy.stateKey));
    if (state.isNotEmpty) {
      CreativeAutonomyPolicy.validateState(state);
      await db.setSettingsAtomically({CreativeAutonomyPolicy.stateKey: jsonEncode({...state, 'suspended': false}),
        CreativeAutonomyPolicy.attemptKey: ''});
    }
    for (final work in await list(includePrivate: true)) {
      if (!CreativeAutonomyPolicy.autonomous(work) || work['preempt'] == 'self_retired') continue;
      if (work['status'] == 'ready' && work['preempt'] == 'import') {
        await write(work, {...work, 'preempt': '', 'share_after': 0});
      } else if (work['status'] == 'paused' || work['status'] == 'failed') {
        await resume(work['id'] as String, privatePermission: true);
      }
    }
  }

  /// Only called by the private inspiration owner after grounded review.
  Map<String, dynamic> autonomousWork(Map<String, dynamic> idea, DateTime at,
      {required String model, required String effort}) {
    final request = 'autonomous:${idea['id']}';
    final id = CreativeContract.hash(request).substring(0, 24);
    return {'schema': 1, 'id': id, 'origin': 'autonomous', 'visibility': 'private',
      'idea_id': idea['id'], 'request_id': request, 'message_id': '', 'original_request': '',
      'motive': idea['motive'], 'brief': idea['brief'], 'evidence': idea['evidence'],
      'interaction': 'unspecified', 'title': '小作品', 'intro': '', 'status': 'queued',
      'attempts': 0, 'updated': at.millisecondsSinceEpoch, 'model': model, 'effort': effort,
      'note': '等待空闲制作', 'draft': '', 'errors': <Object?>[], 'retry_at': 0,
      'agent_step': 0, 'agent_trace': <Object?>[], 'model_turns': 0, 'tool_calls': 0,
      'committed_mutations': 0, 'late_result_dropped': 0, 'preempt': '', 'versions': <String>[]};
  }

  Future<List<Map<String, dynamic>>> shareCandidates(DateTime now) async {
    if (await db.getSetting(CreativeAutonomyPolicy.enabledKey) != '1') return [];
    return (await list(includePrivate: true)).where((w) => CreativeShare.eligible(w, now)).take(2).toList();
  }

  Future<CreativeShare?> claimShare(String id, DateTime now) async {
    if (await db.getSetting(CreativeAutonomyPolicy.enabledKey) != '1') return null;
    final work = await get(id);
    if (!CreativeShare.eligible(work, now)) return null;
    final fence = await db.captureBrainWorkFence(settingKeys: [
      CreativeAutonomyPolicy.enabledKey, CreativeAutonomyPolicy.epochKey]);
    if (fence == null || fence.expectedSettings[CreativeAutonomyPolicy.enabledKey] != '1') return null;
    // WAIT and failed writing leave it private; don't buy the same decision on every heartbeat.
    final next = {...work, 'share_after': now.add(const Duration(hours: 2)).millisecondsSinceEpoch};
    if (!await write(work, next, fence: fence)) return null;
    return CreativeShare(next, fence.expectedSettings[CreativeAutonomyPolicy.epochKey] ?? '');
  }

  static const requestContract = '深度思考只决定本轮能否接受新的制作或修改委托。'
      '一旦委托已登记，工作 Agent 使用独立工作模型和思考力度持续制作；关闭聊天深度思考、继续普通聊天不会取消制作。'
      '已有任务只能依据下面的实际记录说明进度，不得要求用户重新打开深度思考或重新委托才能继续。'
      '用户明确暂停、删除、配置错误或达到自动恢复上限才可能暂停；原因以记录为准。';

  Future<String> chatContext({String query = '', String userMessageId = '', bool relevantOnly = false}) async {
    final facts = await CreativeFacts(db).prompt(query: query, userMessageId: userMessageId, relevantOnly: relevantOnly);
    return facts.isEmpty ? '' : '$requestContract\n$facts';
  }

  Future<Map<String, Object?>> diagnostics() async {
    final works = await list();
    final delivery = <Object?>[];
    final play = <Object?>[];
    for (final work in works.take(20)) {
      final id = work['id'] as String;
      final notice = CreativeContract.decode(await db.getSetting('${CreativeContract.noticePrefix}$id'));
      if (notice.isNotEmpty) delivery.add({'id': id, 'feature': 'creative_completion',
        'execution_id': notice['request_id'], 'trigger_source': 'work_finish',
        'continuation_owner': 'creative_delivery_lease_until', 'usage_lane': 'creative_completion_final',
        'planning_rounds': 0, 'tool_calls': 0, 'committed_mutations': notice['status'] == 'delivered' ? 1 : 0,
        'continuation_requested': notice['status'] == 'pending', 'terminal': notice['status'] != 'pending',
        for (final field in ['status', 'phase', 'attempts', 'failures', 'next_at', 'model_calls', 'provider_failure', 'error', 'preempt', 'late_write'])
          if (notice.containsKey(field)) field: notice[field]});
      final trace = CreativeContract.decode(await db.getSetting('${CreativeContract.playTracePrefix}$id'));
      if (trace.isNotEmpty) play.add({'id': id, 'events': trace['events']});
    }
    return {'feature': 'creative_work', 'worker': 'tool_agent_v1',
      'completion_delivery': delivery, 'interaction_events': play,
      'ui': CreativeContract.decode(await db.getSetting('creative_ui_trace_v1')),
      'continuation_owner': 'creative_worker_lease_until', 'usage_lane': 'creative_build',
      'works': works.take(20).map((work) => {
      'id': work['id'], 'status': work['status'], 'attempts': work['attempts'],
      'execution_id': work['request_id'], 'trigger_source': work['trigger_source'],
      'phase': work['status'], 'planning_rounds': work['model_turns'],
      'tool_calls': work['tool_calls'], 'committed_mutations': work['committed_mutations'],
      'continuation_requested': CreativeContract.active.contains(work['status']),
      'terminal': !CreativeContract.active.contains(work['status']),
      'preempt': work['preempt'], 'late_write': work['late_result_dropped'],
      'agent_step': work['agent_step'], 'retry_at': work['retry_at'],
      'has_draft': (work['draft'] as String? ?? '').isNotEmpty,
      'has_published': (work['current'] as String? ?? '').isNotEmpty,
      'trace': (work['agent_trace'] as List? ?? []).whereType<Map>().map((event) => {
        for (final field in ['at', 'kind', 'code', 'tool', 'ok', 'files', 'finish_reason',
          'content_characters', 'reasoning_characters', 'argument_characters',
          'tool_count', 'elapsed_ms', 'input_tokens', 'output_tokens'])
          if (event.containsKey(field)) field: event[field],
      }).toList(),
    }).toList()};
  }

  Future<void> collectUnusedSources() async {
    // Same transaction as the reference scan, so a concurrent publish cannot
    // lose its source. Tombstones fence network completions after deletion.
    final handle = await db.database;
    await handle.transaction((txn) async {
      if (!await BrainWorkFence.workAllowed(txn)) return;
      final rows = await txn.query('settings', columns: ['key', 'value'],
        where: 'key LIKE ? OR key LIKE ?', whereArgs: [
          '${CreativeContract.metaPrefix}%', '${CreativeContract.playPrefix}%']);
      final keep = <String>{};
      for (final row in rows) {
        final data = CreativeContract.decode(row['value'] as String?);
        for (final field in ['draft', 'current', 'version']) {
          if (data[field] is String) keep.add(data[field] as String);
        }
        keep.addAll((data['versions'] as List? ?? []).whereType<String>());
      }
      final sources = await txn.query('settings', columns: ['key'], where: 'key LIKE ?',
          whereArgs: ['${CreativeContract.sourcePrefix}%']);
      for (final row in sources) {
        final key = row['key'] as String;
        if (!keep.contains(key.substring(CreativeContract.sourcePrefix.length))) {
          await txn.delete('settings', where: 'key = ?', whereArgs: [key]);
        }
      }
    });
  }
}
