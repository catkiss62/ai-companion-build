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

  /// Resume at most one due generation job.
  ///
  /// Only an explicit Stop action may withdraw the user's message. Transport
  /// failures, process death and an expired writer lease keep the durable turn
  /// and start a fresh provider request for that same turn when recovery is
  /// due. The final database commit is still fenced by the job run token.
  Future<bool> recoverOne() async {
    if (!await db.brainWorkAllowed()) return false;
    final acquired = await db.tryAcquireLocalLease(
      'chat_turn_lease',
      holdFor: const Duration(seconds: 30),
    );
    if (!acquired) return false;
    try {
      final job = await db.nextRecoverableGenerationJob(
        runningStaleAfter: Duration.zero,
      );
      if (job == null) return false;
      final result = await runner.run(job);
      if (result.completed) {
        await db.setSetting('last_generation_recovery_error', '');
        return true;
      }
      if (result.error != null) {
        final raw = result.error.toString();
        await db.setSetting(
          'last_generation_recovery_error',
          raw.length <= 320 ? raw : raw.substring(0, 320),
        );
      }
      return false;
    } finally {
      await db.releaseLocalLease('chat_turn_lease');
    }
  }

  Future<GenerationJob?> blockingJob() => db.blockingGenerationJob();
}
