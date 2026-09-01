import '../database/app_database.dart';
import '../models/chat_message.dart';
import 'grounding_snapshot.dart';

class GroundingEngine {
  GroundingEngine(this.db);

  final AppDatabase db;

  Future<GroundingSnapshot> capture({DateTime? now}) async {
    final instant = now ?? DateTime.now();
    final recent = await db.recentMessageHeaders(limit: 100);
    ChatMessage? lastUser;
    for (final message in recent.reversed) {
      if (message.isUser) {
        lastUser = message;
        break;
      }
    }

    final answered = <String>{};
    if (lastUser != null) {
      final job = await db.generationJobForUserMessage(lastUser.id);
      if (job != null && job.status == 'completed') {
        final assistant = await db.messageHeaderById(job.assistantMessageId);
        if (assistant != null && assistant.isAssistant) {
          answered.add(lastUser.id);
        }
      }
    }

    return ConversationGroundingPolicy.build(
      now: instant,
      recent: recent,
      answeredUserMessageIds: answered,
      proactiveBoundaryInjectedUserMessageId:
          await db.getSetting(
                'proactive_time_boundary_anchor_message_id',
              ) ??
              '',
    );
  }
}
