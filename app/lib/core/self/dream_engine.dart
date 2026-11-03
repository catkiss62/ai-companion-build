import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../ai/background_cost_policy.dart';
import '../ai/first_channel_model.dart';
import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../storage/secure_config.dart';
import 'dream_contract.dart';
import 'dream_material.dart';
import 'dream_store.dart';
import 'dream_catchup.dart';
import 'dream_review_diagnostic.dart';

typedef DreamReviewer = Future<Map<String, dynamic>?> Function(Map<String, Object?> material);

/// One bounded step per idle heartbeat. Historical reading is private and resumable.
class DreamEngine {
  DreamEngine(this.db, {this.reviewer, SecureConfig? secureConfig, this.clientFactory})
      : secureConfig = secureConfig ?? SecureConfig.instance;
  final AppDatabase db;
  final DreamReviewer? reviewer;
  final SecureConfig secureConfig;
  final DeepSeekClient Function(Future<bool> Function() abort)? clientFactory;
  static const requestBudgetKey = 'nightly_dream_request_budget_v1';
  static const catchupBatchKey = 'nightly_dream_catchup_batch_limit_v1';

  Future<Map<String, dynamic>?> _review(Map<String, Object?> material,
      BrainWorkFence fence, DeepSeekModelProfile reviewModel) async {
    final key = (await secureConfig.readApiKey())?.trim() ?? '';
    if (key.isEmpty) throw const DreamReviewMissingApiKey();
    Future<bool> abort() async => !await db.brainWorkFenceCurrent(fence) ||
        !await DreamStore.idle(await db.database, DateTime.now(), manual: true);
    final client = clientFactory?.call(abort) ?? DeepSeekClient(abortWhen: abort);
    try {
      return await client.jsonCompletion(
        apiKey: key, endpoint: await secureConfig.readEndpoint(), model: reviewModel,
        thinking: true, effort: ReasoningEffort.high, maxTokens: 12000,
        requestTimeout: const Duration(seconds: 120), usageLane: 'nightly_dream',
        usageExecutionId: 'dream:${material['day']}:${material['phase']}',
        messages: [
          {'role': 'system', 'content': '${DreamContract.instruction}\n${DreamCatchup.instruction(material['phase'].toString())}'},
          {'role': 'user', 'content': jsonEncode(material)},
        ],
      );
    } finally { client.close(); }
  }

  /// Manual skips grace/backoff, never evidence, ownership or request ceilings.
  Future<bool> maybeDream({DateTime? now, bool manual = false}) async {
    final instant = now ?? DateTime.now();
    if (!manual && await BackgroundCostPolicy.deferredUntil(db, instant, config: secureConfig) != null) return false;
    final store = DreamStore(db);
    if (await db.getSetting(DreamStore.enabledKey) == '0' ||
        !await DreamStore.idle(await db.database, instant, manual: manual)) return false;
    final interruptedProcess = DreamContract.decode(await db.getSetting(DreamStore.diagnosticKey))['status'] == 'preparing' &&
        !await db.isLocalLeaseHeld(DreamStore.leaseKey);
    if (!await db.tryAcquireLocalLease(DreamStore.leaseKey, holdFor: const Duration(minutes: 4))) return false;
    try {
      final fence = await db.captureBrainWorkFence(leaseKey: DreamStore.leaseKey,
          settingKeys: [DreamStore.enabledKey, 'conversation_context_reset_at', ...DreamStore.busyLeases]);
      if (fence == null || fence.expectedSettings[DreamStore.enabledKey] == '0') return false;
      final raw = await db.getSetting(DreamStore.stateKey) ?? '';
      final state = DreamContract.decode(raw);
      if (raw.isNotEmpty && (state['schema'] != 1 || state['insights'] is! List)) return false;
      var catchup = DreamCatchup.read(state);
      if (state.containsKey('catchup') && (catchup == null || !DreamCatchup.valid(catchup))) return false;
      // Partition old and future sources atomically. Moving the ordinary cursor
      // does not claim completion: its entire old range remains in this journal.
      if (catchup == null) {
        final started = await DreamCatchup.start(db, state, instant);
        if (started != null) {
          return await store.commit(next: started, expectedRaw: raw,
              stamp: await DreamStore.messageStamp(await db.database), sources: [],
              fence: fence, now: instant, manual: manual, completed: false,
              diagnostic: {'status': 'catchup_started', 'phase': 'catchup_read',
                'at': instant.millisecondsSinceEpoch, 'has_backlog': true});
        }
      }
      final day = DreamContract.day(instant);
      final ordinaryDue = DreamContract.string(state['last_success_day']).compareTo(day) < 0;
      if (!ordinaryDue && catchup == null) return false;
      final lastWeekly = DreamContract.number(state['last_weekly_at']);
      final weekly = lastWeekly == 0 || instant.millisecondsSinceEpoch - lastWeekly >= const Duration(days: 7).inMilliseconds;
      final ordinaryLimit = (int.tryParse(await db.getSetting('nightly_dream_batch_limit_v1') ?? '') ?? 48).clamp(6,48).toInt();
      DreamMaterial? ordinary;
      if (ordinaryDue) ordinary = await DreamMaterial.collect(db, state, instant,
          weekly: catchup == null && weekly, batchLimit: ordinaryLimit, characterLimit: 16000);
      var phase = 'ordinary';
      var batchLimit = ordinaryLimit;
      var working = state;
      late DreamMaterial material;
      if (catchup != null && !(ordinaryDue && (ordinary!.hasNew || ordinary.hasBacklog))) {
        if (catchup['ready'] == true) {
          phase = 'catchup_integrate';
          material = await DreamCatchup.integrationMaterial(db, state, catchup);
        } else {
          phase = 'catchup_read';
          batchLimit = (int.tryParse(await db.getSetting(catchupBatchKey) ?? '') ?? 240).clamp(6,240).toInt();
          working = Map<String, dynamic>.from(catchup['draft'] as Map);
          material = await DreamMaterial.collect(db,
              {...working, 'cursor': catchup['cursor']}, instant, weekly: false,
              batchLimit: batchLimit, characterLimit: 64000,
              upperCursor: Map<String, Object?>.from(catchup['boundary'] as Map));
        }
      } else { material = ordinary!; }
      final attempt = DreamContract.decode(await db.getSetting(DreamStore.attemptKey));
      final sameAttemptDay = attempt['day'] == day;
      final previousAttempts = sameAttemptDay ? DreamContract.number(attempt['count']) : 0;
      final attempts = interruptedProcess ? (previousAttempts - 1).clamp(0, 1000).toInt() : previousAttempts;
      if (!manual && !interruptedProcess && sameAttemptDay &&
          instant.millisecondsSinceEpoch < DreamContract.number(attempt['retry_at'])) return false;
      final usable = await store.usableInsights(working);
      final draftUnchanged = catchup != null &&
          jsonEncode((catchup['draft'] as Map)['insights']) == jsonEncode(catchup['baseline_insights']);
      final needsReview = phase == 'catchup_integrate' ? !draftUnchanged && material.sources.isNotEmpty :
          material.hasNew || (phase == 'ordinary' && weekly && material.sources.isNotEmpty);
      final diagnostic = <String, Object?>{
        'at': instant.millisecondsSinceEpoch, 'weekly': phase != 'catchup_read' && weekly,
        'phase': phase, 'source_count': material.sources.length, 'batch_limit': batchLimit,
        'has_backlog': catchup != null || material.hasBacklog, 'bootstrap': material.bootstrap,
        'recovered_after_process_interruption': interruptedProcess,
      };
      Future<void> preempted(String reason) async {
        final diagnosticFence = BrainWorkFence(identity: fence.identity,
            leaseKey: fence.leaseKey, leaseToken: fence.leaseToken);
        await db.setSettingsAtomically({
          DreamStore.attemptKey: jsonEncode({...attempt, 'day': day, 'count': attempts,
            'retry_at': instant.add(const Duration(minutes: 2)).millisecondsSinceEpoch}),
          DreamStore.diagnosticKey: jsonEncode({...diagnostic, 'status': reason}),
        }, workFence: diagnosticFence, expectedSettings: {DreamStore.stateKey: raw});
      }
      Map<String, dynamic>? payload = {'changes': <Object?>[]};
      Map<String, Object?>? requestAttempt;
      if (needsReview) {
        final rules = (await db.listRuleLayers()).where((r) => r.key == '04_memory_rules');
        final input = <String, Object?>{
          'day': day, 'phase': phase, 'weekly': phase != 'catchup_read' && weekly,
          'sources': material.sources.map((s) => s.toJson()).toList(),
          'current': DreamContract.records(working['insights']).map((i) => {
            ...i, 'originals_available': usable.any((u) => u['id'] == i['id']),
          }).toList(),
          'recent_revisions': DreamContract.records(working['history']).take(8).toList(),
          'background': material.background,
          'memory_policy_context': rules.isEmpty ? '' : DreamStore.clip(rules.first.content, 3000),
          'bootstrap_recent_sample': material.bootstrap,
          'unprocessed_material_remains': material.hasBacklog,
        };
        final reviewModel = await FirstChannelModel.read(db);
        diagnostic['model'] = reviewModel.apiName;
        final inputText = jsonEncode(input);
        // Includes existing evidence and background, not just new chat text.
        if (inputText.length + DreamContract.instruction.length + DreamCatchup.instruction(phase).length > 180000) {
          await db.setSettingsAtomically({
            phase == 'catchup_read' ? catchupBatchKey : 'nightly_dream_batch_limit_v1': '${(batchLimit ~/ 2).clamp(6,240)}',
            DreamStore.diagnosticKey: jsonEncode({...diagnostic, 'status': 'input_limit', 'failure_category': 'input_limit'}),
          }, workFence: fence, expectedSettings: {DreamStore.stateKey: raw});
          return false;
        }
        final budget = DreamContract.decode(await db.getSetting(requestBudgetKey));
        final paid = budget['day'] == day ? DreamContract.number(budget['requests']) : 0;
        final key = reviewer == null ? (await secureConfig.readApiKey())?.trim() ?? '' : 'injected';
        if (key.isEmpty) {
          await db.setSettingsAtomically({DreamStore.diagnosticKey: jsonEncode({...diagnostic,
            'status': 'unavailable', 'failure_category': 'missing_api_key'})},
            workFence: fence, expectedSettings: {DreamStore.stateKey: raw});
          return false;
        }
        // Configuration repair must immediately unlock a previously failed input.
        // Only the one-way digest is persisted, never credentials or prompt text.
        final config = reviewer == null ? '${await secureConfig.readEndpoint()}|$key' : key;
        final hash = sha256.convert(utf8.encode('${reviewModel.apiName}|$config|$inputText')).toString();
        final sameFailures = sameAttemptDay && attempt['input_hash'] == hash ? DreamContract.number(attempt['same_failures']) : 0;
        if (paid >= 24 || sameFailures >= 3) {
          await db.setSettingsAtomically({DreamStore.diagnosticKey: jsonEncode({...diagnostic,
            'status': paid >= 24 ? 'request_budget_paused' : 'repeated_failure_paused'})},
            workFence: fence, expectedSettings: {DreamStore.stateKey: raw});
          return false;
        }
        requestAttempt = {'day': day, 'count': attempts + 1, 'input_hash': hash, 'same_failures': sameFailures,
          'retry_at': instant.add(Duration(minutes: 30 * (1 << attempts.clamp(0, 3).toInt()))).millisecondsSinceEpoch};
        if (!await db.setSettingsAtomically({
          DreamStore.attemptKey: jsonEncode(requestAttempt),
          requestBudgetKey: jsonEncode({'day': day, 'requests': paid + 1}),
          DreamStore.diagnosticKey: jsonEncode({...diagnostic, 'status': 'preparing'}),
        }, expectedSettings: {DreamStore.stateKey: raw}, workFence: fence)) return false;
        try { payload = await (reviewer == null ? _review(input, fence, reviewModel) : reviewer!(input)); }
        catch (error) { diagnostic.addAll(DreamReviewDiagnostic.failure(error)); payload = null; }
      }
      if (!await db.brainWorkFenceCurrent(fence) ||
          !await DreamStore.idle(await db.database, DateTime.now(), manual: true)) {
        await preempted('preempted_by_activity'); return false;
      }
      // Integration has one overall mutation budget, not two changes per old batch.
      final tooMany = phase == 'catchup_integrate' && payload?['changes'] is List && (payload!['changes'] as List).length > 2;
      final proposed = tooMany ? null : DreamContract.apply(payload: payload, state: working,
          sources: material.sources, now: instant);
      if (proposed == null) {
        await db.setSettingsAtomically({
          if (diagnostic['failure_category'] == 'output_limit')
            phase == 'catchup_read' ? catchupBatchKey : 'nightly_dream_batch_limit_v1': '${(batchLimit ~/ 2).clamp(6,240)}',
          if (requestAttempt != null) DreamStore.attemptKey: jsonEncode({...requestAttempt,
            'same_failures': payload != null ||
                const {'output_limit', 'invalid_json', 'invalid_evidence'}.contains(diagnostic['failure_category'])
                ? DreamContract.number(requestAttempt['same_failures']) + 1 : 0}),
          DreamStore.diagnosticKey: jsonEncode({...diagnostic,
            'status': payload == null ? 'unavailable' : 'invalid_evidence',
            if (payload == null && !diagnostic.containsKey('failure_category')) 'failure_category': 'unavailable'}),
        }, workFence: fence, expectedSettings: {DreamStore.stateKey: raw});
        return false;
      }
      late Map<String, dynamic> next;
      if (phase == 'catchup_read') {
        next = {...state, 'catchup': {...catchup!, 'cursor': material.cursor, 'draft': proposed,
          'batches': DreamContract.number(catchup['batches']) + 1, 'ready': !material.hasBacklog}};
      } else {
        next = proposed;
        if (phase == 'catchup_integrate') {
          next.remove('catchup');
          next['last_catchup'] = {'completed_at': instant.millisecondsSinceEpoch,
            'batches': catchup!['batches'], 'before_insights': catchup['baseline_insights']};
          diagnostic['has_backlog'] = false;
        } else { next['cursor'] = material.cursor; }
        if (needsReview || !material.hasBacklog) next['last_success_day'] = day;
        next['last_completed_at'] = instant.millisecondsSinceEpoch;
        next['last_weekly_at'] = weekly && needsReview ? instant.millisecondsSinceEpoch : lastWeekly;
      }
      final changed = phase == 'catchup_read' ? 0 :
          DreamContract.records(next['insights']).where((i) => i['updated_at'] == instant.millisecondsSinceEpoch).length +
          DreamContract.records(next['history']).where((i) => i['retired_at'] == instant.millisecondsSinceEpoch).length;
      final committed = await store.commit(next: next, expectedRaw: raw, stamp: material.stamp,
          sources: material.sources, fence: fence, now: instant, manual: manual,
          completed: phase != 'catchup_read', diagnostic: {...diagnostic,
            'status': phase == 'catchup_read' ? 'catchup_read' : needsReview ? 'completed' : 'quiet', 'changed_count': changed});
      if (!committed) await preempted('evidence_changed_before_commit');
      return committed;
    } catch (_) { return false; }
    finally { await db.releaseLocalLease(DreamStore.leaseKey); }
  }
}
