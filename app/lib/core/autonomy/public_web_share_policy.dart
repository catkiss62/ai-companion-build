import '../models/desire_state.dart';
import '../models/thought.dart';

/// Content-free routing contract for an untrusted public-web candidate.
///
/// Candidate title/summary/URL stay inside WEB_CANDIDATE_DATA. The Thought
/// carries only a stable local candidate id so web text can never become a
/// trusted inner instruction or long-term memory by crossing this boundary.
class PublicWebSharePolicy {
  const PublicWebSharePolicy._();

  static const topicPrefix = 'public_web_candidate:';
  static const sourcePrefix = 'public_web_candidate:';
  static const thoughtText =
      '我刚发现了一条和当前兴趣有关的公开资料，想先判断它是不是真的值得随手分享。';

  static const stagingLifecycle = 'share_staging';
  static const readyLifecycle = 'share_ready';
  static const sharedLifecycle = 'shared';
  static const declinedLifecycle = 'declined';

  static String topicKey(String candidateId) =>
      '$topicPrefix${candidateId.trim().toLowerCase()}';

  static String source(String candidateId) =>
      '$sourcePrefix${candidateId.trim().toLowerCase()}';

  static String? candidateIdFromTopic(String? topicKey) {
    final normalized = (topicKey ?? '').trim().toLowerCase();
    if (!normalized.startsWith(topicPrefix)) return null;
    final id = normalized.substring(topicPrefix.length).trim();
    return id.isEmpty ? null : id;
  }

  static bool isCandidateThought(CompanionThought? thought) =>
      thought != null &&
      candidateIdFromTopic(thought.topicKey) != null &&
      thought.provenance == ThoughtProvenance.publicWebCandidate;

  static DriveKey driveFromKey(String value) => DriveKey.values.firstWhere(
        (drive) => drive.name == value,
        orElse: () => DriveKey.curiosity,
      );
}
