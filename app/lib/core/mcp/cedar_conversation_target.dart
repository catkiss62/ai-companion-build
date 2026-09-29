import '../models/chat_message.dart';
import 'cedar_toy_activity.dart';

/// A recent, explicit catalog reference is evidence for the Agent, not a
/// command to start a game. The pre-reply Jev gate remains authoritative.
class CedarConversationTarget {
  const CedarConversationTarget._();

  static String recentGameId({
    required String latestUserText,
    required DateTime now,
    required List<ChatMessage> previous,
    required String catalog,
  }) {
    final current = CedarToyActivityStore.catalogMentionedGameIds(
      latestUserText, catalog,
    );
    if (current.length > 1) return '';
    if (current.length == 1) return current.single;
    for (final message in previous.reversed.take(6)) {
      if (message.createdAt.isAfter(now)) continue;
      if (!message.isUser) continue;
      final games = CedarToyActivityStore.catalogMentionedGameIds(
        message.content, catalog,
      );
      if (games.length > 1) return '';
      if (games.length == 1) return games.single;
    }
    return '';
  }

  static bool conflictsWithPlan({
    required String targetGameId,
    required Iterable<({String toolId, String gameId})> calls,
  }) => targetGameId.isNotEmpty && calls.any((call) =>
      (call.toolId == 'cedar_toy.get_guide' ||
          call.toolId == 'cedar_toy.play') &&
      call.gameId.isNotEmpty && call.gameId != targetGameId);
}
