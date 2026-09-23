import 'package:ai_companion_localfirst/core/sync/transfer_freeze_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses backup purpose from the owner token', () {
    expect(
      TransferFreezePresentation.purposeFromOwner(
        'runtime-42:backup_export:operation-id',
      ),
      TransferFreezePurpose.backupExport,
    );
    expect(
      TransferFreezePresentation.purposeFromOwner(
        'runtime-42:backup_restore:operation-id',
      ),
      TransferFreezePurpose.backupRestore,
    );
  });

  test('backup copy explicitly avoids a false device-transfer claim', () {
    final message = TransferFreezePresentation.chatBlockedMessage(
      TransferFreezePurpose.backupExport,
    );

    expect(message, contains('保存本机备份'));
    expect(message, contains('没有在换设备'));
  });
}
