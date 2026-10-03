import '../models/chat_message.dart';
import '../models/world_book_turn_context.dart';
import 'memory_retrieval_policy.dart';

/// Read-time limits only. Stored chat, extraction batches and decay are unchanged.
class ConversationRecallPolicy {
  const ConversationRecallPolicy._();
  static const messageLimit = 64;
  static const characterBudget = 36000;

  static List<ChatMessage> recentWindow(List<ChatMessage> messages) {
    final groups = <List<ChatMessage>>[];
    for (final message in messages) {
      if (message.isUser || groups.isEmpty) groups.add(<ChatMessage>[]);
      groups.last.add(message);
    }
    final selected = <ChatMessage>[];
    var characters = 0;
    for (final group in groups.reversed) {
      final size = group.fold<int>(0, (sum, m) => sum + m.promptContent.length);
      if (selected.isNotEmpty &&
          (selected.length + group.length > messageLimit ||
              characters + size > characterBudget)) break;
      // Never cut the current message or manufacture a partial old reply.
      if (selected.isEmpty || group.first.isUser) {
        selected.insertAll(0, group);
        characters += size;
      }
    }
    return selected;
  }

  static bool isFollowup(String query) {
    if (RegExp(r'换个|换一|不说|不聊|别提|不是说|另一个|另外|顺便|说到别的').hasMatch(query)) return false;
    return RegExp(r'那个|那件|那次|那台|这件|这段|这个.{0,4}(事|话题)|刚才.{0,4}(说|聊)|后来|接着说|继续说|然后呢|它.{0,4}(后来|怎么|怎样)').hasMatch(query);
  }

  static String contextualQuery(String query, List<ChatMessage> recent, {
    String currentMessageId = '',
    DateTime? now,
  }) {
    if (!isFollowup(query) || query.length > 120 || query.contains('《')) return query;
    if (recent.any((m) => m.id == currentMessageId &&
        WorldBookTurnContext.decode(m.worldBookContextJson).hasRoleplay)) return query;
    final instant = now ?? DateTime.now();
    final prior = <ChatMessage>[];
    for (final message in recent.reversed) {
      if (message.id == currentMessageId) continue;
      if (WorldBookTurnContext.decode(message.worldBookContextJson).hasRoleplay) break;
      if (instant.difference(message.createdAt) > const Duration(hours: 6)) break;
      prior.add(message);
      if (message.isUser || prior.length >= 3) break;
    }
    if (prior.isEmpty) return query;
    final text = prior.reversed.map((m) => m.promptContent).join('\n');
    // A deictic word alone cannot attach a newly introduced object to the old
    // topic (for example, a computer question following a novel discussion).
    final explicitCue = query.replaceAll(RegExp(
      r'我们|还记得|记得|刚才|之前|说过|说到|聊过|提到|那件事|这件事|这个话题|那个|那次|那台|这段|后来|接着说|继续说|怎么样|怎么了|怎样|然后|结果|到底|你|我|它|呢|吗|呀|吧|啊|了|的|是|还|就'), '');
    if (MemoryRetrievalPolicy.tokensFor(explicitCue).isNotEmpty &&
        !MemoryRetrievalPolicy.hasDirectTextEvidence(explicitCue, text)) return query;
    // Prefer an explicit title over an entire assistant paragraph. If there
    // are several possible titles, do not silently decide which one was meant.
    final titles = <String>{};
    for (final message in prior) {
      titles.addAll(RegExp(r'《([^《》\n]{2,60})》')
          .allMatches(message.promptContent).map((m) => m.group(1)!));
    }
    if (titles.length > 1) return query;
    if (titles.length == 1) return '$query ${titles.single}';
    if (text.length > 600) return query; // No arbitrary partial topic.
    return '$query\n$text';
  }

  static List<String> searchTerms(String query) {
    const noise = {'记忆', '记得', '还记', '以前', '之前', '那次', '那个', '查询',
      '搜索', '检索', '看看', '回忆', '后来', '说过', '聊过', '一下', '继续'};
    final terms = MemoryRetrievalPolicy.tokensFor(query)
        .where((t) => !noise.contains(t)).toList();
    terms.sort((a, b) => b.length.compareTo(a.length));
    return terms.take(32).toList(growable: false);
  }

  static String likePattern(String term) =>
      '%${term.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
}
