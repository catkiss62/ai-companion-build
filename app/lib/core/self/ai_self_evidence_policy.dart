import '../models/chat_message.dart';
import '../models/world_book_turn_context.dart';

class AiSelfEvidenceVerdict {
  const AiSelfEvidenceVerdict({
    required this.allowed,
    required this.canPromote,
    required this.reason,
    this.messages = const <ChatMessage>[],
  });

  final bool allowed;
  final bool canPromote;
  final String reason;
  final List<ChatMessage> messages;
}

class AiSelfEvidencePolicy {
  const AiSelfEvidencePolicy._();

  static AiSelfEvidenceVerdict evaluate({
    required Iterable<String> evidenceMessageIds,
    required Iterable<ChatMessage> availableMessages,
  }) {
    final requested = evidenceMessageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (requested.length < 3) {
      return const AiSelfEvidenceVerdict(
        allowed: false,
        canPromote: false,
        reason: 'fewer_than_three_messages',
      );
    }
    final byId = <String, ChatMessage>{
      for (final message in availableMessages) message.id: message,
    };
    final evidence = <ChatMessage>[];
    for (final id in requested) {
      final message = byId[id];
      if (message == null || !message.isAssistant) {
        return const AiSelfEvidenceVerdict(
          allowed: false,
          canPromote: false,
          reason: 'unknown_or_non_assistant_message',
        );
      }
      final worldBook = WorldBookTurnContext.decode(
        message.worldBookContextJson,
      );
      if (worldBook.hasRoleplay) {
        return const AiSelfEvidenceVerdict(
          allowed: false,
          canPromote: false,
          reason: 'roleplay_evidence',
        );
      }
      if (worldBook.knowledgeSources.isNotEmpty) {
        return const AiSelfEvidenceVerdict(
          allowed: false,
          canPromote: false,
          reason: 'knowledge_reference_evidence',
        );
      }
      evidence.add(message);
    }
    evidence.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    final timeBuckets = evidence
        .map((message) =>
            message.createdAt.millisecondsSinceEpoch ~/
            const Duration(hours: 2).inMilliseconds)
        .toSet();
    if (timeBuckets.length < 2) {
      return const AiSelfEvidenceVerdict(
        allowed: false,
        canPromote: false,
        reason: 'single_time_bucket',
      );
    }
    final days = evidence
        .map((message) {
          final local = message.createdAt.toLocal();
          return '${local.year}-${local.month}-${local.day}';
        })
        .toSet();
    return AiSelfEvidenceVerdict(
      allowed: true,
      canPromote: evidence.length >= 4 && days.length >= 2,
      reason: days.length >= 2 ? 'cross_day_evidence' : 'forming_evidence',
      messages: List<ChatMessage>.unmodifiable(evidence),
    );
  }
}
