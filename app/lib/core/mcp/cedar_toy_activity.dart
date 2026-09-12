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

  bool get continuable =>
      this != completed && this != failed;

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

  bool get continuable => phase.continuable && guideComplete;
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
        'events': events.map((item) => item.toJson()).toList(growable: false),
      };

  factory CedarGameSession.fromJson(Map<Object?, Object?> json) =>
      CedarGameSession(
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
        events: (json['events'] as List?)
                ?.whereType<Map>()
                .map((item) => CedarGameEvent.fromJson(item))
                .toList(growable: false) ??
            const <CedarGameEvent>[],
      );
}

class CedarToyActivityStore {
  CedarToyActivityStore(this.db);

  static const sessionSettingKey = 'cedar_toy_activity_session_v1';
  static const catalogSettingKey = 'cedar_toy_catalog_v1';
  static const maxGuidePromptChars = 120000;
  static const maxStoredTextChars = 1024 * 1024;
  static const maxEventSummaryChars = 6000;
  static const maxEvents = 24;

  final AppDatabase db;

  Future<CedarGameSession?> load() async {
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

  Future<bool> hasContinuableSession() async => (await load())?.continuable ?? false;

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
    final existing = await load();
    final event = CedarGameEvent(
      id: 'guide-${now.microsecondsSinceEpoch}',
      kind: complete ? 'guide' : 'guide_too_long',
      summary: complete
          ? '已取得完整真实指南，可以按指南盲玩。'
          : '指南已取得，但超过当前完整判断容量，已停止而没有截断盲玩。',
      createdAt: now,
    );
    final session = CedarGameSession(
      id: existing?.gameId == gameId
          ? existing!.id
          : 'cedar-${now.microsecondsSinceEpoch}',
      gameId: gameId,
      gameTitle: gameTitle,
      guide: clean.length <= maxStoredTextChars ? clean : '',
      guideComplete: complete,
      mode: existing?.gameId == gameId
          ? existing!.mode
          : CedarParticipationMode.unknown,
      phase: complete
          ? CedarActivityPhase.guideReady
          : CedarActivityPhase.failed,
      lastOutcome: existing?.gameId == gameId ? existing!.lastOutcome : '',
      updatedAt: now,
      events: _append(existing?.gameId == gameId ? existing!.events : const [], event),
    );
    await save(session);
    return session;
  }

  Future<CedarGameSession> markInvitationRequired({
    required String gameId,
    required CedarParticipationMode mode,
    String reason = '',
  }) async {
    final existing = await load();
    if (existing == null || existing.gameId != gameId) {
      throw StateError('cedar_session_missing');
    }
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
      events: _append(existing.events, event),
    );
    await save(next);
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
  }) async {
    final existing = await load();
    if (existing == null || existing.gameId != gameId) {
      throw StateError('cedar_session_missing');
    }
    final now = DateTime.now();
    final viewerUrl = _viewerUrl(outcome) ?? existing.viewerUrl;
    final normalizedActor = const <String>{
      'companion',
      'user',
      'shared',
      'wait',
      'finished',
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
    final contentKinds = outcome.content
        .map((item) => item.kind.name)
        .toSet()
        .toList(growable: false);
    final event = CedarGameEvent(
      id: 'play-${now.microsecondsSinceEpoch}',
      kind: outcome.isError ? 'failure' : 'outcome',
      summary: _bounded(
        fullText.isEmpty ? '远端没有返回可展示的内容。' : fullText,
        maxEventSummaryChars,
      ),
      createdAt: now,
      action: action,
      contentKinds: contentKinds,
      viewerUrl: viewerUrl,
      notable: shareLevel == 'notable' || shareLevel == 'required',
      imageData: outcome.images.isEmpty ||
              outcome.images.first.data.length > maxStoredTextChars
          ? ''
          : outcome.images.first.data,
      imageMimeType:
          outcome.images.isEmpty ? '' : outcome.images.first.mimeType,
    );
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
      invitationApproved:
          invitationApproved || existing.invitationApproved,
      updatedAt: now,
      events: _append(existing.events, event),
    );
    await save(next);
    return next;
  }

  Future<void> pause() async {
    final existing = await load();
    if (existing == null || !existing.phase.continuable) return;
    await save(existing.copyWith(
      phase: CedarActivityPhase.paused,
      waitingReason: '已在本机暂停，进度仍由远端存档保存',
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> clear() => db.setSetting(sessionSettingKey, '');

  Future<void> save(CedarGameSession session) =>
      db.setSetting(sessionSettingKey, jsonEncode(session.toJson()));

  String promptContext(CedarGameSession session) => '''
【CEDAR_ACTIVITY_SESSION · REAL LOCAL STATE】
game=${session.gameId}
mode=${session.mode.key}
phase=${session.phase.key}
next_actor=${session.nextActor}
invitation_approved=${session.invitationApproved}
last_action=${session.lastAction}
last_outcome=${session.lastOutcome}
viewer_url=${session.viewerUrl}
【完整真实指南 · 盲玩唯一规则来源】
${session.guide}
【END CEDAR_ACTIVITY_SESSION】
'''.trim();

  static List<CedarGameEvent> _append(
    List<CedarGameEvent> existing,
    CedarGameEvent event,
  ) {
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
          uri.host.endsWith('.cedarstar.org')) {
        return uri.toString();
      }
    }
    return null;
  }
}
