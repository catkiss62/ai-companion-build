import '../models/desire_state.dart';
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
    required this.sourceRepeatDepth,
    required this.sourceRepetitionPenalty,
    required this.sampledNearTie,
    required this.samplingCandidateCount,
    required this.samplingUnit,
    required this.topAdjustedScore,
    required this.selectedAdjustedScore,
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
  final int sourceRepeatDepth;
  final double sourceRepetitionPenalty;
  final bool sampledNearTie;
  final int samplingCandidateCount;
  final double samplingUnit;
  final double topAdjustedScore;
  final double selectedAdjustedScore;
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
    required this.sourceRepeatDepth,
    required this.sourceRepetitionPenalty,
  });

  final DesireIntent original;
  final DesireIntent adjusted;
  final String sourceType;
  final String intentKind;
  final int repeatDepth;
  final double repetitionPenalty;
  final double waitingBoost;
  final String adjustmentBucket;
  final int sourceRepeatDepth;
  final double sourceRepetitionPenalty;
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
    List<String> recentSourceTypes = const [],
    List<String> recentTopicKeys = const [],
    required DateTime now,
    Map<String, DateTime> readySinceByThoughtId = const {},
    double samplingUnit = 0.0,
  }) {
    if (candidates.isEmpty) return null;
    final recent = recentIntentKinds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(8)
        .toList(growable: false);
    final recentSources = recentSourceTypes
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(8)
        .toList(growable: false);
    final recentTopics = recentTopicKeys
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
          sourceType: sourceType,
        ).key;
        final repeatDepth = _repeatDepth(recent, intentKind);
        final sourceRepeatDepth = _repeatDepth(recentSources, sourceType);
        final topicKey = thought?.topicKey.trim() ?? '';
        final topicRepeatDepth = topicKey.isEmpty
            ? 0
            : _repeatDepth(recentTopics, topicKey);
        final repeatedNewestTopicDepth = recentTopics.isEmpty
            ? 0
            : _repeatDepth(recentTopics, recentTopics.first);
        final intentPenalty = repetition
            ? switch (repeatDepth) {
                0 => 0.0,
                1 => 0.10,
                2 => 0.18,
                _ => 0.26,
              }
            : 0.0;
        final topicPenalty = repetition
            ? switch (topicRepeatDepth) {
                0 => 0.0,
                1 => 0.08,
                2 => 0.16,
                _ => 0.24,
              }
            : 0.0;
        final repetitionPenalty = intentPenalty + topicPenalty;
        final sourceRepetitionPenalty = repetition
            ? switch (sourceRepeatDepth) {
                0 => 0.0,
                1 => 0.04,
                2 => 0.08,
                _ => 0.12,
              }
            : 0.0;
        final rawWaitingData = waiting
            ? _waitingBoost(
                candidate: candidate,
                thought: thought,
                now: now,
                readySince: candidate.thoughtId == null
                    ? null
                    : readySinceByThoughtId[candidate.thoughtId!],
              )
            : const (value: 0.0, bucket: 'none');
        // Age must not turn an already repeated old topic back into the
        // strongest candidate. It may still win when it is the only option.
        final waitingData = topicRepeatDepth > 0
            ? const (value: 0.0, bucket: 'none')
            : rawWaitingData;
        final repeatedNewestDepth = recent.isEmpty
            ? 0
            : _repeatDepth(recent, recent.first);
        final repeatedSourceDepth = recentSources.isEmpty
            ? 0
            : _repeatDepth(recentSources, recentSources.first);
        final diversityBoost = repetition &&
                ((repeatedNewestDepth >= 2 && intentKind != recent.first) ||
                    (repeatedSourceDepth >= 2 &&
                        sourceType != recentSources.first) ||
                    (repeatedNewestTopicDepth >= 2 &&
                        topicKey.isNotEmpty &&
                        topicKey != recentTopics.first))
            ? 0.04
            : 0.0;
        final adjustedScore = (candidate.score -
                repetitionPenalty +
                -sourceRepetitionPenalty +
                waitingData.value +
                diversityBoost)
            .clamp(0.0, 1.0)
            .toDouble();
        final bucket = (repetitionPenalty > 0 ||
                    sourceRepetitionPenalty > 0) &&
                waitingData.value > 0
            ? 'mixed'
            : repetitionPenalty > 0
                ? repeatDepth >= 3
                    ? 'repeat_3_plus'
                    : 'repeat_$repeatDepth'
                : sourceRepetitionPenalty > 0
                    ? sourceRepeatDepth >= 3
                        ? 'source_repeat_3_plus'
                        : 'source_repeat_$sourceRepeatDepth'
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
            sourceRepeatDepth: sourceRepeatDepth,
            sourceRepetitionPenalty: sourceRepetitionPenalty,
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
    final rawRestWinner = rawWinner.drive == DriveKey.fatigue ||
        rawWinner.wantAction == 'rest';
    final top = rawRestWinner
        ? scored.firstWhere((value) => identical(value.original, rawWinner))
        : scored.first;
    final samplePool = top.adjusted.drive == DriveKey.fatigue ||
            top.adjusted.wantAction == 'rest'
        ? <_ScoredIntent>[top]
        : scored
            .where(
              (value) =>
                  value.adjusted.drive != DriveKey.fatigue &&
                  value.adjusted.wantAction != 'rest' &&
                  value.adjusted.score >= 0.52 &&
                  top.adjusted.score - value.adjusted.score <= 0.08,
            )
            .take(4)
            .toList(growable: false);
    final safeUnit = samplingUnit.clamp(0.0, 0.999999999).toDouble();
    final selected = _sampleNearTie(samplePool, safeUnit);
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
      sourceRepeatDepth: selected.sourceRepeatDepth,
      sourceRepetitionPenalty: selected.sourceRepetitionPenalty,
      sampledNearTie: samplePool.length > 1 && !identical(selected, top),
      samplingCandidateCount: samplePool.length,
      samplingUnit: safeUnit,
      topAdjustedScore: top.adjusted.score,
      selectedAdjustedScore: selected.adjusted.score,
    );
  }

  static _ScoredIntent _sampleNearTie(
    List<_ScoredIntent> values,
    double unit,
  ) {
    if (values.length <= 1) return values.first;
    final floor = values.last.adjusted.score;
    final weights = values
        .map(
          (value) => (0.5 +
                  ((value.adjusted.score - floor) / 0.08)
                      .clamp(0.0, 1.0))
              .toDouble(),
        )
        .toList(growable: false);
    final total = weights.fold<double>(0.0, (sum, value) => sum + value);
    var cursor = unit * total;
    for (var i = 0; i < values.length; i++) {
      cursor -= weights[i];
      if (cursor < 0) return values[i];
    }
    return values.last;
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
