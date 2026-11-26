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
    CedarParticipationMode inferred,
  ) {
    if (preference != 'auto' && preferences.contains(preference))
      return CedarParticipationMode.fromKey(preference);
    return knownGames.contains(game) ? CedarParticipationMode.puzzle : inferred;
  }

  static bool revealsSolution(
    CedarParticipationMode mode,
    String action,
    Map<String, Object?> params,
  ) {
    if (mode != CedarParticipationMode.puzzle) return false;
    final command =
        (action == 'cmd' ? params['command']?.toString() ?? '' : action)
            .toLowerCase()
            .trim()
            .replaceAll(RegExp(r'\s+'), '_');
    return RegExp(
      r'^(?:(?:show|view|read|get|reveal|peek)[_-]?(?:the[_-])?(?:answer|solution|walkthrough)|solution|walkthrough|spoiler|human_guide|answer_key|查看答案|标准谜底|查看攻略)(?:$|[_ -])',
    ).hasMatch(command);
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
          ? CedarParticipationMode.unknown
          : session.mode;
      final mode = CedarPuzzleState.effective(
        session.gameId,
        selection,
        inferred,
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
      if (state.execution?.id != executionId || session == null ||
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
