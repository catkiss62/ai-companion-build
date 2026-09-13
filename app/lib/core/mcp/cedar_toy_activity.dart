import 'dart:convert';

import '../database/app_database.dart';
import 'mcp_protocol.dart';

enum CedarParticipationMode {
  unknown('unknown', '待判断'),
  solo('solo', '她自己玩'),
  coPlay('co_play', '和你共玩'),
  multiplayer('multiplayer', '多人游戏'),
  hybrid('hybrid', '混合模式');

  const CedarParticipationMode(this.key, this.label);
  final String key;
  final String label;

  bool get requiresInvitation =>
      this == coPlay || this == multiplayer || this == hybrid;

  static CedarParticipationMode fromKey(String? value) => values.firstWhere(
        (item) => item.key == value,
        orElse: () => unknown,
      );
}

enum CedarActivityPhase {
  guideReady('guide_ready', '已读指南'),
  awaitingInvitation('awaiting_invitation', '等待你同意'),
  active('active', '正在玩'),
  waitingUser('waiting_user', '轮到你'),
  waitingRemote('waiting_remote', '等待游戏'),
  paused('paused', '已暂停'),
  completed('completed', '已结束'),
  failed('failed', '遇到问题');

  const CedarActivityPhase(this.key, this.label);
  final String key;
  final String label;

  bool get continuable => this != completed && this != failed;

  static CedarActivityPhase fromKey(String? value) => values.firstWhere(
        (item) => item.key == value,
        orElse: () => guideReady,
      );
}

class CedarGameEvent {
  const CedarGameEvent({
    required this.id,
    required this.kind,
    required this.summary,
    required this.createdAt,
    this.action = '',
    this.contentKinds = const <String>[],
    this.viewerUrl = '',
    this.notable = false,
    this.imageData = '',
    this.imageMimeType = '',
  });

  final String id;
  final String kind;
  final String summary;
  final DateTime createdAt;
  final String action;
  final List<String> contentKinds;
  final String viewerUrl;
  final bool notable;
  final String imageData;
  final String imageMimeType;

  CedarGameEvent withoutInlineMedia() => imageData.isEmpty
      ? this
      : CedarGameEvent(
          id: id,
          kind: kind,
          summary: summary,
          createdAt: createdAt,
          action: action,
          contentKinds: contentKinds,
          viewerUrl: viewerUrl,
          notable: notable,
        );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': kind,
        'summary': summary,
        'created_at': createdAt.millisecondsSinceEpoch,
        'action': action,
        'content_kinds': contentKinds,
        'viewer_url': viewerUrl,
        'notable': notable,
        'image_data': imageData,
        'image_mime_type': imageMimeType,
      };

  factory CedarGameEvent.fromJson(Map<Object?, Object?> json) => CedarGameEvent(
        id: json['id']?.toString() ?? '',
        kind: json['kind']?.toString() ?? 'outcome',
        summary: json['summary']?.toString() ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['created_at'] as num?)?.toInt() ?? 0,
        ),
        action: json['action']?.toString() ?? '',
        contentKinds: (json['content_kinds'] as List?)
                ?.map((item) => item.toString())
                .toList(growable: false) ??
            const <String>[],
        viewerUrl: json['viewer_url']?.toString() ?? '',
        notable: json['notable'] == true,
        imageData: json['image_data']?.toString() ?? '',
        imageMimeType: json['image_mime_type']?.toString() ?? '',
      );
}

class CedarGameSession {
  const CedarGameSession({
    required this.id,
    required this.gameId,
    required this.guide,
    required this.guideComplete,
    required this.mode,
    required this.phase,
    required this.updatedAt,
    this.gameTitle = '',
    this.lastAction = '',
    this.lastOutcome = '',
    this.nextActor = 'companion',
    this.waitingReason = '',
    this.viewerUrl = '',
    this.invitationApproved = false,
    this.events = const <CedarGameEvent>[],
    this.nextActionAt,
  });

  final String id;
  final String gameId;
  final String gameTitle;
  final String guide;
  final bool guideComplete;
  final CedarParticipationMode mode;
  final CedarActivityPhase phase;
  final String lastAction;
  final String lastOutcome;
  final String nextActor;
  final String waitingReason;
  final String viewerUrl;
  final bool invitationApproved;
  final DateTime updatedAt;
  final List<CedarGameEvent> events;
  final DateTime? nextActionAt;

  bool get continuable => phase.continuable && guideComplete;
  bool get companionCanContinue =>
      continuable &&
      phase != CedarActivityPhase.awaitingInvitation &&
      phase != CedarActivityPhase.waitingUser &&
      phase != CedarActivityPhase.paused &&
      (nextActor == 'companion' ||
          nextActor.isEmpty ||
          (nextActor == 'wait' && nextActionAt != null));
  String get displayName => gameTitle.trim().isEmpty ? gameId : gameTitle;

  CedarGameSession copyWith({
    String? gameTitle,
    String? guide,
    bool? guideComplete,
    CedarParticipationMode? mode,
    CedarActivityPhase? phase,
    String? lastAction,
    String? lastOutcome,
    String? nextActor,
    String? waitingReason,
    String? viewerUrl,
    bool? invitationApproved,
    DateTime? updatedAt,
    List<CedarGameEvent>? events,
    DateTime? nextActionAt,
    bool clearNextActionAt = false,
  }) =>
      CedarGameSession(
        id: id,
        gameId: gameId,
        gameTitle: gameTitle ?? this.gameTitle,
        guide: guide ?? this.guide,
        guideComplete: guideComplete ?? this.guideComplete,
        mode: mode ?? this.mode,
        phase: phase ?? this.phase,
        lastAction: lastAction ?? this.lastAction,
        lastOutcome: lastOutcome ?? this.lastOutcome,
        nextActor: nextActor ?? this.nextActor,
        waitingReason: waitingReason ?? this.waitingReason,
        viewerUrl: viewerUrl ?? this.viewerUrl,
        invitationApproved: invitationApproved ?? this.invitationApproved,
        updatedAt: updatedAt ?? this.updatedAt,
        events: events ?? this.events,
        nextActionAt:
            clearNextActionAt ? null : nextActionAt ?? this.nextActionAt,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'game_id': gameId,
        'game_title': gameTitle,
        'guide': guide,
        'guide_complete': guideComplete,
        'mode': mode.key,
        'phase': phase.key,
        'last_action': lastAction,
        'last_outcome': lastOutcome,
        'next_actor': nextActor,
        'waiting_reason': waitingReason,
        'viewer_url': viewerUrl,
        'invitation_approved': invitationApproved,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'next_action_at': nextActionAt?.millisecondsSinceEpoch ?? 0,
        'events': events.map((item) => item.toJson()).toList(growable: false),
      };

  factory CedarGameSession.fromJson(Map<Object?, Object?> json) {
    final nextMillis = (json['next_action_at'] as num?)?.toInt() ?? 0;
    return CedarGameSession(
      id: json['id']?.toString() ?? '',
      gameId: json['game_id']?.toString() ?? '',
      gameTitle: json['game_title']?.toString() ?? '',
      guide: json['guide']?.toString() ?? '',
      guideComplete: json['guide_complete'] == true,
      mode: CedarParticipationMode.fromKey(json['mode']?.toString()),
      phase: CedarActivityPhase.fromKey(json['phase']?.toString()),
      lastAction: json['last_action']?.toString() ?? '',
      lastOutcome: json['last_outcome']?.toString() ?? '',
      nextActor: json['next_actor']?.toString() ?? 'companion',
      waitingReason: json['waiting_reason']?.toString() ?? '',
      viewerUrl: json['viewer_url']?.toString() ?? '',
      invitationApproved: json['invitation_approved'] == true,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updated_at'] as num?)?.toInt() ?? 0,
      ),
      nextActionAt:
          nextMillis <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(nextMillis),
      events: (json['events'] as List?)
              ?.whereType<Map>()
              .map((item) => CedarGameEvent.fromJson(item))
              .toList(growable: false) ??
          const <CedarGameEvent>[],
    );
  }
}

class CedarQueuedSwitch {
  const CedarQueuedSwitch({
    required this.id,
    required this.targetGameId,
    required this.createdAt,
    this.sourceGameId = '',
    this.reason = '',
  });

  final String id;
  final String targetGameId;
  final String sourceGameId;
  final String reason;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'target_game_id': targetGameId,
        'source_game_id': sourceGameId,
        'reason': reason,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory CedarQueuedSwitch.fromJson(Map<Object?, Object?> json) =>
      CedarQueuedSwitch(
        id: json['id']?.toString() ?? '',
        targetGameId: json['target_game_id']?.toString() ?? '',
        sourceGameId: json['source_game_id']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
}

class CedarCrossGameNotice {
  const CedarCrossGameNotice({
    required this.id,
    required this.sourceGameId,
    required this.targetGameId,
    required this.suggestedAction,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String sourceGameId;
  final String targetGameId;
  final String suggestedAction;
  final String summary;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'source_game_id': sourceGameId,
        'target_game_id': targetGameId,
        'suggested_action': suggestedAction,
        'summary': summary,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory CedarCrossGameNotice.fromJson(Map<Object?, Object?> json) =>
      CedarCrossGameNotice(
        id: json['id']?.toString() ?? '',
        sourceGameId: json['source_game_id']?.toString() ?? '',
        targetGameId: json['target_game_id']?.toString() ?? '',
        suggestedAction: json['suggested_action']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
}

class CedarGameReference {
  const CedarGameReference({required this.gameId, required this.action});
  final String gameId;
  final String action;
}

class CedarGameExecution {
  const CedarGameExecution({
    required this.gameId,
    required this.action,
    required this.startedAt,
  });

  final String gameId;
  final String action;
  final DateTime startedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'game_id': gameId,
        'action': action,
        'started_at': startedAt.millisecondsSinceEpoch,
      };

  factory CedarGameExecution.fromJson(Map<Object?, Object?> json) =>
      CedarGameExecution(
        gameId: json['game_id']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['started_at'] as num?)?.toInt() ?? 0,
        ),
      );
}

class CedarToyActivityState {
  const CedarToyActivityState({
    required this.activeGameId,
    required this.sessions,
    required this.updatedAt,
    this.queuedSwitches = const <CedarQueuedSwitch>[],
    this.notices = const <CedarCrossGameNotice>[],
    this.execution,
  });

  final String activeGameId;
  final Map<String, CedarGameSession> sessions;
  final List<CedarQueuedSwitch> queuedSwitches;
  final List<CedarCrossGameNotice> notices;
  final CedarGameExecution? execution;
  final DateTime updatedAt;

  CedarGameSession? get activeSession => sessions[activeGameId];
  bool get hasUserTurnContinuation {
    final session = activeSession;
    if (session == null || !session.continuable) return false;
    return session.phase == CedarActivityPhase.awaitingInvitation ||
        session.phase == CedarActivityPhase.waitingUser ||
        session.mode.requiresInvitation;
  }

  CedarToyActivityState copyWith({
    String? activeGameId,
    Map<String, CedarGameSession>? sessions,
    List<CedarQueuedSwitch>? queuedSwitches,
    List<CedarCrossGameNotice>? notices,
    CedarGameExecution? execution,
    bool clearExecution = false,
    DateTime? updatedAt,
  }) =>
      CedarToyActivityState(
        activeGameId: activeGameId ?? this.activeGameId,
        sessions: sessions ?? this.sessions,
        queuedSwitches: queuedSwitches ?? this.queuedSwitches,
        notices: notices ?? this.notices,
        execution: clearExecution ? null : execution ?? this.execution,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'version': 2,
        'active_game_id': activeGameId,
        'sessions': sessions.values.map((item) => item.toJson()).toList(),
        'queued_switches': queuedSwitches.map((item) => item.toJson()).toList(),
        'notices': notices.map((item) => item.toJson()).toList(),
        'execution': execution?.toJson(),
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory CedarToyActivityState.fromJson(Map<Object?, Object?> json) {
    final sessions = <String, CedarGameSession>{};
    for (final raw in (json['sessions'] as List?)?.whereType<Map>() ?? const []) {
      final session = CedarGameSession.fromJson(raw);
      if (session.gameId.isNotEmpty) sessions[session.gameId] = session;
    }
    final executionRaw = json['execution'];
    return CedarToyActivityState(
      activeGameId: json['active_game_id']?.toString() ?? '',
      sessions: sessions,
      queuedSwitches: (json['queued_switches'] as List?)
              ?.whereType<Map>()
              .map((item) => CedarQueuedSwitch.fromJson(item))
              .where((item) => item.id.isNotEmpty && item.targetGameId.isNotEmpty)
              .toList(growable: false) ??
          const <CedarQueuedSwitch>[],
      notices: (json['notices'] as List?)
              ?.whereType<Map>()
              .map((item) => CedarCrossGameNotice.fromJson(item))
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false) ??
          const <CedarCrossGameNotice>[],
      execution: executionRaw is Map
          ? CedarGameExecution.fromJson(executionRaw)
          : null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class CedarToyActivityStore {
  CedarToyActivityStore(this.db);

  static const sessionSettingKey = 'cedar_toy_activity_session_v1';
  static const stateSettingKey = 'cedar_toy_activity_state_v2';
  static const catalogSettingKey = 'cedar_toy_catalog_v1';
  static const maxGuidePromptChars = 120000;
  static const maxStoredTextChars = 1024 * 1024;
  static const maxEventSummaryChars = 6000;
  static const maxEvents = 24;
  static const maxSessions = 8;
  static const maxNotices = 24;
  static const continuationGap = Duration(minutes: 2);

  final AppDatabase db;

  Future<CedarToyActivityState> loadState() async {
    final raw = await db.getSetting(stateSettingKey) ?? '';
    if (raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          var state = CedarToyActivityState.fromJson(decoded);
          final execution = state.execution;
          if (execution != null &&
              DateTime.now().difference(execution.startedAt) >
                  const Duration(minutes: 5)) {
            state = state.copyWith(clearExecution: true);
            await _saveState(state);
          }
          return state;
        }
      } catch (_) {}
    }
    final legacy = await _loadLegacy();
    final now = DateTime.now();
    final sessions = <String, CedarGameSession>{};
    if (legacy != null) {
      sessions[legacy.gameId] = legacy.companionCanContinue &&
              legacy.nextActionAt == null
          ? legacy.copyWith(nextActionAt: now)
          : legacy;
    }
    var state = CedarToyActivityState(
      activeGameId: legacy?.gameId ?? '',
      sessions: sessions,
      updatedAt: now,
    );
    if (legacy != null) state = _withExtractedNotices(state, legacy);
    await _saveState(state);
    return state;
  }

  Future<CedarGameSession?> _loadLegacy() async {
    final raw = await db.getSetting(sessionSettingKey) ?? '';
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final session = CedarGameSession.fromJson(decoded);
      return session.id.isEmpty || session.gameId.isEmpty ? null : session;
    } catch (_) {
      return null;
    }
  }

  Future<CedarGameSession?> load() async => (await loadState()).activeSession;

  Future<CedarGameSession?> loadSession(String gameId) async =>
      (await loadState()).sessions[gameId];

  Future<bool> hasContinuableSession() async =>
      (await load())?.continuable ?? false;

  Future<Duration?> nextContinuationDelay(DateTime now) async {
    final state = await loadState();
    if (state.queuedSwitches.isNotEmpty) return Duration.zero;
    final session = state.activeSession;
    if (session == null || !session.companionCanContinue) return null;
    final due = session.nextActionAt ?? now;
    return due.isAfter(now) ? due.difference(now) : Duration.zero;
  }

  Future<void> saveCatalog(String catalog) async {
    final clean = catalog.trim();
    if (clean.isEmpty || clean.length > maxStoredTextChars) return;
    await db.setSetting(catalogSettingKey, clean);
  }

  Future<String> loadCatalog() async =>
      (await db.getSetting(catalogSettingKey) ?? '').trim();

  Future<CedarGameSession> recordGuide({
    required String gameId,
    required String guide,
    String gameTitle = '',
  }) async {
    final clean = guide.trim();
    final complete = clean.isNotEmpty && clean.length <= maxGuidePromptChars;
    final now = DateTime.now();
    var state = await loadState();
    final existing = state.sessions[gameId];
    final event = CedarGameEvent(
      id: 'guide-${now.microsecondsSinceEpoch}',
      kind: complete ? 'guide' : 'guide_too_long',
      summary: complete
          ? '已取得完整真实指南，可以按指南盲玩。'
          : '指南已取得，但超过当前完整判断容量，已停止而没有截断盲玩。',
      createdAt: now,
    );
    final session = CedarGameSession(
      id: existing?.id ?? 'cedar-${now.microsecondsSinceEpoch}',
      gameId: gameId,
      gameTitle: gameTitle.trim().isEmpty
          ? existing?.gameTitle ?? ''
          : gameTitle.trim(),
      guide: clean.length <= maxStoredTextChars ? clean : '',
      guideComplete: complete,
      mode: existing?.mode ?? CedarParticipationMode.unknown,
      phase: complete ? CedarActivityPhase.guideReady : CedarActivityPhase.failed,
      lastAction: existing?.lastAction ?? '',
      lastOutcome: existing?.lastOutcome ?? '',
      nextActor: 'companion',
      viewerUrl: existing?.viewerUrl ?? '',
      invitationApproved: existing?.invitationApproved ?? false,
      updatedAt: now,
      nextActionAt: complete ? now : null,
      events: _append(existing?.events ?? const [], event),
    );
    final sessions = Map<String, CedarGameSession>.from(state.sessions)
      ..[gameId] = session;
    state = state.copyWith(
      activeGameId: gameId,
      sessions: _boundedSessions(sessions),
      queuedSwitches: state.queuedSwitches
          .where((item) => item.targetGameId != gameId)
          .toList(growable: false),
      clearExecution: true,
      updatedAt: now,
    );
    await _saveState(state);
    return session;
  }

  Future<CedarQueuedSwitch> queueSwitch({
    required String targetGameId,
    String reason = '',
  }) async {
    var state = await loadState();
    final existing = state.queuedSwitches
        .where((item) => item.targetGameId == targetGameId);
    if (existing.isNotEmpty) return existing.first;
    final now = DateTime.now();
    final item = CedarQueuedSwitch(
      id: 'switch-${now.microsecondsSinceEpoch}',
      targetGameId: targetGameId,
      sourceGameId: state.activeGameId,
      reason: _bounded(reason.trim(), 500),
      createdAt: now,
    );
    final queued = <CedarQueuedSwitch>[...state.queuedSwitches, item];
    state = state.copyWith(
      queuedSwitches: (queued.length <= 8
              ? queued
              : queued.sublist(queued.length - 8))
          .toList(growable: false),
      updatedAt: now,
    );
    await _saveState(state);
    return item;
  }

  Future<void> beginExecution({
    required String gameId,
    required String action,
  }) async {
    final state = await loadState();
    final now = DateTime.now();
    await _saveState(state.copyWith(
      execution: CedarGameExecution(gameId: gameId, action: action, startedAt: now),
      updatedAt: now,
    ));
  }

  Future<void> finishExecution() async {
    final state = await loadState();
    if (state.execution == null) return;
    await _saveState(state.copyWith(
      clearExecution: true,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> deferContinuation({
    required String gameId,
    Duration delay = const Duration(minutes: 5),
  }) async {
    final state = await loadState();
    final session = state.sessions[gameId];
    if (session == null || !session.companionCanContinue) return;
    final now = DateTime.now();
    await _saveState(state.copyWith(
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[gameId] = session.copyWith(
          nextActionAt: now.add(delay),
          updatedAt: now,
        ),
      clearExecution: true,
      updatedAt: now,
    ));
  }

  Future<CedarGameSession> markInvitationRequired({
    required String gameId,
    required CedarParticipationMode mode,
    String reason = '',
  }) async {
    var state = await loadState();
    final existing = state.sessions[gameId];
    if (existing == null) throw StateError('cedar_session_missing');
    final now = DateTime.now();
    final event = CedarGameEvent(
      id: 'invite-${now.microsecondsSinceEpoch}',
      kind: 'invitation',
      summary: reason.trim().isEmpty
          ? '这个游戏需要先邀请你一起玩。'
          : _bounded(reason, maxEventSummaryChars),
      createdAt: now,
      notable: true,
    );
    final next = existing.copyWith(
      mode: mode,
      phase: CedarActivityPhase.awaitingInvitation,
      nextActor: 'user',
      waitingReason: '等待你接受共玩邀请',
      updatedAt: now,
      clearNextActionAt: true,
      events: _append(existing.events, event),
    );
    state = state.copyWith(
      activeGameId: gameId,
      sessions: Map<String, CedarGameSession>.from(state.sessions)..[gameId] = next,
      clearExecution: true,
      updatedAt: now,
    );
    await _saveState(state);
    return next;
  }

  Future<CedarGameSession> recordPlay({
    required String gameId,
    required String action,
    required McpToolOutcome outcome,
    required CedarParticipationMode mode,
    required String nextActor,
    required String shareLevel,
    required bool invitationApproved,
    int resumeAfterSeconds = 0,
  }) async {
    var state = await loadState();
    final existing = state.sessions[gameId];
    if (existing == null) throw StateError('cedar_session_missing');
    final now = DateTime.now();
    final viewerUrl = _viewerUrl(outcome) ?? existing.viewerUrl;
    final normalizedActor = const <String>{
      'companion', 'user', 'shared', 'wait', 'finished',
    }.contains(nextActor)
        ? nextActor
        : 'companion';
    final phase = switch (normalizedActor) {
      'user' || 'shared' => CedarActivityPhase.waitingUser,
      'wait' => CedarActivityPhase.waitingRemote,
      'finished' => CedarActivityPhase.completed,
      _ => CedarActivityPhase.active,
    };
    final fullText = outcome.text.trim();
    final event = CedarGameEvent(
      id: 'play-${now.microsecondsSinceEpoch}',
      kind: outcome.isError ? 'failure' : 'outcome',
      summary: _bounded(fullText.isEmpty ? '远端没有返回可展示的内容。' : fullText,
          maxEventSummaryChars),
      createdAt: now,
      action: action,
      contentKinds: outcome.content
          .map((item) => item.kind.name)
          .toSet()
          .toList(growable: false),
      viewerUrl: viewerUrl,
      notable: shareLevel == 'notable' || shareLevel == 'required',
      imageData: outcome.images.isEmpty ||
              outcome.images.first.data.length > maxStoredTextChars
          ? ''
          : outcome.images.first.data,
      imageMimeType: outcome.images.isEmpty ? '' : outcome.images.first.mimeType,
    );
    final boundedResumeSeconds = resumeAfterSeconds.clamp(0, 3600).toInt();
    final scheduledWait = normalizedActor == 'wait' && boundedResumeSeconds > 0;
    final shouldContinue = !outcome.isError &&
        (normalizedActor == 'companion' || scheduledWait);
    final next = existing.copyWith(
      mode: mode,
      phase: outcome.isError ? CedarActivityPhase.failed : phase,
      lastAction: action,
      lastOutcome: _bounded(fullText, maxGuidePromptChars),
      nextActor: normalizedActor,
      waitingReason: switch (normalizedActor) {
        'user' || 'shared' => '等待你参与下一步',
        'wait' => '等待游戏允许继续',
        'finished' => '本局已经结束',
        _ => '',
      },
      viewerUrl: viewerUrl,
      invitationApproved: invitationApproved || existing.invitationApproved,
      updatedAt: now,
      nextActionAt: shouldContinue
          ? now.add(scheduledWait
              ? Duration(seconds: boundedResumeSeconds)
              : continuationGap)
          : null,
      clearNextActionAt: !shouldContinue,
      events: _append(existing.events, event),
    );
    state = state.copyWith(
      activeGameId: gameId,
      sessions: Map<String, CedarGameSession>.from(state.sessions)..[gameId] = next,
      clearExecution: true,
      updatedAt: now,
    );
    state = _withExtractedNotices(state, next, onlyEvent: event);
    await _saveState(state);
    return next;
  }

  Future<void> pause() async {
    final state = await loadState();
    final existing = state.activeSession;
    if (existing == null || !existing.phase.continuable ||
        existing.phase == CedarActivityPhase.paused) return;
    final now = DateTime.now();
    final next = existing.copyWith(
      phase: CedarActivityPhase.paused,
      waitingReason: '已在本机暂停，进度仍由远端存档保存',
      updatedAt: now,
      clearNextActionAt: true,
    );
    await _saveState(state.copyWith(
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[existing.gameId] = next,
      updatedAt: now,
    ));
  }

  Future<void> resume() async {
    final state = await loadState();
    final existing = state.activeSession;
    if (existing == null || existing.phase != CedarActivityPhase.paused) return;
    final restoredPhase = switch (existing.nextActor) {
      'user' || 'shared' => CedarActivityPhase.waitingUser,
      'wait' => CedarActivityPhase.waitingRemote,
      'finished' => CedarActivityPhase.completed,
      _ when existing.mode.requiresInvitation && !existing.invitationApproved =>
        CedarActivityPhase.awaitingInvitation,
      _ when existing.lastAction.isEmpty => CedarActivityPhase.guideReady,
      _ => CedarActivityPhase.active,
    };
    final now = DateTime.now();
    final next = existing.copyWith(
      phase: restoredPhase,
      waitingReason: switch (restoredPhase) {
        CedarActivityPhase.awaitingInvitation => '等待你同意后再开始',
        CedarActivityPhase.waitingUser => '等待你参与下一步',
        CedarActivityPhase.waitingRemote => '等待游戏允许继续',
        CedarActivityPhase.completed => '本局已经结束',
        _ => '',
      },
      nextActionAt: restoredPhase == CedarActivityPhase.active ? now : null,
      clearNextActionAt: restoredPhase != CedarActivityPhase.active,
      updatedAt: now,
    );
    await _saveState(state.copyWith(
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[existing.gameId] = next,
      updatedAt: now,
    ));
  }

  Future<void> clear() async {
    await db.setSetting(stateSettingKey, '');
    await db.setSetting(sessionSettingKey, '');
  }

  Future<void> save(CedarGameSession session) async {
    final state = await loadState();
    await _saveState(state.copyWith(
      activeGameId: session.gameId,
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[session.gameId] = session,
      updatedAt: DateTime.now(),
    ));
  }

  String promptContext(CedarGameSession session, {CedarToyActivityState? state}) {
    final queued = state?.queuedSwitches.map((item) => item.targetGameId).join(',') ?? '';
    final notices = state?.notices
            .map((item) => '${item.sourceGameId}->${item.targetGameId}:${item.suggestedAction}')
            .join(',') ??
        '';
    final execution = state?.execution;
    return '''
【CEDAR_ACTIVITY_SESSION · REAL LOCAL STATE】
game=${session.gameId}
mode=${session.mode.key}
phase=${session.phase.key}
next_actor=${session.nextActor}
invitation_approved=${session.invitationApproved}
last_action=${session.lastAction}
last_outcome=${session.lastOutcome}
viewer_url=${session.viewerUrl}
queued_switches=$queued
cross_game_notices=$notices
execution=${execution == null ? '' : '${execution.gameId}:${execution.action}'}
【完整真实指南 · 只授权 game=${session.gameId}】
${session.guide}
【END CEDAR_ACTIVITY_SESSION】
'''.trim();
  }

  Future<void> _saveState(CedarToyActivityState state) async {
    await db.setSetting(stateSettingKey, jsonEncode(state.toJson()));
    final active = state.activeSession;
    await db.setSetting(sessionSettingKey,
        active == null ? '' : jsonEncode(active.toJson()));
  }

  CedarToyActivityState _withExtractedNotices(
    CedarToyActivityState state,
    CedarGameSession session, {
    CedarGameEvent? onlyEvent,
  }) {
    final sourceEvents = onlyEvent == null ? session.events : <CedarGameEvent>[onlyEvent];
    final notices = <CedarCrossGameNotice>[...state.notices];
    final known = notices.map((item) => item.id).toSet();
    for (final event in sourceEvents) {
      for (final reference in crossGameReferences(event.summary)) {
        final target = reference.gameId;
        final action = reference.action;
        if (target.isEmpty || target == session.gameId) continue;
        final id = 'cross-${event.id}-$target-$action';
        if (!known.add(id)) continue;
        notices.add(CedarCrossGameNotice(
          id: id,
          sourceGameId: session.gameId,
          targetGameId: target,
          suggestedAction: action,
          summary: _bounded(event.summary, 800),
          createdAt: event.createdAt,
        ));
      }
    }
    return state.copyWith(
      notices: notices.length <= maxNotices
          ? notices
          : notices.sublist(notices.length - maxNotices),
    );
  }

  static List<CedarGameReference> crossGameReferences(String text) => RegExp(
        r'''play\s*\(\s*game\s*=\s*["']([A-Za-z0-9_.:-]{1,80})["']\s*,\s*action\s*=\s*["']([A-Za-z0-9_.:-]{1,80})["']''',
        caseSensitive: false,
      )
          .allMatches(text)
          .map((match) => CedarGameReference(
                gameId: match.group(1) ?? '',
                action: match.group(2) ?? '',
              ))
          .where((item) => item.gameId.isNotEmpty && item.action.isNotEmpty)
          .toList(growable: false);

  static bool catalogMentionsGame(String userText, String catalog) {
    if (!RegExp(r'(玩|来|进|加入|开房|房间|一局|棋|游戏)').hasMatch(userText) ||
        catalog.trim().isEmpty) return false;
    final entries = RegExp(
      r'(?:^|[|：:]\s*)([A-Za-z][A-Za-z0-9_.:-]{1,79})·([^，,·|\n]{2,30})',
      multiLine: true,
    ).allMatches(catalog);
    for (final entry in entries) {
      final id = entry.group(1) ?? '';
      final title = entry.group(2)?.trim() ?? '';
      if ((id.isNotEmpty && userText.toLowerCase().contains(id.toLowerCase())) ||
          (title.isNotEmpty && userText.contains(title))) return true;
    }
    return false;
  }

  static Map<String, CedarGameSession> _boundedSessions(
      Map<String, CedarGameSession> sessions) {
    if (sessions.length <= maxSessions) return sessions;
    final sorted = sessions.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return <String, CedarGameSession>{
      for (final session in sorted.take(maxSessions)) session.gameId: session,
    };
  }

  static List<CedarGameEvent> _append(
      List<CedarGameEvent> existing, CedarGameEvent event) {
    final values = <CedarGameEvent>[
      ...existing.map((item) => item.withoutInlineMedia()),
      event,
    ];
    return values.length <= maxEvents
        ? values
        : values.sublist(values.length - maxEvents);
  }

  static String _bounded(String value, int limit) =>
      value.length <= limit ? value : '${value.substring(0, limit)}…';

  static String? _viewerUrl(McpToolOutcome outcome) {
    final candidates = <String>[
      for (final item in outcome.content)
        if (item.kind == McpContentKind.resourceLink) item.uri,
      if (outcome.structuredContent != null)
        ...RegExp(r'https://[^\s"}]+')
            .allMatches(jsonEncode(outcome.structuredContent))
            .map((match) => match.group(0) ?? ''),
    ];
    for (final raw in candidates) {
      final uri = Uri.tryParse(raw.trim());
      if (uri == null || uri.scheme != 'https') continue;
      if (uri.host == 'toy.cedarstar.org' ||
          uri.host.endsWith('.cedarstar.org')) return uri.toString();
    }
    return null;
  }
}
