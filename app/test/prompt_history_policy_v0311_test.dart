import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/grounding/prompt_history_policy.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/message_attachment.dart';

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

  test('legacy canned assistant lines stay stored but leave model history', () {
    final recent = [
      message(
        id: 'u1',
        role: 'user',
        content: '想起什么事？',
        at: DateTime(2026, 9, 21, 1, 0),
      ),
      message(
        id: 'a1',
        role: 'assistant',
        content: '「我其实还没有去玩，只是又想起这件事了。」',
        at: DateTime(2026, 9, 21, 1, 1),
      ),
    ];

    final userHistory = PromptHistoryPolicy.userTurnHistory(recent);
    expect(userHistory, hasLength(1));
    expect(userHistory.single['content'], '想起什么事？');

    final proactive =
        PromptHistoryPolicy.proactiveHistoryTranscript(recent)['content']
            as String;
    expect(proactive, contains('想起什么事？'));
    expect(proactive, isNot(contains('我其实还没有去玩')));
  });

  test('current user sticker meaning reaches the final user-turn history', () {
    final sticker = ChatMessage(
      id: 'u-sticker',
      role: 'user',
      content: '',
      createdAt: DateTime(2026, 9, 23),
      attachments: <MessageAttachment>[
        MessageAttachment(
          id: 'sticker-1',
          messageId: 'u-sticker',
          kind: MessageAttachment.imageKind,
          originalPath: 'originals/sticker.gif',
          thumbnailPath: 'thumbnails/sticker.png',
          mimeType: 'image/gif',
          byteSize: 10,
          width: 10,
          height: 10,
          source: 'user_sticker:personal',
          createdAt: DateTime(2026, 9, 23),
          visionStatus: MessageAttachment.visionCompletedStatus,
          visionSummary: '捂着脸害羞地偷看',
          visionModel: 'sticker_index',
        ),
      ],
    );

    final history = PromptHistoryPolicy.userTurnHistory(<ChatMessage>[sticker]);
    expect(history.single['role'], 'user');
    expect(history.single['content'], contains('用户发送了一张表情包'));
    expect(history.single['content'], contains('捂着脸害羞地偷看'));
  });
}
