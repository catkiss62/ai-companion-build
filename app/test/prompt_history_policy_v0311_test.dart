import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/grounding/prompt_history_policy.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';

ChatMessage message({
  required String id,
  required String role,
  required String content,
  required DateTime at,
  bool proactive = false,
}) =>
    ChatMessage(
      id: id,
      role: role,
      content: content,
      createdAt: at,
      isProactive: proactive,
    );

void main() {
  test('user turn history keeps real roles unchanged', () {
    final history = PromptHistoryPolicy.userTurnHistory([
      message(
        id: 'u1',
        role: 'user',
        content: '你好',
        at: DateTime(2026, 8, 12, 22, 0),
      ),
      message(
        id: 'a1',
        role: 'assistant',
        content: '晚上好。',
        at: DateTime(2026, 8, 12, 22, 1),
      ),
    ]);

    expect(history.map((e) => e['role']), ['user', 'assistant']);
    expect(history.first['content'], '你好');
  });

  test('proactive history contains no role=user current turn', () {
    final transcript = PromptHistoryPolicy.proactiveHistoryTranscript([
      message(
        id: 'u1',
        role: 'user',
        content: '你好',
        at: DateTime(2026, 8, 12, 22, 0),
      ),
      message(
        id: 'a1',
        role: 'assistant',
        content: '你好呀。',
        at: DateTime(2026, 8, 12, 22, 1),
      ),
    ]);

    expect(transcript['role'], 'system');
    final content = transcript['content'] as String;
    expect(content, contains('ANSWERED CHAT HISTORY'));
    expect(content, contains('REAL_USER_HISTORY'));
    expect(content, contains('ASSISTANT_HISTORY'));
    expect(content, contains('2026-08-12 22:00'));
    expect(content, contains('你好'));
  });
}
