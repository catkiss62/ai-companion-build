import '../database/app_database.dart';
import '../models/desire_state.dart';

/// Converts a deferred unfinished thread into at most one later Thought pulse.
/// The schedule is consumed only when a proactive message is actually sent.
/// Merely reaching the due time does not spam or repeatedly reinforce it.
class DeferredFollowupEngine {
  DeferredFollowupEngine({required this.db});

  final AppDatabase db;

  Future<int> seedDue({DateTime? now}) async {
    if ((await db.getSetting('deferred_followup_enabled')) == '0') return 0;
    if (!await db.brainWorkAllowed()) return 0;
    final acquired = await db.tryAcquireLocalLease(
      'deferred_followup_lease_until',
      holdFor: const Duration(minutes: 3),
    );
    if (!acquired) return 0;
    try {
      if (!await db.brainWorkAllowed()) return 0;
      final due = await db.dueUnfinishedThreadFollowups(now: now, limit: 3);
      var seeded = 0;
      for (final thread in due) {
        if (!await db.brainWorkAllowed()) break;
        if (!await db.renewLocalLease(
          'deferred_followup_lease_until',
          holdFor: const Duration(minutes: 3),
        )) {
          break;
        }
        if (!thread.isActive || thread.topicKey.isEmpty) continue;
        // Claim the one-shot seed in SQLite before mutating Thought/Desire.
        // A second engine cannot seed the same due thread after takeover.
        final claimToken = await db.claimUnfinishedThreadFollowupSeed(thread.id);
        if (claimToken == null) continue;
        final strength = (0.24 + thread.importance * 0.26)
            .clamp(0.28, 0.52)
            .toDouble();
        try {
          final completed = await db.applyDeferredFollowupSeedAtomic(
            threadId: thread.id,
            claimToken: claimToken,
            topicKey: thread.topicKey,
            thoughtText: '之前说好晚点再继续的事：${thread.title}',
            thoughtDrive: DriveKey.duty,
            thoughtStrength: strength,
            pulses: {
              DriveKey.duty: 0.018 + thread.importance * 0.018,
              DriveKey.attachment: 0.008,
            },
          );
          if (completed) seeded++;
        } finally {
          await db.releaseUnfinishedThreadFollowupSeed(thread.id, claimToken);
        }
      }
      return seeded;
    } finally {
      await db.releaseLocalLease('deferred_followup_lease_until');
    }
  }
}
