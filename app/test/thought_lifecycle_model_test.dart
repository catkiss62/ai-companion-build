import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';

void main() {
  test('reads v0.9 lifecycle fields', () {
    final thought = CompanionThought.fromDb({
      'id': 't1',
      'text': '想问他那件事',
      'drive_key': 'attachment',
      'kind': 'fixation',
      'strength': 0.72,
      'born_at': 1,
      'updated_at': 2,
      'fed_count': 3,
      'source': 'self_drive',
      'last_fed_at': 2,
      'lifecycle_state': 'residual',
      'action_count': 1,
      'last_acted_at': 3,
      'last_satisfied_at': 4,
      'last_resurfaced_at': 5,
      'resurfaced_count': 2,
      'residual_strength': 0.31,
      'last_outbound_message_id': 'm1',
    });
    expect(thought.lifecycleState, 'residual');
    expect(thought.actionCount, 1);
    expect(thought.resurfacedCount, 2);
    expect(thought.lastOutboundMessageId, 'm1');
  });

  test('keeps old thought rows compatible', () {
    final thought = CompanionThought.fromDb({
      'id': 'old',
      'text': '旧念头',
      'drive_key': 'reflection',
      'kind': 'fixation',
      'strength': 0.6,
      'born_at': 1,
      'updated_at': 2,
      'fed_count': 2,
      'source': 'internal',
    });
    expect(thought.lifecycleState, 'fixation');
    expect(thought.actionCount, 0);
  });
}
