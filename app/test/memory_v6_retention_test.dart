import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/memory_item.dart';

void main() {
  test('v6 memory restores retention state without changing content', () {
    final item = MemoryItem.fromDb({
      'id': 'm6',
      'kind': 'shared_experience',
      'content': '很久以前一起聊过一件重要的事',
      'importance': 0.7,
      'confidence': 0.8,
      'tags': '',
      'source': 'conversation',
      'status': 'active',
      'subject_key': '',
      'pinned': 0,
      'superseded_by': null,
      'created_at': 1000,
      'updated_at': 2000,
      'last_recalled_at': 3000,
      'recall_count': 4,
      'retention_score': 0.63,
      'retention_checked_at': 4000,
    });
    expect(item.content, contains('重要'));
    expect(item.retentionScore, closeTo(0.63, 1e-9));
    expect(item.retentionCheckedAt?.millisecondsSinceEpoch, 4000);
  });
}
