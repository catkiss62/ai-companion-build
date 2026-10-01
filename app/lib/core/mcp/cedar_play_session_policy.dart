import 'dart:convert';
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../platform/android_bridge.dart';
import 'cedar_timed_play_task.dart';
import 'cedar_toy_activity.dart';

/// A Desire-granted period, independent from chat/share opportunity counts.
class CedarPlaySession {
  const CedarPlaySession({
    required this.gameId,
    required this.startedAt,
    required this.lastTickAt,
    this.usedMs = 0,
    this.paused = false,
    this.taskId = '',
    this.limitMs = budgetMs,
    this.clockId = '',
  });
  final String gameId;
  final DateTime startedAt;
  final DateTime lastTickAt;
  final int usedMs;
  final bool paused;
  final String taskId;
  final int limitMs;
  final String clockId;
  static const budgetMs = 30 * 60 * 1000;
  static const checkpointGap = Duration(seconds: 30);
  // Recovery checkpoints every 30 s, including the ordinary two-minute wait;
  // in-flight planning checkpoints on its existing 45 s lease heartbeat.
  // A missed observation window is suspension, not billable offline time.
  static const observedTaskGap = Duration(minutes: 3);
  bool validAt(DateTime now, String game) =>
      gameId == game &&
      (taskId.isNotEmpty || (now.year == startedAt.year &&
          now.month == startedAt.month && now.day == startedAt.day &&
          !now.isBefore(lastTickAt) &&
          now.difference(lastTickAt) <= const Duration(hours: 2))) &&
      usedMs < limitMs;
  CedarPlaySession tick(DateTime now, {bool pause = false}) {
    final gap = now.difference(lastTickAt).inMilliseconds;
    // Long gaps are unobserved process suspension, never effective play.
    final observedGap = taskId.isEmpty ? 120000 : observedTaskGap.inMilliseconds;
    final addition = !paused && gap > 0 && gap <= observedGap ? gap : 0;
    return CedarPlaySession(
      gameId: gameId,
      startedAt: startedAt,
      lastTickAt: now.isBefore(lastTickAt) ? lastTickAt : now,
      usedMs: (usedMs + addition).clamp(0, limitMs).toInt(),
      paused: pause,
      taskId: taskId,
      limitMs: limitMs,
      clockId: clockId,
    );
  }

  Map<String, Object?> toJson() => {
    'gameId': gameId,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'lastTickAt': lastTickAt.millisecondsSinceEpoch,
    'usedMs': usedMs,
    'paused': paused,
    'taskId': taskId,
    'limitMs': limitMs,
    'clockId': clockId,
  };
  static CedarPlaySession? decode(String? raw) {
    try {
      final d = jsonDecode(raw ?? '');
      if (d is! Map || d['gameId'] is! String) return null;
      return CedarPlaySession(
        gameId: d['gameId'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          (d['startedAt'] as num).toInt(),
        ),
        lastTickAt: DateTime.fromMillisecondsSinceEpoch(
          (d['lastTickAt'] as num).toInt(),
        ),
        usedMs: ((d['usedMs'] as num?)?.toInt() ?? 0)
            .clamp(0, budgetMs)
            .toInt(),
        paused: d['paused'] == true,
        taskId: d['taskId']?.toString() ?? '',
        limitMs: ((d['limitMs'] as num?)?.toInt() ?? budgetMs)
            .clamp(60000, budgetMs).toInt(),
        clockId: d['clockId']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

class CedarPlaySessionStore {
  CedarPlaySessionStore(this.db);
  final AppDatabase db;
  static const key = 'cedar_toy_play_session_v1';
  Future<String> _epoch() async {
    try {
      final epoch = await AndroidBridge.instance.runtimeProcessEpoch();
      if (epoch.isNotEmpty) return epoch;
    } catch (_) {
      /* Tests have no Android process. */
    }
    return 'dart-${identityHashCode(db)}';
  }

  // Execution grants are local. A committed user task can recreate its clock
  // through reconcile; unsolicited Desire grants are never restored.
  Future<CedarPlaySession?> load() async {
    final raw = await db.getSetting(key);
    try {
      final data = jsonDecode(raw ?? '');
      if (data is! Map || data['processEpoch'] != await _epoch()) return null;
      return CedarPlaySession.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<String> encoded(CedarPlaySession state) async =>
      jsonEncode({...state.toJson(), 'processEpoch': await _epoch(),
        'clockId': state.clockId.isEmpty ? const Uuid().v4() : state.clockId});
  Future<bool> save(CedarPlaySession state, {String? expectedRaw,
      Map<String, String> expectedSettings = const {}}) async {
    final raw = await db.getSetting(key) ?? '';
    if (expectedRaw != null && raw != expectedRaw) return false;
    final taskRaw = await db.getSetting(CedarTimedPlayTaskStore.activeKey) ?? '';
    final task = CedarTimedPlayTaskStore.decode(taskRaw);
    final recorded = CedarPlaySession.decode(raw);
    if (state.taskId.isNotEmpty && task?['id'] != state.taskId) return false;
    if (state.taskId.isEmpty && task != null) return false;
    if (expectedRaw == null && state.clockId.isNotEmpty &&
        recorded?.clockId != state.clockId) return false;
    if (expectedRaw == null && recorded?.taskId == state.taskId &&
        recorded!.lastTickAt.isAfter(state.lastTickAt)) return false;
    return db.setSettingsAtomically({
      key: await encoded(state),
      if (task != null && task['id'] == state.taskId)
        CedarTimedPlayTaskStore.activeKey: jsonEncode({...task, 'usedMs': state.usedMs}),
    }, expectedSettings: {...expectedSettings,
      key: raw, CedarTimedPlayTaskStore.activeKey: taskRaw});
  }
  Future<bool> end(String reason) async {
    final raw = await db.getSetting(key) ?? '';
    final state = CedarPlaySession.decode(raw);
    final tasks = CedarTimedPlayTaskStore(db);
    final task = await tasks.active();
    if (task != null && (state == null || task['id'] == state.taskId)) {
      if (!await tasks.finish(task, usedMs: state?.usedMs ??
          (task['usedMs'] as num?)?.toInt() ?? 0, reason: reason,
          onlyIfActive: true)) return false;
    }
    return db.setSettingsAtomically({
      key: '', 'cedar_toy_play_session_end_reason': reason,
    }, expectedSettings: {key: raw});
  }

  Future<void> pause(DateTime now) async {
    final state = await load();
    if (state != null) {
      if (state.taskId.isEmpty && !state.validAt(now, state.gameId)) {
        await end('expired');
        return;
      }
      await save(state.tick(now, pause: true));
    }
  }

  static bool offer({
    required double interest,
    required double fatigue,
    required double saturation,
  }) => interest >= 0.58 && fatigue < 0.66 && saturation < 0.16;
}

/// A bounded, game-specific conversational preference; repeated yes never stacks.
class CedarGameAttitude {
  const CedarGameAttitude({
    required this.gameId,
    required this.turn,
    required this.at,
    required this.encouraged,
  });
  final String gameId;
  final String turn;
  final DateTime at;
  final bool encouraged;
  double bonusAt(DateTime now, String game) {
    if (gameId.isNotEmpty && gameId != game) return 0;
    final minutes = now.difference(at).inMinutes;
    if (minutes < 0 || minutes >= 720) return 0;
    // Three-hour half life, twelve-hour expiry.
    return (encouraged ? 0.10 : -0.10) *
        math.pow(0.5, minutes / 180).toDouble();
  }

  Map<String, Object?> toJson() => {
    'gameId': gameId,
    'turn': turn,
    'at': at.millisecondsSinceEpoch,
    'encouraged': encouraged,
  };
  static CedarGameAttitude? decode(String? raw) {
    try {
      final d = jsonDecode(raw ?? '');
      if (d is! Map) return null;
      return CedarGameAttitude(
        gameId: d['gameId']?.toString() ?? '',
        turn: d['turn']?.toString() ?? '',
        at: DateTime.fromMillisecondsSinceEpoch((d['at'] as num).toInt()),
        encouraged: d['encouraged'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

class CedarGameAttitudeStore {
  CedarGameAttitudeStore(this.db);
  final AppDatabase db;
  static const key = 'cedar_game_attitude_v1';
  Future<CedarGameAttitude?> load() async =>
      CedarGameAttitude.decode(await db.getSetting(key));
  Future<void> commit({required String turnId, required DateTime now}) async {
    if (await db.getSetting('nsfw_route_turn_id') != turnId) return;
    final signal = await db.getSetting('cedar_game_attitude_route_signal');
    if (signal != 'encourage' && signal != 'pause') return;
    if ((await load())?.turn == turnId) return;
    final game = await db.getSetting('cedar_game_attitude_route_game') ?? '';
    await db.setSetting(
      key,
      jsonEncode(
        CedarGameAttitude(
          gameId: game,
          turn: turnId,
          at: now,
          encouraged: signal == 'encourage',
        ).toJson(),
      ),
    );
    if (signal == 'pause') {
      final task = await CedarTimedPlayTaskStore(db).active();
      await db.setSetting(CedarTimedPlayTaskStore.pendingKey, '');
      await CedarPlaySessionStore(db).end('user_pause');
      final activity = CedarToyActivityStore(db);
      if (task != null && (await activity.load())?.gameId == task['gameId']) {
        await activity.pauseAndRelease();
      }
    }
  }
}
