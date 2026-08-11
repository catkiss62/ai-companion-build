import '../database/app_database.dart';
import '../models/thought.dart';
import 'thought_similarity.dart';

class ThoughtConsolidationResult {
  const ThoughtConsolidationResult({required this.scanned, required this.merged});
  final int scanned;
  final int merged;
}

/// Local, high-precision cleanup for a Thought pool that may live for years.
/// It never asks a model to rewrite memories. Exact topic_key groups are merged
/// first; text-only merges require very high lexical similarity.
class ThoughtConsolidationEngine {
  ThoughtConsolidationEngine(this.db);

  final AppDatabase db;

  Future<ThoughtConsolidationResult> maybeRun({bool force = false}) async {
    if ((await db.getSetting('thought_consolidation_enabled')) == '0') {
      return const ThoughtConsolidationResult(scanned: 0, merged: 0);
    }
    if (!await db.brainWorkAllowed()) {
      return const ThoughtConsolidationResult(scanned: 0, merged: 0);
    }
    final now = DateTime.now();
    final lastMs =
        int.tryParse(await db.getSetting('last_thought_consolidation_at') ?? '') ?? 0;
    final last = lastMs <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);
    if (!force && last != null && now.difference(last) < const Duration(hours: 6)) {
      return const ThoughtConsolidationResult(scanned: 0, merged: 0);
    }

    final acquired = await db.tryAcquireLocalLease(
      'thought_consolidation_lease_until',
      holdFor: const Duration(minutes: 4),
    );
    if (!acquired) {
      return const ThoughtConsolidationResult(scanned: 0, merged: 0);
    }

    try {
      if (!await db.brainWorkAllowed()) {
        return const ThoughtConsolidationResult(scanned: 0, merged: 0);
      }
      // Re-check after taking the lease. Another engine could have completed
      // consolidation while this caller was waiting for the database.
      final currentLastMs =
          int.tryParse(await db.getSetting('last_thought_consolidation_at') ?? '') ?? 0;
      final currentLast = currentLastMs <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(currentLastMs);
      if (!force &&
          currentLast != null &&
          now.difference(currentLast) < const Duration(hours: 6)) {
        return const ThoughtConsolidationResult(scanned: 0, merged: 0);
      }

      final thoughts = await db.lifecycleThoughts(limit: 320);
      var merged = 0;
      final consumed = <String>{};

      for (var i = 0; i < thoughts.length; i++) {
        if (!await db.brainWorkAllowed() ||
            !await db.renewLocalLease(
              'thought_consolidation_lease_until',
              holdFor: const Duration(minutes: 4),
            )) {
          break;
        }
        final a = thoughts[i];
        if (consumed.contains(a.id)) continue;
        final group = <CompanionThought>[a];
        for (var j = i + 1; j < thoughts.length; j++) {
          final b = thoughts[j];
          if (consumed.contains(b.id) || a.driveKey != b.driveKey) continue;
          final sameTopic = a.topicKey.isNotEmpty &&
              b.topicKey.isNotEmpty &&
              a.topicKey == b.topicKey;
          final veryCloseText = a.topicKey.isEmpty &&
              b.topicKey.isEmpty &&
              ThoughtSimilarity.score(a.text, b.text) >= 0.84;
          if (sameTopic || veryCloseText) group.add(b);
        }
        if (group.length < 2) continue;

        group.sort((x, y) => _priority(y).compareTo(_priority(x)));
        final primary = group.first;
        final duplicates = group.skip(1).toList(growable: false);
        final committed = await db.mergeThoughtRecords(
          primary: primary,
          duplicates: duplicates,
        );
        if (!committed) continue;
        consumed.addAll(duplicates.map((e) => e.id));
        merged += duplicates.length;
      }

      if (await db.brainWorkAllowed() &&
          await db.renewLocalLease(
            'thought_consolidation_lease_until',
            holdFor: const Duration(minutes: 4),
          )) {
        await db.setSetting(
          'last_thought_consolidation_at',
          now.millisecondsSinceEpoch.toString(),
        );
      }
      return ThoughtConsolidationResult(scanned: thoughts.length, merged: merged);
    } finally {
      await db.releaseLocalLease('thought_consolidation_lease_until');
    }
  }

  double _priority(CompanionThought t) {
    final state = switch (t.lifecycleState) {
      'fixation' => 0.40,
      'active' => 0.32,
      'acted' => 0.22,
      'residual' => 0.16,
      _ => 0.08,
    };
    return state + t.strength + t.fedCount * 0.025 + t.actionCount * 0.035;
  }
}
