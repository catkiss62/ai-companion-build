import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/models/perception_snapshot.dart';

void main() {
  test('perception snapshot restores local context metadata', () {
    final snapshot = PerceptionSnapshot.fromDb({
      'id': 'p1',
      'summary': '最近前台应用：example.app',
      'device_id': 'device-1',
      'device_label': 'Phone X',
      'current_package': 'example.app',
      'busy_score': 0.63,
      'notification_count': 2,
      'metadata_json': '{"top_durations":{"example.app":37}}',
      'occurred_at': 123456,
    });
    expect(snapshot.deviceId, 'device-1');
    expect(snapshot.deviceLabel, 'Phone X');
    expect(snapshot.currentPackage, 'example.app');
    expect(snapshot.busyScore, closeTo(0.63, 1e-9));
    expect(snapshot.notificationCount, 2);
    expect(snapshot.metadata['top_durations'], isA<Map>());
  });
}
