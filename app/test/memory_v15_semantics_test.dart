import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion_localfirst/core/models/memory_item.dart';

void main() {
  test('v15 memory exposes current fact version and evidence semantics', () {
    final item = MemoryItem.fromDb({
      'id': 'm15',
      'kind': 'user_profile',
      'content': '用户现在通常晚上使用平板',
      'importance': 0.82,
      'confidence': 0.94,
      'tags': '设备|习惯',
      'source': 'conversation_turn:a1',
      'status': 'active',
      'subject_key': 'user.device_evening',
      'pinned': 0,
      'superseded_by': null,
      'created_at': 1000,
      'updated_at': 4000,
      'last_recalled_at': null,
      'recall_count': 2,
      'retention_score': 0.93,
      'retention_checked_at': 4000,
      'semantic_type': 'current_fact',
      'evidence_count': 4,
      'first_observed_at': 1000,
      'last_evidence_at': 3500,
      'fact_version': 3,
    });
    expect(item.isCurrentFact, isTrue);
    expect(item.isInference, isFalse);
    expect(item.evidenceCount, 4);
    expect(item.factVersion, 3);
    expect(item.firstObservedAt.millisecondsSinceEpoch, 1000);
    expect(item.lastEvidenceAt.millisecondsSinceEpoch, 3500);
  });

  test('v15 historical and inference states are explicit', () {
    final historical = MemoryItem.fromDb({
      'id': 'old',
      'kind': 'preference',
      'content': '用户以前更喜欢 A',
      'importance': 0.7,
      'confidence': 0.9,
      'tags': '',
      'source': 'conversation',
      'status': 'superseded',
      'subject_key': 'preference.example',
      'pinned': 0,
      'superseded_by': 'new',
      'created_at': 1000,
      'updated_at': 2000,
      'semantic_type': 'current_fact',
      'evidence_count': 2,
      'fact_version': 1,
    });
    final inference = MemoryItem.fromDb({
      'id': 'guess',
      'kind': 'user_profile',
      'content': '用户可能最近睡得更晚',
      'importance': 0.45,
      'confidence': 0.55,
      'tags': '',
      'source': 'conversation',
      'status': 'active',
      'subject_key': 'user.sleep_schedule',
      'pinned': 0,
      'superseded_by': null,
      'created_at': 3000,
      'updated_at': 3000,
      'semantic_type': 'inference',
      'evidence_count': 1,
      'fact_version': 1,
    });
    expect(historical.isHistorical, isTrue);
    expect(historical.isCurrentFact, isFalse);
    expect(inference.isInference, isTrue);
    expect(inference.isCurrentFact, isFalse);
  });

  test('legacy shared experience rows infer v15 semantic safely', () {
    final item = MemoryItem.fromDb({
      'id': 'legacy',
      'kind': 'shared_experience',
      'content': '一起完成了第一次设备接管',
      'importance': 0.8,
      'confidence': 0.9,
      'tags': '',
      'source': 'conversation',
      'status': 'active',
      'created_at': 1000,
      'updated_at': 1000,
    });
    expect(item.isSharedExperience, isTrue);
    expect(item.evidenceCount, 1);
    expect(item.factVersion, 1);
  });
}
