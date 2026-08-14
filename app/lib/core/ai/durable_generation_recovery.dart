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

  /// Recover at most one unfinished generation. Returns true when a job was
  /// actually claimed/processed. The same chat lease is used by foreground,
  /// overlay and headless engines, so two FlutterEngines cannot recover the
  /// same turn concurrently.
  Future<bool> recoverOne() async {
    if (!await db.brainWorkAllowed()) return false;
    final acquired = await db.tryAcquireLocalLease(
      'chat_turn_lease',
      holdFor: const Duration(minutes: 3),
    );
    if (!acquired) return false;
    try {
      final job = await db.nextRecoverableGenerationJob();
      if (job == null) return false;
      final result = await runner.run(job);
      if (result.completed) {
        await db.setSetting('last_generation_recovery_error', '');
      } else if (result.status != 'suspended' &&
          result.status != 'cancelled_by_user') {
        final raw = result.error?.toString() ?? result.status;
        await db.setSetting(
          'last_generation_recovery_error',
          raw.length <= 320 ? raw : raw.substring(0, 320),
        );
      }
      return true;
    } finally {
      await db.releaseLocalLease('chat_turn_lease');
    }
  }

  Future<GenerationJob?> blockingJob() => db.blockingGenerationJob();
}
