import '../models/thought.dart';
import 'desire_engine.dart';
import 'proactive_presentation.dart';

class ProactiveSelectionResult {
  const ProactiveSelectionResult({
    required this.intent,
    required this.sourceType,
    required this.intentKind,
    required this.repeatDepth,
    required this.repetitionPenalty,
    required this.waitingBoost,
    required this.adjustmentBucket,
    required this.changedRawWinner,
    required this.repetitionChangedWinner,
    required this.waitingChangedWinner,
    required this.rawSourceType,
    required this.rawIntentKind,
    required this.rawRepeatDepth,
    required this.rawRepetitionPenalty,
  });

  final DesireIntent intent;
  final String sourceType;
  final String intentKind;
  final int repeatDepth;
  final double repetitionPenalty;
  final double waitingBoost;
  final String adjustmentBucket;
  final bool changedRawWinner;
  final bool repetitionChangedWinner;
  final bool waitingChangedWinner;
  final String rawSourceType;
  final String rawIntentKind;
  final int rawRepeatDepth;
  final double rawRepetitionPenalty;
}

class _ScoredIntent {
  const _ScoredIntent({
    required this.original,
    required this.adjusted,
    required this.sourceType,
    required this.intentKind,
    required this.repeatDepth,
    required this.repetitionPenalty,
    required this.waitingBoost,
    required this.adjustmentBucket,
  });

  final DesireIntent original;
  final DesireIntent adjusted;
  final String sourceType;
  final String intentKind;
  final int repeatDepth;
  final double repetitionPenalty;
  final double waitingBoost;
  final String adjustmentBucket;
}

/// Re-ranks real Desire/Thought candidates without creating a second motive
/// system. Repetition is friction rather than a ban, and waiting boosts are
/// bounded so an old share can get a decision opportunity without bypassing
/// the normal outbound Gate.
class ProactiveSelectionPolicy {
  const ProactiveSelectionPolicy._();

  static ProactiveSelectionResult? select({
    required List<DesireIntent> candidates,
    required Map<String, CompanionThought> thoughtsById,
    required List<String> recentIntentKinds,
    required DateTime now,
    Map<String, DateTime> readySinceByThoughtId = const {},
  }) {
    if (candidates.isEmpty) return null;
    final recent = recentIntentKinds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(8)
        .toList(growable: false);
    final rawWinner = candidates.first;

    List<_ScoredIntent> score({
      required bool repetition,
      required bool waiting,
    }) {
      final values = <_ScoredIntent>[];
      for (final candidate in candidates) {
        final thought = candidate.thoughtId == null
            ? null
            : thoughtsById[candidate.thoughtId!];
        final sourceType = sourceTypeFor(
          thought: thought,
          reasonSource: candidate.reasonSource,
        );
        final intentKind = ProactivePresentationPolicy.classify(
          intent: candidate,
        ).key;
        final repeatDepth = _repeatDepth(recent, intentKind);
        final repetitionPenalty = repetition
            ? switch (repeatDepth) {
                0 => 0.0,
                1 => 0.10,
                2 => 0.18,
                _ => 0.26,
              }
            : 0.0;
        final waitingData = waiting
            ? _waitingBoost(
                candidate: candidate,
                thought: thought,
                now: now,
                readySince: candidate.thoughtId == null
                    ? null
                    : readySinceByThoughtId[candidate.thoughtId!],
              )
            : const (value: 0.0, bucket: 'none');
        final repeatedNewestDepth = recent.isEmpty
            ? 0
            : _repeatDepth(recent, recent.first);
        final diversityBoost = repetition &&
                repeatedNewestDepth >= 2 &&
                intentKind != recent.first
            ? 0.04
            : 0.0;
        final adjustedScore = (candidate.score -
                repetitionPenalty +
                waitingData.value +
                diversityBoost)
            .clamp(0.0, 1.0)
            .toDouble();
        final bucket = repetitionPenalty > 0 && waitingData.value > 0
            ? 'mixed'
            : repetitionPenalty > 0
                ? repeatDepth >= 3
                    ? 'repeat_3_plus'
                    : 'repeat_$repeatDepth'
                : waitingData.bucket;
        values.add(
          _ScoredIntent(
            original: candidate,
            adjusted: DesireIntent(
              drive: candidate.drive,
              score: adjustedScore,
              reason: candidate.reason,
              wantAction: candidate.wantAction,
              thoughtId: candidate.thoughtId,
              reasonSource: candidate.reasonSource,
            ),
            sourceType: sourceType,
            intentKind: intentKind,
            repeatDepth: repeatDepth,
            repetitionPenalty: repetitionPenalty,
            waitingBoost: waitingData.value,
            adjustmentBucket: bucket,
          ),
        );
      }
      values.sort((a, b) {
        final byScore = b.adjusted.score.compareTo(a.adjusted.score);
        if (byScore != 0) return byScore;
        return candidates.indexOf(a.original).compareTo(
              candidates.indexOf(b.original),
            );
      });
      return values;
    }

    final repetitionOnly = score(repetition: true, waiting: false).first;
    final waitingOnly = score(repetition: false, waiting: true).first;
    final scored = score(repetition: true, waiting: true);
    final selected = scored.first;
    final raw = scored.firstWhere(
      (value) => identical(value.original, rawWinner),
    );
    return ProactiveSelectionResult(
      intent: selected.adjusted,
      sourceType: selected.sourceType,
      intentKind: selected.intentKind,
      repeatDepth: selected.repeatDepth,
      repetitionPenalty: selected.repetitionPenalty,
      waitingBoost: selected.waitingBoost,
      adjustmentBucket: selected.adjustmentBucket,
      changedRawWinner: selected.original.thoughtId != rawWinner.thoughtId ||
          selected.original.wantAction != rawWinner.wantAction ||
          selected.original.drive != rawWinner.drive,
      repetitionChangedWinner:
          repetitionOnly.original.thoughtId != rawWinner.thoughtId ||
              repetitionOnly.original.wantAction != rawWinner.wantAction ||
              repetitionOnly.original.drive != rawWinner.drive,
      waitingChangedWinner:
          waitingOnly.original.thoughtId != rawWinner.thoughtId ||
              waitingOnly.original.wantAction != rawWinner.wantAction ||
              waitingOnly.original.drive != rawWinner.drive,
      rawSourceType: raw.sourceType,
      rawIntentKind: raw.intentKind,
      rawRepeatDepth: raw.repeatDepth,
      rawRepetitionPenalty: raw.repetitionPenalty,
    );
  }

  static String sourceTypeFor({
    CompanionThought? thought,
    required String reasonSource,
  }) {
    final source = (thought?.source ?? reasonSource).trim().toLowerCase();
    if (source.startsWith('public_web_candidate:')) return 'public_web';
    if (source.startsWith('mcp/') || source.startsWith('mcp:')) return 'mcp';
    if (source.startsWith('screen_observation') ||
        source.startsWith('screen/')) {
      return 'screen_observation';
    }
    final provenance = thought?.provenance ??
        ThoughtProvenancePolicy.fromSource(reasonSource);
    return switch (provenance) {
      ThoughtProvenance.realUserMessage => 'user_history',
      ThoughtProvenance.awareness => 'awareness',
      ThoughtProvenance.memory => 'memory',
      ThoughtProvenance.selfExperience => 'self_experience',
      ThoughtProvenance.inference => 'inference',
      ThoughtProvenance.publicWebCandidate => 'public_web',
      ThoughtProvenance.internal => source == 'drive_state'
          ? 'drive_state'
          : 'internal',
    };
  }

  static int _repeatDepth(List<String> recent, String intentKind) {
    var count = 0;
    for (final item in recent) {
      if (item != intentKind) break;
      count++;
    }
    return count;
  }

  static ({double value, String bucket}) _waitingBoost({
    required DesireIntent candidate,
    required CompanionThought? thought,
    required DateTime now,
    DateTime? readySince,
  }) {
    final kind = ProactivePresentationPolicy.classify(intent: candidate);
    final shareLike = kind.key == 'share_thought' ||
        kind.key == 'social_share' ||
        candidate.wantAction == 'wildcard_share';
    if (!shareLike || thought == null) {
      return (value: 0.0, bucket: 'none');
    }
    final anchor = readySince ?? thought.lastFedAt ?? thought.bornAt;
    final age = now.difference(anchor);
    if (age >= const Duration(hours: 24)) {
      return (value: 0.16, bucket: 'wait_24h_plus');
    }
    if (age >= const Duration(hours: 12)) {
      return (value: 0.13, bucket: 'wait_12h');
    }
    if (age >= const Duration(hours: 4)) {
      return (value: 0.08, bucket: 'wait_4h');
    }
    if (age >= const Duration(minutes: 90)) {
      return (value: 0.04, bucket: 'wait_90m');
    }
    return (value: 0.0, bucket: 'none');
  }
}
