import 'package:ai_companion_localfirst/core/presence/background_presence_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only coarse signal wake reasons are reactive', () {
    expect(BackgroundPresencePolicy.isReactiveWakeReason('signal:notification'), isTrue);
    expect(BackgroundPresencePolicy.isReactiveWakeReason(' signal:device_present '), isTrue);
    expect(BackgroundPresencePolicy.isReactiveWakeReason('scheduled'), isFalse);
    expect(BackgroundPresencePolicy.isReactiveWakeReason('overlay_opened'), isFalse);
  });

  test('reactive heartbeat is bounded by perception interval', () {
    final now = DateTime(2026, 8, 12, 10, 0);
    expect(
      BackgroundPresencePolicy.shouldAdvanceHeartbeat(
        wakeReason: 'signal:notification',
        now: now,
        lastPerceptionAt: null,
      ),
      isTrue,
    );
    expect(
      BackgroundPresencePolicy.shouldAdvanceHeartbeat(
        wakeReason: 'signal:notification',
        now: now,
        lastPerceptionAt: now.subtract(const Duration(seconds: 60)),
      ),
      isFalse,
    );
    expect(
      BackgroundPresencePolicy.shouldAdvanceHeartbeat(
        wakeReason: 'signal:accessibility_window',
        now: now,
        lastPerceptionAt: now.subtract(const Duration(seconds: 91)),
      ),
      isTrue,
    );
  });
}
