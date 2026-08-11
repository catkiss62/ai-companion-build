import 'package:ai_companion_localfirst/core/models/awareness_observation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('awareness observation decodes bounded local context', () {
    final now = DateTime(2026, 8, 11, 12, 0);
    final item = AwarenessObservation.fromDb({
      'id': 'a1',
      'device_id': 'phone',
      'kind': 'recent_activity',
      'summary': '最近一段时间主要在玩游戏。',
      'confidence': 0.78,
      'window_start': now.subtract(const Duration(minutes: 60)).millisecondsSinceEpoch,
      'window_end': now.millisecondsSinceEpoch,
      'expires_at': now.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
      'dedupe_key': 'recent_activity',
      'source_fingerprint': 'recent:game:40',
      'metadata_json': '{"activity":"game"}',
      'created_at': now.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    });

    expect(item.kind, 'recent_activity');
    expect(item.confidence, closeTo(0.78, 0.001));
    expect(item.isActiveAt(now), isTrue);
    expect(item.metadata['activity'], 'game');
  });
}
