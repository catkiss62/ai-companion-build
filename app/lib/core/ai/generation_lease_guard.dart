import '../database/app_database.dart';
import '../models/generation_job.dart';

enum GenerationFenceState { current, completed, cancelled, ownershipLost }

/// Polled by the runner's existing cancellation fence, including while no
/// provider delta arrives. Never acquires a lease owned by another runner.
class GenerationLeaseGuard {
  GenerationLeaseGuard(this.db, this.job);
  final AppDatabase db;
  final GenerationJob job;
  DateTime? _lastRenewal;

  Future<GenerationFenceState> check({DateTime? now}) async {
    final latest = await db.generationJobById(job.id);
    if (latest?.status == 'cancelled_by_user') {
      return GenerationFenceState.cancelled;
    }
    if (latest?.status == 'completed' && latest?.runToken == job.runToken) {
      return GenerationFenceState.completed;
    }
    if (latest?.status != 'running' || latest?.runToken != job.runToken) {
      return GenerationFenceState.ownershipLost;
    }
    final at = now ?? DateTime.now();
    if (_lastRenewal == null ||
        at.difference(_lastRenewal!) >= const Duration(seconds: 10)) {
      if (!await db.brainWorkAllowed() ||
          !await db.renewLocalLease('chat_turn_lease',
              holdFor: const Duration(seconds: 30))) {
        return GenerationFenceState.ownershipLost;
      }
      _lastRenewal = at;
    }
    return GenerationFenceState.current;
  }
}
