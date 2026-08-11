class ThoughtSimilarity {
  const ThoughtSimilarity._();

  static double score(String a, String b) {
    final aa = _normalize(a);
    final bb = _normalize(b);
    if (aa.isEmpty || bb.isEmpty) return 0;
    if (aa == bb) return 1;

    final shorter = aa.length <= bb.length ? aa : bb;
    final longer = aa.length > bb.length ? aa : bb;
    if (shorter.length >= 8 && longer.contains(shorter)) return 0.96;

    final at = _tokens(a);
    final bt = _tokens(b);
    if (at.isEmpty || bt.isEmpty) return 0;
    final inter = at.intersection(bt).length.toDouble();
    final union = at.union(bt).length.toDouble();
    final minSize = at.length < bt.length ? at.length.toDouble() : bt.length.toDouble();
    final jaccard = union == 0 ? 0.0 : inter / union;
    final containment = minSize == 0 ? 0.0 : inter / minSize;

    // High precision by design. topic_key is the preferred semantic link;
    // fuzzy text matching only catches wording that is genuinely very close.
    return (containment * 0.58 + jaccard * 0.42).clamp(0.0, 1.0).toDouble();
  }

  static String normalizedKey(String text) => _normalize(text);

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'''[\s，。！？；：、“”‘’（）()【】\[\]{}<>《》…—\-_,.!?;:'\"~`@#￥$%^&*+=|\\/]'''), '');
  }

  static Set<String> _tokens(String input) {
    final lowered = input.toLowerCase();
    final out = <String>{};
    for (final match in RegExp(r'[a-z0-9_]{2,}').allMatches(lowered)) {
      out.add(match.group(0)!);
    }
    final chars = lowered.runes
        .map(String.fromCharCode)
        .where((c) => RegExp(r'[\u4e00-\u9fff]').hasMatch(c))
        .toList(growable: false);
    for (var i = 0; i + 1 < chars.length; i++) {
      out.add('${chars[i]}${chars[i + 1]}');
    }
    for (var i = 0; i + 2 < chars.length; i++) {
      out.add('${chars[i]}${chars[i + 1]}${chars[i + 2]}');
    }
    return out;
  }
}
