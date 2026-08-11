import 'dart:math';

import '../database/app_database.dart';
import '../models/memory_item.dart';

class MemoryMaintenanceResult {
  const MemoryMaintenanceResult({
    required this.checked,
    required this.archived,
    required this.averageRetention,
  });

  final int checked;
  final int archived;
  final double averageRetention;
}

/// Gentle, local-only forgetting curve.
///
/// Nothing is hard-deleted. Weak, old and rarely recalled entries eventually
/// move to archived, where the user can still inspect/restore them. Pinned
/// memories never fade automatically.
class MemoryMaintenanceEngine {
  MemoryMaintenanceEngine(this.db);

  final AppDatabase db;

  Future<MemoryMaintenanceResult> maybeRun({bool force = false}) async {
    if ((await db.getSetting('memory_fading_enabled')) == '0') {
      return const MemoryMaintenanceResult(checked: 0, archived: 0, averageRetention: 1.0);
    }
    if (!await db.brainWorkAllowed()) {
      return const MemoryMaintenanceResult(checked: 0, archived: 0, averageRetention: 1.0);
    }
    final acquired = await db.tryAcquireLocalLease(
      'memory_maintenance_lease_until',
      holdFor: const Duration(minutes: 6),
    );
    if (!acquired) {
      return const MemoryMaintenanceResult(
        checked: 0,
        archived: 0,
        averageRetention: 1.0,
      );
    }
    try {
      if (!await db.brainWorkAllowed()) {
        return const MemoryMaintenanceResult(checked: 0, archived: 0, averageRetention: 1.0);
      }
      final now = DateTime.now();
      final lastRaw =
          int.tryParse(await db.getSetting('last_memory_maintenance_at') ?? '0') ?? 0;
      if (!force && lastRaw > 0) {
        final last = DateTime.fromMillisecondsSinceEpoch(lastRaw);
        if (now.difference(last) < const Duration(hours: 18)) {
          return const MemoryMaintenanceResult(
            checked: 0,
            archived: 0,
            averageRetention: 1.0,
          );
        }
      }

      final items = await db.memoryMaintenanceCandidates(limit: 600);
      var archived = 0;
      var total = 0.0;
      var checked = 0;
      var index = 0;
      for (final item in items) {
        index++;
        if (index == 1 || index % 40 == 0) {
          if (!await db.brainWorkAllowed() ||
              !await db.renewLocalLease(
                'memory_maintenance_lease_until',
                holdFor: const Duration(minutes: 6),
              )) {
            break;
          }
        }
        if (item.pinned) continue;
        final checkedAt = item.retentionCheckedAt ?? item.updatedAt;
        final elapsedDays =
            max(0.0, now.difference(checkedAt).inMinutes / 1440.0);
        if (!force && elapsedDays < 0.75) continue;

        final halfLife = _halfLifeDays(item);
        final decay = pow(0.5, elapsedDays / halfLife).toDouble();
        var retention =
            (item.retentionScore * decay).clamp(0.0, 1.0).toDouble();

        // Rehearsal makes a memory harder to lose. Recent recall matters more
        // than a large lifetime counter by itself.
        if (item.lastRecalledAt != null) {
          final sinceRecall =
              max(0.0, now.difference(item.lastRecalledAt!).inHours / 24.0);
          final recentRecall = exp(-sinceRecall / 45.0);
          retention +=
              recentRecall * min(0.12, 0.025 + item.recallCount * 0.006);
        }
        retention = retention.clamp(0.0, 1.0).toDouble();

        final contentAgeDays =
            max(0.0, now.difference(item.updatedAt).inHours / 24.0);
        final canArchive = contentAgeDays >= _minimumArchiveAge(item) &&
            retention < 0.105 &&
            item.importance < 0.62 &&
            item.confidence < 0.86 &&
            item.recallCount < 5;
        final changed = await db.updateMemoryRetentionIfUnchanged(
          id: item.id,
          expectedCheckedAt: checkedAt,
          retentionScore: retention,
          checkedAt: now,
          status: canArchive ? 'archived' : null,
        );
        if (!changed) continue;
        checked++;
        total += retention;
        if (canArchive) archived++;
      }
      if (await db.brainWorkAllowed() &&
          await db.renewLocalLease(
            'memory_maintenance_lease_until',
            holdFor: const Duration(minutes: 6),
          )) {
        await db.setSetting(
          'last_memory_maintenance_at',
          now.millisecondsSinceEpoch.toString(),
        );
      }
      return MemoryMaintenanceResult(
        checked: checked,
        archived: archived,
        averageRetention: checked == 0 ? 1.0 : total / checked,
      );
    } finally {
      await db.releaseLocalLease('memory_maintenance_lease_until');
    }
  }

  double _halfLifeDays(MemoryItem item) {
    final base = switch (item.kind) {
      'user_profile' => 520.0,
      'ai_self' => 470.0,
      'preference' => 430.0,
      'shared_experience' => 300.0,
      _ => 240.0,
    };
    final importanceMultiplier = 0.72 + item.importance * 1.05;
    final confidenceMultiplier = 0.82 + item.confidence * 0.45;
    final rehearsalMultiplier = 1.0 + min(0.65, item.recallCount * 0.045);
    final evidenceMultiplier = 1.0 + min(0.55, max(0, item.evidenceCount - 1) * 0.075);
    final semanticMultiplier = item.isInference ? 0.52 : 1.0;
    return base * importanceMultiplier * confidenceMultiplier * rehearsalMultiplier *
        evidenceMultiplier * semanticMultiplier;
  }

  double _minimumArchiveAge(MemoryItem item) {
    if (item.isInference) return 75.0;
    return switch (item.kind) {
      'user_profile' => 420.0,
      'ai_self' => 360.0,
      'preference' => 330.0,
      'shared_experience' => 240.0,
      _ => 180.0,
    };
  }
}
