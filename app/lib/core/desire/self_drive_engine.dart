import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../database/app_database.dart';
import '../models/desire_state.dart';
import '../models/self_experience.dart';
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
    SelfReviewCandidate? claimedCandidate;
    try {
      if (!await stillOwn()) return false;
      await _refreshCandidates(now);
      final candidates = await db.pendingSelfReviewCandidates(now: now);
      if (candidates.isEmpty) return false;

      // Urgent unfinished matters should not be lost behind a second random
      // gate. Ordinary memories keep the existing low-frequency character.
      final urgent = candidates.any((candidate) => candidate.importance >= 0.72);
      if (!forceForDebug && !urgent && _random.nextDouble() > 0.38) return false;

      final candidate = await _selectCandidate(candidates);
      if (!await db.claimSelfReviewCandidate(candidate.id, now: now)) {
        return false;
      }
      claimedCandidate = candidate;
      if (!await stillOwn()) {
        // Do not write after Active Brain ownership is lost. A later active
        // worker safely reopens stale selected candidates after ten minutes.
        return false;
      }

      final completed = await _reviewCandidate(candidate, now, stillOwn);
      if (completed) {
        await db.setSetting(
          'last_self_drive_at',
          now.millisecondsSinceEpoch.toString(),
        );
      }
      return completed;
    } catch (error, stackTrace) {
      // A transfer-related exception must not let the old brain write even a
      // failure record. If the database check itself is unavailable, preserve
      // the original failure and let stale-selection recovery reopen the item.
      try {
        if (claimedCandidate != null && await stillOwn()) {
          await db.finishSelfReviewCandidate(
            candidate: claimedCandidate,
            status: 'failed',
            appraisal: 'review_exception',
            now: now,
          );
        }
      } catch (_) {}
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      await db.releaseLocalLease('self_drive_lease_until');
    }
  }

  Future<void> _refreshCandidates(DateTime now) async {
    final threads = await db.activeUnfinishedThreads(limit: 12);
    for (final thread in threads) {
      final hash = sha256
          .convert(utf8.encode(
            '${thread.id}|${thread.updatedAt.millisecondsSinceEpoch}|'
            '${thread.title}|${thread.detail}',
          ))
          .toString();
      await db.upsertSelfReviewCandidate(
        sourceKind: 'unfinished_thread',
        sourceRef: thread.id,
        sourceHash: hash,
        topicKey: thread.topicKey,
        driveKey: thread.importance >= 0.72
            ? DriveKey.duty.name
            : DriveKey.attachment.name,
        importance: thread.importance,
        now: now,
      );
    }

    final memories = await db.memoryCandidatesForSelfDrive(limit: 32);
    for (final memory in memories) {
      final drive = _driveForMemoryKind(memory.kind);
      final hash = sha256
          .convert(utf8.encode(
            '${memory.id}|${memory.factVersion}|'
            '${memory.updatedAt.millisecondsSinceEpoch}',
          ))
          .toString();
      await db.upsertSelfReviewCandidate(
        sourceKind: 'memory',
        sourceRef: memory.id,
        sourceHash: hash,
        topicKey: memory.subjectKey,
        driveKey: drive.name,
        importance: memory.importance,
        now: now,
      );
    }
  }

  Future<SelfReviewCandidate> _selectCandidate(
    List<SelfReviewCandidate> candidates,
  ) async {
    final snapshot = await db.loadDesire();
    final scored = candidates.map((candidate) {
      final drive = _parseDrive(candidate.driveKey);
      final current = snapshot.drives[drive] ?? 0.0;
      final baseline = snapshot.baselines[drive] ?? 0.0;
      final driveExcess = max(0.0, current - baseline);
      final freshnessNoise = _random.nextDouble() * 0.08;
      return (
        candidate: candidate,
        score: candidate.importance * 0.78 + driveExcess * 0.36 + freshnessNoise,
      );
    }).toList()
      ..sort((left, right) => right.score.compareTo(left.score));
    return scored.first.candidate;
  }

  Future<bool> _reviewCandidate(
    SelfReviewCandidate candidate,
    DateTime now,
    Future<bool> Function() stillOwn,
  ) async {
    if (candidate.sourceKind == 'unfinished_thread') {
      final thread = await db.unfinishedThreadById(candidate.sourceRef);
      if (thread == null || !thread.isActive) {
        await db.finishSelfReviewCandidate(
          candidate: candidate,
          status: 'discarded',
          appraisal: 'source_no_longer_active',
          now: now,
        );
        return false;
      }
      final drive = _parseDrive(candidate.driveKey);
      final thoughtId = await desire.feedThought(
        text: '我还惦记着这件没结束的事：${thread.title}。${thread.detail}',
        drive: drive,
        incomingStrength:
            (0.18 + thread.importance * 0.24).clamp(0.18, 0.46).toDouble(),
        source: 'self_drive/thread',
        topicKey: thread.topicKey,
        now: now,
      );
      if (!await stillOwn()) return false;
      await desire.applyExperience(
        {drive: 0.015 + thread.importance * 0.018},
        baselineLearning: 0.003,
        source: 'self_review/unfinished_thread',
      );
      if (!await stillOwn()) return false;
      await db.finishSelfReviewCandidate(
        candidate: candidate,
        status: 'completed',
        appraisal: 'unfinished_thread_reviewed',
        thoughtId: thoughtId,
        now: now,
      );
      return true;
    }

    if (candidate.sourceKind == 'memory') {
      final memory = await db.memoryById(candidate.sourceRef);
      if (memory == null || !memory.isActive) {
        await db.finishSelfReviewCandidate(
          candidate: candidate,
          status: 'discarded',
          appraisal: 'source_no_longer_active',
          now: now,
        );
        return false;
      }
      final drive = _parseDrive(candidate.driveKey);
      final thoughtId = await desire.feedThought(
        text: '我自己又想起了一条长期记忆：${memory.content}',
        drive: drive,
        incomingStrength:
            (0.16 + memory.importance * 0.20).clamp(0.16, 0.40).toDouble(),
        source: 'self_drive/memory',
        topicKey: candidate.topicKey,
        now: now,
      );
      if (!await stillOwn()) return false;
      await desire.applyExperience(
        {drive: 0.012 + memory.importance * 0.012},
        baselineLearning: 0.002,
        source: 'self_review/memory',
      );
      if (!await stillOwn()) return false;
      await db.finishSelfReviewCandidate(
        candidate: candidate,
        status: 'completed',
        appraisal: 'memory_recalled',
        thoughtId: thoughtId,
        now: now,
      );
      return true;
    }

    await db.finishSelfReviewCandidate(
      candidate: candidate,
      status: 'discarded',
      appraisal: 'unsupported_source_kind',
      now: now,
    );
    return false;
  }

  DriveKey _driveForMemoryKind(String kind) => switch (kind) {
        'preference' => DriveKey.attachment,
        'user_profile' => DriveKey.curiosity,
        'shared_experience' => DriveKey.reflection,
        'ai_self' => DriveKey.reflection,
        _ => DriveKey.curiosity,
      };

  DriveKey _parseDrive(String key) {
    for (final drive in DriveKey.values) {
      if (drive.name == key) return drive;
    }
    return DriveKey.reflection;
  }
}
