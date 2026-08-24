import 'package:ai_companion_localfirst/core/integration/moe_input_adapter.dart';
import 'package:ai_companion_localfirst/core/models/chat_message.dart';
import 'package:ai_companion_localfirst/core/models/desire_state.dart';
import 'package:ai_companion_localfirst/core/moe/domain/moe_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 25, 1);

  ChatMessage assistant(String content) => ChatMessage(
        id: 'assistant-1',
        role: 'assistant',
        content: content,
        createdAt: now,
        emotionKey: 'playful',
        emotionLabel: '调皮',
      );

  test('adapter uses committed metadata without reading message content', () {
    const adapter = MoeInputAdapter();
    final desire = DesireSnapshot();
    final a = adapter.fromCompletedTurn(
      assistant: assistant('完全不同的正文 A'),
      desire: desire,
      relationshipDay: 20,
    );
    final b = adapter.fromCompletedTurn(
      assistant: assistant('完全不同的正文 B'),
      desire: desire,
      relationshipDay: 20,
    );
    expect(a.event!.idempotencyKey, 'turn:assistant-1');
    expect(a.event!.axisPulses, b.event!.axisPulses);
    expect(a.event!.contextTags, b.event!.contextTags);
    expect(a.relationshipStage, 'established');
    expect(a.event!.axisPulses[MoeAxis.playfulImpulse], greaterThan(10));
  });

  test('relationship stages are bounded metadata only', () {
    const adapter = MoeInputAdapter();
    final desire = DesireSnapshot();
    String stage(int day) => adapter
        .fromCompletedTurn(
          assistant: assistant('ignored'),
          desire: desire,
          relationshipDay: day,
        )
        .relationshipStage;
    expect(stage(1), 'new');
    expect(stage(4), 'familiarizing');
    expect(stage(15), 'established');
    expect(stage(61), 'long_term');
  });
}
