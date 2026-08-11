class TransferStateIdentity {
  const TransferStateIdentity({
    required this.lineageId,
    required this.generation,
    required this.deviceId,
  });

  final String lineageId;
  final int generation;
  final String deviceId;
}

class PendingImportedTransfer {
  const PendingImportedTransfer({
    required this.snapshotId,
    required this.lineageId,
    required this.sourceDeviceId,
    required this.sourceGeneration,
    required this.stateSha256,
  });

  final String snapshotId;
  final String lineageId;
  final String sourceDeviceId;
  final int sourceGeneration;
  final String stateSha256;
}

class TransferReceipt {
  const TransferReceipt({
    required this.snapshotId,
    required this.lineageId,
    required this.sourceDeviceId,
    required this.sourceGeneration,
    required this.stateSha256,
    required this.targetDeviceId,
    required this.targetLineageBefore,
    required this.targetGenerationBefore,
    required this.importedAt,
  });

  final String snapshotId;
  final String lineageId;
  final String sourceDeviceId;
  final int sourceGeneration;
  final String stateSha256;
  final String targetDeviceId;
  final String targetLineageBefore;
  final int targetGenerationBefore;
  final int importedAt;

  factory TransferReceipt.fromDb(Map<String, Object?> row) => TransferReceipt(
        snapshotId: row['snapshot_id'] as String,
        lineageId: row['lineage_id'] as String,
        sourceDeviceId: row['source_device_id'] as String,
        sourceGeneration: (row['source_generation'] as num).toInt(),
        stateSha256: row['state_sha256'] as String,
        targetDeviceId: row['target_device_id'] as String,
        targetLineageBefore: row['target_lineage_before'] as String? ?? '',
        targetGenerationBefore: (row['target_generation_before'] as num).toInt(),
        importedAt: (row['imported_at'] as num).toInt(),
      );

  Map<String, Object?> toDb() => {
        'snapshot_id': snapshotId,
        'lineage_id': lineageId,
        'source_device_id': sourceDeviceId,
        'source_generation': sourceGeneration,
        'state_sha256': stateSha256,
        'target_device_id': targetDeviceId,
        'target_lineage_before': targetLineageBefore,
        'target_generation_before': targetGenerationBefore,
        'imported_at': importedAt,
      };
}
