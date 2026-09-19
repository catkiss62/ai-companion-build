import 'dart:convert';

import 'cedar_game_protocol.dart';
import 'mcp_protocol.dart';

enum CedarAntiAddictionLevel { none, reminder, locked }

class CedarAntiAddictionSignal {
  const CedarAntiAddictionSignal({
    this.level = CedarAntiAddictionLevel.none,
    this.allowSelfReset,
    this.resumeAt,
    this.source = 'none',
  });

  final CedarAntiAddictionLevel level;
  final bool? allowSelfReset;
  final DateTime? resumeAt;
  final String source;

  bool get present => level != CedarAntiAddictionLevel.none;
}

class CedarSoloEpisodeState {
  const CedarSoloEpisodeState({
    required this.gameId,
    required this.startedAt,
    this.stateChangeCount = 0,
    this.checkpointPending = false,
    this.checkpointReason = '',
    this.antiAddictionLevel = CedarAntiAddictionLevel.none,
    this.allowSelfReset = false,
    this.antiAddictionResumeAt,
    this.antiAddictionObservedAt,
  });

  final String gameId;
  final DateTime startedAt;
  final int stateChangeCount;
  final bool checkpointPending;
  final String checkpointReason;
  final CedarAntiAddictionLevel antiAddictionLevel;
  final bool allowSelfReset;
  final DateTime? antiAddictionResumeAt;
  final DateTime? antiAddictionObservedAt;

  bool get antiAddictionPresent =>
      antiAddictionLevel != CedarAntiAddictionLevel.none;

  bool lockedAt(DateTime now) =>
      antiAddictionLevel == CedarAntiAddictionLevel.locked &&
      (antiAddictionResumeAt == null || now.isBefore(antiAddictionResumeAt!));

  Map<String, Object?> toJson() => <String, Object?>{
        'version': 1,
        'game_id': gameId,
        'started_at': startedAt.millisecondsSinceEpoch,
        'state_change_count': stateChangeCount,
        'checkpoint_pending': checkpointPending,
        'checkpoint_reason': checkpointReason,
        'anti_addiction_level': antiAddictionLevel.name,
        'allow_self_reset': allowSelfReset,
        'anti_addiction_resume_at':
            antiAddictionResumeAt?.millisecondsSinceEpoch ?? 0,
        'anti_addiction_observed_at':
            antiAddictionObservedAt?.millisecondsSinceEpoch ?? 0,
      };

  factory CedarSoloEpisodeState.fromJson(Map<Object?, Object?> json) {
    DateTime? optionalTime(String key) {
      final millis = (json[key] as num?)?.toInt() ?? 0;
      return millis <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(millis);
    }

    final levelName = json['anti_addiction_level']?.toString() ?? '';
    return CedarSoloEpisodeState(
      gameId: json['game_id']?.toString() ?? '',
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['started_at'] as num?)?.toInt() ?? 0,
      ),
      stateChangeCount:
          ((json['state_change_count'] as num?)?.toInt() ?? 0)
              .clamp(0, 9999)
              .toInt(),
      checkpointPending: json['checkpoint_pending'] == true,
      checkpointReason: json['checkpoint_reason']?.toString() ?? '',
      antiAddictionLevel: CedarAntiAddictionLevel.values.firstWhere(
        (item) => item.name == levelName,
        orElse: () => CedarAntiAddictionLevel.none,
      ),
      allowSelfReset: json['allow_self_reset'] == true,
      antiAddictionResumeAt: optionalTime('anti_addiction_resume_at'),
      antiAddictionObservedAt: optionalTime('anti_addiction_observed_at'),
    );
  }
}

class CedarSoloEpisodePolicy {
  const CedarSoloEpisodePolicy._();

  static const stateChangeLimit = 3;
  static const durationLimit = Duration(minutes: 25);

  static CedarSoloEpisodeState start(String gameId, DateTime now) =>
      CedarSoloEpisodeState(gameId: gameId, startedAt: now);

  static CedarSoloEpisodeState ensureCurrent({
    required CedarSoloEpisodeState? current,
    required String gameId,
    required DateTime now,
  }) {
    if (current == null ||
        current.gameId != gameId ||
        current.startedAt.millisecondsSinceEpoch <= 0) {
      return start(gameId, now);
    }
    return current;
  }

  static CedarSoloEpisodeState checkpointIfDue(
    CedarSoloEpisodeState state,
    DateTime now,
  ) {
    if (state.checkpointPending) return state;
    final byActions = state.stateChangeCount >= stateChangeLimit;
    final byTime = now.difference(state.startedAt) >= durationLimit;
    if (!byActions && !byTime) return state;
    return copy(
      state,
      checkpointPending: true,
      checkpointReason: byActions ? 'state_change_limit' : 'duration_limit',
    );
  }

  static CedarSoloEpisodeState recordOutcome({
    required CedarSoloEpisodeState state,
    required DateTime now,
    required String action,
    required bool succeeded,
    required CedarAntiAddictionSignal antiAddiction,
  }) {
    var next = state;
    if (succeeded && isStateChangingAction(action)) {
      next = copy(next, stateChangeCount: next.stateChangeCount + 1);
    }
    if (antiAddiction.present) {
      next = copy(
        next,
        checkpointPending: true,
        checkpointReason: antiAddiction.level == CedarAntiAddictionLevel.locked
            ? 'anti_addiction_locked'
            : 'anti_addiction_reminder',
        antiAddictionLevel: antiAddiction.level,
        allowSelfReset:
            antiAddiction.allowSelfReset ?? next.allowSelfReset,
        antiAddictionResumeAt: antiAddiction.resumeAt,
        clearAntiAddictionResumeAt: antiAddiction.resumeAt == null,
        antiAddictionObservedAt: now,
      );
    }
    return checkpointIfDue(next, now);
  }

  static bool isStateChangingAction(String action) =>
      action.trim().isNotEmpty &&
      !CedarPlatformActionPolicy.isPlatformAction(action) &&
      !CedarPlatformActionPolicy.isReadOnly(action) &&
      !CedarPlatformActionPolicy.isRemoteExit(action);

  static CedarSoloEpisodeState resetForResume(
    CedarSoloEpisodeState state,
    DateTime now,
  ) =>
      start(state.gameId, now);

  static CedarSoloEpisodeState copy(
    CedarSoloEpisodeState source, {
    int? stateChangeCount,
    bool? checkpointPending,
    String? checkpointReason,
    CedarAntiAddictionLevel? antiAddictionLevel,
    bool? allowSelfReset,
    DateTime? antiAddictionResumeAt,
    bool clearAntiAddictionResumeAt = false,
    DateTime? antiAddictionObservedAt,
  }) =>
      CedarSoloEpisodeState(
        gameId: source.gameId,
        startedAt: source.startedAt,
        stateChangeCount: stateChangeCount ?? source.stateChangeCount,
        checkpointPending: checkpointPending ?? source.checkpointPending,
        checkpointReason: checkpointReason ?? source.checkpointReason,
        antiAddictionLevel:
            antiAddictionLevel ?? source.antiAddictionLevel,
        allowSelfReset: allowSelfReset ?? source.allowSelfReset,
        antiAddictionResumeAt: clearAntiAddictionResumeAt
            ? null
            : antiAddictionResumeAt ?? source.antiAddictionResumeAt,
        antiAddictionObservedAt:
            antiAddictionObservedAt ?? source.antiAddictionObservedAt,
      );
}

class CedarAntiAddictionParser {
  const CedarAntiAddictionParser._();

  static CedarAntiAddictionSignal inspect(
    McpToolOutcome outcome, {
    required DateTime now,
  }) {
    var level = CedarAntiAddictionLevel.none;
    bool? allowSelfReset;
    DateTime? resumeAt;
    var structuredEvidence = false;

    void acceptLevel(CedarAntiAddictionLevel candidate) {
      if (candidate.index > level.index) level = candidate;
    }

    void walk(Object? value, {bool antiContext = false}) {
      if (value is List) {
        for (final item in value) {
          walk(item, antiContext: antiContext);
        }
        return;
      }
      if (value is! Map) return;
      for (final entry in value.entries) {
        final key = _key(entry.key.toString());
        final nestedAnti = antiContext || key.contains('antiaddiction');
        final item = entry.value;
        if (key.contains('antiaddiction')) {
          structuredEvidence = true;
          final directStatus = _key(item?.toString() ?? '');
          if (const <String>{'locked', 'blocked', 'forcedrest'}
              .contains(directStatus)) {
            acceptLevel(CedarAntiAddictionLevel.locked);
          } else if (const <String>{'reminder', 'warning', 'warn'}
              .contains(directStatus)) {
            acceptLevel(CedarAntiAddictionLevel.reminder);
          }
        }
        if (key == 'allowselfreset' && item is bool) {
          allowSelfReset = item;
        }
        if (key == 'antiaddictionreminder' && item == true) {
          structuredEvidence = true;
          acceptLevel(CedarAntiAddictionLevel.reminder);
        }
        if ((key == 'antiaddictionlocked' ||
                (nestedAnti && const <String>{'locked', 'blocked'}.contains(key))) &&
            item == true) {
          structuredEvidence = true;
          acceptLevel(CedarAntiAddictionLevel.locked);
        }
        if (nestedAnti && const <String>{'status', 'state', 'level'}.contains(key)) {
          final status = _key(item?.toString() ?? '');
          if (const <String>{'locked', 'blocked', 'forcedrest'}.contains(status)) {
            structuredEvidence = true;
            acceptLevel(CedarAntiAddictionLevel.locked);
          } else if (const <String>{'reminder', 'warning', 'warn'}.contains(status)) {
            structuredEvidence = true;
            acceptLevel(CedarAntiAddictionLevel.reminder);
          }
        }
        if (nestedAnti) {
          final parsed = _resumeAt(key, item, now);
          if (parsed != null) resumeAt = parsed;
        }
        walk(item, antiContext: nestedAnti);
      }
    }

    walk(outcome.structuredContent);
    for (final block in outcome.content) {
      if (block.kind != McpContentKind.text &&
          block.kind != McpContentKind.resource &&
          block.kind != McpContentKind.unknown) continue;
      final text = block.text;
      if (_explicitLocked.hasMatch(text)) {
        acceptLevel(CedarAntiAddictionLevel.locked);
      } else if (_explicitReminder.hasMatch(text)) {
        acceptLevel(CedarAntiAddictionLevel.reminder);
      }
      if (allowSelfReset == null && _explicitSelfResetAllowed.hasMatch(text)) {
        allowSelfReset = true;
      }
      if (!structuredEvidence) {
        final json = _wholeJson(text);
        if (json != null) walk(json);
      }
    }
    return CedarAntiAddictionSignal(
      level: level,
      allowSelfReset: allowSelfReset,
      resumeAt: resumeAt,
      source: structuredEvidence
          ? 'structured'
          : level == CedarAntiAddictionLevel.none
              ? 'none'
              : 'explicit_text',
    );
  }

  static DateTime? _resumeAt(String key, Object? value, DateTime now) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number != null) {
      if (const <String>{'resumeafterseconds', 'retryafterseconds', 'lockseconds'}
          .contains(key)) {
        return now.add(Duration(seconds: number.clamp(0, 86400).round()));
      }
      if (const <String>{'lockminutes', 'remainingminutes'}.contains(key)) {
        return now.add(Duration(minutes: number.clamp(0, 1440).round()));
      }
      if (const <String>{'lockeduntil', 'lockuntil', 'resumeat', 'resumeafter'}
          .contains(key)) {
        final millis = number > 100000000000
            ? number.round()
            : number > 1000000000
                ? (number * 1000).round()
                : 0;
        if (millis > 0) return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }
    if (const <String>{'lockeduntil', 'lockuntil', 'resumeat', 'resumeafter'}
        .contains(key)) {
      return DateTime.tryParse('$value')?.toLocal();
    }
    return null;
  }

  static Object? _wholeJson(String text) {
    final clean = text.trim();
    if (!(clean.startsWith('{') && clean.endsWith('}')) &&
        !(clean.startsWith('[') && clean.endsWith(']'))) return null;
    try {
      return jsonDecode(clean);
    } catch (_) {
      return null;
    }
  }

  static String _key(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static final RegExp _explicitLocked = RegExp(
    r'(?:防沉迷.{0,80}(?:已锁定|锁定中|强制休息|达到.{0,12}上限)|(?:已锁定|锁定中|强制休息).{0,40}防沉迷|anti[-_ ]?addiction.{0,80}(?:locked|blocked|forced\s+rest))',
    caseSensitive: false,
  );
  static final RegExp _explicitReminder = RegExp(
    r'(?:防沉迷.{0,80}(?:提醒|建议休息|连续游玩)|(?:提醒|建议休息|连续游玩).{0,40}防沉迷|anti[-_ ]?addiction.{0,80}(?:reminder|warning))',
    caseSensitive: false,
  );
  static final RegExp _explicitSelfResetAllowed = RegExp(
    r'(?:允许.{0,16}(?:小机|AI|自主|自行).{0,16}重置|allow[_ -]?self[_ -]?reset\s*[:=]\s*true)',
    caseSensitive: false,
  );
}
