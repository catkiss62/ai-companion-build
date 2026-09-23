enum TransferFreezePurpose {
  deviceTransfer,
  backupExport,
  backupRestore,
}

class TransferFreezePresentation {
  const TransferFreezePresentation._();

  static TransferFreezePurpose purposeFromOwner(String? owner) {
    final value = owner?.trim().toLowerCase() ?? '';
    if (value.contains(':backup_export:')) {
      return TransferFreezePurpose.backupExport;
    }
    if (value.contains(':backup_restore:')) {
      return TransferFreezePurpose.backupRestore;
    }
    return TransferFreezePurpose.deviceTransfer;
  }

  static String chatBlockedMessage(TransferFreezePurpose purpose) => switch (purpose) {
        TransferFreezePurpose.backupExport =>
          '正在保存本机备份，完成后即可继续聊天。她没有在换设备。',
        TransferFreezePurpose.backupRestore =>
          '正在恢复本机备份，完成前暂时不能聊天。她没有在换设备。',
        TransferFreezePurpose.deviceTransfer =>
          '她正在换到另一台设备，接管完成前先不能继续聊天。',
      };
}
