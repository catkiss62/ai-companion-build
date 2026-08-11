import 'dart:math';

import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/desire_state.dart';
import '../models/thought.dart';
import 'thought_similarity.dart';

class DesireIntent {
  const DesireIntent({
    required this.drive,
    required this.score,
    required this.reason,
    required this.wantAction,
    this.thoughtId,
  });

  final DriveKey drive;
  final double score;
  final String reason;
  final String wantAction;
  final String? thoughtId;
}

class DesireEngine {
  DesireEngine(this.db, {Random? random}) : _random = random ?? Random();

  final AppDatabase db;
  final Random _random;
  final Uuid _uuid = Uuid();

  static const _unitMinutes = 12.0;

  static const _decayPerUnit = <DriveKey, double>{
    DriveKey.attachment: 0.010,
    DriveKey.curiosity: 0.018,
    DriveKey.reflection: 0.014,
    DriveKey.duty: 0.016,
    DriveKey.social: 0.020,
    DriveKey.libido: 0.015,
    DriveKey.stress: 0.025,
    DriveKey.fatigue: 0.012,
  };

  static const _intentActions = <DriveKey, String>{
    DriveKey.attachment: 'contact_user',
    DriveKey.curiosity: 'explore_or_ask',
    DriveKey.reflection: 'reflect_or_share',
    DriveKey.duty: 'remember_unfinished_thread',
    DriveKey.social: 'observe_social_context',
    DriveKey.libido: 'seek_intimacy',
    DriveKey.stress: 'vent_or_seek_grounding',
    DriveKey.fatigue: 'rest',
  };

  Future<DesireSnapshot> tick({
    Map<DriveKey, double> pulses = const {},
    bool userBusy = false,
  }) async {
    final now = DateTime.now();
    if ((await db.getSetting('thought_lifecycle_enabled')) == '0') {
      await _tickThoughts(now);
    }
    final thoughts = await db.activeThoughts(limit: 24);

    return db.mutateDesire((snapshot) {
      final elapsedMinutes = snapshot.lastTickAt == null
          ? _unitMinutes
          : now.difference(snapshot.lastTickAt!).inSeconds / 60.0;
      // A phone can be suspended for hours. We advance the state, but cap one
      // catch-up pass so resume does not instantly slam every drive to baseline.
      final scale =
          (elapsedMinutes / _unitMinutes).clamp(0.15, 8.0).toDouble();

      final drives = Map<DriveKey, double>.from(snapshot.drives);
      final baselines = Map<DriveKey, double>.from(snapshot.baselines);
      final refractory = Map<DriveKey, DateTime>.from(snapshot.refractoryUntil)
        ..removeWhere((_, until) => !until.isAfter(now));

      for (final drive in DriveKey.values) {
        var value = drives[drive] ?? 0;
        final baseline = baselines[drive] ?? 0.2;
        final decay = _decayPerUnit[drive] ?? 0.015;
        final returnRate = 1 - pow(1 - 0.055, scale).toDouble();
        value += (baseline - value) * returnRate;
        value *= pow(1 - decay, scale).toDouble();
        value += pulses[drive] ?? 0;
        drives[drive] = value.clamp(0.0, 1.0).toDouble();
      }

      _applyCoupling(drives, scale);

      // Busy is contextual friction, never an absolute mute switch.
      if (userBusy) {
        drives[DriveKey.fatigue] =
            ((drives[DriveKey.fatigue] ?? 0) + 0.006 * scale)
                .clamp(0.0, 1.0)
                .toDouble();
        drives[DriveKey.stress] =
            ((drives[DriveKey.stress] ?? 0) + 0.003 * scale)
                .clamp(0.0, 1.0)
                .toDouble();
      }

      final wildcard = _maybeWildcard(snapshot, now, drives);
      final intent = _pickIntent(drives, refractory, thoughts, now);
      return snapshot.copyWith(
        drives: drives,
        baselines: baselines,
        refractoryUntil: refractory,
        lastIntent: intent?.wantAction,
        lastTickAt: now,
        lastWildcardAt: wildcard ? now : snapshot.lastWildcardAt,
        clearIntent: intent == null,
      );
    });
  }

  /// Apply a real experience (conversation, remembered promise, perception)
  /// and allow a very small long-term baseline drift. Baselines are bounded
  /// around their original anchors so one intense evening cannot rewrite her.
  Future<void> applyExperience(
    Map<DriveKey, double> pulses, {
    double baselineLearning = 0.018,
  }) async {
    if (pulses.isEmpty) return;
    await db.mutateDesire((snapshot) {
      final drives = Map<DriveKey, double>.from(snapshot.drives);
      final baselines = Map<DriveKey, double>.from(snapshot.baselines);
      final anchors = DesireSnapshot.defaultBaselines();

      for (final entry in pulses.entries) {
        final drive = entry.key;
        final delta = entry.value.clamp(-0.35, 0.35).toDouble();
        drives[drive] = ((drives[drive] ?? anchors[drive]!) + delta)
            .clamp(0.0, 1.0)
            .toDouble();
        final anchor = anchors[drive]!;
        final currentBase = baselines[drive] ?? anchor;
        final target = (currentBase + delta * baselineLearning)
            .clamp(max(0.02, anchor - 0.10), min(0.92, anchor + 0.10))
            .toDouble();
        baselines[drive] = target;
      }
      return snapshot.copyWith(drives: drives, baselines: baselines);
    });
  }

  Future<void> pulse(
    DriveKey drive,
    double delta, {
    String? thought,
    double thoughtStrength = 0.28,
    String thoughtSource = 'internal',
  }) async {
    await applyExperience({drive: delta}, baselineLearning: 0.006);
    if (thought != null && thought.trim().isNotEmpty) {
      await feedThought(
        text: thought,
        drive: drive,
        incomingStrength: thoughtStrength,
        source: thoughtSource,
      );
    }
  }

  Future<void> satisfy(DriveKey drive, {double factor = 0.68}) async {
    final refractoryUntil =
        DateTime.now().add(Duration(minutes: 22 + _random.nextInt(35)));
    await db.mutateDesire((snapshot) {
      final drives = Map<DriveKey, double>.from(snapshot.drives);
      final baseline = snapshot.baselines[drive] ?? 0.2;
      final value = drives[drive] ?? baseline;
      drives[drive] = (baseline + (value - baseline) * factor)
          .clamp(0.0, 1.0)
          .toDouble();
      final refractory = Map<DriveKey, DateTime>.from(snapshot.refractoryUntil)
        ..[drive] = refractoryUntil;
      return snapshot.copyWith(
        drives: drives,
        refractoryUntil: refractory,
      );
    });
  }

  Future<void> feedThought({
    required String text,
    required DriveKey drive,
    double incomingStrength = 0.25,
    String source = 'internal',
    String topicKey = '',
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    // Self-reflection can be retried by another FlutterEngine after a stale
    // lease. A stable run source means the first committed reflection thought
    // wins even if the model wording differs on the retry.
    if (source.startsWith('self_reflection_run:') &&
        await db.thoughtBySource(source) != null) {
      return;
    }
    final thoughts = await db.lifecycleThoughts(limit: 120);
    final normalizedTopic = topicKey.trim().toLowerCase();
    CompanionThought? match;
    var bestScore = 0.0;
    for (final t in thoughts) {
      if (t.driveKey != drive.name) continue;
      if (normalizedTopic.isNotEmpty && t.topicKey == normalizedTopic) {
        match = t;
        bestScore = 1.0;
        break;
      }
      if (normalizedTopic.isNotEmpty && t.topicKey.isNotEmpty && t.topicKey != normalizedTopic) {
        continue;
      }
      final score = ThoughtSimilarity.score(t.text, normalized);
      if (score >= 0.84 && score > bestScore) {
        bestScore = score;
        match = t;
      }
    }

    final now = DateTime.now();
    if (match == null) {
      await db.upsertThought(
        id: _uuid.v4(),
        text: normalized,
        drive: drive,
        kind: 'flit',
        strength: incomingStrength.clamp(0.08, 0.70).toDouble(),
        source: source,
        lastFedAt: now,
        topicKey: normalizedTopic,
      );
      return;
    }

    final fed = match.fedCount + 1;
    final nextStrength = (match.strength * 0.88 + incomingStrength * 0.55 + 0.06)
        .clamp(0.0, 1.0)
        .toDouble();
    final kind = fed >= 3 || nextStrength >= 0.68 ? 'fixation' : match.kind;
    final lifecycleState = kind == 'fixation' ? 'fixation' : 'active';
    await db.upsertThought(
      id: match.id,
      text: match.text,
      drive: drive,
      kind: kind,
      strength: nextStrength,
      fedCount: fed,
      bornAt: match.bornAt,
      source: match.source == 'internal' ? source : match.source,
      lastFedAt: now,
      lifecycleState: lifecycleState,
      actionCount: match.actionCount,
      lastActedAt: match.lastActedAt,
      lastSatisfiedAt: match.lastSatisfiedAt,
      lastResurfacedAt: match.lastResurfacedAt,
      resurfacedCount: match.resurfacedCount,
      residualStrength: match.residualStrength,
      lastOutboundMessageId: match.lastOutboundMessageId,
      topicKey: match.topicKey.isNotEmpty ? match.topicKey : normalizedTopic,
      mergedCount: match.mergedCount,
      lastMergedAt: match.lastMergedAt,
      // If the user herself brings a snoozed topic back in a later real
      // conversation, that fresh evidence reopens it immediately. Internal
      // self-drive/perception signals must not silently override a dismissal.
      snoozedUntil: source == 'conversation' ? null : match.snoozedUntil,
    );
  }

  DesireIntent? previewIntent(
    DesireSnapshot snapshot,
    List<CompanionThought> thoughts,
  ) {
    return _pickIntent(
      snapshot.drives,
      snapshot.refractoryUntil,
      thoughts,
      DateTime.now(),
    );
  }

  DesireIntent? _pickIntent(
    Map<DriveKey, double> drives,
    Map<DriveKey, DateTime> refractory,
    List<CompanionThought> thoughts,
    DateTime now,
  ) {
    final fatigue = drives[DriveKey.fatigue] ?? 0;
    if (fatigue >= 0.90) {
      return DesireIntent(
        drive: DriveKey.fatigue,
        score: fatigue,
        reason: 'fatigue is temporarily dominant',
        wantAction: 'rest',
      );
    }

    DesireIntent? best;
    for (final drive in DriveKey.values) {
      if (drive == DriveKey.fatigue) continue;
      final until = refractory[drive];
      if (until != null && until.isAfter(now)) continue;
      var score = drives[drive] ?? 0;
      final related = thoughts.where((t) => t.driveKey == drive.name && t.canDriveIntent).toList();
      for (final thought in related.take(4)) {
        final boost = thought.strength * (thought.isFixation ? 0.23 : 0.11);
        score += boost;
      }
      score = 1 - sqrt(max(0, 1 - score.clamp(0.0, 1.0)));
      score = (score + (drives[drive] ?? 0) * 0.62).clamp(0.0, 1.0).toDouble();
      if (best == null || score > best.score) {
        CompanionThought? strongest;
        if (related.isNotEmpty) {
          strongest = related.reduce((a, b) => a.strength >= b.strength ? a : b);
        }
        best = DesireIntent(
          drive: drive,
          score: score,
          reason: strongest?.text ?? 'drive baseline',
          wantAction: _intentActions[drive] ?? 'wait',
          thoughtId: strongest?.id,
        );
      }
    }
    return best;
  }

  Future<void> _tickThoughts(DateTime now) async {
    final thoughts = await db.activeThoughts(limit: 100);
    for (final thought in thoughts) {
      final elapsedHours = max(
        0.05,
        now.difference(thought.updatedAt).inMinutes / 60.0,
      );
      final hourlyRetention = thought.isFixation ? 0.965 : 0.90;
      final next = thought.strength * pow(hourlyRetention, elapsedHours).toDouble();
      if (next < 0.07 && thought.canDriveIntent) {
        await db.updateThoughtLifecycle(
          thought.id,
          lifecycleState: 'dormant',
          strength: next,
          residualStrength: next,
        );
        continue;
      }
      // Lifecycle bookkeeping stays intact while the legacy light
      // decay path remains for foreground chat compatibility.
      await db.upsertThought(
        id: thought.id,
        text: thought.text,
        drive: DriveKey.values.firstWhere(
          (d) => d.name == thought.driveKey,
          orElse: () => DriveKey.reflection,
        ),
        kind: thought.kind,
        strength: next,
        fedCount: thought.fedCount,
        bornAt: thought.bornAt,
        source: thought.source,
        lastFedAt: thought.lastFedAt,
        lifecycleState: thought.lifecycleState,
        actionCount: thought.actionCount,
        lastActedAt: thought.lastActedAt,
        lastSatisfiedAt: thought.lastSatisfiedAt,
        lastResurfacedAt: thought.lastResurfacedAt,
        resurfacedCount: thought.resurfacedCount,
        residualStrength: thought.residualStrength,
        lastOutboundMessageId: thought.lastOutboundMessageId,
        topicKey: thought.topicKey,
        mergedCount: thought.mergedCount,
        lastMergedAt: thought.lastMergedAt,
        snoozedUntil: thought.snoozedUntil,
      );
    }
  }

  bool _maybeWildcard(
    DesireSnapshot snapshot,
    DateTime now,
    Map<DriveKey, double> drives,
  ) {
    final last = snapshot.lastWildcardAt;
    if (last != null && now.difference(last) < const Duration(hours: 2)) {
      return false;
    }
    if (_random.nextDouble() > 0.18) return false;

    const candidates = [
      DriveKey.curiosity,
      DriveKey.reflection,
      DriveKey.social,
      DriveKey.attachment,
      DriveKey.libido,
    ];
    final drive = candidates[_random.nextInt(candidates.length)];
    final pulse = 0.018 + _random.nextDouble() * 0.035;
    drives[drive] = ((drives[drive] ?? 0) + pulse).clamp(0.0, 1.0).toDouble();
    return true;
  }

  void _applyCoupling(Map<DriveKey, double> d, double scale) {
    void delta(DriveKey target, double amount) {
      d[target] = ((d[target] ?? 0) + amount * scale).clamp(0.0, 1.0).toDouble();
    }

    // Small coefficients only. Coupling shapes the mood but cannot self-excite
    // into saturation without real experiences feeding the system.
    delta(DriveKey.libido, ((d[DriveKey.attachment] ?? 0) - 0.5) * 0.012);
    delta(DriveKey.reflection, ((d[DriveKey.curiosity] ?? 0) - 0.5) * 0.014);
    delta(DriveKey.attachment, ((d[DriveKey.reflection] ?? 0) - 0.5) * 0.009);
    delta(DriveKey.stress, ((d[DriveKey.duty] ?? 0) - 0.5) * 0.008);
    delta(DriveKey.social, ((d[DriveKey.curiosity] ?? 0) - 0.5) * 0.007);
    delta(DriveKey.fatigue, ((d[DriveKey.stress] ?? 0) - 0.45) * 0.006);
  }
}
