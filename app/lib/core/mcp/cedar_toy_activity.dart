import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'cedar_agent_loop_policy.dart';
import 'cedar_game_protocol.dart';
import 'cedar_duel_observer_resolver.dart';
import 'cedar_toy_client.dart';
import 'mcp_protocol.dart';
import 'mcp_turn_state_resolver.dart';

enum CedarParticipationMode {
  unknown('unknown', '待判断'),
  solo('solo', '她自己玩'),
  coPlay('co_play', '和你共玩'),
  multiplayer('multiplayer', '多人游戏'),
  hybrid('hybrid', '混合模式');

  const CedarParticipationMode(this.key, this.label);
  final String key;
  final String label;

  bool get requiresInvitation => this == coPlay || this == multiplayer;
  bool get supportsSharedParticipation =>
      this == coPlay || this == multiplayer || this == hybrid;

  static CedarParticipationMode fromKey(String? value) => values.firstWhere(
        (item) => item.key == value,
        orElse: () => unknown,
      );
}

/// User-selected pace while the Cedar activity window is visibly open.
/// A stale/missing viewer heartbeat always resolves to [leisure], so the
/// faster rates are temporary observation modes rather than durable autonomy
/// settings.
enum CedarViewingPace {
  leisure('leisure', '休闲模式', Duration(minutes: 2)),
  fast('fast', '快速模式', Duration(seconds: 5)),
  spectate('spectate', '观战模式', Duration(seconds: 10));

  const CedarViewingPace(this.key, this.label, this.soloStepGap);
  final String key;
  final String label;
  final Duration soloStepGap;

  bool get isWatching => this != leisure;

  static CedarViewingPace fromKey(String? value) => values.firstWhere(
        (item) => item.key == value,
        orElse: () => leisure,
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
    this.continuationAction = '',
    this.continuationParamsJson = '',
    this.continuationWaitScope = '',
    this.pendingRoomMessage = '',
    this.seenRoomMessageKeys = const <String>[],
    this.ownRoomAliases = const <String>[],
    this.adviceNotes = const <String>[],
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
  final String continuationAction;
  final String continuationParamsJson;
  final String continuationWaitScope;
  final String pendingRoomMessage;
  final List<String> seenRoomMessageKeys;
  final List<String> ownRoomAliases;
  final List<String> adviceNotes;

  bool get continuable => phase.continuable && guideComplete;
  bool get companionCanContinue =>
      continuable &&
      phase != CedarActivityPhase.awaitingInvitation &&
      phase != CedarActivityPhase.waitingUser &&
      phase != CedarActivityPhase.paused &&
      (nextActor == 'companion' ||
          nextActor.isEmpty ||
          (nextActor == 'wait' && nextActionAt != null));
  bool get hasContinuationCall => continuationAction.trim().isNotEmpty;
  bool get hasPendingRoomMessage => pendingRoomMessage.trim().isNotEmpty;
  /// Cedar can legitimately ask the client to wait, but a wait without an
  /// exact follow-up call or a wake-up time has no executable route. Keeping
  /// such a session active forever blocks both this game and every other game.
  bool get isUnroutableRemoteWait =>
      guideComplete &&
      phase == CedarActivityPhase.waitingRemote &&
      nextActor == 'wait' &&
      !hasContinuationCall &&
      nextActionAt == null;
  bool get companionCanObserve =>
      CedarServerContinuationPolicy.canObserve(
        guideComplete: guideComplete,
        phaseContinuable: phase.continuable &&
            phase != CedarActivityPhase.awaitingInvitation,
        paused: phase == CedarActivityPhase.paused,
        hasContinuationCall: hasContinuationCall,
        nextActor: nextActor,
      );
  bool get needsContinuation => companionCanContinue || companionCanObserve;
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
    String? continuationAction,
    String? continuationParamsJson,
    String? continuationWaitScope,
    bool clearContinuation = false,
    String? pendingRoomMessage,
    bool clearPendingRoomMessage = false,
    List<String>? seenRoomMessageKeys,
    List<String>? ownRoomAliases,
    List<String>? adviceNotes,
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
        continuationAction:
            clearContinuation ? '' : continuationAction ?? this.continuationAction,
        continuationParamsJson: clearContinuation
            ? ''
            : continuationParamsJson ?? this.continuationParamsJson,
        continuationWaitScope: clearContinuation
            ? ''
            : continuationWaitScope ?? this.continuationWaitScope,
        pendingRoomMessage: clearPendingRoomMessage
            ? ''
            : pendingRoomMessage ?? this.pendingRoomMessage,
        seenRoomMessageKeys:
            seenRoomMessageKeys ?? this.seenRoomMessageKeys,
        ownRoomAliases: ownRoomAliases ?? this.ownRoomAliases,
        adviceNotes: adviceNotes ?? this.adviceNotes,
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
        'continuation_action': continuationAction,
        'continuation_params_json': continuationParamsJson,
        'continuation_wait_scope': continuationWaitScope,
        'pending_room_message': pendingRoomMessage,
        'seen_room_message_keys': seenRoomMessageKeys,
        'own_room_aliases': ownRoomAliases,
        'advice_notes': adviceNotes,
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
      continuationAction: json['continuation_action']?.toString() ?? '',
      continuationParamsJson:
          json['continuation_params_json']?.toString() ?? '',
      continuationWaitScope:
          json['continuation_wait_scope']?.toString() ?? '',
      pendingRoomMessage: json['pending_room_message']?.toString() ?? '',
      seenRoomMessageKeys: (json['seen_room_message_keys'] as List?)
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const <String>[],
      ownRoomAliases: (json['own_room_aliases'] as List?)
              ?.map((item) => item.toString())
              .toList(growable: false) ??
            const <String>[],
      adviceNotes: (json['advice_notes'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .take(CedarGameAdvicePolicy.maxNotes)
              .toList(growable: false) ??
          const <String>[],
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
    required this.id,
    required this.gameId,
    required this.action,
    required this.startedAt,
  });

  final String id;
  final String gameId;
  final String action;
  final DateTime startedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'game_id': gameId,
        'action': action,
        'started_at': startedAt.millisecondsSinceEpoch,
      };

  factory CedarGameExecution.fromJson(Map<Object?, Object?> json) =>
      CedarGameExecution(
        id: json['id']?.toString() ?? '',
        gameId: json['game_id']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['started_at'] as num?)?.toInt() ?? 0,
        ),
      );
}

class CedarExecutionPreemptedException implements Exception {
  const CedarExecutionPreemptedException([this.reason = 'preempted']);

  final String reason;

  @override
  String toString() => 'cedar_execution_preempted:$reason';
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
    return CedarServerContinuationPolicy.needsUserTurnTools(
      guideReady: session.phase == CedarActivityPhase.guideReady,
      awaitingInvitation:
          session.phase == CedarActivityPhase.awaitingInvitation,
      waitingUser: session.phase == CedarActivityPhase.waitingUser,
      hasContinuationCall: session.hasContinuationCall,
      participationActive: session.mode.requiresInvitation ||
          (session.mode.supportsSharedParticipation &&
              session.invitationApproved),
    );
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
    final rawSessions = json['sessions'];
    if (rawSessions is List) {
      for (final raw in rawSessions) {
        if (raw is! Map) continue;
        final session = CedarGameSession.fromJson(
          raw.cast<Object?, Object?>(),
        );
        if (session.gameId.isNotEmpty) sessions[session.gameId] = session;
      }
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
  static const playProtocolSettingKey = 'cedar_toy_play_protocol_v2';
  static const realtimeDiagnosticsSettingKey =
      'cedar_toy_realtime_diagnostics_v1';
  static const viewingPaceSettingKey = 'cedar_toy_viewing_pace_v1';
  static const viewerHeartbeatSettingKey = 'cedar_toy_viewer_heartbeat_at_v1';
  static const pendingDirectSharesSettingKey =
      'cedar_toy_pending_direct_shares_v1';
  static const executionFenceSettingKey =
      'cedar_toy_execution_fence_v1';
  static const switchPausedGameSettingKey =
      'cedar_toy_switch_paused_game_v1';
  static const maxGuidePromptChars = 120000;
  static const maxStoredTextChars = 1024 * 1024;
  static const maxEventSummaryChars = 6000;
  static const maxEvents = 24;
  static const maxSessions = 8;
  static const maxNotices = 24;
  static const continuationGap = Duration(minutes: 2);
  static const realtimeContinuationGap = Duration(seconds: 1);
  // The user may leave Flutter in the background while watching Cedar in the
  // browser. Closing the activity window resets immediately; this long TTL is
  // only a crash/stale-state fallback, not the normal close mechanism.
  static const viewerHeartbeatTtl = Duration(hours: 6);

  final AppDatabase db;
  static const Uuid _uuid = Uuid();

  Future<void> beginViewing() async {
    final now = DateTime.now();
    await db.setSetting(viewingPaceSettingKey, CedarViewingPace.leisure.key);
    await db.setSetting(
      viewerHeartbeatSettingKey,
      now.millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> touchViewer() => db.setSetting(
        viewerHeartbeatSettingKey,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );

  Future<void> endViewing() async {
    await db.setSetting(viewingPaceSettingKey, CedarViewingPace.leisure.key);
    await db.setSetting(viewerHeartbeatSettingKey, '0');
  }

  Future<CedarViewingPace> currentViewingPace({DateTime? now}) async {
    final at = int.tryParse(await db.getSetting(viewerHeartbeatSettingKey) ?? '');
    if (at == null || at <= 0) return CedarViewingPace.leisure;
    final current = now ?? DateTime.now();
    if (current.difference(DateTime.fromMillisecondsSinceEpoch(at)) >
        viewerHeartbeatTtl) {
      return CedarViewingPace.leisure;
    }
    return CedarViewingPace.fromKey(
      await db.getSetting(viewingPaceSettingKey),
    );
  }

  Future<void> setViewingPace(CedarViewingPace pace) async {
    final now = DateTime.now();
    await db.setSetting(viewingPaceSettingKey, pace.key);
    await db.setSetting(
      viewerHeartbeatSettingKey,
      now.millisecondsSinceEpoch.toString(),
    );
    if (!pace.isWatching) return;
    final state = await loadState();
    final session = state.activeSession;
    if (session == null || !session.needsContinuation) return;
    final fasterDue = now.add(pace.soloStepGap);
    final existingDue = session.nextActionAt;
    if (existingDue != null && !existingDue.isAfter(fasterDue)) return;
    await _saveState(state.copyWith(
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[session.gameId] = session.copyWith(
          nextActionAt: fasterDue,
          updatedAt: now,
        ),
      updatedAt: now,
    ));
  }

  Future<void> queueDirectShare(String thoughtId) async {
    final clean = thoughtId.trim();
    if (clean.isEmpty) return;
    final queue = await pendingDirectShares();
    if (!queue.contains(clean)) queue.add(clean);
    final bounded = queue.length <= 8 ? queue : queue.sublist(queue.length - 8);
    await db.setSetting(pendingDirectSharesSettingKey, jsonEncode(bounded));
  }

  Future<List<String>> pendingDirectShares() async {
    final raw = await db.getSetting(pendingDirectSharesSettingKey) ?? '';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: true);
      }
    } catch (_) {}
    return <String>[];
  }

  Future<void> removeDirectShare(String thoughtId) async {
    final queue = await pendingDirectShares();
    queue.removeWhere((item) => item == thoughtId);
    await db.setSetting(pendingDirectSharesSettingKey, jsonEncode(queue));
  }

  Future<CedarToyActivityState> loadState() async {
    final raw = await db.getSetting(stateSettingKey) ?? '';
    if (raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          var state = CedarToyActivityState.fromJson(decoded);
          final guideRepaired = _repairPlayerGuides(state);
          if (guideRepaired != null) {
            state = guideRepaired;
            await _saveState(state);
          }
          final repaired = _repairRealtimeState(state);
          if (repaired != null) {
            state = repaired;
            await _saveState(state);
          }
          final titleRepaired = _repairCatalogTitles(
            state,
            (await db.getSetting(catalogSettingKey) ?? '').trim(),
          );
          if (titleRepaired != null) {
            state = titleRepaired;
            await _saveState(state);
          }
          final execution = state.execution;
          final executionLeaseHeld = execution != null &&
              await db.isLocalLeaseHeld('cedar_toy_action_lease_until');
          if (execution != null &&
              (execution.id.isEmpty ||
                  (await db.getSetting(executionFenceSettingKey)) !=
                      execution.id ||
                  (!executionLeaseHeld &&
                      DateTime.now().difference(execution.startedAt) >
                          const Duration(minutes: 2)))) {
            state = state.copyWith(clearExecution: true);
            await db.setSettingsAtomically(<String, String>{
              ..._stateSettingValues(state),
              executionFenceSettingKey: 'cancel-stale-${_uuid.v4()}',
            });
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
    if (session == null || !session.needsContinuation) return null;
    final due = session.nextActionAt ?? now;
    return due.isAfter(now) ? due.difference(now) : Duration.zero;
  }

  Future<void> saveCatalog(
    String catalog, {
    String executionId = '',
  }) async {
    final clean = catalog.trim();
    if (clean.isEmpty || clean.length > maxStoredTextChars) return;
    final catalogSaved = executionId.isEmpty
        ? await db.setSettingsAtomically(<String, String>{
            catalogSettingKey: clean,
          })
        : await db.setSettingsAtomically(
            <String, String>{catalogSettingKey: clean},
            guardKey: executionFenceSettingKey,
            expectedGuardValue: executionId,
          );
    if (!catalogSaved) {
      throw const CedarExecutionPreemptedException('catalog_fenced');
    }
    final state = await loadState();
    var changed = false;
    final sessions = Map<String, CedarGameSession>.from(state.sessions);
    for (final entry in state.sessions.entries) {
      final title = CedarCatalogParser.titleFor(clean, entry.key);
      if (title.isEmpty || entry.value.gameTitle == title) continue;
      sessions[entry.key] = entry.value.copyWith(gameTitle: title);
      changed = true;
    }
    if (changed) {
      final saved = await _saveState(state.copyWith(
        sessions: sessions,
        updatedAt: DateTime.now(),
      ), executionId: executionId);
      if (!saved && executionId.isNotEmpty) {
        throw const CedarExecutionPreemptedException('catalog_fenced');
      }
    }
  }

  Future<void> savePlayProtocol(String protocol) async {
    final clean = CedarToyClient.playerSafeGuide(protocol).trim();
    if (clean.isEmpty || clean.length > 60 * 1024) return;
    await db.setSetting(playProtocolSettingKey, clean);
  }

  Future<String> loadPlayProtocol() async =>
      (await db.getSetting(playProtocolSettingKey) ?? '').trim();

  Future<String> loadCatalog() async =>
      (await db.getSetting(catalogSettingKey) ?? '').trim();

  Future<CedarGameSession> recordGuide({
    required String gameId,
    required String guide,
    String gameTitle = '',
    String executionId = '',
  }) async {
    final clean = guide.trim();
    final complete = clean.isNotEmpty && clean.length <= maxGuidePromptChars;
    final now = DateTime.now();
    var state = await loadState();
    final existing = state.sessions[gameId];
    final catalogTitle = CedarCatalogParser.titleFor(
      await loadCatalog(),
      gameId,
    );
    final event = CedarGameEvent(
      id: 'guide-${now.microsecondsSinceEpoch}',
      kind: complete ? 'guide' : 'guide_too_long',
      summary: complete
          ? '已取得完整真实指南，可以按指南盲玩。'
          : '指南已取得，但超过当前完整判断容量，已停止而没有截断盲玩。',
      createdAt: now,
    );
    final resolvedTitle = catalogTitle.isNotEmpty
        ? catalogTitle
        : gameTitle.trim().isNotEmpty
            ? gameTitle.trim()
            : existing?.gameTitle ?? '';
    // Refreshing a guide is metadata, not a new game transition. Preserve an
    // existing room's actor, next_call, messages, aliases and pause state; the
    // previous implementation silently reset all of them to guideReady.
    final session = existing == null
        ? CedarGameSession(
            id: 'cedar-${now.microsecondsSinceEpoch}',
            gameId: gameId,
            gameTitle: resolvedTitle,
            guide: clean.length <= maxStoredTextChars ? clean : '',
            guideComplete: complete,
            mode: CedarParticipationMode.unknown,
            phase: complete
                ? CedarActivityPhase.guideReady
                : CedarActivityPhase.failed,
            updatedAt: now,
            nextActionAt: complete ? now : null,
            events: _append(const <CedarGameEvent>[], event),
          )
        : existing.copyWith(
            gameTitle: resolvedTitle,
            guide: complete ? clean : existing.guide,
            guideComplete: complete ? true : existing.guideComplete,
            phase: existing.phase == CedarActivityPhase.completed ||
                    existing.phase == CedarActivityPhase.failed
                ? (complete
                    ? CedarActivityPhase.guideReady
                    : CedarActivityPhase.failed)
                : existing.phase,
            updatedAt: now,
            events: _append(existing.events, event),
            nextActionAt: existing.phase == CedarActivityPhase.completed ||
                    existing.phase == CedarActivityPhase.failed
                ? (complete ? now : null)
                : existing.nextActionAt,
            clearNextActionAt:
                !complete && (existing.phase == CedarActivityPhase.completed ||
                    existing.phase == CedarActivityPhase.failed),
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
    final saved = await _saveState(state, executionId: executionId);
    if (!saved && executionId.isNotEmpty) {
      throw const CedarExecutionPreemptedException('guide_fenced');
    }
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

  Future<String> beginExecution({
    required String gameId,
    required String action,
  }) async {
    final state = await loadState();
    final now = DateTime.now();
    final executionId = _uuid.v4();
    final next = state.copyWith(
      execution: CedarGameExecution(
        id: executionId,
        gameId: gameId,
        action: action,
        startedAt: now,
      ),
      updatedAt: now,
    );
    await db.setSettingsAtomically(<String, String>{
      ..._stateSettingValues(next),
      executionFenceSettingKey: executionId,
    });
    return executionId;
  }

  Future<void> finishExecution({required String executionId}) async {
    final state = await loadState();
    if (state.execution?.id != executionId) return;
    await _saveState(state.copyWith(
      clearExecution: true,
      updatedAt: DateTime.now(),
    ), executionId: executionId);
  }

  Future<void> updateExecutionAction({
    required String executionId,
    required String action,
  }) async {
    final state = await loadState();
    final execution = state.execution;
    if (execution == null || execution.id != executionId) {
      throw const CedarExecutionPreemptedException('execution_fenced');
    }
    final saved = await _saveState(
      state.copyWith(
        execution: CedarGameExecution(
          id: execution.id,
          gameId: execution.gameId,
          action: action,
          startedAt: execution.startedAt,
        ),
        updatedAt: DateTime.now(),
      ),
      executionId: executionId,
    );
    if (!saved) {
      throw const CedarExecutionPreemptedException('execution_fenced');
    }
  }

  Future<bool> isExecutionCurrent(String executionId) async {
    return executionId.isNotEmpty &&
        (await db.getSetting(executionFenceSettingKey)) == executionId;
  }

  Future<void> cancelExecution({String reason = 'cancelled'}) async {
    final state = await loadState();
    final now = DateTime.now();
    await db.setSettingsAtomically(<String, String>{
      ..._stateSettingValues(state.copyWith(
        clearExecution: true,
        updatedAt: now,
      )),
      executionFenceSettingKey: 'cancel-$reason-${_uuid.v4()}',
    });
  }

  Future<void> deferContinuation({
    required String gameId,
    Duration delay = const Duration(seconds: 15),
    String executionId = '',
  }) async {
    final state = await loadState();
    final session = state.sessions[gameId];
    if (session == null || !session.needsContinuation) return;
    final now = DateTime.now();
    final saved = await _saveState(state.copyWith(
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[gameId] = session.copyWith(
          nextActionAt: now.add(delay),
          updatedAt: now,
        ),
      clearExecution: true,
      updatedAt: now,
    ), executionId: executionId);
    if (!saved && executionId.isNotEmpty) {
      throw const CedarExecutionPreemptedException('defer_fenced');
    }
  }

  Future<void> markWriteOutcomeUncertain({
    required String gameId,
    required String action,
    Map<String, Object?> params = const <String, Object?>{},
    String executionId = '',
  }) async {
    final state = await loadState();
    final session = state.sessions[gameId];
    if (session == null) return;
    final now = DateTime.now();
    McpContinuationCall? reconciliation;
    if (gameId == 'duel') {
      final roomId = params['room_id']?.toString().trim() ?? '';
      reconciliation = roomId.isEmpty
          ? const McpContinuationCall(
              game: 'duel',
              action: 'rooms',
              params: <String, Object?>{},
              waitScope: 'write_reconcile_once',
            )
          : McpContinuationCall(
              game: 'duel',
              action: 'state',
              params: <String, Object?>{
                'room_id': roomId,
                'full_state': true,
                'wait': false,
              },
              waitScope: 'write_reconcile_once',
            );
    } else if (session.hasContinuationCall) {
      reconciliation = _savedContinuation(session);
    }
    final canSynchronize = reconciliation != null;
    final event = CedarGameEvent(
      id: 'sync-${now.microsecondsSinceEpoch}',
      kind: 'write_outcome_uncertain',
      summary: canSynchronize
          ? '本机未收到这次操作的完整回包，先按 Cedar 已给的查询指令同步真实远端状态，不盲目重放。'
          : '本机未收到这次操作的完整回包，暂缓后继续。',
      createdAt: now,
      action: action,
    );
    final next = session.copyWith(
      phase: canSynchronize
          ? CedarActivityPhase.waitingRemote
          : session.phase,
      nextActor: canSynchronize ? 'wait' : session.nextActor,
      waitingReason: canSynchronize
          ? '正在从 Cedar 同步已提交动作的真实结果'
          : '等待重新读取真实状态',
      nextActionAt: now.add(
        canSynchronize
            ? realtimeContinuationGap
            : const Duration(seconds: 15),
      ),
      updatedAt: now,
      continuationAction: reconciliation?.action,
      continuationParamsJson:
          reconciliation == null ? null : jsonEncode(reconciliation.params),
      continuationWaitScope: reconciliation?.waitScope,
      clearContinuation: reconciliation == null,
      events: _append(session.events, event),
    );
    final saved = await _saveState(state.copyWith(
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[gameId] = next,
      clearExecution: true,
      updatedAt: now,
    ), executionId: executionId);
    if (!saved && executionId.isNotEmpty) {
      throw const CedarExecutionPreemptedException('uncertain_fenced');
    }
  }

  Future<CedarGameSession> markInvitationRequired({
    required String gameId,
    required CedarParticipationMode mode,
    String reason = '',
    String executionId = '',
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
    final saved = await _saveState(state, executionId: executionId);
    if (!saved && executionId.isNotEmpty) {
      throw const CedarExecutionPreemptedException('invitation_fenced');
    }
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
    bool roomMessageSent = false,
    String executionId = '',
  }) async {
    var state = await loadState();
    final existing = state.sessions[gameId];
    if (existing == null) throw StateError('cedar_session_missing');
    final now = DateTime.now();
    final viewerUrl = _viewerUrl(outcome) ?? existing.viewerUrl;
    final rawContinuation = _continuationCall(outcome);
    final returnedContinuation = rawContinuation == null ||
            (rawContinuation.game.isNotEmpty &&
                rawContinuation.game != gameId)
        ? null
        : rawContinuation;
    final roomBatch = _roomMessages(
      outcome,
      knownOwnAliases: existing.ownRoomAliases,
    );
    final seenRoomMessageKeys = <String>{
      ...existing.seenRoomMessageKeys,
      ...roomBatch.messages.map((item) => item.fingerprint),
    }.toList(growable: false);
    final previouslySeen = existing.seenRoomMessageKeys.toSet();
    final newRemoteMessages = roomBatch.messages
        .where((item) =>
            !item.fromCompanion && !previouslySeen.contains(item.fingerprint))
        .toList(growable: false);
    var pendingRoomMessage =
        roomMessageSent ? '' : existing.pendingRoomMessage;
    if (newRemoteMessages.isNotEmpty) {
      final latest = newRemoteMessages.last;
      pendingRoomMessage = latest.author.isEmpty
          ? latest.message
          : '${latest.author}：${latest.message}';
    }
    final normalizedActor = const <String>{
      'companion', 'user', 'shared', 'wait', 'finished',
    }.contains(nextActor)
        ? nextActor
        : 'companion';
    // A wait continuation has current-request scope. If a successful poll
    // returns a fresh snapshot without another next_call, renew the same
    // already-authorized read action instead of silently dropping the room
    // observer. A different write action never inherits it.
    final derivedDuelObserver = gameId == 'duel' &&
            returnedContinuation == null &&
            const <String>{'user', 'shared', 'wait'}.contains(normalizedActor)
        ? (_duelObserver(outcome))
        : null;
    final renewableServerWait =
        existing.continuationWaitScope == 'current_request_only' &&
            action == existing.continuationAction &&
            const <String>{'user', 'shared', 'wait'}.contains(normalizedActor);
    final continuation = returnedContinuation ??
        derivedDuelObserver ??
        (!outcome.isError && renewableServerWait
            ? _savedContinuation(existing)
            : null);
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
    final scheduledWait =
        normalizedActor != 'finished' && boundedResumeSeconds > 0;
    final shouldContinue = !outcome.isError &&
        (normalizedActor == 'companion' ||
            scheduledWait ||
            continuation != null ||
            pendingRoomMessage.isNotEmpty);
    final effectiveInvitationApproved =
        invitationApproved || existing.invitationApproved;
    final realtime = CedarServerContinuationPolicy.usesRealtimePace(
      hasContinuationCall: continuation != null,
      hasPendingRoomMessage: pendingRoomMessage.isNotEmpty,
      companionTurn: normalizedActor == 'companion' &&
          (mode.supportsSharedParticipation ||
              existing.hasContinuationCall ||
              existing.ownRoomAliases.isNotEmpty),
    );
    final viewingPace = await currentViewingPace(now: now);
    final ordinaryRetryGap = mode.supportsSharedParticipation &&
            effectiveInvitationApproved
        ? realtimeContinuationGap
        : viewingPace.soloStepGap;
    final next = existing.copyWith(
      mode: mode,
      // An explicit MCP error means this action did not succeed; it is a
      // recoverable service result, not proof that the durable game ended.
      phase: outcome.isError ? existing.phase : phase,
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
      invitationApproved: effectiveInvitationApproved,
      updatedAt: now,
      nextActionAt: outcome.isError
          ? now.add(ordinaryRetryGap)
          : shouldContinue
          ? now.add(scheduledWait
              ? Duration(seconds: boundedResumeSeconds)
              : realtime
                  ? realtimeContinuationGap
                  : viewingPace.soloStepGap)
          : null,
      clearNextActionAt: !outcome.isError && !shouldContinue,
      continuationAction: continuation?.action,
      continuationParamsJson:
          continuation == null ? null : jsonEncode(continuation.params),
      continuationWaitScope: continuation?.waitScope,
      clearContinuation: continuation == null,
      pendingRoomMessage: pendingRoomMessage,
      clearPendingRoomMessage: pendingRoomMessage.isEmpty,
      seenRoomMessageKeys: seenRoomMessageKeys.length <= 64
          ? seenRoomMessageKeys
          : seenRoomMessageKeys.sublist(seenRoomMessageKeys.length - 64),
      ownRoomAliases: roomBatch.ownAliases.length <= 24
          ? roomBatch.ownAliases.toList(growable: false)
          : roomBatch.ownAliases.skip(roomBatch.ownAliases.length - 24).toList(
                growable: false,
              ),
      events: _append(existing.events, event),
    );
    // Enforce the invariant at the write boundary as well as when recovering
    // historical state. A successful play that says only "wait" but supplies
    // no next_call and no resume time must not become the permanent active
    // game. Keep its remote progress as a resumable parked session.
    final storedNext = next.isUnroutableRemoteWait
        ? next.copyWith(
            phase: CedarActivityPhase.paused,
            waitingReason:
                '服务端没有提供下一调用或唤醒时间，已暂存远端进度并释放当前游戏',
            updatedAt: now,
          )
        : next;
    state = state.copyWith(
      activeGameId: next.isUnroutableRemoteWait ? '' : gameId,
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[gameId] = storedNext,
      clearExecution: true,
      updatedAt: now,
    );
    state = _withExtractedNotices(state, storedNext, onlyEvent: event);
    final saved = await _saveState(state, executionId: executionId);
    if (!saved && executionId.isNotEmpty) {
      throw const CedarExecutionPreemptedException('play_result_fenced');
    }
    return storedNext;
  }

  Future<CedarGameSession> recordPlatformAction({
    required String gameId,
    required String action,
    required McpToolOutcome outcome,
    String executionId = '',
  }) async {
    final state = await loadState();
    final existing = state.sessions[gameId];
    if (existing == null) throw StateError('cedar_session_missing');
    final now = DateTime.now();
    final text = outcome.text.trim();
    final event = CedarGameEvent(
      id: 'platform-${now.microsecondsSinceEpoch}',
      kind: outcome.isError ? 'platform_failure' : 'platform_action',
      summary: _bounded(
        text.isEmpty ? 'Cedar 平台没有返回可展示的内容。' : text,
        maxEventSummaryChars,
      ),
      createdAt: now,
      action: action,
      notable: outcome.isError,
    );
    final next = existing.copyWith(
      updatedAt: now,
      events: _append(existing.events, event),
      nextActionAt: existing.needsContinuation
          ? now.add(outcome.isError
              ? const Duration(minutes: 2)
              : const Duration(seconds: 1))
          : existing.nextActionAt,
    );
    final saved = await _saveState(state.copyWith(
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[gameId] = next,
      clearExecution: true,
      updatedAt: now,
    ), executionId: executionId);
    if (!saved && executionId.isNotEmpty) {
      throw const CedarExecutionPreemptedException('platform_result_fenced');
    }
    return next;
  }

  Future<void> pause() async {
    final state = await loadState();
    final existing = state.activeSession;
    if (existing == null || !existing.phase.continuable) {
      if (state.execution != null) await cancelExecution(reason: 'pause');
      return;
    }
    if (existing.phase == CedarActivityPhase.paused) {
      await cancelExecution(reason: 'pause');
      return;
    }
    final now = DateTime.now();
    final next = existing.copyWith(
      phase: CedarActivityPhase.paused,
      waitingReason: '已在本机暂停，进度仍由远端存档保存',
      updatedAt: now,
      clearNextActionAt: true,
    );
    final paused = state.copyWith(
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[existing.gameId] = next,
      clearExecution: true,
      updatedAt: now,
    );
    await db.setSettingsAtomically(<String, String>{
      ..._stateSettingValues(paused),
      executionFenceSettingKey: 'cancel-pause-${_uuid.v4()}',
    });
  }

  Future<void> suspendForSwitch() async {
    final state = await loadState();
    final session = state.activeSession;
    if (session == null || !session.phase.continuable) {
      await cancelExecution(reason: 'switch_off');
      return;
    }
    final shouldRemember = session.phase != CedarActivityPhase.paused;
    final rememberedGame =
        (await db.getSetting(switchPausedGameSettingKey) ?? '').trim();
    final now = DateTime.now();
    final next = session.copyWith(
      phase: CedarActivityPhase.paused,
      waitingReason: '游戏厅开关已关闭，远端存档保留',
      clearNextActionAt: true,
      updatedAt: now,
    );
    await db.setSettingsAtomically(<String, String>{
      ..._stateSettingValues(state.copyWith(
        sessions: Map<String, CedarGameSession>.from(state.sessions)
          ..[session.gameId] = next,
        clearExecution: true,
        updatedAt: now,
      )),
      executionFenceSettingKey: 'cancel-switch-${_uuid.v4()}',
      switchPausedGameSettingKey:
          shouldRemember ? session.gameId : rememberedGame,
    });
  }

  Future<void> resumeAfterSwitchIfNeeded() async {
    if ((await db.getSetting('cedar_toy_enabled')) == '0' ||
        (await db.getSetting('cedar_toy_autonomy_enabled')) == '0') return;
    final gameId =
        (await db.getSetting(switchPausedGameSettingKey) ?? '').trim();
    if (gameId.isEmpty) return;
    await db.setSetting(switchPausedGameSettingKey, '');
    await resumeGame(gameId);
  }

  Future<void> pauseAndRelease() async {
    await pause();
    final state = await loadState();
    if (state.activeGameId.isEmpty) return;
    await _saveState(state.copyWith(
      activeGameId: '',
      updatedAt: DateTime.now(),
    ));
  }

  /// Parks a server wait that supplied neither `next_call` nor a resume time.
  /// The remote save remains resumable, while the empty active slot allows the
  /// Agent to choose another game instead of deadlocking the whole arcade.
  Future<bool> parkUnroutableRemoteWait() async {
    final state = await loadState();
    final session = state.activeSession;
    if (session == null || !session.isUnroutableRemoteWait) return false;
    final now = DateTime.now();
    final parked = session.copyWith(
      phase: CedarActivityPhase.paused,
      waitingReason: '服务端没有提供下一调用或唤醒时间，已暂存远端进度并释放当前游戏',
      clearNextActionAt: true,
      updatedAt: now,
    );
    await db.setSettingsAtomically(<String, String>{
      ..._stateSettingValues(state.copyWith(
        activeGameId: '',
        sessions: Map<String, CedarGameSession>.from(state.sessions)
          ..[session.gameId] = parked,
        clearExecution: true,
        updatedAt: now,
      )),
      executionFenceSettingKey: 'park-unroutable-wait-${_uuid.v4()}',
    });
    return true;
  }

  Future<void> resumeGame([String gameId = '']) async {
    var state = await loadState();
    var targetId = gameId.trim().isEmpty ? state.activeGameId : gameId.trim();
    if (targetId.isEmpty) {
      final paused = state.sessions.values
          .where((item) => item.phase == CedarActivityPhase.paused)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (paused.isNotEmpty) targetId = paused.first.gameId;
    }
    final target = state.sessions[targetId];
    if (target == null || !target.phase.continuable) return;
    if (state.activeGameId != targetId) {
      state = state.copyWith(
        activeGameId: targetId,
        updatedAt: DateTime.now(),
      );
      await _saveState(state);
    }
    if (target.phase == CedarActivityPhase.paused) await resume();
  }

  Future<void> rememberUserAdvice(String text) async {
    if (!CedarGameAdvicePolicy.isLikelyAdvice(text)) return;
    final state = await loadState();
    final session = state.activeSession;
    if (session == null || !session.continuable) return;
    final note = CedarGameAdvicePolicy.bounded(text);
    final values = <String>[
      ...session.adviceNotes.where((item) => item != note),
      note,
    ];
    final bounded = values.length <= CedarGameAdvicePolicy.maxNotes
        ? values
        : values.sublist(values.length - CedarGameAdvicePolicy.maxNotes);
    final now = DateTime.now();
    await _saveState(state.copyWith(
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[session.gameId] = session.copyWith(
          adviceNotes: bounded,
          updatedAt: now,
        ),
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
      nextActionAt: restoredPhase == CedarActivityPhase.active ||
              (existing.mode.supportsSharedParticipation &&
                  existing.invitationApproved &&
                  existing.hasContinuationCall &&
                  const <CedarActivityPhase>{
                    CedarActivityPhase.waitingUser,
                    CedarActivityPhase.waitingRemote,
                  }.contains(restoredPhase))
          ? now
          : null,
      clearNextActionAt: restoredPhase != CedarActivityPhase.active &&
          !(existing.mode.supportsSharedParticipation &&
              existing.invitationApproved &&
              existing.hasContinuationCall &&
              const <CedarActivityPhase>{
                CedarActivityPhase.waitingUser,
                CedarActivityPhase.waitingRemote,
              }.contains(restoredPhase)),
      updatedAt: now,
    );
    await _saveState(state.copyWith(
      sessions: Map<String, CedarGameSession>.from(state.sessions)
        ..[existing.gameId] = next,
      updatedAt: now,
    ));
  }

  Future<void> clear() async {
    await db.setSettingsAtomically(<String, String>{
      stateSettingKey: '',
      sessionSettingKey: '',
      executionFenceSettingKey: 'cancel-clear-${_uuid.v4()}',
      realtimeDiagnosticsSettingKey: jsonEncode(const <String, Object?>{
        'activeSession': false,
        'roomMessageBodiesIncluded': false,
        'continuationParamsIncluded': false,
        'roomIdentityIncluded': false,
      }),
    });
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

  String promptContext(
    CedarGameSession session, {
    CedarToyActivityState? state,
    String playProtocol = '',
  }) {
    final queued = state?.queuedSwitches.map((item) => item.targetGameId).join(',') ?? '';
    final notices = state?.notices
            .map((item) => '${item.sourceGameId}->${item.targetGameId}:${item.suggestedAction}')
            .join(',') ??
        '';
    final execution = state?.execution;
    var latestPlatformEvent = '';
    for (final event in session.events.reversed) {
      if (!event.kind.startsWith('platform_')) continue;
      latestPlatformEvent = '${event.action}:${event.summary}';
      break;
    }
    return '''
【CEDAR_ACTIVITY_SESSION · REAL LOCAL STATE】
game=${session.gameId}
mode=${session.mode.key}
phase=${session.phase.key}
next_actor=${session.nextActor}
invitation_approved=${session.invitationApproved}
continuation_action=${session.continuationAction}
continuation_params=${session.continuationParamsJson}
pending_room_message=${session.pendingRoomMessage}
recent_user_game_advice=${session.adviceNotes.join(' | ')}
latest_platform_event=$latestPlatformEvent
last_action=${session.lastAction}
last_outcome=${session.lastOutcome}
viewer_url=${session.viewerUrl}
queued_switches=$queued
cross_game_notices=$notices
execution=${execution == null ? '' : '${execution.gameId}:${execution.action}'}
【完整真实指南 · 只授权 game=${session.gameId}】
${session.guide}
${playProtocol.trim().isEmpty ? '' : '【Cedar 实时玩家操作 schema】\n${playProtocol.trim()}'}
${CedarPlayerProtocolContract.actionSignaturesFor(session.gameId)}
【END CEDAR_ACTIVITY_SESSION】
'''.trim();
  }

  Future<bool> _saveState(
    CedarToyActivityState state, {
    String executionId = '',
  }) async =>
      db.setSettingsAtomically(
        _stateSettingValues(state),
        guardKey: executionId.isEmpty ? null : executionFenceSettingKey,
        expectedGuardValue: executionId,
      );

  Map<String, String> _stateSettingValues(CedarToyActivityState state) {
    final active = state.activeSession;
    // Keep diagnostics useful without copying room ids, continuation params,
    // outcomes, or message bodies into the redacted report path.
    return <String, String>{
      stateSettingKey: jsonEncode(state.toJson()),
      sessionSettingKey: active == null ? '' : jsonEncode(active.toJson()),
      realtimeDiagnosticsSettingKey: jsonEncode(<String, Object?>{
        'activeSession': active != null,
        'phase': active?.phase.key ?? 'none',
        'mode': active?.mode.key ?? 'none',
        'nextActor': active?.nextActor ?? 'none',
        'lastAction': active?.lastAction ?? 'none',
        'continuationPending': active?.hasContinuationCall ?? false,
        'continuationIsLongPoll':
            active != null && active.continuationWaitScope.trim().isNotEmpty,
        'pendingRoomMessage': active?.hasPendingRoomMessage ?? false,
        'seenRoomMessageCount': active?.seenRoomMessageKeys.length ?? 0,
        'ownAliasCount': active?.ownRoomAliases.length ?? 0,
        'roomMessageBodiesIncluded': false,
        'continuationParamsIncluded': false,
        'roomIdentityIncluded': false,
        'executionActive': state.execution != null,
        'executionAgeMs': state.execution == null
            ? 0
            : DateTime.now().difference(state.execution!.startedAt).inMilliseconds,
      }),
    };
  }

  CedarToyActivityState? _repairRealtimeState(CedarToyActivityState state) {
    var changed = false;
    final now = DateTime.now();
    final sessions = Map<String, CedarGameSession>.from(state.sessions);
    for (final entry in state.sessions.entries) {
      final session = entry.value;
      final actor = McpTurnStateResolver.resolve(session.lastOutcome);
      if (session.mode == CedarParticipationMode.solo &&
          session.continuable &&
          session.phase != CedarActivityPhase.paused &&
          actor == null &&
          const <String>{'user', 'shared'}.contains(session.nextActor)) {
        // Repair the historical local classifier bug. In a solo activity the
        // companion remains the player unless Cedar supplied an explicit
        // structured actor/wait/terminal fact.
        changed = true;
        sessions[entry.key] = session.copyWith(
          nextActor: 'companion',
          phase: CedarActivityPhase.active,
          waitingReason: '',
          nextActionAt: now,
          updatedAt: now,
        );
        continue;
      }
      if (!session.mode.supportsSharedParticipation ||
          !session.invitationApproved ||
          !session.continuable ||
          session.phase == CedarActivityPhase.paused ||
          session.lastOutcome.trim().isEmpty) {
        continue;
      }
      final rawContinuation = McpContinuationCallResolver.resolve(
        session.lastOutcome,
      );
      final continuation = rawContinuation == null ||
              (rawContinuation.game.isNotEmpty &&
                  rawContinuation.game != session.gameId)
          ? null
          : rawContinuation;
      final roomBatch = McpRoomMessageResolver.resolve(
        session.lastOutcome,
        knownOwnAliases: session.ownRoomAliases,
      );
      final previouslySeen = session.seenRoomMessageKeys.toSet();
      final newMessages = roomBatch.messages
          .where((item) =>
              !item.fromCompanion && !previouslySeen.contains(item.fingerprint))
          .toList(growable: false);
      final nextActor = actor?.nextActor ?? session.nextActor;
      final nextPhase = switch (nextActor) {
        'user' || 'shared' => CedarActivityPhase.waitingUser,
        'wait' => CedarActivityPhase.waitingRemote,
        'finished' => CedarActivityPhase.completed,
        _ => CedarActivityPhase.active,
      };
      final shouldWake = nextActor == 'companion' || continuation != null;
      final seen = <String>{
        ...session.seenRoomMessageKeys,
        ...roomBatch.messages.map((item) => item.fingerprint),
      }.toList(growable: false);
      final pending = newMessages.isEmpty
          ? session.pendingRoomMessage
          : newMessages.last.author.isEmpty
              ? newMessages.last.message
              : '${newMessages.last.author}：${newMessages.last.message}';
      final needsRepair = nextActor != session.nextActor ||
          nextPhase != session.phase ||
          (continuation != null && !session.hasContinuationCall) ||
          newMessages.isNotEmpty ||
          roomBatch.ownAliases.length != session.ownRoomAliases.length;
      if (!needsRepair) continue;
      changed = true;
      sessions[entry.key] = session.copyWith(
        nextActor: nextActor,
        phase: nextPhase,
        waitingReason: switch (nextPhase) {
          CedarActivityPhase.waitingUser => '等待你参与下一步',
          CedarActivityPhase.waitingRemote => '等待游戏允许继续',
          CedarActivityPhase.completed => '本局已经结束',
          _ => '',
        },
        continuationAction: continuation?.action,
        continuationParamsJson:
            continuation == null ? null : jsonEncode(continuation.params),
        continuationWaitScope: continuation?.waitScope,
        pendingRoomMessage: pending,
        seenRoomMessageKeys:
            seen.length <= 64 ? seen : seen.sublist(seen.length - 64),
        ownRoomAliases: roomBatch.ownAliases.toList(growable: false),
        nextActionAt: shouldWake ? now : session.nextActionAt,
        updatedAt: now,
      );
    }
    if (!changed) return null;
    return state.copyWith(sessions: sessions, updatedAt: now);
  }

  CedarToyActivityState? _repairPlayerGuides(CedarToyActivityState state) {
    var changed = false;
    final sessions = <String, CedarGameSession>{};
    for (final entry in state.sessions.entries) {
      final safeGuide = CedarToyClient.playerSafeGuide(entry.value.guide);
      if (safeGuide != entry.value.guide) changed = true;
      sessions[entry.key] = entry.value.copyWith(guide: safeGuide);
    }
    if (!changed) return null;
    return state.copyWith(
      sessions: sessions,
      updatedAt: DateTime.now(),
    );
  }

  CedarToyActivityState? _repairCatalogTitles(
    CedarToyActivityState state,
    String catalog,
  ) {
    if (catalog.isEmpty) return null;
    var changed = false;
    final sessions = Map<String, CedarGameSession>.from(state.sessions);
    for (final entry in state.sessions.entries) {
      final title = CedarCatalogParser.titleFor(catalog, entry.key);
      if (title.isEmpty || entry.value.gameTitle == title) continue;
      sessions[entry.key] = entry.value.copyWith(gameTitle: title);
      changed = true;
    }
    return changed
        ? state.copyWith(sessions: sessions, updatedAt: DateTime.now())
        : null;
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

  static List<String> catalogMentionedGameIds(
    String userText,
    String catalog,
  ) {
    if (!RegExp(r'(玩|来|进|加入|开|创建|存档|房间|一局|棋|游戏)')
            .hasMatch(userText) ||
        catalog.trim().isEmpty) return const <String>[];
    final matches = <String>[];
    final entries = CedarCatalogParser.parse(catalog);
    for (final entry in entries) {
      final id = entry.id;
      final title = entry.title;
      if ((id.isNotEmpty && userText.toLowerCase().contains(id.toLowerCase())) ||
          _mentionsCatalogTitle(userText, title) ||
          _mentionsCatalogTitle(userText, entry.description) ||
          CedarCatalogParser.displayAliases(id)
              .any((alias) => userText.contains(alias))) {
        matches.add(id);
      }
    }
    return matches.toSet().toList(growable: false);
  }

  static String catalogMentionedGameId(String userText, String catalog) {
    final matches = catalogMentionedGameIds(userText, catalog);
    return matches.length == 1 ? matches.single : '';
  }

  static bool catalogMentionsGame(String userText, String catalog) =>
      catalogMentionedGameIds(userText, catalog).isNotEmpty;

  static bool _mentionsCatalogTitle(String userText, String title) {
    if (title.isEmpty) return false;
    if (userText.contains(title)) return true;
    final titleRunes = title.runes.toList(growable: false);
    for (var length = titleRunes.length - 1; length >= 4; length -= 1) {
      final prefix = String.fromCharCodes(titleRunes.take(length));
      if (userText.contains(prefix)) return true;
    }
    return false;
  }

  static bool requestsImmediateGameEntry(String userText) {
    final clean = userText.trim();
    if (clean.isEmpty) return false;
    final explicitlyDeferred = RegExp(
      r'(以后|有空|改天|哪天|下次|偶尔|可以考虑|可以玩玩|推荐你)',
    ).hasMatch(clean);
    final explicitlyImmediate = RegExp(
      r'(现在|马上|立刻|这就|赶紧|立即)',
    ).hasMatch(clean);
    if (explicitlyDeferred && !explicitlyImmediate) return false;
    return explicitlyImmediate ||
        RegExp(r'(?:^|[，。！？\s])(?:去|来).{0,20}玩').hasMatch(clean) ||
        RegExp(r'(?:玩|进|进入|加入|开|创建).{0,20}(?:吧|一下|一局|存档|房间)')
            .hasMatch(clean) ||
        RegExp(r'^(?:去)?玩\S+').hasMatch(clean);
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

  static McpContinuationCall? _continuationCall(McpToolOutcome outcome) {
    final structured = McpContinuationCallResolver.resolveStructured(
      outcome.structuredContent,
    );
    if (structured != null) return structured;
    for (final block in outcome.content) {
      if (block.kind != McpContentKind.text || block.text.trim().isEmpty) {
        continue;
      }
      final resolved = McpContinuationCallResolver.resolve(block.text);
      if (resolved != null) return resolved;
    }
    return null;
  }

  static McpContinuationCall? _duelObserver(McpToolOutcome outcome) {
    final structured = CedarDuelObserverResolver.resolveStructured(
      outcome.structuredContent,
    );
    if (structured != null) return structured;
    for (final block in outcome.content) {
      if (block.kind != McpContentKind.text || block.text.trim().isEmpty) {
        continue;
      }
      final resolved = CedarDuelObserverResolver.resolve(block.text);
      if (resolved != null) return resolved;
    }
    return null;
  }

  static McpContinuationCall? _savedContinuation(CedarGameSession session) {
    if (!session.hasContinuationCall) return null;
    try {
      final decoded = jsonDecode(session.continuationParamsJson);
      if (decoded is! Map) return null;
      return McpContinuationCall(
        game: session.gameId,
        action: session.continuationAction,
        params: decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        waitScope: session.continuationWaitScope,
      );
    } catch (_) {
      return null;
    }
  }

  static McpRoomMessageBatch _roomMessages(
    McpToolOutcome outcome, {
    Iterable<String> knownOwnAliases = const <String>[],
  }) {
    var aliases = knownOwnAliases.toSet();
    final messages = <McpRoomMessageSignal>[];
    final seen = <String>{};
    void merge(McpRoomMessageBatch batch) {
      aliases = <String>{...aliases, ...batch.ownAliases};
      for (final message in batch.messages) {
        if (seen.add(message.fingerprint)) messages.add(message);
      }
    }

    merge(McpRoomMessageResolver.resolveStructured(
      outcome.structuredContent,
      knownOwnAliases: aliases,
    ));
    for (final block in outcome.content) {
      if (block.kind != McpContentKind.text || block.text.trim().isEmpty) {
        continue;
      }
      merge(McpRoomMessageResolver.resolve(
        block.text,
        knownOwnAliases: aliases,
      ));
    }
    return McpRoomMessageBatch(messages: messages, ownAliases: aliases);
  }

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
