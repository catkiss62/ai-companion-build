import 'package:ai_companion_localfirst/features/home/companion_home_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CompanionHomeSnapshot snapshot({
    required bool active,
    required bool transfer,
  }) => CompanionHomeSnapshot(
        activeBrain: active,
        transferLocked: transfer,
        deviceId: 'device-test',
        refreshedAt: DateTime(2026, 8, 11),
      );

  test('active device is presented as the current companion brain', () {
    final value = snapshot(active: true, transfer: false);
    expect(value.isStandby, isFalse);
    expect(value.presenceTitle, contains('这台设备'));
    expect(value.presenceDetail, contains('这台设备'));
    expect(value.presenceDetail, isNot(contains('Active Brain')));
  });

  test('standby device never pretends to be a second active companion', () {
    final value = snapshot(active: false, transfer: false);
    expect(value.isStandby, isTrue);
    expect(value.presenceTitle, contains('另一台设备'));
    expect(value.presenceDetail, contains('第二份人生'));
  });

  test('transfer lock has priority over active flag in presentation', () {
    final value = snapshot(active: true, transfer: true);
    expect(value.presenceTitle, contains('换到另一台设备'));
    expect(value.presenceDetail, contains('暂时停止'));
  });
}
