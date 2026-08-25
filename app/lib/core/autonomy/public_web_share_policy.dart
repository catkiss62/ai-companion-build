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

class PublicWebShareTestDecision {
  const PublicWebShareTestDecision({
    required this.result,
    required this.blockCategory,
    required this.modelDecisionReached,
  });

  final String result;
  final String blockCategory;
  final bool modelDecisionReached;
}

/// Privacy-safe classification for the explicit true-device share test.
///
/// Only stable categories are persisted. Raw model output, candidate content,
/// URLs, prompt text and arbitrary exception strings never cross this boundary.
class PublicWebShareTestPolicy {
  const PublicWebShareTestPolicy._();

  static const existingReadySource = 'existing_ready';
  static const diagnosticSeededSource = 'diagnostic_seeded';
  static const pendingSource = 'pending';

  static PublicWebShareTestDecision classify({
    required bool sent,
    required String reason,
  }) {
    if (sent) {
      return const PublicWebShareTestDecision(
        result: 'sent',
        blockCategory: 'none',
        modelDecisionReached: true,
      );
    }
    final normalized = reason.trim();
    if (normalized.contains('选择 WAIT')) {
      return const PublicWebShareTestDecision(
        result: 'model_wait',
        blockCategory: 'none',
        modelDecisionReached: true,
      );
    }
    if (normalized.contains('Reality Grounding')) {
      return const PublicWebShareTestDecision(
        result: 'blocked',
        blockCategory: 'grounding_guard',
        modelDecisionReached: true,
      );
    }
    if (normalized.contains('重复服务模板')) {
      return const PublicWebShareTestDecision(
        result: 'blocked',
        blockCategory: 'service_template_guard',
        modelDecisionReached: true,
      );
    }
    final block = switch (normalized) {
      final value when value.contains('设备转移锁定') => 'transfer_lock',
      final value when value.contains('Active Brain') => 'active_brain',
      final value when value.contains('主动心跳正在由另一引擎处理') =>
        'proactive_lease',
      final value when value.contains('用户正在与我聊天') => 'chat_turn',
      final value when value.contains('仍有真实用户轮次') => 'pending_user_turn',
      final value when value.contains('没有 API Key') => 'api_key',
      final value when value.contains('过去24小时') => 'daily_ceiling',
      final value when value.contains('短时间内') => 'short_window_ceiling',
      final value when value.startsWith('Gate ') => 'delivery_gate',
      final value when value.contains('更需要休息') => 'fatigue',
      final value when value.contains('没有形成意图') => 'no_intent',
      final value when value.contains('写入权限已经转移') => 'writer_lease',
      final value when value.contains('用户已经开始新的聊天') =>
        'user_preempted',
      final value when value.contains('设备状态已变化') => 'device_state',
      _ => 'other',
    };
    return PublicWebShareTestDecision(
      result: 'blocked',
      blockCategory: block,
      modelDecisionReached: false,
    );
  }
}

