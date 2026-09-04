import '../database/app_database.dart';

class Phase2BConsolidationResult {
  const Phase2BConsolidationResult({
    required this.ran,
    required this.reason,
    this.memoryTopics = 0,
    this.candidateTopics = 0,
  });

  final bool ran;
  final String reason;
  final int memoryTopics;
  final int candidateTopics;
}

/// Local-only bounded housekeeping. It never invokes a model, rewrites source
/// evidence, changes maturity, or creates AI habits/Thoughts/Drives.
class Phase2BConsolidationEngine {
  Phase2BConsolidationEngine(this.db);

  final AppDatabase db;

  static bool scheduleEligible({
    required DateTime now,
    required DateTime? lastUserMessageAt,
  }) {
    final night = now.hour < 7;
    final idle = lastUserMessageAt == null ||
        now.difference(lastUserMessageAt) >= const Duration(minutes: 90);
    return night || idle;
  }

  Future<Phase2BConsolidationResult> maybeRun({
    bool force = false,
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    if (!await db.brainWorkAllowed()) {
      return const Phase2BConsolidationResult(
        ran: false,
        reason: 'brain_work_blocked',
      );
    }
    final lastMs = int.tryParse(
          await db.getSetting('phase2b_consolidation_last_at') ?? '',
        ) ??
        0;
    if (!force &&
        lastMs > 0 &&
        instant.difference(DateTime.fromMillisecondsSinceEpoch(lastMs)) <
            const Duration(hours: 6)) {
      return const Phase2BConsolidationResult(
        ran: false,
        reason: 'interval_gate',
      );
    }
    final lastUser = await db.lastUserMessageAt();
    if (!force &&
        !scheduleEligible(now: instant, lastUserMessageAt: lastUser)) {
      return const Phase2BConsolidationResult(
        ran: false,
        reason: 'not_idle_or_night',
      );
    }
    const lease = 'phase2b_consolidation_lease_until';
    if (!await db.tryAcquireLocalLease(
      lease,
      holdFor: const Duration(minutes: 2),
    )) {
      return const Phase2BConsolidationResult(
        ran: false,
        reason: 'lease_busy',
      );
    }
    try {
      if (!await db.brainWorkAllowed()) {
        return const Phase2BConsolidationResult(
          ran: false,
          reason: 'brain_work_blocked_after_lease',
        );
      }
      final result = await db.backfillPhase2BTopicKeys();
      await db.setSetting(
        'phase2b_consolidation_last_at',
        instant.millisecondsSinceEpoch.toString(),
      );
      await db.setSetting(
        'phase2b_consolidation_last_outcome',
        'completed',
      );
      await db.setSetting(
        'phase2b_consolidation_last_counts',
        '${result.memories}|${result.candidates}',
      );
      return Phase2BConsolidationResult(
        ran: true,
        reason: 'completed',
        memoryTopics: result.memories,
        candidateTopics: result.candidates,
      );
    } finally {
      await db.releaseLocalLease(lease);
    }
  }
}
