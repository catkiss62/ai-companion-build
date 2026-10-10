import 'public_web_discovery_policy.dart';

/// Only catalog topics leave the device; private source sentences stay local.
class RecentWebTopics {
  static const domains = <String, String>{
    'ai': '人工智能研究与应用', 'ocean': '海洋生物与海洋科学',
    'space': '天文学与航天探索', 'games': '电子游戏与互动叙事',
    'animation': '动画与漫画作品', 'music': '音乐与声音技术',
    'nature': '动物行为与生态保护', 'technology': '消费科技与软件技术',
    'art': '艺术展览与视觉设计', 'science': '科学研究与新材料',
  };
  static final _patterns = <String, RegExp>{
    'ai': RegExp(r'人工智能|大模型|深度学习|机器学习|神经网络|\b(?:AI|Gemini|DeepSeek|GPT)\b', caseSensitive: false),
    'ocean': RegExp(r'海洋|鲸鱼|鲸豚|海豚|珊瑚|深海'),
    'space': RegExp(r'天文|宇宙|星系|航天|火星|黑洞|太空'),
    'games': RegExp(r'游戏|互动叙事|桌游'),
    'animation': RegExp(r'动画|漫画|动漫'),
    'music': RegExp(r'音乐|歌曲|作曲|音色|语音合成'),
    'nature': RegExp(r'动物|生态|植物|鸟类|昆虫'),
    'technology': RegExp(r'软件|安卓|芯片|处理器|手机|平板'),
    'art': RegExp(r'绘画|美术|艺术|展览|视觉设计'),
    'science': RegExp(r'物理|化学|新材料|科学研究|生物学'),
  };

  static Set<String> matching(Iterable<String> localText) {
    final found = <String>{};
    for (final text in localText.take(40)) {
      if (RegExp(r'不喜欢|不感兴趣|别聊|不想聊|不要再提').hasMatch(text)) continue;
      for (final entry in _patterns.entries) {
        if (entry.value.hasMatch(text)) found.add(entry.key);
      }
    }
    return found;
  }

  static PublicWebDiscoveryTopic choose({required PublicWebDiscoveryTopic fallback,
      required DateTime now, Iterable<String> ownInterest = const [],
      Iterable<String> userPreferences = const [], Iterable<String> sharedTopics = const [],
      List<String> recentKeys = const []}) {
    final own = matching(ownInterest), user = matching(userPreferences), shared = matching(sharedTopics);
    final scores = <String, int>{for (final k in domains.keys)
      k: (own.contains(k) ? 4 : 0) + (user.contains(k) ? 2 : 0) + (shared.contains(k) ? 2 : 0)};
    final slot = now.millisecondsSinceEpoch ~/ const Duration(hours: 6).inMilliseconds;
    final order = domains.keys.toList();
    final rotated = [...order.skip(slot % order.length), ...order.take(slot % order.length)];
    // One in five slots remains open exploration. Recent topics lose priority,
    // rather than repeatedly reinforcing the same discovered interest.
    final rank = {for (var i = 0; i < rotated.length; i++) rotated[i]: i};
    if (slot % 5 != 0) rotated.sort((a, b) {
      int score(String k) => scores[k]! -
          (recentKeys.take(9).any((v) => v.contains(':$k:')) ? 5 : 0);
      final difference = score(b).compareTo(score(a));
      return difference != 0 ? difference : rank[a]!.compareTo(rank[b]!);
    });
    final domain = rotated.first;
    return PublicWebDiscoveryTopic(query: '${domains[domain]}最近一周有哪些可核验的新进展',
      interestKey: '${fallback.interestKey.split(':').first}:recent_interest:$domain:recent7d',
      searchMode: 'recent_interest', domain: domain);
  }

  static bool isRecent(String key) => key.endsWith(':recent7d');
  static String? dateTag(Iterable<String> tags, String key) {
    for (final tag in tags) {
      if (tag.startsWith('$key=')) return tag.substring(key.length + 1);
    }
    return null;
  }
  static bool recentEvent(Iterable<String> tags, DateTime now) {
    final raw = dateTag(tags, 'event_date');
    if (raw == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return false;
    final date = DateTime.tryParse('${raw}T00:00:00Z');
    if (date == null || date.toIso8601String().substring(0, 10) != raw) return false;
    final today = DateTime.utc(now.year, now.month, now.day);
    return !date.isAfter(today) && today.difference(date).inDays <= 7;
  }
}
