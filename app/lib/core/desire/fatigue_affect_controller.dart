import '../database/app_database.dart';
import 'fatigue_affect_policy.dart';

/// Persists only bounded sleep-debt telemetry. Emotion activation is derived
/// from existing evidence-grounded episodes and is never a second mood engine.
class FatigueAffectController {
  FatigueAffectController(this.db);

  static const debtKey = 'fatigue_sleep_debt_v1';
  static const updatedAtKey = 'fatigue_sleep_debt_updated_at_v1';
  static const lastExertionAtKey = 'fatigue_last_exertion_at_v1';
  static const lastExertionSourceKey = 'fatigue_last_exertion_source_v1';
  static const exertionCountKey = 'fatigue_exertion_count_v1';

  final AppDatabase db;

  Future<FatigueAffectSnapshot> snapshot({
    DateTime? now,
    double activityActivation = 0,
    bool persistRecovery = true,
  }) async {
    final instant = now ?? DateTime.now();
    final storedDebt = double.tryParse(await db.getSetting(debtKey) ?? '') ?? 0;
    final storedUpdatedAt = _date(await db.getSetting(updatedAtKey));
    final lastExertionAt = _date(await db.getSetting(lastExertionAtKey));
    final lastSource = await db.getSetting(lastExertionSourceKey) ?? '';
    final latestHeaders = await db.recentMessageHeaders(limit: 1);
    final lastMessageAt = latestHeaders.isEmpty ? null : latestHeaders.last.createdAt;
    final wakefulAt = _latest(lastExertionAt, lastMessageAt);
    final updatedAt = storedUpdatedAt ?? instant;
    final repaid = FatigueAffectPolicy.repaySleepDebt(
      sleepDebt: storedDebt,
      updatedAt: updatedAt,
      now: instant,
      lastWakefulAt: wakefulAt,
    );
    if (persistRecovery &&
        ((repaid - storedDebt).abs() >= 0.0001 || storedUpdatedAt == null)) {
      await db.setSettingsAtomically({
        debtKey: repaid.toStringAsFixed(6),
        updatedAtKey: instant.millisecondsSinceEpoch.toString(),
      });
    }
    final episodes = await db.activeEmotionEpisodes(now: instant, limit: 6);
    return FatigueAffectPolicy.evaluate(
      episodes: episodes,
      now: instant,
      sleepDebt: repaid,
      updatedAt: storedUpdatedAt ?? instant,
      lastExertionAt: lastExertionAt,
      lastExertionSource: lastSource,
      activityActivation: activityActivation,
    );
  }

  Future<double> recordAutonomousExertion({
    required double bodyFatigue,
    required String source,
    DateTime? now,
    double weight = 1,
  }) async {
    final addition = FatigueAffectPolicy.exertionDebt(
      bodyFatigue: bodyFatigue,
      weight: weight,
    );
    if (addition <= 0) return 0;
    final instant = now ?? DateTime.now();
    final current = await snapshot(now: instant);
    final next = (current.sleepDebt + addition)
        .clamp(0.0, FatigueAffectPolicy.maxSleepDebt)
        .toDouble();
    final count = int.tryParse(await db.getSetting(exertionCountKey) ?? '') ?? 0;
    await db.setSettingsAtomically({
      debtKey: next.toStringAsFixed(6),
      updatedAtKey: instant.millisecondsSinceEpoch.toString(),
      lastExertionAtKey: instant.millisecondsSinceEpoch.toString(),
      lastExertionSourceKey: source,
      exertionCountKey: '${count + 1}',
    });
    return next;
  }

  static DateTime? _date(String? value) {
    final millis = int.tryParse(value ?? '');
    return millis == null || millis <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}
