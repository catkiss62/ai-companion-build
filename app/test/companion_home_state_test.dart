import 'package:ai_companion_localfirst/features/home/companion_home_state.dart';
import 'package:ai_companion_localfirst/core/sync/transfer_freeze_presentation.dart';
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

  test('backup freeze is not presented as a device transfer', () {
    final value = CompanionHomeSnapshot(
      activeBrain: true,
      transferLocked: true,
      freezePurpose: TransferFreezePurpose.backupExport,
      deviceId: 'device-test',
      refreshedAt: DateTime(2026, 8, 11),
    );

    expect(value.presenceTitle, contains('保存本机备份'));
    expect(value.presenceTitle, isNot(contains('另一台设备')));
    expect(value.presenceDetail, contains('不是设备接管'));
  });
}
