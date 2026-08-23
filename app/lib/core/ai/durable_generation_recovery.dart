import '../database/app_database.dart';
import '../models/generation_job.dart';
import 'durable_generation_runner.dart';

class DurableGenerationRecovery {
  DurableGenerationRecovery({
    required this.db,
    required this.runner,
  });

  final AppDatabase db;
  final DurableGenerationRunner runner;

  /// Finalize at most one abandoned generation. A process interruption has
  /// the same semantics as the user's Stop button: withdraw the incomplete
  /// turn and release its durable lock. Recovery must never resend an LLM
  /// request behind the user's back.
  Future<bool> recoverOne() async {
    if (!await db.brainWorkAllowed()) return false;
    final acquired = await db.tryAcquireLocalLease(
      'chat_turn_lease',
      holdFor: const Duration(minutes: 3),
    );
    if (!acquired) return false;
    try {
      final job = await db.nextRecoverableGenerationJob(
        runningStaleAfter: Duration.zero,
      );
      if (job == null) return false;
      await db.cancelGenerationJobByUser(job.id);
      await db.setSetting('last_generation_recovery_error', '');
      return true;
    } finally {
      await db.releaseLocalLease('chat_turn_lease');
    }
  }

  Future<GenerationJob?> blockingJob() => db.blockingGenerationJob();
}
