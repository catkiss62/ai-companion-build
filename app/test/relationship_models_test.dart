import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion_localfirst/core/models/interaction_session.dart';
import 'package:ai_companion_localfirst/core/models/relationship_event.dart';
import 'package:ai_companion_localfirst/core/relationship/relationship_context.dart';

void main() {
  test('relationship event reads durable metadata', () {
    final event = RelationshipEvent.fromDb({
      'id': 'e1',
      'kind': 'promise',
      'summary': '晚些时候回来继续聊',
      'intensity': 0.7,
      'valence': 0.4,
      'source_message_id': 'm1',
      'metadata_json': '{"source":"conversation"}',
      'created_at': 1000,
    });
    expect(event.kind, 'promise');
    expect(event.metadata['source'], 'conversation');
    expect(event.intensity, 0.7);
  });

  test('interaction session stays a temporary layer', () {
    final session = InteractionSession.fromDb({
      'id': 's1',
      'kind': 'roleplay',
      'title': '临时场景',
      'status': 'active',
      'premise': '只在当前场景生效',
      'boundaries_json': '["可随时结束"]',
      'continuity_note': '下一轮保持场景连续',
      'source_message_id': 'm2',
      'started_at': 1000,
      'updated_at': 2000,
      'ended_at': null,
    });
    final context = RelationshipContext(events: const [], activeSession: session)
        .formatForPrompt();
    expect(session.isActive, isTrue);
    expect(context, contains('不覆盖你的 AI 本体身份'));
    expect(context, contains('可随时结束'));
  });
}
