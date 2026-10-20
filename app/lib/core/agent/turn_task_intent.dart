import '../ai/jev_decision_gateway.dart';
import '../mcp/cedar_timed_play_task.dart';
import '../mcp/cedar_game_protocol.dart';
import '../mcp/cedar_toy_activity.dart';
import 'turn_execution_contract.dart';

/// Semantic interpretation from the existing short-decision batch. Target IDs
/// come only from the supplied snapshot, never model-invented identifiers.
class TurnTaskIntent {
  const TurnTaskIntent({this.available = false, this.gameAction = 'none',
    this.gameId = '', this.sessionId = '', this.durationText = '', this.minutes = 0, this.durationResolved = true,
    this.unresolvedFields = const {}, this.creativeAction = 'none', this.workId = '', this.requestId = '', this.workTargetKind = 'unresolved'});
  final Set<String> unresolvedFields;
  bool get gameExecutionResolved => !unresolvedFields.any((k)=>const {'task_game','task_game_target'}.contains(k));
  bool get creativeExecutionResolved => !unresolvedFields.any((k)=>const {'task_creative','task_work_target'}.contains(k));
  Set<String> get deferredToolIds => {
    if (!gameExecutionResolved) ...{'cedar_toy.play','cedar_toy.manage_activity','cedar_toy.start_timed_play'},
    if (unresolvedFields.contains('task_duration')) 'cedar_toy.start_timed_play',
    if (!creativeExecutionResolved) ...{'creative_work.commission','creative_work.stop'},
  };
  final bool available;
  final bool durationResolved;
  final String gameAction, gameId, sessionId, durationText;
  final int minutes;
  final String creativeAction, workId, requestId, workTargetKind;
  bool get gameControl => const {'pause', 'pause_and_release', 'resume'}.contains(gameAction);
  Map<String, Object?> toJson() => {'available': available, 'game_action': gameAction,
    'game_id': gameId, 'session_id': sessionId, 'duration_text': durationText,
    'minutes': minutes, 'duration_resolved': durationResolved, 'creative_action': creativeAction, 'work_id': workId, 'request_id': requestId, 'work_target_kind': workTargetKind, 'unresolved_fields': unresolvedFields.toList()};
  static TurnTaskIntent fromJson(Object? raw) {
    if (raw is! Map) return const TurnTaskIntent();
    return TurnTaskIntent(available: raw['available'] == true,
      unresolvedFields: (raw['unresolved_fields'] as List?)?.whereType<String>().toSet() ?? const {},
      gameAction: raw['game_action'] as String? ?? 'none', gameId: raw['game_id'] as String? ?? '',
      sessionId: raw['session_id'] as String? ?? '', durationText: raw['duration_text'] as String? ?? '',
      minutes: (raw['minutes'] as num?)?.toInt() ?? 0,
      durationResolved: raw['duration_resolved'] == true,
      creativeAction: raw['creative_action'] as String? ?? 'none',
      workId: raw['work_id'] as String? ?? '', requestId: raw['request_id'] as String? ?? '',
      workTargetKind: raw['work_target_kind'] as String? ?? 'unresolved');
  }
  List<TurnTaskGoal> goals(String turnId) => [
    if (gameAction == 'play') TurnTaskGoal(turnId: turnId,
      slot: TurnEffectSlot.cedarForegroundWrite, authorized: gameExecutionResolved, description: '本轮进入或推进真实游戏',
      target: {if (gameId.isNotEmpty) 'game_id': gameId}),
    if (const {'play', 'resume'}.contains(gameAction) && (minutes > 0 || !durationResolved)) TurnTaskGoal(turnId: turnId,
      slot: TurnEffectSlot.cedarTimedRegistration, authorized: durationResolved && gameExecutionResolved,
      description: durationResolved ? '登记持续游玩 $minutes 分钟并在结束后汇报' : '确认持续游玩时长并登记对应任务',
      target: {if (gameId.isNotEmpty) 'game_id': gameId}, durationText: durationText, minutes: minutes),
    if (gameControl) TurnTaskGoal(turnId: turnId, slot: TurnEffectSlot.cedarControl, authorized: gameExecutionResolved,
      description: '按本轮请求 $gameAction 指定游戏', target: {
        'game_id': gameId, 'session_id': sessionId, 'operation': gameAction}),
    if (creativeAction == 'commission') TurnTaskGoal(turnId: turnId,
      slot: TurnEffectSlot.creativeCommission, authorized: creativeExecutionResolved, description: '登记本轮作品制作委托',
      target: {'work_id': workId, 'request_id': requestId, 'target_kind': workTargetKind}),
    if (creativeAction == 'stop') TurnTaskGoal(turnId: turnId,
      slot: TurnEffectSlot.creativeControl, authorized: creativeExecutionResolved, description: '停止指定作品的本次制作',
      target: {'work_id': workId, 'request_id': requestId, 'operation': 'stop'}),
  ];
}

class TurnTaskQuestionSet {
  TurnTaskQuestionSet({required this.userText, required this.state, required this.works, String catalog = ''}) {
    var index = 0;
    for (final session in state.sessions.values.take(16)) {
      games['g${index++}'] = (id: session.gameId, title: session.displayName, sessionId: session.id, phase: session.phase.key);
    }
    for (final entry in CedarCatalogParser.parse(catalog)) {
      if (games.values.any((g) => g.id == entry.id)) continue;
      if (games.length >= 48) break;
      games['g${index++}'] = (id: entry.id, title: entry.title, sessionId: '', phase: 'not_started');
    }
    index = 0;
    for (final work in works.take(8)) { workTargets['w${index++}'] = work; }
    index = 0;
    for (final match in RegExp(
      r'半(?:个)?小时|\d{1,3}\s*(?:分钟|minutes?|mins?)|[一二两三四五六七八九十]{1,3}分钟|half an hour',
      caseSensitive: false).allMatches(userText)) {
      final text = match.group(0)!;
      if (CedarTimedPlayTaskStore.durationMinutes(text, userText) != null && !durations.containsValue(text)) {
        durations['d${index++}'] = text;
      }
    }
  }
  final String userText;
  final CedarToyActivityState state;
  final List<Map<String, dynamic>> works;
  final games = <String, ({String id, String title, String sessionId, String phase})>{};
  final workTargets = <String, Map<String, dynamic>>{};
  final durations = <String, String>{};
  Map<String, Object?> get context => {
    'game_targets': {for (final e in games.entries) e.key: {
      'game_id': e.value.id, 'title': e.value.title, 'session_id': e.value.sessionId,
      'phase': e.value.phase, 'active': state.activeGameId == e.value.id}},
    'work_targets': {for (final e in workTargets.entries) e.key: {
      'id': e.value['id'], 'title': e.value['title'], 'status': e.value['status']}},
  };
  Map<String, JevChoiceQuestion> get questions => {
    'task_game': const JevChoiceQuestion(
      'From latest_user_text and references in recent_context, select the present authorized game action. '
      'Respect negation, conditional/future requests, quotes, different games and user-only play. '
      'none for discussion or optional free-time permission. Pause/resume must refer to a real game target.',
      {'none': 'No present action', 'play': 'Enter or advance an actual game now',
       'pause': 'Pause the named/current game now', 'pause_and_release': 'Pause it and allow switching to other games now',
       'resume': 'Resume the specified paused game now',
       'report': 'Asks for the real pending game result or timed-task progress now; no new play action'}, optional: true),
    if (games.isNotEmpty) 'task_game_target': JevChoiceQuestion(
      'Resolve the game actually targeted by this user request. Use current references only when unambiguous; '
      'never select the active game if the user names a different one. none for no matching or ambiguous target.',
      {'none': 'No unique existing target', for (final e in games.entries) e.key: e.value.title}, optional: true),
    if (durations.isNotEmpty) 'task_duration': JevChoiceQuestion(
      'Which literal duration is requested for the companion to actually keep playing now? '
      'none for quoted, hypothetical, future, user-only, negated or unrelated duration. This is separate from starting one move.',
      {'none': 'No present timed-play request', ...durations}, optional: true),
    'task_creative': const JevChoiceQuestion(
      'Resolve the present user request about companion-made works using context. '
      'commission requires a real creation/revision request, not feedback, discussion or a hypothetical. '
      'stop includes contextual references such as 先别做那个了; game pause is a separate task_game action.',
      {'none': 'No present creation/control request', 'commission': 'Create or revise a work now',
       'stop': 'Stop making the specified work now'}, optional: true),
    'task_work_target': JevChoiceQuestion(
      'Identify the work referred to in the current request. new_work ONLY for an explicitly new creation; '
      'Do not choose by recency alone when the user names another work.',
      {'unresolved': 'No unique existing target, ambiguous modification, or no task',
       'new_work': 'Explicitly make a new work, not a reference to an existing one', for (final e in workTargets.entries) e.key: '${e.value['title']} (${e.value['status']})'}, optional: true),
  };
  TurnTaskIntent interpret(Map<String, String>? answers, {Map<String, JevChoiceDecision> details = const {}}) {
    if (answers == null || !answers.containsKey('task_game') || !answers.containsKey('task_creative')) return const TurnTaskIntent();
    final game = games[answers['task_game_target']];
    final work = workTargets[answers['task_work_target']];
    final unresolved = details.entries.where((e)=>e.key.startsWith('task_') && e.value.ambiguous).map((e)=>e.key).toSet();
    final duration = unresolved.contains('task_duration') ? '' : durations[answers['task_duration']] ?? '';
    return TurnTaskIntent(available: true, unresolvedFields: unresolved, gameAction: answers['task_game'] ?? 'none',
      gameId: game?.id ?? '', sessionId: game?.sessionId ?? '', durationText: duration,
      minutes: CedarTimedPlayTaskStore.durationMinutes(duration, userText) ?? 0,
      durationResolved: !unresolved.contains('task_duration') && (durations.isEmpty || answers['task_duration'] == 'none' || durations.containsKey(answers['task_duration'])),
      creativeAction: answers['task_creative'] ?? 'none',
      workId: work?['id']?.toString() ?? '', requestId: work?['request_id']?.toString() ?? '',
      workTargetKind: work != null ? 'existing' : answers['task_work_target'] == 'new_work' ? 'new_work' : 'unresolved');
  }
}
