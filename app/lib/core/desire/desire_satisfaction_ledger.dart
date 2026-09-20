import 'dart:convert';

import '../database/app_database.dart';
import '../models/desire_state.dart';

class DesireSatisfactionEntry {
  const DesireSatisfactionEntry({
    required this.lastAt,
    required this.count,
    required this.source,
  });

  final DateTime lastAt;
  final int count;
  final String source;

  Map<String, Object?> toJson() => <String, Object?>{
        'last_at': lastAt.millisecondsSinceEpoch,
        'count': count,
        'source': source,
      };

  factory DesireSatisfactionEntry.fromJson(Map<Object?, Object?> json) {
    final millis = (json['last_at'] as num?)?.toInt() ?? 0;
    return DesireSatisfactionEntry(
      lastAt: DateTime.fromMillisecondsSinceEpoch(millis),
      count: ((json['count'] as num?)?.toInt() ?? 0)
          .clamp(0, 1000000)
          .toInt(),
      source: json['source']?.toString() ?? '',
    );
  }
}

/// Observes real satisfactions without becoming another desire state.
///
/// The ledger is causal metadata: it can explain which action lanes actually
/// got an opportunity, but it never creates a motive or raises a baseline.
class DesireSatisfactionLedger {
  const DesireSatisfactionLedger({
    required this.startedAt,
    this.actions = const <String, DesireSatisfactionEntry>{},
    this.drives = const <String, DesireSatisfactionEntry>{},
  });

  final DateTime startedAt;
  final Map<String, DesireSatisfactionEntry> actions;
  final Map<String, DesireSatisfactionEntry> drives;

  Map<String, Object?> toJson() => <String, Object?>{
        'version': 1,
        'started_at': startedAt.millisecondsSinceEpoch,
        'actions': <String, Object?>{
          for (final entry in actions.entries) entry.key: entry.value.toJson(),
        },
        'drives': <String, Object?>{
          for (final entry in drives.entries) entry.key: entry.value.toJson(),
        },
      };

  factory DesireSatisfactionLedger.fromJson(
    Map<Object?, Object?> json, {
    required DateTime fallbackNow,
  }) {
    Map<String, DesireSatisfactionEntry> decodeMap(Object? raw) {
      if (raw is! Map) return const <String, DesireSatisfactionEntry>{};
      return <String, DesireSatisfactionEntry>{
        for (final entry in raw.entries)
          if (entry.value is Map)
            entry.key.toString(): DesireSatisfactionEntry.fromJson(
              entry.value as Map,
            ),
      };
    }

    final startedMillis = (json['started_at'] as num?)?.toInt() ?? 0;
    return DesireSatisfactionLedger(
      startedAt: startedMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(startedMillis)
          : fallbackNow,
      actions: decodeMap(json['actions']),
      drives: decodeMap(json['drives']),
    );
  }

  DesireSatisfactionLedger record({
    required DriveKey drive,
    required String actionLane,
    required String source,
    required DateTime now,
  }) {
    DesireSatisfactionEntry next(DesireSatisfactionEntry? previous) =>
        DesireSatisfactionEntry(
          lastAt: now,
          count: (previous?.count ?? 0) + 1,
          source: source.trim().isEmpty ? 'unknown' : source.trim(),
        );

    return DesireSatisfactionLedger(
      startedAt: startedAt,
      actions: <String, DesireSatisfactionEntry>{
        ...actions,
        actionLane: next(actions[actionLane]),
      },
      drives: <String, DesireSatisfactionEntry>{
        ...drives,
        drive.name: next(drives[drive.name]),
      },
    );
  }

  Map<String, Object?> diagnostic(DateTime now) {
    const coreLanes = <String>{
      'play_game',
      'game_share',
      'public_web_discovery',
      'public_web_share',
      'reach_out',
      'ask_user',
      'share_thought',
    };
    final oldEnough = now.difference(startedAt) >= const Duration(hours: 24);
    return <String, Object?>{
        'version': 1,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'actionCount': actions.length,
        'driveCount': drives.length,
        'actions': <String, Object?>{
          for (final entry in actions.entries)
            entry.key: <String, Object?>{
              'count': entry.value.count,
              'lastAt': entry.value.lastAt.millisecondsSinceEpoch,
              'ageMinutes': now.difference(entry.value.lastAt).inMinutes,
              'source': entry.value.source,
            },
        },
        'drives': <String, Object?>{
          for (final entry in drives.entries)
            entry.key: <String, Object?>{
              'count': entry.value.count,
              'lastAt': entry.value.lastAt.millisecondsSinceEpoch,
            },
        },
        'zeroUseCoreLanes': oldEnough
            ? coreLanes.where((lane) => !actions.containsKey(lane)).toList()
            : const <String>[],
        'thoughtBodiesIncluded': false,
        'messageBodiesIncluded': false,
        'sourceIdsIncluded': false,
      };
  }
}

class DesireSatisfactionLedgerController {
  const DesireSatisfactionLedgerController(this.db);

  static const settingKey = 'desire_satisfaction_ledger_v1';

  final AppDatabase db;

  Future<DesireSatisfactionLedger> load({
    DateTime? now,
    bool persistIfMissing = false,
  }) async {
    final instant = now ?? DateTime.now();
    final raw = await db.getSetting(settingKey) ?? '';
    if (raw.trim().isEmpty) {
      final initial = DesireSatisfactionLedger(startedAt: instant);
      if (persistIfMissing) {
        await db.setSetting(settingKey, jsonEncode(initial.toJson()));
      }
      return initial;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return DesireSatisfactionLedger.fromJson(
          decoded,
          fallbackNow: instant,
        );
      }
    } catch (_) {}
    return DesireSatisfactionLedger(startedAt: instant);
  }

  Future<void> record({
    required DriveKey drive,
    required String action,
    required String source,
    required DateTime now,
  }) async {
    final current = await load(now: now);
    final lane = laneFor(action: action, source: source);
    final safeSource = coarseSource(source);
    final next = current.record(
      drive: drive,
      actionLane: lane,
      source: safeSource,
      now: now,
    );
    await db.setSetting(settingKey, jsonEncode(next.toJson()));
  }

  static String laneFor({required String action, required String source}) {
    final normalizedAction = action.trim().toLowerCase();
    final normalizedSource = source.trim().toLowerCase();
    if ((normalizedAction == 'share_thought' ||
            normalizedAction == 'wildcard_share') &&
        normalizedSource.startsWith('mcp/cedar_game:')) {
      return 'game_share';
    }
    if (const <String>{
      'play_game',
      'resume_game',
      'self_reset_and_resume',
    }.contains(normalizedAction)) {
      return 'play_game';
    }
    if (normalizedAction == 'discover_interest') {
      return 'public_web_discovery';
    }
    if (normalizedAction == 'prepare_public_web_share') {
      return 'public_web_share';
    }
    return normalizedAction.isEmpty ? 'unknown' : normalizedAction;
  }

  static String coarseSource(String source) {
    final normalized = source.trim().toLowerCase();
    if (normalized.startsWith('mcp/cedar_game:')) {
      final game = normalized
          .substring('mcp/cedar_game:'.length)
          .split(':')
          .first
          .replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
      return game.isEmpty ? 'mcp/cedar_game' : 'mcp/cedar_game:$game';
    }
    if (normalized.startsWith('public_web')) return 'public_web';
    if (normalized.startsWith('self_drive/')) return 'self_drive';
    if (normalized.startsWith('conversation')) return 'conversation';
    if (normalized.startsWith('capability/')) return 'capability';
    if (normalized == 'drive_state') return 'drive_state';
    return normalized.isEmpty ? 'unknown' : 'internal';
  }
}
