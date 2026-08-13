import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';

void main() {
  test('reasoning is stored separately from content', () {
    final message = ChatMessage(
      id: 'm1',
      role: 'assistant',
      content: '正文',
      reasoningContent: '思考',
      model: 'deepseek-v4-pro',
      createdAt: DateTime.fromMillisecondsSinceEpoch(123456),
      isProactive: true,
      proactiveIntent: 'miss_you',
      proactiveDelivery: 'warm',
      deviceId: 'd1',
    );
    final restored = ChatMessage.fromDb(message.toDb());
    expect(restored.content, '正文');
    expect(restored.reasoningContent, '思考');
    expect(restored.isProactive, isTrue);
    expect(restored.proactiveIntent, 'miss_you');
    expect(restored.proactiveDelivery, 'warm');
  });
}
