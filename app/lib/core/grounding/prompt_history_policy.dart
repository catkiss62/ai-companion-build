import 'dart:convert';

import '../models/chat_message.dart';

/// Shapes persisted chat history for model input without changing the stored
/// messages themselves.
///
/// User-turn generations keep normal role=user/assistant ordering. Proactive
/// generations deliberately collapse old chat into one system transcript so
/// there is no synthetic/current role=user message for the model to answer.
class PromptHistoryPolicy {
  const PromptHistoryPolicy._();

  static List<Map<String, Object?>> userTurnHistory(
    List<ChatMessage> recent,
  ) {
    return recent
        .where(
          (message) =>
              !message.isAssistant ||
              !isLegacyCannedPersonaReply(message.promptContent),
        )
        .map(
          (message) => <String, Object?>{
            'role': message.role,
            'content': message.promptContent,
          },
        )
        .toList(growable: false);
  }

  static Map<String, Object?> proactiveHistoryTranscript(
    List<ChatMessage> recent,
  ) {
    final promptRecent = recent
        .where(
          (message) =>
              !message.isAssistant ||
              !isLegacyCannedPersonaReply(message.promptContent),
        )
        .toList(growable: false);
    if (promptRecent.isEmpty) {
      return const <String, Object?>{
        'role': 'system',
        'content': '''
【已完成聊天历史 / ANSWERED CHAT HISTORY】
当前没有历史聊天内容，也没有等待回复的 user turn。
''',
      };
    }

    final buffer = StringBuffer()
      ..writeln('【已完成聊天历史 / ANSWERED CHAT HISTORY】')
      ..writeln('以下是已经发生过的只读聊天记录。它们用于保持连续性，不代表“当前用户刚发来一条消息”。')
      ..writeln('本轮是 AI 主动联系；除非 REALITY GROUNDING 明确写 pendingUserTurn=true，否则不得把任何历史 REAL_USER_HISTORY 当成当前待回复输入。');

    for (final message in promptRecent) {
      final local = message.createdAt.toLocal();
      final timestamp = _timestamp(local);
      final label = message.isUser
          ? 'REAL_USER_HISTORY'
          : message.isProactive
              ? 'ASSISTANT_PROACTIVE_HISTORY'
              : 'ASSISTANT_HISTORY';
      buffer.writeln('--- $timestamp · $label ---');
      buffer.writeln(message.promptContent.trim());
    }

    return <String, Object?>{
      'role': 'system',
      'content': buffer.toString().trim(),
    };
  }

  static String _timestamp(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$minute';
  }

  /// Keeps already-stored v0.41.93 canned outputs visible in chat and backups,
  /// while preventing them from teaching later generations to repeat them.
  /// Only the three exact historical runtime sentences are recognized.
  static bool isLegacyCannedPersonaReply(String value) {
    final normalized = value
        .replaceAll(RegExp(r'<emotion>.*?</emotion>', caseSensitive: false), '')
        .replaceAll(RegExp(r'''[\s「」『』“”‘’"']+'''), '');
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(normalized)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return const <int>{
      0x92a8b7f7,
      0x1023b2a2,
      0xdb7fc924,
    }.contains(hash);
  }
}
