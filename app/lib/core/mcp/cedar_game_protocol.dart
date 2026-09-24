import 'dart:convert';

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

  /// Reading a completed result is a snapshot, not a new shareable outcome.
  static bool isResultSnapshot(String action) =>
      action == 'get_result' || action.endsWith('_get_result');

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

/// Cedar save slots are a player-visible protocol shared by the long-running
/// games that advertise it in their live guide. The guide remains the source
/// of truth: room/session games without the five-slot clause are untouched.
class CedarSaveSlotPolicy {
  const CedarSaveSlotPolicy._();

  static bool supportsFiveSlots(String guide) => RegExp(
        r'(?:每游戏\s*5\s*槽|slot\s*=\s*1\s*[-~～至到]\s*5|slot=1-5)',
        caseSensitive: false,
      ).hasMatch(guide);

  static bool isOverwriteConfirmation({
    required String guide,
    required Map<String, Object?> params,
  }) =>
      supportsFiveSlots(guide) && params['confirm'] == true;

  static bool outcomeIndicatesExistingSave(String outcome) {
    final text = outcome.trim().toLowerCase();
    if (text.isEmpty) return false;
    return text.contains('confirm: true') ||
        text.contains('confirm=true') ||
        text.contains('already exists') ||
        text.contains('overwrite') ||
        (text.contains('已有') &&
            RegExp(r'(存档|池塘|世界|花园|旅程|游戏)').hasMatch(text)) ||
        (text.contains('覆盖') &&
            RegExp(r'(无法恢复|原存档|重新调用|确认)').hasMatch(text));
  }

  static bool isNewOrResetAction(String action) => RegExp(
        r'(?:^|[_.:-])(new|create|start|reset|import)$',
        caseSensitive: false,
      ).hasMatch(action.trim());

  static bool blocksAutonomousAction({
    required String guide,
    required String lastOutcome,
    required String action,
    required Map<String, Object?> params,
  }) {
    if (!supportsFiveSlots(guide)) return false;
    if (params['confirm'] == true) return true;
    return outcomeIndicatesExistingSave(lastOutcome) &&
        isNewOrResetAction(action);
  }

  static bool userExplicitlyApprovesOverwrite(String text) {
    final clean = text.trim();
    if (!RegExp(r'(覆盖|重开|重置|清空|删档)').hasMatch(clean)) return false;
    if (RegExp(
      r'(不要|别|不能|不许|不想|不需|不确认|先不|拒绝|为什么|为何|怎么|怎样|什么|是否|是不是|会不会|吗|？)',
    ).hasMatch(clean)) {
      return false;
    }
    return true;
  }

  static String promptGuidance(String guide, String lastOutcome) {
    if (!supportsFiveSlots(guide)) return '';
    final existing = outcomeIndicatesExistingSave(lastOutcome)
        ? '最新结果已经提示该槽有存档：不要再次调用 new/create/start/reset；先按指南观察或继续。'
        : '';
    return '''【Cedar 五槽存档边界】
此游戏明确支持 slot=1..5，缺省为 slot 1；每个 game 的五个槽彼此独立，不同 game 的同号槽也互不覆盖。已有存档默认继续。turn 0/尚未推进的初始存档可能由 Cedar 官方人类前端或服务自动建立，应视为可继续的有效存档，不能据此声称与另一游戏串档。
她确实想开新周目/新世界时，可以自主选择已知空槽并在 params_json 明确传 slot，不必为每次使用空槽询问用户；不知道某槽是否为空时不得猜成空槽。任何已有槽的覆盖、导入覆盖或 confirm:true 都是破坏性操作，后台绝不自主执行，用户回合也必须先得到用户对覆盖的明确同意。$existing''';
  }
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

/// Turns a model decision into the smallest executable call by carrying
/// forward only transport identity already returned by Cedar. Business
/// choices such as a move, target or purchase are never invented locally.
class CedarExecutableCallPolicy {
  const CedarExecutableCallPolicy._();

  static const _transportKeys = <String>{
    'room_id',
    'session_id',
    'match_id',
    'revision',
  };

  static Map<String, Object?> hydrateTransportParams({
    required Map<String, Object?> planned,
    required String continuationParamsJson,
    required String lastOutcome,
  }) {
    final result = Map<String, Object?>.from(planned);
    for (final raw in <String>[continuationParamsJson, lastOutcome]) {
      final source = _decodeObject(raw);
      if (source == null) continue;
      final flattened = <String, List<Object?>>{};
      _collectKnownTransportValues(source, flattened);
      for (final key in _transportKeys) {
        final values = flattened[key] ?? const <Object?>[];
        if (_isMissing(result[key]) && values.length == 1) {
          result[key] = values.single;
        }
      }
    }
    return result;
  }

  /// Reads only explicit action-scoped `required` declarations. Ambiguous
  /// prose is ignored so the APK cannot become a second, stricter game server.
  static Set<String> missingExplicitRequiredFields({
    required String action,
    required Map<String, Object?> params,
    required String guide,
    required String playProtocol,
  }) {
    final required = <String>{};
    for (final source in <String>[playProtocol, guide]) {
      final decoded = _decodeObject(source);
      if (decoded != null) {
        _collectActionRequired(decoded, action, required, actionScoped: false);
      }
      required.addAll(_requiredFromExplicitText(source, action));
    }
    return required.where((key) => _isMissing(params[key])).toSet();
  }

  /// Returns a transport identity only when Cedar exposed exactly one value.
  /// This is safe for deterministic read hydration (for example rooms ->
  /// state), but deliberately refuses to choose between multiple rooms.
  static String uniqueTransportValue({
    required String key,
    required Object? structuredContent,
    required String text,
  }) {
    final values = <String>{};
    void collect(Object? node) {
      if (node is Map) {
        for (final entry in node.entries) {
          if (entry.key.toString() == key) {
            final value = entry.value?.toString().trim() ?? '';
            if (value.isNotEmpty) values.add(value);
          }
          collect(entry.value);
        }
      } else if (node is List) {
        for (final item in node) {
          collect(item);
        }
      }
    }

    collect(structuredContent);
    collect(_decodeObject(text));
    if (values.isEmpty) {
      final escaped = RegExp.escape(key);
      final pattern = RegExp(
        '["\']$escaped["\']\\s*:\\s*["\']([^"\']{1,160})["\']',
      );
      for (final match in pattern.allMatches(text)) {
        final value = match.group(1)?.trim() ?? '';
        if (value.isNotEmpty) values.add(value);
      }
    }
    return values.length == 1 ? values.single : '';
  }

  static Map<String, Object?>? _decodeObject(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;
    try {
      final decoded = jsonDecode(clean);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          final decoded = jsonDecode(clean.substring(start, end + 1));
          if (decoded is Map) {
            return decoded.map((key, value) => MapEntry(key.toString(), value));
          }
        } catch (_) {}
      }
    }
    return null;
  }

  static void _collectKnownTransportValues(
    Object? node,
    Map<String, List<Object?>> output,
  ) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString();
        if (_transportKeys.contains(key) && !_isMissing(entry.value)) {
          final values = output.putIfAbsent(key, () => <Object?>[]);
          final fingerprint = entry.value.toString();
          if (!values.any((value) => value.toString() == fingerprint)) {
            values.add(entry.value);
          }
        }
        _collectKnownTransportValues(entry.value, output);
      }
    } else if (node is List) {
      for (final item in node) {
        _collectKnownTransportValues(item, output);
      }
    } else if (node is String && node.trim().startsWith('{')) {
      final decoded = _decodeObject(node);
      if (decoded != null) _collectKnownTransportValues(decoded, output);
    }
  }

  static void _collectActionRequired(
    Object? node,
    String action,
    Set<String> output, {
    required bool actionScoped,
  }) {
    if (node is List) {
      for (final item in node) {
        _collectActionRequired(item, action, output, actionScoped: actionScoped);
      }
      return;
    }
    if (node is! Map) return;
    final map = node.map((key, value) => MapEntry(key.toString(), value));
    var scoped = actionScoped || map['action']?.toString() == action;
    final properties = map['properties'];
    if (properties is Map) {
      final actionSchema = properties['action'];
      if (actionSchema is Map) {
        final constant = actionSchema['const']?.toString();
        final values = actionSchema['enum'];
        if (constant == action ||
            (values is List && values.map((e) => e.toString()).contains(action))) {
          scoped = true;
        }
      }
      if (scoped && properties['params'] is Map) {
        final required = (properties['params'] as Map)['required'];
        if (required is List) {
          output.addAll(required.map((item) => item.toString()));
        }
      }
    }
    if (map[action] case final actionNode?) {
      _collectActionRequired(actionNode, action, output, actionScoped: true);
    }
    for (final entry in map.entries) {
      if (entry.key != action) {
        _collectActionRequired(entry.value, action, output, actionScoped: scoped);
      }
    }
  }

  static Set<String> _requiredFromExplicitText(String source, String action) {
    if (source.trim().isEmpty) return const <String>{};
    final escaped = RegExp.escape(action);
    final result = <String>{};
    final patterns = <RegExp>[
      RegExp(
        '$escaped[^\\n]{0,240}(?:required|必填)[：: ]+([A-Za-z0-9_,./\\s-]{1,160})',
        caseSensitive: false,
      ),
      RegExp(
        '$escaped[^\\n]{0,120}params[^\\n]{0,80}(?:required|必填)[：: ]*([A-Za-z0-9_,./\\s-]{1,160})',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(source)) {
        result.addAll(RegExp(r'[A-Za-z_][A-Za-z0-9_]{1,63}')
            .allMatches(match.group(1) ?? '')
            .map((item) => item.group(0)!)
            .where((item) => !const <String>{'and', 'or', 'true', 'false'}
                .contains(item.toLowerCase())));
      }
    }
    for (final line in source.split('\n')) {
      if (!RegExp(
        // A guide may qualify an action as `game.action` (for example
        // `duel.new`). The dot is a valid left boundary for the action name;
        // letters, digits and protocol punctuation are not.
        '(^|[^A-Za-z0-9_:-])$escaped([^A-Za-z0-9_.:-]|\$)',
        caseSensitive: false,
      ).hasMatch(line)) {
        continue;
      }
      result.addAll(
        RegExp(
          r'([A-Za-z_][A-Za-z0-9_]{1,63})\s*(?:为|是)?\s*(?:必填|required)',
          caseSensitive: false,
        )
            .allMatches(line)
            .map((item) => item.group(1)!)
            .where((item) => !const <String>{
                  'action',
                  'params',
                  'required',
                }.contains(item.toLowerCase())),
      );
    }
    return result;
  }

  static bool _isMissing(Object? value) =>
      value == null ||
      (value is String && value.trim().isEmpty) ||
      (value is Map && value.isEmpty) ||
      (value is List && value.isEmpty);
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
