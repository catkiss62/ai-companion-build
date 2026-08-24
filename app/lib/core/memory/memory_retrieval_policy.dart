import '../models/memory_item.dart';

class MemoryRetrievalDecision {
  const MemoryRetrievalDecision({
    required this.direct,
    required this.strongEvidence,
    required this.cooldownBlocked,
    required this.queryTokenCount,
    required this.memoryTokenCount,
    required this.overlapCount,
    required this.score,
    required this.reason,
  });

  final bool direct;
  final bool strongEvidence;
  final bool cooldownBlocked;
  final int queryTokenCount;
  final int memoryTokenCount;
  final int overlapCount;
  final double score;
  final String reason;
}

/// Pure, local admission policy shared by prompt retrieval, extraction
/// deduplication and redacted diagnostics.
///
/// Importance, confidence and pinned status may rank a directly relevant item,
/// but can never manufacture relevance. This is the direct-seed rule: without
/// lexical evidence from the current query, long-term memory stays quiet.
class MemoryRetrievalPolicy {
  const MemoryRetrievalPolicy._();

  static const Set<String> _stopTokens = <String>{
    '这个', '那个', '就是', '但是', '然后', '现在', '今天', '昨天', '真的',
    '感觉', '觉得', '可以', '还是', '没有', '已经', '一下', '什么', '怎么',
    '为什么', '我们', '你们', '他们', '我的', '你的', '他的', '她的', '一个',
    '一些', '时候', '可能', '应该', '比较', '如果', '因为', '所以', '不是',
    '自己', '东西', '事情', '的话', '聊天', '回复', '消息',
  };

  static const Set<String> _ambiguousStandalone = <String>{
    '喜欢', '想你', '想我', '爱你', '爱我', '想念', '心动', '关系', '感情',
  };

  static final RegExp _romance = RegExp(
    r'喜欢你|喜欢我|爱你|爱我|想你|想我|想念|心动|恋爱|亲密|依恋',
  );

  static Set<String> tokensFor(String text) {
    final lowered = text.toLowerCase();
    final latin = RegExp(r'[a-z0-9_]{2,}')
        .allMatches(lowered)
        .map((match) => match[0]!)
        .where((token) => !_stopTokens.contains(token));
    final chinese = <String>[];
    final chars = lowered.runes.map(String.fromCharCode).toList();
    for (var index = 0; index < chars.length - 1; index += 1) {
      final pair = '${chars[index]}${chars[index + 1]}';
      if (RegExp(r'[\u4e00-\u9fff]{2}').hasMatch(pair) &&
          !_stopTokens.contains(pair)) {
        chinese.add(pair);
      }
    }
    return <String>{...latin, ...chinese};
  }

  static String _compactPhrase(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_\\u3400-\\u9fff]+'), '');

  static bool hasDirectTextEvidence(String query, String candidate) {
    final queryTokens = tokensFor(query);
    final candidateTokens = tokensFor(candidate);
    if (queryTokens.isEmpty || candidateTokens.isEmpty) return false;
    final shared =
        queryTokens.where(candidateTokens.contains).toSet();
    final overlap = shared.length;
    final onlyAmbiguous =
        overlap == 1 && _ambiguousStandalone.contains(shared.first);
    if (overlap > 0 && !onlyAmbiguous) return true;

    final compactQuery = _compactPhrase(query);
    final compactCandidate = _compactPhrase(candidate);
    if (compactQuery.length < 4 || compactCandidate.length < 4) return false;
    return compactCandidate.contains(compactQuery) ||
        compactQuery.contains(compactCandidate);
  }

  static Duration cooldownFor(MemoryItem item) {
    final searchable =
        '${item.content} ${item.subjectKey} ${item.tags.join(' ')}';
    if (_romance.hasMatch(searchable)) return const Duration(hours: 18);
    if (item.isSharedExperience) return const Duration(hours: 8);
    if (item.kind == 'preference') return const Duration(hours: 4);
    return const Duration(minutes: 90);
  }

  static MemoryRetrievalDecision evaluate({
    required String query,
    required MemoryItem item,
    DateTime? now,
    bool enforceCooldown = true,
  }) {
    final queryTokens = tokensFor(query);
    final memoryText =
        '${item.content} ${item.subjectKey} ${item.tags.join(' ')}';
    final memoryTokens = tokensFor(memoryText);
    if (queryTokens.isEmpty || memoryTokens.isEmpty) {
      return MemoryRetrievalDecision(
        direct: false,
        strongEvidence: false,
        cooldownBlocked: false,
        queryTokenCount: queryTokens.length,
        memoryTokenCount: memoryTokens.length,
        overlapCount: 0,
        score: 0,
        reason: 'empty_direct_seed',
      );
    }

    final shared = queryTokens.where(memoryTokens.contains).toSet();
    final overlapCount = shared.length;
    final onlyAmbiguous =
        overlapCount == 1 && _ambiguousStandalone.contains(shared.first);
    final compactQuery = _compactPhrase(query);
    final compactMemory = _compactPhrase(memoryText);
    final phraseMatch = compactQuery.length >= 4 &&
        compactMemory.length >= 4 &&
        (compactMemory.contains(compactQuery) ||
            compactQuery.contains(compactMemory));
    final direct = phraseMatch || (overlapCount > 0 && !onlyAmbiguous);
    if (!direct) {
      return MemoryRetrievalDecision(
        direct: false,
        strongEvidence: false,
        cooldownBlocked: false,
        queryTokenCount: queryTokens.length,
        memoryTokenCount: memoryTokens.length,
        overlapCount: overlapCount,
        score: 0,
        reason:
            overlapCount == 0 ? 'no_direct_seed' : 'ambiguous_single_overlap',
      );
    }

    final queryCoverage = overlapCount / queryTokens.length;
    final memoryCoverage = overlapCount / memoryTokens.length;
    final strongThreshold =
        queryTokens.length <= 3 ? queryTokens.length : (queryTokens.length / 2).ceil();
    final strongEvidence = phraseMatch ||
        (queryTokens.length == 1 && overlapCount == 1) ||
        overlapCount >= strongThreshold.clamp(2, 6);
    final instant = now ?? DateTime.now();
    final lastUse = _latest(item.lastRecalledAt, item.lastExpressedAt);
    final cooldownBlocked = enforceCooldown &&
        lastUse != null &&
        instant.difference(lastUse) < cooldownFor(item) &&
        !strongEvidence;
    if (cooldownBlocked) {
      return MemoryRetrievalDecision(
        direct: true,
        strongEvidence: false,
        cooldownBlocked: true,
        queryTokenCount: queryTokens.length,
        memoryTokenCount: memoryTokens.length,
        overlapCount: overlapCount,
        score: 0,
        reason: 'recently_injected_or_expressed',
      );
    }

    final ageHours = instant.difference(item.updatedAt).inMinutes / 60.0;
    final recency = 1 / (1 + ageHours / (24 * 45));
    final directScore =
        queryCoverage * 0.46 + memoryCoverage.clamp(0.0, 1.0) * 0.22;
    final score = directScore +
        item.importance * 0.10 +
        item.confidence * 0.07 +
        item.retentionScore * 0.08 +
        recency * 0.05 +
        (item.pinned ? 0.02 : 0.0);
    return MemoryRetrievalDecision(
      direct: true,
      strongEvidence: strongEvidence,
      cooldownBlocked: false,
      queryTokenCount: queryTokens.length,
      memoryTokenCount: memoryTokens.length,
      overlapCount: overlapCount,
      score: score,
      reason: phraseMatch ? 'direct_phrase' : 'direct_token_overlap',
    );
  }

  static DateTime? _latest(DateTime? left, DateTime? right) {
    if (left == null) return right;
    if (right == null) return left;
    return left.isAfter(right) ? left : right;
  }
}
