import '../database/app_database.dart';
import '../memory/memory_grounding_policy.dart';
import '../models/memory_item.dart';

/// Both participants receive the same durable background. Reading here does
/// not advance ordinary-chat recall cooldowns or create personality evidence.
class ModelDialogueContext {
  ModelDialogueContext(this.db);
  final AppDatabase db;

  Future<String> build(String query) async {
    final identity = await db.memoriesByKind('ai_self', limit: 6);
    final user = await db.memoriesByKind('user_profile', limit: 4);
    final related = await db.relevantMemories(query, limit: 12,
        retrievalMode: 'model_dialogue', recordRecall: false);
    final selected = <String, MemoryItem>{
      for (final item in [...identity, ...user, ...related]) item.id: item,
    };
    final out = StringBuffer();
    var remaining = 14000;
    for (final item in selected.values) {
      final line = MemoryGroundingPolicy.formatForPrompt(item);
      if (line.length > remaining) continue;
      out.writeln('- $line');
      remaining -= line.length + 3;
    }
    return out.toString().trim();
  }
}
