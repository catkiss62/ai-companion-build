import '../models/companion_album.dart';

class CompanionAlbumSearchMatch {
  const CompanionAlbumSearchMatch({
    required this.item,
    required this.score,
    required this.confidence,
  });

  final CompanionAlbumItem item;
  final double score;
  final String confidence;
}

/// Local-only fuzzy ranking for the companion's saved album.
///
/// This policy never reads image bytes and never mutates album lifecycle. It
/// ranks the already persisted title, vision summary, save reason, category,
/// source domain and save time. A generic request intentionally returns a few
/// recent candidates with low confidence so the model can ask which one the
/// user means instead of inventing a unique match.
class CompanionAlbumSearchPolicy {
  const CompanionAlbumSearchPolicy._();

  static List<CompanionAlbumSearchMatch> rank({
    required String query,
    required Iterable<CompanionAlbumItem> items,
    int limit = 5,
  }) {
    final normalized = _normalize(query);
    final wantsSelfImage = RegExp(
      r'(你自己|自己的|自拍|自画像|形象|鲸鱼娘)',
    ).hasMatch(normalized);
    final wantsMemory = RegExp(r'(回忆|纪念|我们俩|我们一起)').hasMatch(normalized);
    final wantsOther = RegExp(r'(其他|别的类别)').hasMatch(normalized);
    final semantic = _semanticQuery(normalized);
    final terms = _terms(semantic);
    final hasCategoryIntent = wantsSelfImage || wantsMemory || wantsOther;

    final ranked = <CompanionAlbumSearchMatch>[];
    for (final item in items) {
      if (item.nsfw || item.lifecycle != CompanionAlbumItem.saved) continue;

      var score = 0.0;
      if (wantsSelfImage && item.category == 'self_image') score += 7;
      if (wantsMemory && item.category == 'memory') score += 7;
      if (wantsOther && item.category == 'other') score += 5;

      score += _fieldScore(semantic, terms, item.title, 7.0);
      score += _fieldScore(semantic, terms, item.summary, 5.0);
      score += _fieldScore(semantic, terms, item.reason, 3.5);
      score += _fieldScore(semantic, terms, item.sourceDomain, 1.5);
      score += _fieldScore(semantic, terms, item.category, 1.0);

      if (score > 0) {
        ranked.add(CompanionAlbumSearchMatch(
          item: item,
          score: score,
          confidence: score >= 10 ? 'strong' : 'possible',
        ));
      }
    }

    ranked.sort(_compare);
    final safeLimit = limit.clamp(1, 8).toInt();
    if (ranked.isNotEmpty) {
      return ranked.take(safeLimit).toList(growable: false);
    }

    // With no usable semantic/category clue (or no match), expose only a few
    // recent safe candidates and label them ambiguous. Recency is never
    // presented as proof that one of them is the image the user meant.
    final recent = items
        .where((item) =>
            !item.nsfw && item.lifecycle == CompanionAlbumItem.saved)
        .toList()
      ..sort((a, b) => _savedAt(b).compareTo(_savedAt(a)));
    if (normalized.isEmpty && !hasCategoryIntent) return const [];
    return recent
        .take(safeLimit.clamp(1, 3).toInt())
        .map((item) => CompanionAlbumSearchMatch(
              item: item,
              score: 0,
              confidence: 'ambiguous_recent',
            ))
        .toList(growable: false);
  }

  static int _compare(
    CompanionAlbumSearchMatch a,
    CompanionAlbumSearchMatch b,
  ) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return _savedAt(b.item).compareTo(_savedAt(a.item));
  }

  static DateTime _savedAt(CompanionAlbumItem item) =>
      item.savedAt ?? item.createdAt;

  static double _fieldScore(
    String semantic,
    Set<String> terms,
    String value,
    double weight,
  ) {
    if (semantic.isEmpty || value.trim().isEmpty) return 0;
    final haystack = _normalize(value);
    if (haystack.contains(semantic)) return weight;
    if (terms.isEmpty) return 0;
    final matched = terms.where(haystack.contains).length;
    if (matched == 0) return 0;
    return weight * matched / terms.length;
  }

  static Set<String> _terms(String value) {
    final result = <String>{};
    for (final match in RegExp(r'[a-z0-9]{2,}|[\u4e00-\u9fff]+')
        .allMatches(value)) {
      final token = match.group(0)!;
      if (RegExp(r'^[a-z0-9]').hasMatch(token)) {
        result.add(token);
        continue;
      }
      if (token.length <= 2) {
        result.add(token);
        continue;
      }
      for (var index = 0; index < token.length - 1; index++) {
        result.add(token.substring(index, index + 2));
      }
    }
    return result;
  }

  static String _semanticQuery(String value) {
    var result = value;
    for (final phrase in const <String>[
      '你记不记得',
      '还记不记得',
      '记不记得',
      '还记得',
      '之前',
      '以前',
      '曾经',
      '你自己',
      '自己的',
      '你保存过的',
      '你存过的',
      '你保存的',
      '你存的',
      '保存过',
      '存过',
      '保存',
      '收藏',
      '相册里面',
      '相册里的',
      '相册',
      '一张',
      '那张',
      '这张',
      '图片',
      '照片',
      '图像',
      '帮我',
      '给我',
      '看看',
      '找找',
      '查查',
      '搜索',
      '检索',
      '一下',
      '什么',
      '哪张',
      '吗',
      '呢',
      '吧',
    ]) {
      result = result.replaceAll(phrase, ' ');
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
