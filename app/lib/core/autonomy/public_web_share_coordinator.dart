import '../database/app_database.dart';
import '../desire/desire_engine.dart';
import '../models/thought.dart';
import 'public_web_share_policy.dart';

class PublicWebShareStageResult {
  const PublicWebShareStageResult({
    required this.state,
    this.candidateId,
    this.thoughtId,
  });

  final String state;
  final String? candidateId;
  final String? thoughtId;

  bool get ready =>
      state == PublicWebSharePolicy.readyLifecycle &&
      candidateId != null &&
      thoughtId != null;
}

/// Bridges one untrusted web candidate into the existing Thought/Desire path.
///
/// It never sends a message. ProactiveEngine remains the only outbound writer
/// and must still pass its ordinary rhythm, device, Grounding and frequency
/// gates before the persona may share or return WAIT.
class PublicWebShareCoordinator {
  PublicWebShareCoordinator({
    required this.db,
    required this.desire,
  });

  final AppDatabase db;
  final DesireEngine desire;

  Future<PublicWebShareStageResult> stageNextCandidate({
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    final claimed = await db.claimNextPublicWebCandidateForSharing(now: instant);
    if (claimed == null) {
      return const PublicWebShareStageResult(state: 'none');
    }
    final source = PublicWebSharePolicy.source(claimed.id);
    final topicKey = PublicWebSharePolicy.topicKey(claimed.id);
    try {
      await desire.feedThought(
        text: PublicWebSharePolicy.thoughtText,
        drive: PublicWebSharePolicy.driveFromKey(claimed.driveKey),
        incomingStrength: 0.62,
        source: source,
        topicKey: topicKey,
      );
      final thought = await db.thoughtBySource(source);
      if (thought == null) {
        await db.completePublicWebCandidateShareStage(
          claimed.id,
          ready: false,
          outcome: 'thought_missing',
          now: instant,
        );
        return PublicWebShareStageResult(
          state: 'thought_missing',
          candidateId: claimed.id,
        );
      }
      final completed = await db.completePublicWebCandidateShareStage(
        claimed.id,
        ready: true,
        outcome: 'thought_created',
        now: instant,
      );
      if (!completed) {
        return PublicWebShareStageResult(
          state: 'ownership_lost',
          candidateId: claimed.id,
          thoughtId: thought.id,
        );
      }
      return PublicWebShareStageResult(
        state: PublicWebSharePolicy.readyLifecycle,
        candidateId: claimed.id,
        thoughtId: thought.id,
      );
    } catch (_) {
      await db.completePublicWebCandidateShareStage(
        claimed.id,
        ready: false,
        outcome: 'thought_error',
        now: instant,
      );
      return PublicWebShareStageResult(
        state: 'thought_error',
        candidateId: claimed.id,
      );
    }
  }

  Future<PublicWebShareStageResult> seedDiagnosticCandidate({
    DateTime? now,
  }) async {
    await db.seedDiagnosticPublicWebShareCandidate(now: now);
    return stageNextCandidate(now: now);
  }

  String? candidateIdForThought(CompanionThought? thought) =>
      PublicWebSharePolicy.isCandidateThought(thought)
          ? PublicWebSharePolicy.candidateIdFromTopic(thought!.topicKey)
          : null;

  Future<void> markShared(String candidateId, {DateTime? now}) =>
      db.markPublicWebCandidateShareOutcome(
        candidateId,
        outcome: PublicWebSharePolicy.sharedLifecycle,
        now: now,
      );

  Future<void> markDeclined(String candidateId, {DateTime? now}) =>
      db.markPublicWebCandidateShareOutcome(
        candidateId,
        outcome: PublicWebSharePolicy.declinedLifecycle,
        now: now,
      );
}
