class CedarCatalogEntry {
  const CedarCatalogEntry({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

/// Parses the live Cedar catalog. The catalog remains authoritative; this
/// class only turns its public `id·description·author` rows into presentation
/// metadata and never decides which games exist.
class CedarCatalogParser {
  const CedarCatalogParser._();

  static List<CedarCatalogEntry> parse(String catalog) {
    final entries = <CedarCatalogEntry>[];
    final seen = <String>{};
    final matches = RegExp(
      r'(?:^|[|：:\n]\s*)([A-Za-z][A-Za-z0-9_.:-]{1,79})·([^·|\n]{2,120})·([^|\n]{1,160})',
      multiLine: true,
    ).allMatches(catalog);
    for (final match in matches) {
      final id = match.group(1)?.trim() ?? '';
      final description = match.group(2)?.trim() ?? '';
      if (id.isEmpty || description.isEmpty || !seen.add(id)) continue;
      entries.add(CedarCatalogEntry(
        id: id,
        title: displayTitle(description),
        description: description,
      ));
    }
    return entries;
  }

  static String titleFor(String catalog, String gameId) {
    for (final entry in parse(catalog)) {
      if (entry.id == gameId) return entry.title;
    }
    return '';
  }

  static String displayTitle(String description) {
    final clean = description.trim();
    if (clean.isEmpty) return '';
    final separator = RegExp(r'[，,]').firstMatch(clean);
    final title = separator == null
        ? clean
        : clean.substring(0, separator.start).trim();
    return title.isEmpty ? clean : title;
  }

  /// Public Cedar front-end names can be shorter than the MCP catalog
  /// description. Keep only confirmed display aliases that cannot be derived
  /// by prefix matching; game existence still comes exclusively from catalog.
  static List<String> displayAliases(String gameId) => switch (gameId) {
        'eco' => const <String>['瓶中生态'],
        _ => const <String>[],
      };
}

/// Platform actions are declared by Cedar's live `play` tool schema rather
/// than repeated in every game's guide. They still go to Cedar for the final
/// permission decision; notably `rest` is accepted or rejected by the human's
/// server-side `allow_self_reset` switch.
class CedarPlatformActionPolicy {
  const CedarPlatformActionPolicy._();

  static const actions = <String>{'rest', 'announcements', 'vote'};

  static bool isPlatformAction(String action) => actions.contains(action);

  static bool isReadOnly(String action) => const <String>{
        'state',
        'status',
        'observe',
        'rooms',
        'actions',
        'catalog',
        'help',
        'look',
        'inventory',
        'announcements',
      }.contains(action);

  /// Discovery reads normally need one more planning decision in the same
  /// user goal. Passive state/status/observe polls are deliberately excluded:
  /// their next timing and actor come from the service response instead.
  static bool continuesPlanning(String action) => const <String>{
        'list_games',
        'get_guide',
        'rooms',
        'actions',
        'catalog',
        'help',
        'look',
        'inventory',
        'announcements',
      }.contains(action);

  static bool isRemoteExit(String action) => const <String>{
        'leave',
        'resign',
        'quit',
        'exit',
      }.contains(action);
}

/// Keeps a Cedar action and a server-side long poll as two different durable
/// operations. CedarDuet may commit `new`/`move` before waiting for the other
/// player; the generic MCP transport times out sooner than that wait window,
/// so carrying `wait=true` on an ordinary action makes a successful write look
/// like a failed one. The immediate outcome is persisted first and its
/// `next_call` is then owned by the background continuation loop.
class CedarActionTransportPolicy {
  const CedarActionTransportPolicy._();

  static Map<String, Object?> immediateResponseParams({
    required String gameId,
    required Map<String, Object?> params,
  }) {
    final normalized = Map<String, Object?>.from(params);
    if (gameId == 'duel' && normalized['wait'] == true) {
      normalized['wait'] = false;
    }
    return normalized;
  }
}

/// Merely displaying the APK chat page is not active foreground work. A real
/// chat lease preempts Cedar atomically; page visibility alone must not strand
/// a committed room turn forever.
class CedarContinuationPriorityPolicy {
  const CedarContinuationPriorityPolicy._();

  static bool shouldDefer({required bool chatTurnLeaseHeld}) =>
      chatTurnLeaseHeld;
}

/// Minimal player-operation signatures for a known upstream guide omission.
///
/// These fields describe how to submit an action; they contain no strategy,
/// source material, hidden state, room identity or puzzle answer. The live MCP
/// schema and game guide remain authoritative whenever they provide the same
/// contract.
class CedarPlayerProtocolContract {
  const CedarPlayerProtocolContract._();

  static String actionSignaturesFor(String gameId) => switch (gameId.trim()) {
        'duel' => '''【玩家动作参数签名补充 · 不是攻略】
duel.new 的 params：game_type 必填，值必须来自刚才 duel.catalog 的精确 game_type；mode 可填 human_first 或 ai_first；stake 可填非负整数。仅当 catalog 允许多人/NPC 时，才可按 catalog 填 target_player_count 与 fill_with_npcs。身份、绑定人类与 player_id 由 Cedar 凭据确定，不得自行填写或换人。''',
        _ => '',
      };
}

class CedarGameAdvicePolicy {
  const CedarGameAdvicePolicy._();

  static const maxNotes = 3;
  static const maxNoteChars = 500;

  static bool isLikelyAdvice(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return false;
    return RegExp(
      r'(建议|主意|策略|思路|试试|不如|可以.{0,12}(下|走|选|用|买|卖|种|做)|'
      r'(先|再|然后|记得|别忘了).{0,18}(下|走|选|用|买|卖|种|做)|'
      r'(下|落|走|放|选|用|买|卖|种).{0,12}(这里|那边|中间|左|右|上|下|这个|那个|张|格|列|行))',
      caseSensitive: false,
    ).hasMatch(clean);
  }

  static String bounded(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length <= maxNoteChars
        ? clean
        : '${clean.substring(0, maxNoteChars)}…';
  }
}
