/// Host-recorded, revealed interactions only. This never authorizes Cedar
/// operations, live activity claims, arbitrary scores, or sealed choices.
class CreativePlayEvidence {
  const CreativePlayEvidence({this.works = const {}, this.scopedAt});
  final Map<String, int> works;
  final int? scopedAt;

  // These name the external operations already guarded by the Cedar adapter.
  // A local game must not turn its existence into permission to claim them.
  static final _externalOperation = RegExp(
      r'Cedar|MCP|游戏厅|钓鱼|鱼漂|浮标|鱼竿|池塘|钓点|鱼饵|饵盒|下矿|挖矿|采矿|矿洞|图鉴|花园|种植|浇水|旅行|探索|决斗|对弈|'
      r'(钓了|甩了|抛了).{0,10}(竿|条|鱼)|'
      r'(这就|马上|现在就).{0,6}(进去|进房|加入|开局|开始玩|杀进去)',
      caseSensitive: false);

  bool supports(String sentence, {bool recent = false, DateTime? now}) {
    if (_externalOperation.hasMatch(sentence)) return false;
    final times = <int>[
      if (scopedAt != null) scopedAt!,
      for (final e in works.entries)
        if (e.key.length > 1 && sentence.contains(e.key)) e.value,
    ];
    if (!recent) return times.isNotEmpty;
    final instant = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return times.any((at) => at > 0 && at <= instant && instant - at <= 3600000);
  }
}
