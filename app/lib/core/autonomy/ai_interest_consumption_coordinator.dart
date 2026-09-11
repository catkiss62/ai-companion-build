import 'dart:math';

import '../database/app_database.dart';
import 'ai_interest_consumption_policy.dart';

class AiInterestConsumptionCoordinator {
  AiInterestConsumptionCoordinator(
    this.db, {
    Random? random,
  }) : _random = random ?? Random.secure();

  final AppDatabase db;
  final Random _random;

  Future<AiInterestConsumptionPlan?> plan({
    required AiInterestConsumptionSurface surface,
    DateTime? now,
  }) async {
    if ((await db.getSetting('ai_interest_consumption_enabled')) == '0') {
      return null;
    }
    final instant = now ?? DateTime.now();
    final candidates =
        await db.aiInterestCandidatesForConsumption(now: instant);
    if (candidates.isEmpty) return null;
    final events = await db.recentAiInterestConsumptionEvents(now: instant);
    return AiInterestConsumptionPolicy.select(
      candidates: candidates,
      recentEvents: events,
      surface: surface,
      now: instant,
      modeUnit: _random.nextDouble(),
      candidateUnit: _random.nextDouble(),
    );
  }
}
