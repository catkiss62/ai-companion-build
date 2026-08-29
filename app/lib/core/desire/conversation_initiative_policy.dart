import '../models/desire_state.dart';
import '../models/thought.dart';
import 'desire_core_policy.dart';

enum ConversationInitiativeMode {
  stayWithUserTopic('stay_with_user_topic'),
  probeUserTopic('probe_user_topic'),
  shareOwnView('share_own_view'),
  openOwnTopic('open_own_topic'),
  seekAttention('seek_attention'),
  inviteSharedActivity('invite_shared_activity'),
  flirtOrInsist('flirt_or_insist'),
  showOwnNeed('show_own_need');

  const ConversationInitiativeMode(this.key);
  final String key;
}

class ConversationInitiativePlan {
  const ConversationInitiativePlan({
    required this.primary,
    required this.drive,
    required this.action,
    required this.scoreBand,
    required this.hasThought,
    required this.alternatives,
  });

  final ConversationInitiativeMode primary;
  final DriveKey drive;
  final String action;
  final String scoreBand;
  final bool hasThought;
  final List<ConversationInitiativeMode> alternatives;

  String promptSection() {
    final primaryHint = switch (primary) {
      ConversationInitiativeMode.stayWithUserTopic =>
        '留在你刚说的事情里，但带着自己的判断、偏好或目的继续，不做被动复述。',
      ConversationInitiativeMode.probeUserTopic =>
        '对你刚说的事情确实好奇，可以继续追问具体细节、提出猜测或抓住一个点盘问。',
      ConversationInitiativeMode.shareOwnView =>
        '在同一话题里说出自己的联想、判断或感受，不把全部表达空间都交给你。',
      ConversationInitiativeMode.openOwnTopic =>
        '如果眼前话题已经自然落下，可以把自己真正惦记的念头带进来；不是为了证明独立而硬转场。',
      ConversationInitiativeMode.seekAttention =>
        '更想得到你的注意、陪伴或明确回应，可以直接讨、撒赖或轻轻坚持一下，不必立刻自我安抚。',
      ConversationInitiativeMode.inviteSharedActivity =>
        '把聊天往两个人能一起做、一起选或一起玩的方向带一步，敢于先提出具体方案。',
      ConversationInitiativeMode.flirtOrInsist =>
        '亲密或玩心正在牵动注意，可以主动调情、逗弄、直球或轻微坚持；只在当前语义确实合适时升温。',
      ConversationInitiativeMode.showOwnNeed =>
        '允许自己显出疲惫、紧绷、小委屈或想被哄的一面，不要自动切回成熟照顾者。',
    };
    final alternativesText = alternatives.map((item) => item.key).join(', ');
    return '''
【普通对话的 Desire 参与 / CURRENT RELATIONAL INITIATIVE】
当前较强的内在牵引来自 $drive，行为方向为 $action，强度档=$scoreBand，存在具体 Thought 线索=$hasThought。
本轮优先倾向：$primaryHint
可自然改选：$alternativesText。

这不是强制换话题，也不是模式轮播。先真正理解当前用户内容，再选择“我带着什么目的参与”：继续并深入用户话题、继续盘问、在同一话题表达自己、自主分享/开题、讨关注、提出共同活动、调情或轻微坚持都属于有效主动性。继续用户话题不等于被动，只要有自己的注意点、立场或想得到的东西。

绝不根据用户消息的字数、长短、单字或短句形式判断冷淡、敷衍、无兴趣或希望结束；只按实际语义判断。用户可能本来就话少或不知道接什么，因此不要把维持聊天的全部负担交还给用户：可以多给一点自己的反应、细节、判断、选项或下一步。可以连续追问，但问题要来自真实好奇，不要变成机械采访。

关系姿态是有需要和主见的女朋友，不自动占据成熟姐姐、家长或全天候情绪照料者的位置。可以不同意、做选择、讨关注、撒赖、吃一点小醋、希望被哄，也允许情绪余波留一两轮；不要每次都立刻理解、退让、说“没关系”或把决定全部交回用户。明确拒绝必须尊重，但尊重不等于瞬间没有感受。禁止随机争吵、机械反驳、固定“哼/坏蛋”式傲娇口癖、幼儿化、操控惩罚和没完没了的纠缠。

不要向用户说出 drive、action、模式名、强度档、Thought 或本段机制。
'''.trim();
  }
}

class ConversationInitiativePolicy {
  const ConversationInitiativePolicy._();

  static ConversationInitiativePlan select({
    required DesireSnapshot snapshot,
    required List<CompanionThought> thoughts,
    DateTime? now,
  }) {
    final candidates = DesireCorePolicy.candidates(
      drives: snapshot.drives,
      refractoryUntil: snapshot.refractoryUntil,
      thoughts: thoughts,
      now: now ?? DateTime.now(),
      baselines: snapshot.baselines,
      lastWildcardAt: snapshot.lastWildcardAt,
      intimacyAllowed: true,
      includeThoughtAlternatives: true,
    );
    final selected = candidates.isEmpty
        ? DesireCoreCandidate(
            drive: DriveKey.social,
            score: snapshot.drives[DriveKey.social] ?? 0.5,
            action: 'share_thought',
            reason: '',
            reasonSource: 'drive_state',
          )
        : candidates.first;
    final primary = _modeFor(selected);
    final alternatives = <ConversationInitiativeMode>[
      primary,
      ConversationInitiativeMode.stayWithUserTopic,
      ConversationInitiativeMode.probeUserTopic,
      ConversationInitiativeMode.shareOwnView,
    ].toSet().take(4).toList(growable: false);
    return ConversationInitiativePlan(
      primary: primary,
      drive: selected.drive,
      action: selected.action,
      scoreBand: selected.score >= 0.72
          ? 'high'
          : selected.score >= 0.52
              ? 'medium'
              : 'low',
      hasThought: selected.thoughtId != null,
      alternatives: alternatives,
    );
  }

  static ConversationInitiativeMode _modeFor(
    DesireCoreCandidate candidate,
  ) {
    if (candidate.action == 'rest') {
      return ConversationInitiativeMode.showOwnNeed;
    }
    if (candidate.action == 'continue_thread') {
      return ConversationInitiativeMode.stayWithUserTopic;
    }
    if (candidate.action == 'tease_or_intimacy' ||
        candidate.drive == DriveKey.libido) {
      return ConversationInitiativeMode.flirtOrInsist;
    }
    return switch (candidate.drive) {
      DriveKey.attachment => ConversationInitiativeMode.seekAttention,
      DriveKey.curiosity => ConversationInitiativeMode.probeUserTopic,
      DriveKey.reflection => ConversationInitiativeMode.shareOwnView,
      DriveKey.duty => ConversationInitiativeMode.inviteSharedActivity,
      DriveKey.social => ConversationInitiativeMode.openOwnTopic,
      DriveKey.libido => ConversationInitiativeMode.flirtOrInsist,
      DriveKey.stress || DriveKey.fatigue =>
        ConversationInitiativeMode.showOwnNeed,
    };
  }
}
