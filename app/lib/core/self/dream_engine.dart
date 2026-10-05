import 'dart:convert';
import '../ai/deepseek_client.dart';
import '../ai/model_profile.dart';
import '../database/app_database.dart';
import '../database/brain_work_fence.dart';
import '../storage/secure_config.dart';
import 'dream_contract.dart';
import 'dream_material.dart';
import 'dream_store.dart';

typedef DreamReviewer =
    Future<Map<String, dynamic>?> Function(Map<String, Object?> material);

/// Runs on the existing heartbeat, without messages, tools or Desire pulses.
class DreamEngine {
  DreamEngine(this.db, {this.reviewer, SecureConfig? secureConfig})
    : secureConfig = secureConfig ?? SecureConfig.instance;
  final AppDatabase db;
  final DreamReviewer? reviewer;
  final SecureConfig secureConfig;

  Future<Map<String, dynamic>?> _review(
    Map<String, Object?> material,
    BrainWorkFence fence,
  ) async {
    final key = (await secureConfig.readApiKey())?.trim() ?? '';
    if (key.isEmpty) return null;
    final client = DeepSeekClient(
      abortWhen: () async =>
          !await db.brainWorkFenceCurrent(fence) ||
          !await DreamStore.idle(
            await db.database,
            DateTime.now(),
            manual: true,
          ),
    );
    try {
      return await client.jsonCompletion(
        apiKey: key,
        endpoint: await secureConfig.readEndpoint(),
        model: DeepSeekModelProfile.pro,
        thinking: true,
        effort: ReasoningEffort.high,
        maxTokens: 6000,
        requestTimeout: const Duration(seconds: 120),
        usageLane: 'nightly_dream',
        usageExecutionId: 'dream:${material['day']}',
        messages: [
          {'role': 'system', 'content': DreamContract.instruction},
          {'role': 'user', 'content': jsonEncode(material)},
        ],
      );
    } finally {
      client.close();
    }
  }

  /// [manual] skips the idle grace and retry delay, never a busy/ownership
  /// gate, the successful-day limit, or evidence validation.
  Future<bool> maybeDream({DateTime? now, bool manual = false}) async {
    final instant = now ?? DateTime.now();
    final store = DreamStore(db);
    if (await db.getSetting(DreamStore.enabledKey) == '0' ||
        !await DreamStore.idle(await db.database, instant, manual: manual))
      return false;
    if (!await db.tryAcquireLocalLease(
      DreamStore.leaseKey,
      holdFor: const Duration(minutes: 4),
    ))
      return false;
    try {
      final fence = await db.captureBrainWorkFence(
        leaseKey: DreamStore.leaseKey,
        settingKeys: [
          DreamStore.enabledKey,
          'conversation_context_reset_at',
          ...DreamStore.busyLeases,
        ],
      );
      if (fence == null || fence.expectedSettings[DreamStore.enabledKey] == '0')
        return false;
      final raw = await db.getSetting(DreamStore.stateKey) ?? '';
      final state = DreamContract.decode(raw);
      // Unknown/corrupt state is never silently overwritten with a fresh soul.
      if (raw.isNotEmpty &&
          (state['schema'] != 1 || state['insights'] is! List))
        return false;
      final day = DreamContract.day(instant);
      if (DreamContract.string(state['last_success_day']).compareTo(day) >= 0)
        return false;
      final attempt = DreamContract.decode(
        await db.getSetting(DreamStore.attemptKey),
      );
      final sameAttemptDay = attempt['day'] == day;
      final attempts = sameAttemptDay
          ? DreamContract.number(attempt['count'])
          : 0;
      if (!manual &&
          sameAttemptDay &&
          instant.millisecondsSinceEpoch <
              DreamContract.number(attempt['retry_at']))
        return false;
      final lastWeekly = DreamContract.number(state['last_weekly_at']);
      final weekly =
          lastWeekly == 0 ||
          instant.millisecondsSinceEpoch - lastWeekly >=
              const Duration(days: 7).inMilliseconds;
      final material = await DreamMaterial.collect(
        db,
        state,
        instant,
        weekly: weekly,
      );
      final usable = await store.usableInsights(state);
      // A quiet week may reconsider existing originals; quiet ordinary days
      // skip the network. Cursor/day still advance atomically over empty rows.
      final needsReview =
          material.hasNew || (weekly && material.sources.isNotEmpty);
      final diagnostic = <String, Object?>{
        'at': instant.millisecondsSinceEpoch,
        'weekly': weekly,
        'source_count': material.sources.length,
        'has_backlog': material.hasBacklog,
        'bootstrap': material.bootstrap,
      };
      Map<String, dynamic>? payload = {'changes': <Object?>[]};
      if (needsReview) {
        if (!await db.setSettingsAtomically(
          {
            DreamStore.attemptKey: jsonEncode({
              'day': day,
              'count': attempts + 1,
              'retry_at': instant
                  .add(
                    Duration(minutes: 30 * (1 << attempts.clamp(0, 3).toInt())),
                  )
                  .millisecondsSinceEpoch,
            }),
            DreamStore.diagnosticKey: jsonEncode({
              ...diagnostic,
              'status': 'preparing',
            }),
          },
          expectedSettings: {DreamStore.stateKey: raw},
          workFence: fence,
        ))
          return false;
        final rules = (await db.listRuleLayers()).where(
          (r) => r.key == '04_memory_rules',
        );
        final input = <String, Object?>{
          'day': day,
          'weekly': weekly,
          'sources': material.sources.map((s) => s.toJson()).toList(),
          'current': DreamContract.records(state['insights'])
              .map(
                (i) => {
                  ...i,
                  'originals_available': usable.any((u) => u['id'] == i['id']),
                },
              )
              .toList(),
          'recent_revisions': DreamContract.records(
            state['history'],
          ).take(8).toList(),
          'background': material.background,
          'memory_policy_context': rules.isEmpty
              ? ''
              : DreamStore.clip(rules.first.content, 3000),
          'bootstrap_recent_sample': material.bootstrap,
          'unprocessed_material_remains': material.hasBacklog,
        };
        try {
          payload = await (reviewer == null
              ? _review(input, fence)
              : reviewer!(input));
        } catch (_) {
          payload = null;
        }
      }
      final next = DreamContract.apply(
        payload: payload,
        state: state,
        sources: material.sources,
        now: instant,
      );
      if (next == null) {
        await db.setSettingsAtomically({
          DreamStore.diagnosticKey: jsonEncode({
            ...diagnostic,
            'status': payload == null ? 'unavailable' : 'invalid_evidence',
          }),
        }, workFence: fence);
        return false;
      }
      next.addAll({
        'cursor': material.cursor,
        'last_success_day': day,
        'last_completed_at': instant.millisecondsSinceEpoch,
        'last_weekly_at': weekly && needsReview
            ? instant.millisecondsSinceEpoch
            : lastWeekly,
      });
      final changed =
          DreamContract.records(next['insights'])
              .where((i) => i['updated_at'] == instant.millisecondsSinceEpoch)
              .length +
          DreamContract.records(next['history'])
              .where((i) => i['retired_at'] == instant.millisecondsSinceEpoch)
              .length;
      return await store.commit(
        next: next,
        expectedRaw: raw,
        stamp: material.stamp,
        sources: material.sources,
        fence: fence,
        now: instant,
        manual: manual,
        diagnostic: {
          ...diagnostic,
          'status': needsReview ? 'completed' : 'quiet',
          'changed_count': changed,
        },
      );
    } catch (_) {
      // Best effort maintenance must never block the normal heartbeat. The
      // durable attempt and unchanged cursor allow a later bounded retry.
      return false;
    } finally {
      await db.releaseLocalLease(DreamStore.leaseKey);
    }
  }
}
