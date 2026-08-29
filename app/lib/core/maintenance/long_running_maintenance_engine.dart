import '../database/app_database.dart';
import '../diagnostics/runtime_error_category.dart';

class LongRunningMaintenanceResult {
  const LongRunningMaintenanceResult({
    required this.retiredThreads,
    required this.prunedLifecycle,
    required this.prunedFeedback,
    required this.prunedHistory,
    required this.prunedPerceptions,
    required this.prunedDeviceEvents,
    required this.prunedJobs,
  });

  final int retiredThreads;
  final int prunedLifecycle;
  final int prunedFeedback;
  final int prunedHistory;
  final int prunedPerceptions;
  final int prunedDeviceEvents;
  final int prunedJobs;
}

/// Local-only database hygiene for a companion expected to live for months or
/// years. It never deletes raw chat, long-term memories, relationship history,
/// reference documents, AI Self or rule layers.
class LongRunningMaintenanceEngine {
  LongRunningMaintenanceEngine(this.db);

  final AppDatabase db;

  Future<LongRunningMaintenanceResult?> maybeRun({bool force = false}) async {
    if ((await db.getSetting('long_running_maintenance_enabled')) == '0') {
      return null;
    }
    if (!await db.brainWorkAllowed()) return null;
    final now = DateTime.now();
    final lastRaw = int.tryParse(
          await db.getSetting('last_long_running_maintenance_at') ?? '',
        ) ??
        0;
    if (!force &&
        lastRaw > 0 &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(lastRaw)) <
            const Duration(hours: 18)) {
      return null;
    }

    final acquired = await db.tryAcquireLocalLease(
      'long_running_maintenance_lease',
      holdFor: const Duration(minutes: 8),
    );
    if (!acquired) return null;

    final started = DateTime.now();
    Future<bool> stillOwn() async =>
        await db.brainWorkAllowed() &&
        await db.renewLocalLease(
          'long_running_maintenance_lease',
          holdFor: const Duration(minutes: 8),
        );
    try {
      if (!await stillOwn()) return null;
      await db.recoverStalePostTurnJobs();
      if (!await stillOwn()) return null;
      final retired = await db.retireStaleUnfinishedThreads(now: now);
      if (!await stillOwn()) return null;
      for (final thread in retired) {
        if (thread.topicKey.isNotEmpty) {
          await db.markThoughtsDormantForTopic(
            thread.topicKey,
            detail: '对应未完成话题长期没有新进展，已从主动关注队列退休。',
          );
        }
      }

      if (!await stillOwn()) return null;
      final lifecycle = await db.pruneThoughtLifecycleEvents();
      if (!await stillOwn()) return null;
      final feedback = await db.pruneTableByAgeAndCap(
        table: 'proactive_feedback',
        timeColumn: 'sent_at',
        maxAge: const Duration(days: 365),
        maxRows: 1500,
      );
      if (!await stillOwn()) return null;
      final proactiveHistory = await db.pruneTableByAgeAndCap(
        table: 'proactive_history',
        timeColumn: 'created_at',
        maxAge: const Duration(days: 60),
        maxRows: 2500,
      );
      if (!await stillOwn()) return null;
      // Daily continuity is a bounded short-term bridge. Durable truth remains
      // in relationship_events / memory_items, so old daily rows can expire.
      final dailyContinuity = await db.pruneTableByAgeAndCap(
        table: 'daily_continuity',
        timeColumn: 'window_start',
        maxAge: const Duration(days: 180),
        maxRows: 220,
      );
      final history = proactiveHistory + dailyContinuity;
      if (!await stillOwn()) return null;
      final perceptionSnapshots = await db.pruneTableByAgeAndCap(
        table: 'perception_snapshots',
        timeColumn: 'occurred_at',
        maxAge: const Duration(days: 45),
        maxRows: 3000,
      );
      if (!await stillOwn()) return null;
      final awareness = await db.pruneTableByAgeAndCap(
        table: 'awareness_observations',
        timeColumn: 'updated_at',
        maxAge: const Duration(days: 14),
        maxRows: 600,
      );
      final perceptions = perceptionSnapshots + awareness;
      if (!await stillOwn()) return null;
      final deviceEvents = await db.pruneTableByAgeAndCap(
        table: 'device_events',
        timeColumn: 'occurred_at',
        maxAge: const Duration(days: 21),
        maxRows: 12000,
      );
      if (!await stillOwn()) return null;
      final postTurnJobs = await db.pruneCompletedPostTurnJobs();
      final generationJobs = await db.pruneTerminalGenerationJobs();
      final jobs = postTurnJobs + generationJobs;
      if (!await stillOwn()) return null;
      await db.pruneTableByAgeAndCap(
        table: 'provider_health_events',
        timeColumn: 'created_at',
        maxAge: const Duration(days: 14),
        maxRows: 500,
      );
      if (!await stillOwn()) return null;
      await db.pruneTableByAgeAndCap(
        table: 'proactive_policy_events',
        timeColumn: 'created_at',
        maxAge: const Duration(days: 14),
        maxRows: 500,
      );

      final result = LongRunningMaintenanceResult(
        retiredThreads: retired.length,
        prunedLifecycle: lifecycle,
        prunedFeedback: feedback,
        prunedHistory: history,
        prunedPerceptions: perceptions,
        prunedDeviceEvents: deviceEvents,
        prunedJobs: jobs,
      );
      if (!await stillOwn()) return null;
      await db.addMaintenanceRun(
        startedAt: started,
        retiredThreads: result.retiredThreads,
        prunedLifecycle: result.prunedLifecycle,
        prunedFeedback: result.prunedFeedback,
        prunedHistory: result.prunedHistory,
        prunedPerceptions: result.prunedPerceptions,
        prunedDeviceEvents: result.prunedDeviceEvents,
        prunedJobs: result.prunedJobs,
      );
      if (!await stillOwn()) return null;
      await db.pruneTableByAgeAndCap(
        table: 'maintenance_runs',
        timeColumn: 'completed_at',
        maxAge: const Duration(days: 365),
        maxRows: 60,
      );
      if (!await stillOwn()) return null;
      await db.setSetting(
        'last_long_running_maintenance_at',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await db.setSetting('last_long_running_maintenance_error', '');
      await db.setSetting(
        'last_long_running_maintenance_error_category',
        'none',
      );
      await db.setSetting(
        'last_long_running_maintenance_success_at',
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      return result;
    } catch (e) {
      if (await db.brainWorkAllowed() &&
          await db.renewLocalLease(
            'long_running_maintenance_lease',
            holdFor: const Duration(minutes: 8),
          )) {
        final text = e.toString();
        await db.setSetting(
          'last_long_running_maintenance_error',
          text.length <= 320 ? text : text.substring(0, 320),
        );
        await db.setSetting(
          'last_long_running_maintenance_error_category',
          classifyRuntimeError(e),
        );
        await db.setSetting(
          'last_long_running_maintenance_error_at',
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }
      rethrow;
    } finally {
      await db.releaseLocalLease('long_running_maintenance_lease');
    }
  }
}
