import 'dart:math';

import '../database/app_database.dart';
import '../models/desire_state.dart';
import 'desire_engine.dart';

/// Generates low-cost local self-initiated thoughts without calling an LLM.
/// The wording is intentionally simple data; natural language generation only
/// happens later if a thought actually reaches an outbound/chat context.
class SelfDriveEngine {
  SelfDriveEngine({
    required this.db,
    required this.desire,
    Random? random,
  }) : _random = random ?? Random();

  final AppDatabase db;
  final DesireEngine desire;
  final Random _random;

  Future<bool> maybeGenerate({bool forceForDebug = false}) async {
    if ((await db.getSetting('self_drive_enabled')) == '0') return false;
    if (!await db.brainWorkAllowed()) return false;

    final now = DateTime.now();
    final rawLast = await db.getSetting('last_self_drive_at');
    final lastMillis = int.tryParse(rawLast ?? '');
    if (!forceForDebug && lastMillis != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
      final minGap = Duration(minutes: 55 + _random.nextInt(45));
      if (now.difference(last) < minGap) return false;
    }
    if (!forceForDebug && _random.nextDouble() > 0.38) return false;

    final acquired = await db.tryAcquireLocalLease(
      'self_drive_lease_until',
      holdFor: const Duration(minutes: 3),
    );
    if (!acquired) return false;
    Future<bool> stillOwn() async =>
        await db.brainWorkAllowed() &&
        await db.renewLocalLease(
          'self_drive_lease_until',
          holdFor: const Duration(minutes: 3),
        );
    try {
      if (!await stillOwn()) return false;

      final threads = await db.activeUnfinishedThreads(limit: 8);
      if (threads.isNotEmpty && (_random.nextDouble() < 0.58 || forceForDebug)) {
        final thread = threads[_random.nextInt(threads.length)];
        if (!await stillOwn()) return false;
        await desire.feedThought(
          text: '我还惦记着这件没结束的事：${thread.title}。${thread.detail}',
          drive: thread.importance >= 0.72 ? DriveKey.duty : DriveKey.attachment,
          incomingStrength:
              (0.18 + thread.importance * 0.24).clamp(0.18, 0.46).toDouble(),
          source: 'self_drive/thread',
          topicKey: thread.topicKey,
        );
        if (!await stillOwn()) return false;
        await desire.applyExperience({
          DriveKey.duty: 0.015 + thread.importance * 0.018,
        }, baselineLearning: 0.003);
        if (!await stillOwn()) return false;
        await db.setSetting(
          'last_self_drive_at',
          now.millisecondsSinceEpoch.toString(),
        );
        return true;
      }

      final memories = await db.memoryCandidatesForSelfDrive(limit: 24);
      if (memories.isEmpty) return false;
      final weighted = memories.where((m) => m.importance >= 0.45).toList();
      final pool = weighted.isEmpty ? memories : weighted;
      final memory = pool[_random.nextInt(pool.length)];
      final drive = switch (memory.kind) {
        'preference' => DriveKey.attachment,
        'user_profile' => DriveKey.curiosity,
        'shared_experience' => DriveKey.reflection,
        'ai_self' => DriveKey.reflection,
        _ => DriveKey.curiosity,
      };
      if (!await stillOwn()) return false;
      await desire.feedThought(
        text: '我自己又想起了一条长期记忆：${memory.content}',
        drive: drive,
        incomingStrength:
            (0.16 + memory.importance * 0.20).clamp(0.16, 0.40).toDouble(),
        source: 'self_drive/memory',
      );
      if (!await stillOwn()) return false;
      await desire.applyExperience(
        {drive: 0.012 + memory.importance * 0.012},
        baselineLearning: 0.002,
      );
      if (!await stillOwn()) return false;
      await db.setSetting(
        'last_self_drive_at',
        now.millisecondsSinceEpoch.toString(),
      );
      return true;
    } finally {
      await db.releaseLocalLease('self_drive_lease_until');
    }
  }
}
