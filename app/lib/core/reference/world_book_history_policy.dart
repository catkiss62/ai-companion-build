import '../models/chat_message.dart';
import '../models/world_book_turn_context.dart';

class WorldBookHistoryPolicy {
  const WorldBookHistoryPolicy._();

  static bool isRoleplayAssistant(ChatMessage message) =>
      message.isAssistant &&
      WorldBookTurnContext.decode(message.worldBookContextJson).hasRoleplay;

  /// Removes a committed roleplay assistant message and the user turn directly
  /// paired with it. Historical schema-49 rows carry no invented provenance.
  static List<ChatMessage> withoutRoleplayTurns(
    List<ChatMessage> messages,
  ) => _filter(messages, activeRoleplaySessionId: null);

  /// Keeps ordinary history plus roleplay turns from only the active source
  /// session. Switching character cards cannot leak the previous role into
  /// the new prompt.
  static List<ChatMessage> forActiveRoleplay(
    List<ChatMessage> messages,
    String activeRoleplaySessionId,
  ) =>
      _filter(
        messages,
        activeRoleplaySessionId: activeRoleplaySessionId.trim(),
      );

  static List<ChatMessage> _filter(
    List<ChatMessage> messages, {
    required String? activeRoleplaySessionId,
  }) {
    if (messages.isEmpty) return const <ChatMessage>[];
    final excluded = <String>{};
    for (var index = 0; index < messages.length; index += 1) {
      final message = messages[index];
      if (!isRoleplayAssistant(message)) continue;
      final context = WorldBookTurnContext.decode(message.worldBookContextJson);
      if (activeRoleplaySessionId != null &&
          activeRoleplaySessionId.isNotEmpty &&
          context.roleplaySessionId == activeRoleplaySessionId) {
        continue;
      }
      excluded.add(message.id);
      // Proactive messages have no paired user turn. Never erase the nearest
      // ordinary user message merely because a roleplay proactive followed it.
      if (message.isProactive) continue;
      for (var previous = index - 1; previous >= 0; previous -= 1) {
        final candidate = messages[previous];
        if (candidate.isAssistant) break;
        if (candidate.isUser) {
          excluded.add(candidate.id);
          break;
        }
      }
    }
    return messages
        .where((message) => !excluded.contains(message.id))
        .toList(growable: false);
  }
}
