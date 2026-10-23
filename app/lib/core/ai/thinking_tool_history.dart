/// Transport history is independent of the user-facing reasoning panel.
/// An upstream may return a tool call with empty reasoning. Preserve that as
/// an explicit empty field, never invent reasoning or omit the protocol field.
class ThinkingToolHistory {
  const ThinkingToolHistory._();

  static List<Map<String, Object?>> prepare(
      List<Map<String, Object?>> messages, {required bool thinking,
      required bool toolsOffered}) {
    if (!thinking || (!toolsOffered &&
        !messages.any((m) => m['tool_calls'] is List))) return messages;
    return [for (final message in messages)
      if (message['role'] == 'assistant')
        {...message, 'reasoning_content': message['reasoning_content'] ?? ''}
      else message,
    ];
  }
}
