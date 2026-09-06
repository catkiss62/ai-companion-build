import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/world_book_turn_context.dart';
import 'package:ai_companion_localfirst/core/reference/world_book_history_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatMessage message({
    required String id,
    required String role,
    required String content,
    String sessionId = '',
  }) {
    final context = sessionId.isEmpty
        ? ''
        : WorldBookTurnContext(
            roleplaySessionId: sessionId,
          ).encode();
    return ChatMessage(
      id: id,
      role: role,
      content: content,
      createdAt: DateTime(2026, 9, 6),
      worldBookContextJson: context,
    );
  }

  test('removes roleplay continuity already present as raw history', () {
    const sessionId = 'roleplay-a';
    final retained = <ChatMessage>[
      message(id: 'u1', role: 'user', content: '靠一会儿就足够了？'),
      message(
        id: 'a1',
        role: 'assistant',
        content: '「现在够……再待一会儿，就说不好了。」',
        sessionId: sessionId,
      ),
    ];
    final result = WorldBookHistoryPolicy.continuityBeforeRetainedTurns(
      continuityNote: '''用户：更早的剧情
AI：更早的回答
用户：靠一会儿就足够了？
AI：「现在够……再待一会儿，就说不好了。」''',
      retainedHistory: retained,
      activeRoleplaySessionId: sessionId,
    );

    expect(result, '用户：更早的剧情\nAI：更早的回答');
  });

  test('keeps unmatched older continuity as long-session fallback', () {
    final result = WorldBookHistoryPolicy.continuityBeforeRetainedTurns(
      continuityNote: '用户：很早以前的剧情\nAI：仍未出现在原始历史里的回答',
      retainedHistory: <ChatMessage>[
        message(id: 'u2', role: 'user', content: '当前消息'),
      ],
      activeRoleplaySessionId: 'roleplay-a',
    );

    expect(result, contains('很早以前的剧情'));
  });
}
