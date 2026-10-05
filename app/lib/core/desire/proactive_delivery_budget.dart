import 'daily_wake_store.dart';
import 'package:sqflite/sqflite.dart';

import '../models/proactive_frequency.dart';

/// Counts successful autonomous sends, independent of the selected profile.
/// Explicit live-game reports retain their user-requested delivery path.
class ProactiveDeliveryBudget {
  const ProactiveDeliveryBudget({
    required this.now,
    required this.mode,
    required this.dayUsed,
    required this.nightUsed,
    required this.twoHourUsed,
    required this.gameDayUsed,
    required this.gameTwoHourUsed,
    this.wakeAt,
    this.lastSentAt,
    this.lastGameSentAt,
  });

  final DateTime now;
  final DateTime? wakeAt;
  final ProactiveFrequencyMode mode;
  final int dayUsed, nightUsed, twoHourUsed, gameDayUsed, gameTwoHourUsed;
  final DateTime? lastSentAt, lastGameSentAt;
  bool get night => ProactiveFrequencyPolicy.isNight(now, wakeAt: wakeAt);
  int get used => night ? nightUsed : dayUsed;
  int get released => mode.releasedLimit(now, wakeAt: wakeAt);
  int get remaining => (released - used).clamp(0, released);

  String? blockReason({bool gameShare = false}) {
    if (lastSentAt != null && !mode.allowsGap(now.difference(lastSentAt!))) {
      return 'minimum_gap';
    }
    if (gameShare &&
        lastGameSentAt != null &&
        now.difference(lastGameSentAt!) < const Duration(minutes: 45)) {
      return 'minimum_gap';
    }
    if (remaining == 0) {
      return night ? 'night_contact_ceiling' : 'daytime_window_ceiling';
    }
    if (twoHourUsed >= mode.twoHourLimit || (gameShare && gameTwoHourUsed >= 3))
      return 'short_window_ceiling';
    // Preserve the extra game-share guard during daytime, without charging
    // yesterday's gaming against the independent night allowance.
    if (!night && gameShare && gameDayUsed >= 6) return 'game_daily_ceiling';
    return null;
  }

  Map<String, Object?> toJson() => {
    'mode': mode.key,
    'modeLabel': mode.zhLabel,
    'window': night ? 'night' : 'daytime',
    'windowStart': ProactiveFrequencyPolicy.windowStart(now, wakeAt: wakeAt).toIso8601String(),
    'wakeAt': wakeAt?.toIso8601String(),
    'releasedLimit': released,
    'windowUsed': used,
    'windowRemaining': remaining,
    'dayLimit': mode.dayLimit,
    'dayUsed': dayUsed,
    'dayRemaining': (mode.dayLimit - dayUsed).clamp(0, mode.dayLimit),
    'nightLimit': ProactiveFrequencyPolicy.nightLimit,
    'nightUsed': nightUsed,
    'nightRemaining': (ProactiveFrequencyPolicy.nightLimit - nightUsed).clamp(
      0,
      ProactiveFrequencyPolicy.nightLimit,
    ),
    'twoHourLimit': mode.twoHourLimit,
    'twoHourUsed': twoHourUsed,
    'twoHourRemaining': (mode.twoHourLimit - twoHourUsed).clamp(
      0,
      mode.twoHourLimit,
    ),
    'separateDeliveryGate': true,
    'quotaIsTarget': false,
  };

  static Future<ProactiveDeliveryBudget> read(
    DatabaseExecutor db,
    DateTime now, {
    ProactiveFrequencyMode? mode,
  }) async {
    if (mode == null) {
      final rows = await db.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [ProactiveFrequencyPolicy.settingKey],
      );
      mode = ProactiveFrequencyMode.fromSetting(
        rows.isEmpty ? null : rows.first['value'] as String?,
      );
    }
    final wake = await DailyWakeStore.read(db, now);
    final midnight = ProactiveFrequencyPolicy.boundary(
      now,
      0,
    ).millisecondsSinceEpoch;
    final morning = wake.wakeAt.millisecondsSinceEpoch;
    final tomorrow = ProactiveFrequencyPolicy.boundary(
      now,
      24,
    ).millisecondsSinceEpoch;
    final twoHours = now
        .subtract(const Duration(hours: 2))
        .millisecondsSinceEpoch;
    final dayAgo = now
        .subtract(const Duration(hours: 24))
        .millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN created_at >= ? AND created_at < ? THEN 1 ELSE 0 END) AS daytime,
        SUM(CASE WHEN created_at >= ? AND created_at < ? THEN 1 ELSE 0 END) AS night,
        SUM(CASE WHEN created_at >= ? THEN 1 ELSE 0 END) AS two_hours,
        SUM(CASE WHEN trigger_reason GLOB 'game_share:*' AND created_at >= ? THEN 1 ELSE 0 END) AS game_day,
        SUM(CASE WHEN trigger_reason GLOB 'game_share:*' AND created_at >= ? THEN 1 ELSE 0 END) AS game_two_hours,
        MAX(created_at) AS last_sent,
        MAX(CASE WHEN trigger_reason GLOB 'game_share:*' THEN created_at END) AS last_game
      FROM proactive_history WHERE decision = 'sent'
        AND trigger_reason NOT GLOB 'game_share:immediate:*'
    ''',
      [morning, tomorrow, midnight, morning, twoHours, dayAgo, twoHours],
    );
    final row = rows.single;
    int count(String key) => (row[key] as num?)?.toInt() ?? 0;
    DateTime? time(String key) => row[key] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(count(key), isUtc: now.isUtc);
    return ProactiveDeliveryBudget(
      now: now,
      wakeAt: wake.wakeAt,
      mode: mode,
      dayUsed: count('daytime'),
      nightUsed: count('night'),
      twoHourUsed: count('two_hours'),
      gameDayUsed: count('game_day'),
      gameTwoHourUsed: count('game_two_hours'),
      lastSentAt: time('last_sent'),
      lastGameSentAt: time('last_game'),
    );
  }
}
