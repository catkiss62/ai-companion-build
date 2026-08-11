import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion_localfirst/core/models/memory_item.dart';

void main() {
  test('v4 memory exposes subject key and pin state', () {
    final item = MemoryItem.fromDb({
      'id': 'm1',
      'kind': 'user_profile',
      'content': '用户晚上改用平板',
      'importance': 0.8,
      'confidence': 0.9,
      'tags': '设备|习惯',
      'source': 'conversation',
      'status': 'active',
      'subject_key': 'user.device_evening',
      'pinned': 1,
      'superseded_by': null,
      'created_at': 1000,
      'updated_at': 2000,
      'last_recalled_at': null,
      'recall_count': 2,
    });
    expect(item.subjectKey, 'user.device_evening');
    expect(item.pinned, isTrue);
    expect(item.tags, contains('设备'));
  });
}
