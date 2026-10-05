import '../models/chat_message.dart';
import '../models/thought.dart';
import '../reference/world_book_history_policy.dart';
import 'desire_core_policy.dart';
import 'thought_similarity.dart';

/// Content guidance and bounded novelty ranking. No retrieval, generation,
/// quota, persistent state or change to the underlying drive scores.
class ConversationTopicPolicy {
  const ConversationTopicPolicy._();

  static String prompt({required bool proactive, required bool freshSourceOnly}) {
    final continuity = freshSourceOnly
        ? '本轮新话题来源隔离仍然有效：只展开本轮选中的来源和真实当前状态；不要从旧聊天、旧线程或记忆补题。没有具体内容可表达就 WAIT。'
        : '若上下文已有相关未完成线程，只接住其中尚有意义的一点；回到旧话题要带新进展、新观点或真实未解之处，不能把旧问题换句话再问。用户正在兴致勃勃地聊同一件事时可以深入，不为去重硬换题。';
    return '''
【话题内容与自然展开】
自主性也包括你自己决定什么值得说：从本轮已提供的兴趣、愿望、真实活动、共同经历或当下想法中选有具体内容的一点；这些是可用来源，不是必须轮流完成的清单。没有来源的生活经历、游戏进度、新闻或用户偏好不得编造。想象、假设与主观看法可以自然表达，但不能冒充已发生的事。
“先表达，再让对方接”只是选项之一，没有固定比例。你可以说自己的判断、感受、一个具体细节或想一起尝试的小事，也可以回答、关心、打趣、亲密、好奇或自然收尾；先照顾用户此刻真正的问题和方向，不抢走正在展开的话题。
${proactive ? '本轮是否值得联系仍服从原主动判断；可以用具体内容开头，不必总用想你、在干嘛或照料式问候。允许安静，不为填次数硬找话。' : '结合前后语义理解“嗯、确实、哈哈”等回应：若对方接住了你的话而你还有想说的，可往前讲一个新细节、理由或联想，不把供题责任立即退回给对方；若语义上已收尾、拒绝、忙碌或换题，就尊重它。不得仅凭回复短就降温，也不得把简短回应一律当作继续邀请。'}
优先推进内容，不复述上一轮结论；检查近期可见表达，避免重复开头、相同感慨和相同问题。表达可以留有回应空间，不要求句尾提问；真有具体好奇时仍按现有追问授权自然问，不连续采访。
$continuity
以上是表达选择，不是额外任务；不要向用户讲述选题、评分、线程或去重机制。
'''.trim();
  }

  /// Used only when choosing a new subject. Never applies to ordinary
  /// continuation, answers or user boundaries. Near-duplicate body text is
  /// evidence; a shared topic key alone is not, so genuine progress survives.
  static DesireCoreCandidate preferNovel({
    required List<DesireCoreCandidate> candidates,
    required List<CompanionThought> thoughts,
    required Iterable<ChatMessage> recent,
    required DateTime now,
  }) {
    assert(candidates.isNotEmpty);
    final history = WorldBookHistoryPolicy.withoutRoleplayTurns(recent.toList())
        .where((m) => m.isAssistant && !m.createdAt.isAfter(now) &&
            now.difference(m.createdAt) <= const Duration(hours: 24))
        .toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final byId = {for (final thought in thoughts) thought.id: thought};
    double adjusted(DesireCoreCandidate candidate) {
      final thought = byId[candidate.thoughtId];
      if (thought == null) return candidate.score;
      final repeated = history.take(8).any((m) =>
          ThoughtSimilarity.score(thought.text, m.content) >= 0.78);
      return candidate.score - (repeated ? 0.18 : 0.0);
    }
    var best = candidates.first;
    var score = adjusted(best);
    for (final candidate in candidates.skip(1)) {
      final next = adjusted(candidate);
      if (next > score) {
        best = candidate;
        score = next;
      }
    }
    return best;
  }
}
