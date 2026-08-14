import '../database/app_database.dart';
import '../models/somatic_state.dart';
import 'somatic_policy.dart';

class SomaticEngine {
  const SomaticEngine(this.db);

  final AppDatabase db;

  Future<int> captureUserTurn({
    required String turnId,
    required String text,
    DateTime? now,
  }) async {
    final instant = now ?? DateTime.now();
    final events = SomaticPolicy.detectDailyTouch(
      turnId: turnId,
      text: text,
      now: instant,
    );
    if (events.isEmpty) return 0;
    return db.recordSomaticEvents(events, now: instant);
  }

  List<SomaticEvent> assistantCommitEvents({
    required String turnId,
    required String text,
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now();
    return SomaticPolicy.detectAssistantSelfTouch(
      turnId: turnId,
      text: text,
      now: instant,
    );
  }

  Future<String> buildPromptSection({DateTime? now}) async {
    final instant = now ?? DateTime.now();
    final aggregates = await db.activeSomaticAggregates(now: instant);
    return SomaticPolicy.formatPrompt(aggregates, now: instant);
  }
}
