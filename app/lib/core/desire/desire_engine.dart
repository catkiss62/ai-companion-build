import 'dart:math';

import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/desire_state.dart';
import '../models/thought.dart';
import 'desire_core_policy.dart';
import 'thought_similarity.dart';

class DesireIntent {
  const DesireIntent({
    required this.drive,
    required this.score,
    required this.reason,
    required this.wantAction,
    this.thoughtId,
    this.reasonSource = 'drive_state',
  });

  final DriveKey drive;
  final double score;
  final String reason;
  final String wantAction;
  final String? thoughtId;
  final String reasonSource;
}

class DesireEngine {
  DesireEngine(this.db, {Random? random}) : _random = random ?? Random();

  final AppDatabase db;
  final Random _random;
  final Uuid _uuid = Uuid();

  Future<DesireSnapshot> tick({
    Map<DriveKey, double> pulses = const {},
    bool userBusy = false,
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    if ((await db.getSetting('thought_lifecycle_enabled')) == '0') {
      await _tickThoughts(instant);
    }
    final thoughts = await db.activeThoughts(limit: 24);
    return db.mutateDesire((snapshot) {
      final advanced = DesireCorePolicy.advance(
        snapshot: snapshot,
        now: instant,
        pulses: pulses,
        userBusy: userBusy,
      );
      final drives = Map<DriveKey, double>.from(advanced.drives);
      final intent = _pickIntent(
        snapshot.copyWith(
          drives: drives,
          baselines: advanced.baselines,
          refractoryUntil: advanced.refractoryUntil,
        ),
        drives,
        advanced.refractoryUntil,
        thoughts,
        instant,
        intimacyAllowed: true,
      );
      return snapshot.copyWith(
        drives: drives,
        baselines: advanced.baselines,
        refractoryUntil: advanced.refractoryUntil,
        lastIntent: intent?.wantAction,
        lastIntentDrive: intent?.drive.name,
        lastIntentScore: intent?.score,
        lastTickAt: instant,
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

  /// Legacy single-drive settle used by ordinary user-reply completion.
  /// Proactive actions use [satisfyIntent] so the actual action decides which
  /// related drives settle and which refractory period is applied.
  Future<void> satisfy(DriveKey drive, {double factor = 0.68}) async {
    final now = DateTime.now();
    final refractoryUntil =
        now.add(Duration(minutes: 22 + _random.nextInt(35)));
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
        lastSatisfiedAction: 'user_reply',
        lastSatisfiedAt: now,
      );
    });
  }

  Future<void> satisfyIntent(
    DesireIntent intent, {
    double intensity = 0.55,
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    final refractoryUntil =
        instant.add(Duration(minutes: 22 + _random.nextInt(35)));
    await db.mutateDesire((snapshot) {
      final drives = DesireCorePolicy.satisfiedDrives(
        snapshot: snapshot,
        action: intent.wantAction,
        primaryDrive: intent.drive,
        intensity: intensity,
      );
      final refractory = Map<DriveKey, DateTime>.from(snapshot.refractoryUntil)
        ..[intent.drive] = refractoryUntil;
      return snapshot.copyWith(
        drives: drives,
        refractoryUntil: refractory,
        lastSatisfiedAction: intent.wantAction,
        lastSatisfiedAt: instant,
        lastWildcardAt: intent.wantAction == 'wildcard_share'
            ? instant
            : snapshot.lastWildcardAt,
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
    List<CompanionThought> thoughts, {
    DateTime? now,
    bool intimacyAllowed = true,
  }) {
    return _pickIntent(
      snapshot,
      snapshot.drives,
      snapshot.refractoryUntil,
      thoughts,
      now ?? DateTime.now(),
      intimacyAllowed: intimacyAllowed,
    );
  }

  List<DesireIntent> previewCandidates(
    DesireSnapshot snapshot,
    List<CompanionThought> thoughts, {
    DateTime? now,
    bool intimacyAllowed = true,
    bool includeThoughtAlternatives = false,
  }) {
    final candidates = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: snapshot.refractoryUntil,
      thoughts: thoughts,
      now: now ?? DateTime.now(),
      baselines: snapshot.baselines,
      lastWildcardAt: snapshot.lastWildcardAt,
      intimacyAllowed: intimacyAllowed,
      includeThoughtAlternatives: includeThoughtAlternatives,
    );
    return candidates.map(_fromCandidate).toList();
  }

  DesireIntent? _pickIntent(
    DesireSnapshot snapshot,
    Map<DriveKey, double> drives,
    Map<DriveKey, DateTime> refractory,
    List<CompanionThought> thoughts,
    DateTime now, {
    required bool intimacyAllowed,
  }) {
    final candidates = DesireCorePolicy.candidates(
      drives: drives,
      refractoryUntil: refractory,
      thoughts: thoughts,
      now: now,
      baselines: snapshot.baselines,
      lastWildcardAt: snapshot.lastWildcardAt,
      intimacyAllowed: intimacyAllowed,
    );
    return candidates.isEmpty ? null : _fromCandidate(candidates.first);
  }

  DesireIntent _fromCandidate(DesireCoreCandidate candidate) => DesireIntent(
        drive: candidate.drive,
        score: candidate.score,
        reason: candidate.reason,
        wantAction: candidate.action,
        thoughtId: candidate.thoughtId,
        reasonSource: candidate.reasonSource,
      );

  Future<void> _tickThoughts(DateTime now) async {
    final thoughts = await db.activeThoughts(limit: 100);
    for (final thought in thoughts) {
      final elapsedHours = max(
        0.05,
        now.difference(thought.updatedAt).inMinutes / 60.0,
      );
      final hourlyRetention = thought.isFixation ? 0.965 : 0.90;
      final next = thought.strength * pow(hourlyRetention, elapsedHours).toDouble();
      if (next < 0.07 && thought.canDriveIntentAt(now)) {
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

}
