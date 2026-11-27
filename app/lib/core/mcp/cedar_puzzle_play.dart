part of 'cedar_toy_activity.dart';

class CedarPuzzleState {
  const CedarPuzzleState({
    this.preference = 'auto',
    this.questionId = '',
    this.note = '',
    this.goal = '',
    this.steps = 0,
    this.serverTurn = '',
  });
  static const knownGames = {'puzzle_box', 'memoria', 'soup'};
  static const preferences = {'auto', 'solo', 'co_play', 'puzzle'};
  final String preference, questionId, note, goal, serverTurn;
  final int steps;
  bool get quickFollowUp => steps > 0 && steps < 3;
  bool get empty =>
      preference == 'auto' &&
      questionId.isEmpty &&
      note.isEmpty &&
      goal.isEmpty &&
      steps == 0 &&
      serverTurn.isEmpty;

  static CedarParticipationMode effective(
    String game,
    String preference,
    CedarParticipationMode inferred, {
    bool revised = false,
  }) {
    if (preference != 'auto' && preferences.contains(preference))
      return CedarParticipationMode.fromKey(preference);
    return !revised && knownGames.contains(game)
        ? CedarParticipationMode.puzzle
        : inferred;
  }

  static CedarParticipationMode declaredMode(String guide) {
    // Prefer an explicit guide header; leave ambiguous prose to the normal planner.
    final heading = guide.split(RegExp(r'[。；;\n]')).first.trim();
    if (RegExp(
      r'^(?:(?:游玩方式|游戏类型|模式)[:：]\s*)?(?:(?:独立|单人)(?:推理)?解谜|解谜模式)',
    ).hasMatch(heading))
      return CedarParticipationMode.puzzle;
    if (RegExp(r'^(?:(?:游玩方式|游戏类型|模式)[:：]\s*)?单人(?:游戏)?$').hasMatch(heading))
      return CedarParticipationMode.solo;
    return CedarParticipationMode.unknown;
  }

  static final _revealName = RegExp(
    r'^(?:(?:show|view|read|get|reveal|peek|unlock)[_-]?(?:the[_-])?(?:answer|solution|walkthrough|truth)|solution|walkthrough|spoiler|human_guide|answer_key|查看答案|标准谜底|查看攻略)(?:$|[_ -])',
  );
  static final _revealDescription = RegExp(
    r'(?:查看|显示|揭晓|揭示|公开|揭开|阅读|直接给出|展示)(?:本题|本案|游戏|最终|完整|全部|标准|正确|真正|的|所有|本关|官方|此题|该题|这道题){0,5}(?:答案|解答|谜底|真相|攻略)|(?:仅供人类|仅供主人)(?:查看|阅读)的?(?:攻略|解答)|(?:show|display|read|reveal|view|unlock)\s+(?:(?:the|full|complete|correct|final|official)\s+)*(?:solution|answer\s*key|walkthrough|answer\b|truth\b)',
    caseSensitive: false,
  );
  static bool _describesReveal(String text) {
    if (RegExp(
      r'^(?:提交|验证|核对)(?:玩家|自己|你的|所填|猜测|推理|推测|答案)|^(?:submit|check|verify)\s+(?:(?:your|a|the player.s)\s+)?(?:guess|answer)',
      caseSensitive: false,
    ).hasMatch(text.trimLeft()))
      return false;
    for (final match in _revealDescription.allMatches(text)) {
      final prefix = text.substring(0, match.start);
      if (!RegExp(
        r'(?:不(?:会|能|可)?|禁止|无法|不要|without|never|not)\s*$',
        caseSensitive: false,
      ).hasMatch(prefix))
        return true;
    }
    return false;
  }

  static bool revealsSolution(
    CedarParticipationMode mode,
    String action,
    Map<String, Object?> params, {
    String guide = '',
  }) {
    if (mode != CedarParticipationMode.puzzle &&
        mode != CedarParticipationMode.unknown)
      return false;
    final raw = (action == 'cmd' ? params['command']?.toString() ?? '' : action)
        .trim();
    if (raw.isEmpty) return false;
    if (_revealName.hasMatch(raw.toLowerCase().replaceAll(RegExp(r'\s+'), '_')))
      return true;
    final command = raw.split(RegExp(r'\s+')).first;
    final selections = <String,Object?>{...params};
    if (action == 'cmd') {
      // Tokenize quoted values before interpreting flags. A player's quoted
      // guess can itself contain spaces or text that resembles an option.
      final tokens = RegExp(r"""(?:[^\s"'=]+|=|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')""")
          .allMatches(raw).map((m) => m[0]!).toList();
      for (var i = 1; i < tokens.length; i++) {
        final flag = RegExp(r'^(--)?([A-Za-z_][\w-]*)(:?)$').firstMatch(tokens[i]);
        if (flag == null || i + 1 >= tokens.length) continue;
        final equals = tokens[i + 1] == '=';
        if (flag[1] == null && !equals && flag[3]!.isEmpty) continue;
        if (equals) i++;
        if (i + 1 >= tokens.length || tokens[i + 1].startsWith('--')) continue;
        final value = tokens[++i];
        selections[flag[2]!.toLowerCase()] = value.replaceFirst(RegExp(r"""^["']"""), '')
            .replaceFirst(RegExp(r"""["']$"""), '');
      }
      for (final m in RegExp(r'(?:^|\s)(?:--)?(page|section|view|tab|topic|mode):([\w-]+)', caseSensitive:false).allMatches(raw)) {
        selections.putIfAbsent(m[1]!.toLowerCase(), () => m[2]);
      }
      final page = RegExp(r'^(?:read|open|view|browse)(?:[_-](?:page|book|section))?\s+(\w+)$',caseSensitive:false).firstMatch(raw);
      if (page != null) selections.putIfAbsent('page', () => page[1]);
    }
    final label = RegExp.escape(command);
    // Match an action entry, not examples or an answer supplied by the player.
    final entry = RegExp(
      '(?:^|[；;。，,、|])\\s*(?:[-*]\\s*)?[\x60"\']?' +
          label +
          '(?![a-z0-9_-])[\x60"\']?\\s*(?:\\([^()\\n]{0,100}\\))?\\s*[:：=|—–-]?\\s*([^；;。，,、|\\n]{1,140})',
      caseSensitive: false,
    );
    bool described(Object? value) {
      if (value is String) return _describesReveal(value);
      if (value is! Map) return false;
      return const ['description','desc','summary','label','title','说明','描述']
          .any((k) => value[k] is String && _describesReveal(value[k] as String));
    }

    // Only a matched choice in a selector with an explicitly documented
    // spoiler sibling can disambiguate a multi-purpose action description.
    bool selectedOrdinaryBranch = false;
    bool hasDescription(Object? item) => item is String && item.trim().isNotEmpty ||
        item is Map && const ['description','desc','summary','label','title','说明','描述']
            .any((key) => item[key] is String && (item[key] as String).trim().isNotEmpty);

    bool selectedOption(Object? spec, Object? chosen, {bool spoilerSibling = false}) {
      if (spec is List) {
        final mixed = spec.any(described);
        return spec.any((item) => selectedOption(item, chosen, spoilerSibling: mixed));
      }
      if (spec is! Map) return false;
      if (chosen is Map) {
        final properties = spec['properties'] ?? spec;
        return properties is Map && chosen.entries.any((e) =>
            selectedOption(properties[e.key], e.value));
      }
      if (chosen is List) return chosen.any((item) => selectedOption(spec, item));
      if (chosen == null) return false;
      final named = spec[chosen.toString()];
      if (described(named)) return true;
      if (hasDescription(named) && spec.values.any(described)) selectedOrdinaryBranch = true;
      if (const ['const','value','id','name'].any((key) => spec[key] == chosen)) {
        if (described(spec)) return true;
        if (spoilerSibling && hasDescription(spec)) selectedOrdinaryBranch = true;
      }
      return const ['oneOf','anyOf','options','choices','values','enum']
          .any((key) => selectedOption(spec[key], chosen));
    }

    bool actionEntry(Object? item) {
      if (item is! Map) return described(item);
      selectedOrdinaryBranch = false;
      for (final key in const ['parameters','params','inputSchema','arguments','properties']) {
        if (selectedOption(item[key], selections)) return true;
      }
      if (!described(item)) return false;
      final description = const ['description','desc','summary','label','title','说明','描述']
          .map((k) => item[k]).whereType<String>().join(' ');
      final alternatives = RegExp(r'也可|或者|或是|或查看|或阅读|或揭|可选|分别|也能|either|\bor\b',caseSensitive:false);
      return !(selectedOrdinaryBranch && alternatives.hasMatch(description));
    }

    bool structured(Object? node) {
      if (node is List) return node.any(structured);
      if (node is! Map) return false;
      if (actionEntry(node[command])) return true;
      if (const ['name','id','action','command'].any((k) => node[k] == command)) {
        return actionEntry(node);
      }
      return node.values.any((v) => (v is Map || v is List) && structured(v));
    }

    // Values of navigation selectors identify destinations. Free-form guesses
    // and questions can contain the same words without requesting an answer.
    for (final key in const ['page','section','view','tab','topic','mode']) {
      final value = selections[key];
      if (value is String && RegExp(r'^(?:solution|walkthrough|answer_key|spoiler|谜底|标准答案|完整攻略)$',
          caseSensitive:false).hasMatch(value)) return true;
    }
    if (guide.trimLeft().startsWith('{') || guide.trimLeft().startsWith('[')) {
      try { return structured(jsonDecode(guide)); } on FormatException { /* Mixed guide. */ }
    }
    for (final line in const LineSplitter().convert(guide)) {
      final clean = line.trim();
      if (clean.startsWith('{') || clean.startsWith('[')) {
        try {
          if (structured(jsonDecode(clean))) return true;
          continue;
        } on FormatException {
          /* mixed text */
        }
      }
      for (final match in entry.allMatches(clean.replaceAll('**', ''))) {
        if (!_describesReveal(match.group(1)!)) continue;
        // In text guides each action variant may have its own parenthesized selector.
        final qualifier = RegExp(r'\((\w+)\s*[:=]\s*["\x27`]?([\w-]+)').firstMatch(match[0]!);
        if (qualifier == null || selections[qualifier[1]]?.toString() == qualifier[2]) return true;
      }
    }
    return false;
  }

  Map<String, Object?> toJson() => {
    'preference': preference,
    'question': questionId,
    'note': note,
    'goal': goal,
    'steps': steps,
    'server_turn': serverTurn,
  };
  factory CedarPuzzleState.fromJson(Object? value) {
    if (value is! Map) return const CedarPuzzleState();
    return CedarPuzzleState(
      preference: preferences.contains(value['preference'])
          ? value['preference'] as String
          : 'auto',
      questionId: value['question']?.toString() ?? '',
      note: value['note']?.toString() ?? '',
      goal: value['goal']?.toString() ?? '',
      steps: (value['steps'] as num?)?.toInt() ?? 0,
      serverTurn: value['server_turn']?.toString() ?? '',
    );
  }

  CedarPuzzleState afterAction({
    required CedarParticipationMode mode,
    required String goal,
    required String actor,
    required String serverTurn,
    required bool scheduled,
    required bool succeeded,
  }) {
    final follow =
        mode == CedarParticipationMode.puzzle &&
        succeeded &&
        actor == 'companion' &&
        !scheduled &&
        goal.trim().isNotEmpty;
    // Switching objectives ends the old burst. The third action always restores ordinary pacing.
    final nextSteps = follow && (steps == 0 || steps >= 3 || this.goal == goal)
        ? (steps % 3) + 1
        : 0;
    return CedarPuzzleState(
      preference: preference,
      note: note,
      serverTurn: serverTurn,
      goal: nextSteps > 0 ? goal : '',
      steps: nextSteps,
    );
  }
}

extension CedarPuzzleControls on CedarToyActivityStore {
  Future<bool> selectPlayMode(
    CedarGameSession shown, {
    String? preference,
  }) async {
    if (preference != null &&
        !CedarPuzzleState.preferences.contains(preference))
      return false;
    final fence = await db.captureBrainWorkFence();
    if (fence == null) return false;
    final sql = await db.database;
    return sql.transaction((txn) async {
      if (!await fence.matches(txn)) return false;
      final state = await CedarToyActivityStore.readStateInTransaction(txn);
      final session = state.sessions[shown.gameId];
      if (session == null || session.id != shown.id || state.execution != null)
        return false;
      final previous = session.puzzle;
      final selection = preference ?? previous.preference;
      final inferred = preference == 'auto' && previous.preference != 'auto'
          ? CedarPuzzleState.declaredMode(session.guide)
          : session.mode;
      final mode = CedarPuzzleState.effective(
        session.gameId,
        selection,
        inferred,
        revised: session.useRevisedGuide,
      );
      final actor = previous.serverTurn.isNotEmpty
          ? previous.serverTurn
          : McpTurnStateResolver.resolve(session.lastOutcome)?.nextActor ?? '';
      final waiting = session.phase == CedarActivityPhase.waitingUser;
      final canResume =
          waiting &&
          !session.hasContinuationCall &&
          !const {'user', 'shared', 'wait', 'finished'}.contains(actor) &&
          (preference == null ||
              mode.playsAlone ||
              previous.questionId.isNotEmpty);
      if (preference == null &&
          (!canResume || state.activeGameId != session.gameId))
        return false;
      final now = DateTime.now();
      final preserveQuestion =
          previous.questionId.isNotEmpty &&
          preference != null &&
          mode == CedarParticipationMode.puzzle;
      final resume = canResume && !preserveQuestion;
      final next = session.copyWith(
        mode: mode,
        invitationApproved:
            selection == 'co_play' || session.invitationApproved,
        puzzle: CedarPuzzleState(
          preference: selection,
          note: previous.note,
          questionId: preserveQuestion ? previous.questionId : '',
          serverTurn: previous.serverTurn,
        ),
        phase: resume ? CedarActivityPhase.active : null,
        nextActor: resume ? 'companion' : null,
        waitingReason: resume
            ? (!mode.playsAlone && previous.questionId.isEmpty
                  ? '正在核对游戏回合'
                  : '')
            : null,
        nextActionAt: resume ? now : null,
        updatedAt: now,
      );
      await CedarToyActivityStore.writeSettingsInTransaction(txn, {
        ...CedarToyActivityStore.stateSettingValues(
          state.copyWith(
            sessions: {...state.sessions, session.gameId: next},
            updatedAt: now,
          ),
        ),
        'cedar_play_mode_${session.gameId}': selection,
        CedarToyActivityStore.controlRevisionKey: CedarToyActivityStore._uuid
            .v4(),
        CedarToyActivityStore.userControlRevisionKey: CedarToyActivityStore
            ._uuid
            .v4(),
      });
      return true;
    });
  }

  Future<bool> savePuzzleChoice(
    CedarGameSession shown, {
    required String executionId,
    required String text,
    required bool ask,
  }) async {
    final fence = await db.captureBrainWorkFence();
    if (fence == null ||
        executionId.isEmpty ||
        text.trim().isEmpty ||
        text.length > 600)
      return false;
    final sql = await db.database;
    return sql.transaction((txn) async {
      if (!await fence.matches(txn) ||
          await BrainWorkFence.value(
                txn,
                CedarToyActivityStore.executionFenceSettingKey,
              ) !=
              executionId)
        return false;
      final state = await CedarToyActivityStore.readStateInTransaction(txn);
      final session = state.activeSession;
      if (state.execution?.id != executionId ||
          session == null ||
          session.id != shown.id ||
          session.mode != CedarParticipationMode.puzzle ||
          !session.companionCanContinue ||
          session.hasContinuationCall ||
          session.puzzle.questionId.isNotEmpty)
        return false;
      final now = DateTime.now();
      final id = 'cedar-puzzle-$executionId';
      if (ask) {
        final busy = await txn.rawQuery(
          "SELECT 1 FROM generation_jobs WHERE status IN ('pending','running','retry_wait','awaiting_confirmation') LIMIT 1",
        );
        if (busy.isNotEmpty) return false;
        await ConversationSourceStore.insertMessage(
          txn,
          ChatMessage(
            id: id,
            role: 'assistant',
            content: text.trim(),
            createdAt: now,
            isProactive: true,
            proactiveIntent: 'cedar_puzzle_help',
            expectsReply: true,
          ).toDb(),
        );
      }
      final next = session.copyWith(
        phase: ask ? CedarActivityPhase.waitingUser : CedarActivityPhase.active,
        nextActor: ask ? 'user' : 'companion',
        waitingReason: ask ? '等待你的提示' : '留题再想',
        nextActionAt: ask ? null : now.add(const Duration(minutes: 30)),
        clearNextActionAt: ask,
        puzzle: CedarPuzzleState(
          preference: session.puzzle.preference,
          questionId: ask ? id : '',
          note: text.trim(),
        ),
        updatedAt: now,
      );
      await CedarToyActivityStore.writeSettingsInTransaction(
        txn,
        CedarToyActivityStore.stateSettingValues(
          state.copyWith(
            sessions: {...state.sessions, session.gameId: next},
            updatedAt: now,
          ),
        ),
      );
      return true;
    });
  }
}
