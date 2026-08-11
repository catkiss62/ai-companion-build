import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';
import 'package:ai_companion_localfirst/core/models/thought.dart';

void main() {
  test('v2 memory row keeps confidence/source/status and tags', () {
    final item = MemoryItem.fromDb({
      'id': 'mem1',
      'kind': 'shared_experience',
      'content': '一起完成了第一版程序设计',
      'importance': 0.82,
      'confidence': 0.94,
      'tags': '项目|共同经历',
      'source': 'conversation',
      'status': 'active',
      'created_at': 1000,
      'updated_at': 2000,
      'last_recalled_at': 3000,
      'recall_count': 4,
    });
    expect(item.confidence, 0.94);
    expect(item.status, 'active');
    expect(item.tags, ['项目', '共同经历']);
    expect(item.recallCount, 4);
  });

  test('thought row keeps source and last fed timestamp', () {
    final thought = CompanionThought.fromDb({
      'id': 't1',
      'text': '他晚上可能会回来',
      'drive_key': 'attachment',
      'kind': 'fixation',
      'strength': 0.76,
      'born_at': 1000,
      'updated_at': 2000,
      'fed_count': 3,
      'source': 'conversation',
      'last_fed_at': 1800,
    });
    expect(thought.isFixation, isTrue);
    expect(thought.source, 'conversation');
    expect(thought.lastFedAt?.millisecondsSinceEpoch, 1800);
  });
}
