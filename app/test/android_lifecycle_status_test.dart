import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion_localfirst/core/platform/android_bridge.dart';

void main() {
  test('CapabilityStatus separates permission, connection and runtime state', () {
    final status = CapabilityStatus.fromMap(<Object?, Object?>{
      'overlay': true,
      'usage': true,
      'accessibility': true,
      'notificationListener': true,
      'postNotifications': false,
      'overlayRunning': true,
      'overlayUserEnabled': true,
      'overlayVisible': false,
      'notificationListenerConnected': false,
      'accessibilityConnected': true,
      'appVisible': false,
      'screenInteractive': false,
      'deviceLocked': true,
      'lastServiceStart': 1_700_000_000_000,
      'lastServiceStop': 1_699_000_000_000,
      'lastServiceReason': 'sticky_restart',
    });

    expect(status.overlay, isTrue);
    expect(status.overlayRunning, isTrue);
    expect(status.overlayVisible, isFalse);
    expect(status.notificationListener, isTrue);
    expect(status.notificationListenerConnected, isFalse);
    expect(status.accessibilityConnected, isTrue);
    expect(status.screenInteractive, isFalse);
    expect(status.deviceLocked, isTrue);
    expect(status.lastServiceStart, isNotNull);
    expect(status.lastServiceReason, 'sticky_restart');
  });
}
