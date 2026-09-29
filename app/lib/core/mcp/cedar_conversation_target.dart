import '../models/chat_message.dart';
import 'cedar_game_protocol.dart';

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
    final current = _referencedGameIds(latestUserText, catalog);
    if (current.length > 1) return '';
    if (current.length == 1) return current.single;
    for (final message in previous.reversed.take(6)) {
      if (message.createdAt.isAfter(now)) continue;
      if (!message.isUser) continue;
      final games = _referencedGameIds(message.content, catalog);
      if (games.length > 1) return '';
      if (games.length == 1) return games.single;
    }
    return '';
  }

  // This is only a catalog-grounded hint for the Agent after Jev has accepted
  // the invitation. Short replies like "继续钓鱼" need no extra activity keyword.
  // Do not use the activity store's entry gate here: that gate serves a
  // different purpose and would discard the direct choice in this dialogue.
  static List<String> _referencedGameIds(String userText, String catalog) {
    final text = userText.toLowerCase();
    if (text.trim().isEmpty) return const [];
    final matches = <String>[];
    for (final entry in CedarCatalogParser.parse(catalog)) {
      final title = entry.title;
      final runes = title.runes.toList(growable: false);
      final titleMention = title.isNotEmpty &&
          (userText.contains(title) ||
              [for (var length = runes.length - 1; length >= 4; length--)
                String.fromCharCodes(runes.take(length))]
                  .any(userText.contains));
      // Public short names are aliases of catalog entries, never additional
      // game IDs. They help disambiguate a request; DeepSeek still plans it.
      final shortNames = switch (entry.id) {
        'fishing' => const ['钓鱼'],
        'white_room' => const ['白房间'],
        _ => const <String>[],
      };
      if (text.contains(entry.id.toLowerCase()) || titleMention ||
          shortNames.any(userText.contains)) matches.add(entry.id);
    }
    return matches;
  }

  static bool conflictsWithPlan({
    required String targetGameId,
    required Iterable<({String toolId, String gameId})> calls,
  }) => targetGameId.isNotEmpty && calls.any((call) =>
      (call.toolId == 'cedar_toy.get_guide' ||
          call.toolId == 'cedar_toy.play') &&
      call.gameId != targetGameId);
}
