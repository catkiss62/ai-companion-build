import 'package:ai_companion_localfirst/core/models/immersive_room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy room rows default to an isolated daily NSFW route', () {
    final room = ImmersiveRoom.fromDb({
      'id': 'room-1',
      'title': '旧房间',
      'status': 'paused',
      'created_at': 1000,
      'updated_at': 2000,
    });

    expect(room.nsfwActive, isFalse);
    expect(room.nsfwManualOverride, isEmpty);
    expect(room.nsfwRouteSource, 'initial');
  });

  test('room NSFW route reads independently persisted state', () {
    final room = ImmersiveRoom.fromDb({
      'id': 'room-2',
      'title': '进行中的房间',
      'status': 'active',
      'nsfw_active': 1,
      'nsfw_manual_override': 'on',
      'nsfw_route_source': 'manual_pending_on',
      'created_at': 1000,
      'updated_at': 2000,
    });

    expect(room.nsfwActive, isTrue);
    expect(room.nsfwManualOverride, 'on');
    expect(room.nsfwRouteSource, 'manual_pending_on');
  });
}
