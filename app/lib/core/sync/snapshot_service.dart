import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../storage/companion_album_storage.dart';
import '../storage/message_attachment_storage.dart';
import '../storage/snapshot_directory_swap.dart';
import 'transfer_identity.dart';

enum SnapshotArchiveKind {
  takeover('takeover'),
  backup('backup');

  const SnapshotArchiveKind(this.key);
  final String key;

  static SnapshotArchiveKind parse(String value) {
    return SnapshotArchiveKind.values.firstWhere(
      (item) => item.key == value,
      orElse: () => throw FormatException('未知状态包用途：$value'),
    );
  }

  bool acceptsSourceGeneration(int generation) => switch (this) {
        SnapshotArchiveKind.takeover => generation > 0,
        SnapshotArchiveKind.backup => generation >= 0,
      };

  String get manifestEncryption => switch (this) {
        SnapshotArchiveKind.takeover => 'nearby_transport_or_manual_aes_gcm',
        SnapshotArchiveKind.backup => 'none',
      };
}

class SnapshotMetadata {
  const SnapshotMetadata({
    required this.snapshotId,
    required this.lineageId,
    required this.sourceDeviceId,
    required this.sourceGeneration,
    required this.targetActivationGeneration,
    required this.stateSha256,
    required this.stateBytes,
    required this.schemaVersion,
    required this.createdAt,
    required this.protocolVersion,
    this.archiveKind = SnapshotArchiveKind.takeover,
    this.legacy = false,
  });

  final String snapshotId;
  final String lineageId;
  final String sourceDeviceId;
  final int sourceGeneration;
  final int targetActivationGeneration;
  final String stateSha256;
  final int stateBytes;
  final int schemaVersion;
  final DateTime createdAt;
  final int protocolVersion;
  final SnapshotArchiveKind archiveKind;
  final bool legacy;

  bool get hasCompleteArchiveState => protocolVersion >= 4;
  bool get isBackup => archiveKind == SnapshotArchiveKind.backup;
  bool get isTakeover => archiveKind == SnapshotArchiveKind.takeover;
}

class SnapshotBundle {
  const SnapshotBundle({
    required this.filePath,
    required this.metadata,
  });

  final String filePath;
  final SnapshotMetadata metadata;

  String get sha256Hex => metadata.stateSha256;
  DateTime get createdAt => metadata.createdAt;
}

class SnapshotImportResult {
  const SnapshotImportResult({
    required this.metadata,
    required this.imported,
    required this.duplicate,
    this.restoredFromBackup = false,
    this.requiresManualTakeover = false,
  });

  final SnapshotMetadata metadata;
  final bool imported;
  final bool duplicate;
  final bool restoredFromBackup;
  final bool requiresManualTakeover;
}

class SnapshotLineageMismatch implements Exception {
  const SnapshotLineageMismatch({
    required this.localLineageId,
    required this.incomingLineageId,
  });

  final String localLineageId;
  final String incomingLineageId;

  @override
  String toString() => '状态包属于另一段 Companion 数据谱系，需要明确确认后才能替换本机。';
}

class SnapshotStaleException implements Exception {
  const SnapshotStaleException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _ValidatedSnapshot {
  const _ValidatedSnapshot(
    this.metadata,
    this.backup,
    this.workDirectory,
  );
  final SnapshotMetadata metadata;
  final Map<String, dynamic> backup;
  final Directory workDirectory;

  Directory get attachmentsDirectory =>
      Directory(p.join(workDirectory.path, 'attachments'));

  Directory get albumDirectory =>
      Directory(p.join(workDirectory.path, 'album'));

  Future<void> dispose() async {
    if (await workDirectory.exists()) {
      await workDirectory.delete(recursive: true);
    }
  }
}

class _PreparedSnapshotFiles {
  const _PreparedSnapshotFiles(this.attachments, this.album);

  final PreparedDirectorySwap attachments;
  final PreparedDirectorySwap album;

  Future<void> activate() async {
    await attachments.activate();
    try {
      await album.activate();
    } catch (_) {
      await attachments.rollback();
      rethrow;
    }
  }

  Future<void> rollback() async {
    try {
      await album.rollback();
    } finally {
      await attachments.rollback();
    }
  }

  Future<void> commit() async {
    await attachments.commit();
    await album.commit();
  }
}

class SnapshotService {
  SnapshotService(
    this.db, {
    MessageAttachmentStorage? attachmentStorage,
    CompanionAlbumStorage? albumStorage,
  }) : attachmentStorage = attachmentStorage ?? MessageAttachmentStorage(),
       albumStorage = albumStorage ?? CompanionAlbumStorage();

  final AppDatabase db;
  final MessageAttachmentStorage attachmentStorage;
  final CompanionAlbumStorage albumStorage;
  final Uuid _uuid = const Uuid();

  Future<SnapshotBundle> exportBundle() =>
      _exportBundle(SnapshotArchiveKind.takeover);

  Future<SnapshotBundle> exportBackupBundle() =>
      _exportBundle(SnapshotArchiveKind.backup);

  Future<SnapshotBundle> _exportBundle(SnapshotArchiveKind archiveKind) async {
    final snapshotId = _uuid.v4();
    final isTakeover = archiveKind == SnapshotArchiveKind.takeover;
    final identity = isTakeover
        ? await db.reserveTransferSnapshot(snapshotId)
        : await db.transferStateIdentity();
    try {
      if (!isTakeover) {
        if (await db.getSetting('transfer_lock') != '1') {
          throw StateError('创建普通备份前必须先冻结本机写入。');
        }
        if (await db.getSetting('active_brain') == '0') {
          throw StateError('只有当前 Active Brain 可以创建普通备份。');
        }
      }
      final exported = await db.exportAll();
      if (!isTakeover) _normalizeBackupRuntimeSettings(exported);
      final jsonBytes = utf8.encode(jsonEncode(exported));
      final digest = sha256.convert(jsonBytes).toString();
      final now = DateTime.now().toUtc();
      final temp = await getTemporaryDirectory();
      final stamp = now.toIso8601String().replaceAll(':', '-');
      final nonce = DateTime.now().microsecondsSinceEpoch;
      final work = Directory(
        p.join(temp.path, 'companion_snapshot_work_$nonce'),
      );
      final zipPath = p.join(temp.path, 'ai_companion_${stamp}_$nonce.zip');
      await work.create(recursive: true);

      final stateFile = File(p.join(work.path, 'state.json'));
      final manifestFile = File(p.join(work.path, 'manifest.json'));
      final attachmentExportDirectory =
          Directory(p.join(work.path, 'attachments'));
      final albumExportDirectory = Directory(p.join(work.path, 'album'));
      try {
      final pendingSnapshotId = _settingFromBackup(exported, 'pending_outbound_snapshot_id');
      final pendingGeneration = int.tryParse(
            _settingFromBackup(exported, 'pending_outbound_generation'),
          ) ??
          -1;
      if (isTakeover &&
          (pendingSnapshotId != snapshotId ||
              pendingGeneration != identity.generation)) {
        throw StateError('冻结状态代次与导出内容不一致，已拒绝生成状态包。');
      }
      if (!isTakeover &&
          (pendingSnapshotId.isNotEmpty || pendingGeneration != 0)) {
        throw StateError('普通备份不能携带待发送接管状态。');
      }
      if (exported['state_lineage_id'] != identity.lineageId ||
          exported['state_generation'] != identity.generation ||
          exported['source_device_id'] != identity.deviceId) {
        throw StateError('导出事务的状态身份与冻结身份不一致。');
      }

      await stateFile.writeAsBytes(jsonBytes, flush: true);
      final attachmentFiles = <String, String>{};
      final missingAttachmentFiles = <String>[];
      var attachmentBytes = 0;
      final attachments = await db.allMessageAttachments();
      final paths = <String>{
        for (final attachment in attachments) ...[
          attachment.originalPath,
          attachment.thumbnailPath,
        ],
      };
      for (final rawPath in paths) {
        final relative = MessageAttachmentStorage.requireSafeRelativePath(rawPath);
        final source = await attachmentStorage.fileFor(relative);
        if (!await source.exists()) {
          missingAttachmentFiles.add(relative);
          continue;
        }
        final length = await source.length();
        attachmentBytes += length;
        final target = File(
          p.joinAll([attachmentExportDirectory.path, ...relative.split('/')]),
        );
        await target.parent.create(recursive: true);
        await source.copy(target.path);
        attachmentFiles[relative] =
            (await sha256.bind(target.openRead()).first).toString();
      }
      final albumFiles = <String, String>{};
      final missingAlbumFiles = <String>[];
      var albumBytes = 0;
      for (final rawPath in _expectedAlbumPaths(exported)) {
        final relative = CompanionAlbumStorage.requireSafeRelativePath(rawPath);
        final source = await albumStorage.fileFor(relative);
        if (!await source.exists()) {
          missingAlbumFiles.add(relative);
          continue;
        }
        final length = await source.length();
        albumBytes += length;
        final target = File(
          p.joinAll([albumExportDirectory.path, ...relative.split('/')]),
        );
        await target.parent.create(recursive: true);
        await source.copy(target.path);
        albumFiles[relative] =
            (await sha256.bind(target.openRead()).first).toString();
      }
      final manifest = {
        'format': 'ai-companion-snapshot-zip',
        'protocol_version': 5,
        'archive_kind': archiveKind.key,
        'schema_version': AppDatabase.schemaVersion,
        'snapshot_id': snapshotId,
        'lineage_id': identity.lineageId,
        'source_device_id': identity.deviceId,
        'source_generation': identity.generation,
        'target_activation_generation': identity.generation + 1,
        'created_at': now.toIso8601String(),
        'state_sha256': digest,
        'state_bytes': jsonBytes.length,
        'attachment_files': attachmentFiles,
        'missing_attachment_files': missingAttachmentFiles,
        'attachment_bytes': attachmentBytes,
        'album_files': albumFiles,
        'missing_album_files': missingAlbumFiles,
        'album_bytes': albumBytes,
        'encryption': archiveKind.manifestEncryption,
        'zip_layout': 'files_only',
      };
      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
      );

      final encoder = ZipFileEncoder();
      try {
        encoder.create(zipPath);
        await encoder.addFile(stateFile);
        await encoder.addFile(manifestFile);
        final sortedAttachmentPaths = attachmentFiles.keys.toList()..sort();
        for (final relative in sortedAttachmentPaths) {
          final file = File(
            p.joinAll([
              attachmentExportDirectory.path,
              ...relative.split('/'),
            ]),
          );
          await encoder.addFile(file, 'attachments/$relative');
        }
        final sortedAlbumPaths = albumFiles.keys.toList()..sort();
        for (final relative in sortedAlbumPaths) {
          final file = File(
            p.joinAll([albumExportDirectory.path, ...relative.split('/')]),
          );
          await encoder.addFile(file, 'album/$relative');
        }
        await encoder.close();
      } catch (_) {
        try {
          await encoder.close();
        } catch (_) {}
        final partial = File(zipPath);
        if (await partial.exists()) await partial.delete();
        rethrow;
      }
      return SnapshotBundle(
        filePath: zipPath,
        metadata: SnapshotMetadata(
          snapshotId: snapshotId,
          lineageId: identity.lineageId,
          sourceDeviceId: identity.deviceId,
          sourceGeneration: identity.generation,
          targetActivationGeneration: identity.generation + 1,
          stateSha256: digest,
          stateBytes: jsonBytes.length,
          schemaVersion: AppDatabase.schemaVersion,
          createdAt: now,
          protocolVersion: 5,
          archiveKind: archiveKind,
        ),
      );
      } finally {
        // state.json contains the full unencrypted relationship history. Keep
        // the transport ZIP only as long as Nearby/manual encryption needs it;
        // never leave the expanded plaintext workspace behind in cache.
        if (await work.exists()) await work.delete(recursive: true);
      }
    } catch (_) {
      if (isTakeover) await db.cancelPreparedTransferSnapshot(snapshotId);
      rethrow;
    }
  }

  Future<SnapshotMetadata> inspectBundle(
    String zipPath, {
    bool allowLegacy = false,
  }) async {
    final validated = await _readValidatedBundle(zipPath, allowLegacy: allowLegacy);
    try {
      return validated.metadata;
    } finally {
      await validated.dispose();
    }
  }

  Future<SnapshotImportResult> importBundle(
    String zipPath, {
    bool allowLineageReplacement = false,
    bool allowLegacy = false,
  }) async {
    final validated = await _readValidatedBundle(zipPath, allowLegacy: allowLegacy);
    try {
      if (validated.metadata.isBackup) {
        throw const FormatException('这是普通备份，请使用“恢复加密备份”导入。');
      }
      return await _importValidatedBundle(
        validated,
        allowLineageReplacement: allowLineageReplacement,
      );
    } finally {
      await validated.dispose();
    }
  }

  Future<SnapshotImportResult?> restoreBackupBundle(
    String zipPath, {
    bool allowLineageReplacement = false,
    Future<bool> Function(SnapshotMetadata metadata)? confirmRestore,
  }) async {
    final validated = await _readValidatedBundle(zipPath, allowLegacy: false);
    try {
      if (!validated.metadata.isBackup) {
        throw const FormatException('这不是普通备份，请使用设备接管入口导入。');
      }
      if (confirmRestore != null &&
          !await confirmRestore(validated.metadata)) {
        return null;
      }
      return await _restoreValidatedBackup(
        validated,
        allowLineageReplacement: allowLineageReplacement,
      );
    } finally {
      await validated.dispose();
    }
  }

  Future<SnapshotImportResult> _importValidatedBundle(
    _ValidatedSnapshot validated, {
    required bool allowLineageReplacement,
  }) async {
    final metadata = validated.metadata;
    final localDeviceId = await db.ensureDeviceId();
    final localIdentity = await db.transferStateIdentity();

    final priorReceipt = await db.transferReceipt(metadata.snapshotId);
    if (priorReceipt != null) {
      if (priorReceipt.lineageId != metadata.lineageId ||
          priorReceipt.sourceGeneration != metadata.sourceGeneration ||
          priorReceipt.stateSha256 != metadata.stateSha256 ||
          priorReceipt.sourceDeviceId != metadata.sourceDeviceId) {
        throw const FormatException('检测到 snapshot_id 冲突，已拒绝导入。');
      }
      final pending = await db.pendingImportedTransfer();
      final mayRepairPending = pending?.snapshotId == metadata.snapshotId &&
          pending?.lineageId == metadata.lineageId &&
          pending?.sourceDeviceId == metadata.sourceDeviceId &&
          pending?.sourceGeneration == metadata.sourceGeneration &&
          pending?.stateSha256 == metadata.stateSha256;
      if (mayRepairPending) {
        await _replaceValidatedFiles(validated);
      }
      return SnapshotImportResult(
        metadata: metadata,
        imported: false,
        duplicate: true,
      );
    }

    if (metadata.lineageId != localIdentity.lineageId && !allowLineageReplacement) {
      throw SnapshotLineageMismatch(
        localLineageId: localIdentity.lineageId,
        incomingLineageId: metadata.lineageId,
      );
    }
    if (metadata.lineageId == localIdentity.lineageId &&
        metadata.sourceGeneration <= localIdentity.generation) {
      throw SnapshotStaleException(
        '状态包代次 ${metadata.sourceGeneration} 不新于本机代次 ${localIdentity.generation}，已拒绝旧包覆盖新状态。',
      );
    }

    final receipt = TransferReceipt(
      snapshotId: metadata.snapshotId,
      lineageId: metadata.lineageId,
      sourceDeviceId: metadata.sourceDeviceId,
      sourceGeneration: metadata.sourceGeneration,
      stateSha256: metadata.stateSha256,
      targetDeviceId: localDeviceId,
      targetLineageBefore: localIdentity.lineageId,
      targetGenerationBefore: localIdentity.generation,
      importedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final preparedFiles = await _prepareValidatedFiles(validated);
    try {
      // Files become live first while their exact previous trees remain beside
      // them for rollback. The database transaction only starts after both
      // complete incoming trees can be activated.
      await preparedFiles.activate();
      // Device identity and transport receipts are installation-local and must
      // never be overwritten by the source snapshot. Imported relationship
      // state remains frozen until takeover succeeds.
      await db.importAll(
        validated.backup,
        runtimeSettingOverrides: <String, String>{
        'device_id': localDeviceId,
        'state_lineage_id': metadata.lineageId,
        'state_generation': '${metadata.sourceGeneration}',
        'active_brain': '0',
        'transfer_lock': '1',
        'pending_outbound_snapshot_id': '',
        'pending_outbound_generation': '0',
        'pending_import_snapshot_id': metadata.snapshotId,
        'pending_import_lineage_id': metadata.lineageId,
        'pending_import_source_device_id': metadata.sourceDeviceId,
        'pending_import_generation': '${metadata.sourceGeneration}',
        'pending_import_state_sha256': metadata.stateSha256,
        'proactive_lease_until': '0',
        'memory_maintenance_lease_until': '0',
        'relationship_assimilation_lease_until': '0',
        'deferred_followup_lease_until': '0',
        'self_drive_lease_until': '0',
        'thought_lifecycle_lease_until': '0',
        'thought_consolidation_lease_until': '0',
        'ai_self_reflection_lease_until': '0',
        'conversation_summary_lease_until': '0',
        'long_running_maintenance_lease': '0',
        'post_turn_memory_lease': '0',
        'chat_turn_lease': '0',
        'recovery_orchestrator_lease_until': '0',
        'recovery_orchestrator_state': 'standby_after_import',
        'recovery_orchestrator_last_wake_reason': 'state_import',
        'recovery_orchestrator_last_started_at': '0',
        'recovery_orchestrator_last_completed_at': '0',
        'recovery_orchestrator_cycle_count': '0',
        'recovery_orchestrator_last_proactive_reason': '',
        'recovery_orchestrator_next_wake_at': '0',
        'recovery_orchestrator_next_heartbeat_at': '0',
        'recovery_orchestrator_last_error': '',
        'last_perception_capture_at': '0',
        'last_perception_summary': '',
        'last_long_usage_thought_at': '0',
        'last_long_usage_package': '',
        'last_accessibility_thought_text': '',
        'last_accessibility_thought_at': '0',
        },
        localTransferReceipt: receipt,
      );
    } catch (_) {
      await preparedFiles.rollback();
      rethrow;
    }
    await preparedFiles.commit();
    return SnapshotImportResult(
      metadata: metadata,
      imported: true,
      duplicate: false,
    );
  }

  Future<SnapshotImportResult> _restoreValidatedBackup(
    _ValidatedSnapshot validated, {
    required bool allowLineageReplacement,
  }) async {
    final metadata = validated.metadata;
    final localDeviceId = await db.ensureDeviceId();
    final localIdentity = await db.transferStateIdentity();
    if (metadata.lineageId != localIdentity.lineageId &&
        !allowLineageReplacement) {
      throw SnapshotLineageMismatch(
        localLineageId: localIdentity.lineageId,
        incomingLineageId: metadata.lineageId,
      );
    }

    final sameInstallation = metadata.sourceDeviceId == localDeviceId;
    final restoredGeneration =
        (localIdentity.generation > metadata.sourceGeneration
                ? localIdentity.generation
                : metadata.sourceGeneration) +
            1;
    final runtime = <String, String>{
      ..._restoredRuntimeSettings,
      'device_id': localDeviceId,
      'state_lineage_id': metadata.lineageId,
      'state_generation': '$restoredGeneration',
      'active_brain': sameInstallation ? '1' : '0',
      'recovery_orchestrator_state':
          sameInstallation ? 'idle_after_backup_restore' : 'standby_after_backup_restore',
      'recovery_orchestrator_last_wake_reason': 'backup_restore',
      'pending_import_snapshot_id': sameInstallation ? '' : metadata.snapshotId,
      'pending_import_lineage_id': sameInstallation ? '' : metadata.lineageId,
      'pending_import_source_device_id':
          sameInstallation ? '' : metadata.sourceDeviceId,
      'pending_import_generation':
          sameInstallation ? '0' : '$restoredGeneration',
      'pending_import_state_sha256':
          sameInstallation ? '' : metadata.stateSha256,
    };

    final preparedFiles = await _prepareValidatedFiles(validated);
    try {
      await preparedFiles.activate();
      await db.importAll(
        validated.backup,
        runtimeSettingOverrides: runtime,
      );
    } catch (_) {
      await preparedFiles.rollback();
      rethrow;
    }
    await preparedFiles.commit();
    return SnapshotImportResult(
      metadata: metadata,
      imported: true,
      duplicate: false,
      restoredFromBackup: true,
      requiresManualTakeover: !sameInstallation,
    );
  }

  Future<_PreparedSnapshotFiles> _prepareValidatedFiles(
    _ValidatedSnapshot validated,
  ) async {
    final attachments = await attachmentStorage.prepareSnapshotInstall(
      extractedAttachments: validated.attachmentsDirectory,
      expectedPaths: _expectedAttachmentPaths(validated.backup),
      snapshotId: validated.metadata.snapshotId,
    );
    try {
      final album = await albumStorage.prepareSnapshotInstall(
        extractedAlbum: validated.albumDirectory,
        expectedPaths: _expectedAlbumPaths(validated.backup),
        snapshotId: validated.metadata.snapshotId,
      );
      return _PreparedSnapshotFiles(attachments, album);
    } catch (_) {
      await attachments.rollback();
      rethrow;
    }
  }

  Future<void> _replaceValidatedFiles(_ValidatedSnapshot validated) async {
    final prepared = await _prepareValidatedFiles(validated);
    try {
      await prepared.activate();
    } catch (_) {
      await prepared.rollback();
      rethrow;
    }
    await prepared.commit();
  }

  Future<_ValidatedSnapshot> _readValidatedBundle(
    String zipPath, {
    required bool allowLegacy,
  }) async {
    final source = File(zipPath);
    if (!await source.exists()) {
      throw const FormatException('状态包文件不存在');
    }
    const maxArchiveBytes = 8 * 1024 * 1024 * 1024;
    if (await source.length() > maxArchiveBytes) {
      throw const FormatException('状态包异常过大，已拒绝导入');
    }

    final temp = await getTemporaryDirectory();
    final target = Directory(p.join(
      temp.path,
      'companion_import_${DateTime.now().microsecondsSinceEpoch}',
    ));
    await target.create(recursive: true);

    InputFileStream? input;
    Archive? archive;
    var retainTarget = false;
    try {
      input = InputFileStream(zipPath);
      archive = ZipDecoder().decodeStream(input);
      const maxStateBytes = 480 * 1024 * 1024;
      const maxManifestBytes = 1024 * 1024;
      const maxBundledFileBytes = 8 * 1024 * 1024 * 1024;
      const maxExpandedBytes = 9 * 1024 * 1024 * 1024;
      const maxArchiveEntries = 200000;
      final seen = <String>{};
      var stateSize = 0;
      var manifestSize = 0;
      var attachmentSize = 0;
      var albumSize = 0;
      var totalExpanded = 0;
      final directoryEntries = <String>[];
      const legacyDirectoryEntries = <String>{
        'attachments/',
        'attachments/originals/',
        'attachments/thumbnails/',
        'album/',
        'album/thumbnails/',
      };
      for (final entry in archive.files) {
        final name = entry.name;
        if (entry.isSymbolicLink) {
          throw FormatException('状态包不能包含符号链接：$name');
        }
        if (!entry.isFile && !entry.isDirectory) {
          throw FormatException('状态包包含不受支持的条目类型：$name');
        }
        if (name.contains('\\')) {
          throw FormatException('状态包路径不能包含反斜杠：$name');
        }
        final isDirectoryEntry = entry.isDirectory || name.endsWith('/');
        if (isDirectoryEntry) {
          if (!legacyDirectoryEntries.contains(name)) {
            throw FormatException('状态包包含不受支持的目录：$name');
          }
          directoryEntries.add(name);
        }
        final isAttachment = name.startsWith('attachments/');
        final isAlbum = name.startsWith('album/');
        if (name != 'state.json' &&
            name != 'manifest.json' &&
            !isAttachment &&
            !isAlbum) {
          throw FormatException('状态包含意外文件：$name');
        }
        if (isAttachment && !isDirectoryEntry) {
          MessageAttachmentStorage.requireSafeRelativePath(
            name.substring('attachments/'.length),
          );
        }
        if (isAlbum && !isDirectoryEntry) {
          CompanionAlbumStorage.requireSafeRelativePath(
            name.substring('album/'.length),
          );
        }
        if (!seen.add(name)) {
          throw FormatException('状态包包含重复文件：$name');
        }
        if (seen.length > maxArchiveEntries) {
          throw const FormatException('状态包文件数量异常过多');
        }
        final size = entry.size;
        if (size < 0) throw const FormatException('状态包文件大小异常');
        totalExpanded += size;
        if (name == 'state.json') stateSize = size;
        if (name == 'manifest.json') manifestSize = size;
        if (isAttachment && !isDirectoryEntry) attachmentSize += size;
        if (isAlbum && !isDirectoryEntry) albumSize += size;
      }
      if (!seen.contains('state.json') || !seen.contains('manifest.json')) {
        throw const FormatException('状态包必须包含 state.json 与 manifest.json');
      }
      if (stateSize <= 0 || stateSize > maxStateBytes) {
        throw const FormatException('state.json 大小异常');
      }
      if (manifestSize <= 0 || manifestSize > maxManifestBytes) {
        throw const FormatException('manifest.json 大小异常');
      }
      if (attachmentSize + albumSize > maxBundledFileBytes ||
          totalExpanded > maxExpandedBytes) {
        throw const FormatException('状态包解压后大小异常');
      }

      await extractArchiveToDisk(archive, target.path);
      final stateFile = File(p.join(target.path, 'state.json'));
      final manifestFile = File(p.join(target.path, 'manifest.json'));
      if (!await stateFile.exists() || !await manifestFile.exists()) {
        throw const FormatException('状态包缺少 state.json 或 manifest.json');
      }
      if (await stateFile.length() != stateSize ||
          await manifestFile.length() != manifestSize) {
        throw const FormatException('状态包解压结果大小不一致');
      }

      final manifestRaw = jsonDecode(await manifestFile.readAsString());
      if (manifestRaw is! Map) {
        throw const FormatException('manifest.json 格式不正确');
      }
      final manifest = Map<String, dynamic>.from(manifestRaw);
      if (manifest['format'] != 'ai-companion-snapshot-zip') {
        throw const FormatException('状态包格式不正确');
      }
      final zipLayout = manifest['zip_layout']?.toString() ?? '';
      if (zipLayout.isNotEmpty && zipLayout != 'files_only') {
        throw FormatException('状态包 ZIP 布局不受支持：$zipLayout');
      }
      if (zipLayout == 'files_only' && directoryEntries.isNotEmpty) {
        throw const FormatException('files-only 状态包不能包含目录条目');
      }
      final manifestVersion = (manifest['schema_version'] as num?)?.toInt();
      if (manifestVersion == null ||
          manifestVersion < 1 ||
          manifestVersion > AppDatabase.schemaVersion) {
        throw FormatException('状态包版本不受支持：$manifestVersion');
      }
      final bytes = await stateFile.readAsBytes();
      final actual = sha256.convert(bytes).toString();
      if (actual != manifest['state_sha256']) {
        throw const FormatException('状态包 SHA-256 校验失败');
      }
      final declaredBytes = (manifest['state_bytes'] as num?)?.toInt();
      if (declaredBytes != null && declaredBytes != bytes.length) {
        throw const FormatException('状态包声明大小与实际内容不一致');
      }
      final backupRaw = jsonDecode(utf8.decode(bytes));
      if (backupRaw is! Map) {
        throw const FormatException('state.json 格式不正确');
      }
      final backup = Map<String, dynamic>.from(backupRaw);
      if ((backup['schema_version'] as num?)?.toInt() != manifestVersion) {
        throw const FormatException('manifest 与 state.json 的版本不一致');
      }

      final protocolVersion = (manifest['protocol_version'] as num?)?.toInt() ?? 1;
      if (protocolVersion < 1 || protocolVersion > 5) {
        throw FormatException('状态包协议版本不受支持：$protocolVersion');
      }
      final archiveKind = protocolVersion >= 5
          ? SnapshotArchiveKind.parse(manifest['archive_kind']?.toString() ?? '')
          : SnapshotArchiveKind.takeover;
      _normalizeArchiveStateDomains(backup, protocolVersion);
      await _validateAttachmentPayload(
        target: target,
        manifest: manifest,
        backup: backup,
        protocolVersion: protocolVersion,
        observedAttachmentBytes: attachmentSize,
      );
      await _validateAlbumPayload(
        target: target,
        manifest: manifest,
        backup: backup,
        protocolVersion: protocolVersion,
        observedAlbumBytes: albumSize,
      );
      if (protocolVersion >= 2) {
        final snapshotId = manifest['snapshot_id'] as String? ?? '';
        final lineageId = manifest['lineage_id'] as String? ?? '';
        final sourceDeviceId = manifest['source_device_id'] as String? ?? '';
        final sourceGeneration = (manifest['source_generation'] as num?)?.toInt() ?? 0;
        final targetActivationGeneration =
            (manifest['target_activation_generation'] as num?)?.toInt() ?? 0;
        if (snapshotId.isEmpty ||
            lineageId.isEmpty ||
            sourceDeviceId.isEmpty ||
            !archiveKind.acceptsSourceGeneration(sourceGeneration)) {
          throw const FormatException('v2 状态包缺少必要身份字段');
        }
        if (targetActivationGeneration != sourceGeneration + 1) {
          throw const FormatException('状态包目标接管代次不连续');
        }
        if (backup['state_lineage_id'] != lineageId ||
            backup['state_generation'] != sourceGeneration ||
            backup['source_device_id'] != sourceDeviceId) {
          throw const FormatException('manifest 与 state.json 的状态身份不一致');
        }
        final pendingSnapshotId =
            _settingFromBackup(backup, 'pending_outbound_snapshot_id');
        final pendingGeneration = int.tryParse(
              _settingFromBackup(backup, 'pending_outbound_generation'),
            ) ??
            0;
        final sharedIdentityMatches =
            _settingFromBackup(backup, 'state_lineage_id') == lineageId &&
                int.tryParse(_settingFromBackup(backup, 'state_generation')) ==
                    sourceGeneration &&
                _settingFromBackup(backup, 'device_id') == sourceDeviceId;
        final archiveIntentMatches = archiveKind == SnapshotArchiveKind.takeover
            ? pendingSnapshotId == snapshotId &&
                pendingGeneration == sourceGeneration
            : pendingSnapshotId.isEmpty &&
                pendingGeneration == 0 &&
                _settingFromBackup(backup, 'transfer_lock') == '0' &&
                _settingFromBackup(backup, 'active_brain') == '1';
        if (!sharedIdentityMatches || !archiveIntentMatches) {
          throw const FormatException('状态包内部 settings、用途与 manifest 身份不一致');
        }
        final createdAt = DateTime.tryParse(manifest['created_at'] as String? ?? '')?.toUtc();
        if (createdAt == null) throw const FormatException('状态包创建时间无效');
        retainTarget = true;
        return _ValidatedSnapshot(
          SnapshotMetadata(
            snapshotId: snapshotId,
            lineageId: lineageId,
            sourceDeviceId: sourceDeviceId,
            sourceGeneration: sourceGeneration,
            targetActivationGeneration: targetActivationGeneration,
            stateSha256: actual,
            stateBytes: bytes.length,
            schemaVersion: manifestVersion,
            createdAt: createdAt,
            protocolVersion: protocolVersion,
            archiveKind: archiveKind,
          ),
          backup,
          target,
        );
      }

      if (!allowLegacy) {
        throw const FormatException('这是旧版状态包；Nearby 自动顶号要求两台设备都使用 v0.26+。');
      }
      final sourceDeviceId = _settingFromBackup(backup, 'device_id').isEmpty
          ? 'legacy-unknown-device'
          : _settingFromBackup(backup, 'device_id');
      final legacyLineage = 'legacy-${actual.substring(0, 32)}';
      final createdAt = DateTime.tryParse(manifest['created_at'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      retainTarget = true;
      return _ValidatedSnapshot(
        SnapshotMetadata(
          snapshotId: 'legacy-$actual',
          lineageId: legacyLineage,
          sourceDeviceId: sourceDeviceId,
          sourceGeneration: 1,
          targetActivationGeneration: 2,
          stateSha256: actual,
          stateBytes: bytes.length,
          schemaVersion: manifestVersion,
          createdAt: createdAt,
          protocolVersion: 1,
          archiveKind: SnapshotArchiveKind.takeover,
          legacy: true,
        ),
        backup,
        target,
      );
    } finally {
      if (archive != null) {
        try {
          await archive.clear();
        } catch (_) {}
      }
      if (input != null) {
        try {
          await input.close();
        } catch (_) {}
      }
      if (!retainTarget && await target.exists()) {
        await target.delete(recursive: true);
      }
    }
  }

  static void _normalizeArchiveStateDomains(
    Map<String, dynamic> backup,
    int protocolVersion,
  ) {
    final rawTables = backup['tables'];
    if (rawTables is! Map) {
      throw const FormatException('state.json 缺少数据表');
    }
    final tables = Map<String, dynamic>.from(rawTables);
    const completeArchiveTables = <String>[
      'autonomous_action_runs',
      'public_web_candidates',
      'companion_browser_visits',
      'companion_album_candidates',
    ];
    if (protocolVersion >= 4) {
      for (final table in completeArchiveTables) {
        if (tables[table] is! List) {
          throw FormatException('v4 状态包缺少完整状态表：$table');
        }
      }
    } else {
      // Protocol 1-3 never promised these domains. Clear them explicitly so a
      // target device cannot retain another relationship's local rows.
      for (final table in completeArchiveTables) {
        tables[table] = const <Object?>[];
      }
    }
    const personalityLearningTables = <String>[
      'personality_learning_candidates',
      'personality_learning_evidence',
    ];
    final schemaVersion = (backup['schema_version'] as num?)?.toInt() ?? 0;
    const interruptedTurnTable = 'interrupted_turn_displays';
    if (schemaVersion >= 48) {
      if (tables[interruptedTurnTable] is! List) {
        throw const FormatException('schema 48 状态包缺少中断回合显示表');
      }
    } else {
      tables[interruptedTurnTable] = const <Object?>[];
    }
    if (schemaVersion >= 42) {
      for (final table in personalityLearningTables) {
        if (tables[table] is! List) {
          throw FormatException('schema 42 状态包缺少人格学习表：$table');
        }
      }
    } else {
      // Schema 1-41 never promised the observation-only learning domain.
      // Import it as empty so an older complete archive cannot inherit rows
      // that already exist on the target device.
      for (final table in personalityLearningTables) {
        tables[table] = const <Object?>[];
      }
    }
    const personalityLearningRevisionTable =
        'personality_learning_evidence_revisions';
    if (schemaVersion >= 44) {
      if (tables[personalityLearningRevisionTable] is! List) {
        throw FormatException(
          'schema 44 状态包缺少人格学习审计表：$personalityLearningRevisionTable',
        );
      }
    } else {
      tables[personalityLearningRevisionTable] = const <Object?>[];
    }
    const selfExperienceTables = <String>[
      'self_review_candidates',
      'self_experiences',
      'desire_events',
    ];
    if (schemaVersion >= 43) {
      for (final table in selfExperienceTables) {
        if (tables[table] is! List) {
          throw FormatException('schema 43 状态包缺少自我体验表：$table');
        }
      }
    } else {
      // Schema 1-42 predates Phase 2A. Explicit empty lists prevent a restore
      // on an existing installation from retaining unrelated local evidence.
      for (final table in selfExperienceTables) {
        tables[table] = const <Object?>[];
      }
    }
    backup['tables'] = tables;
  }

  static Future<void> _validateAttachmentPayload({
    required Directory target,
    required Map<String, dynamic> manifest,
    required Map<String, dynamic> backup,
    required int protocolVersion,
    required int observedAttachmentBytes,
  }) async {
    final expected = _expectedAttachmentPaths(backup);
    if (protocolVersion < 3) {
      if (observedAttachmentBytes != 0 || expected.isNotEmpty) {
        throw const FormatException('旧版状态包不能包含图片附件');
      }
      return;
    }

    final rawHashes = manifest['attachment_files'];
    final rawMissing = manifest['missing_attachment_files'];
    if (rawHashes is! Map || rawMissing is! List) {
      throw const FormatException('状态包缺少图片附件清单');
    }
    final hashes = <String, String>{};
    for (final entry in rawHashes.entries) {
      final relative = MessageAttachmentStorage.requireSafeRelativePath(
        entry.key.toString(),
      );
      final digest = entry.value?.toString() ?? '';
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
        throw FormatException('图片附件校验值无效：$relative');
      }
      hashes[relative] = digest;
    }
    final missing = <String>{
      for (final item in rawMissing)
        MessageAttachmentStorage.requireSafeRelativePath(item.toString()),
    };
    final included = hashes.keys.toSet();
    final declared = included.union(missing);
    if (included.intersection(missing).isNotEmpty ||
        declared.length != expected.length ||
        !declared.containsAll(expected)) {
      throw const FormatException('图片附件清单与数据库记录不一致');
    }

    final attachmentDirectory = Directory(p.join(target.path, 'attachments'));
    final observed = <String>{};
    var actualBytes = 0;
    if (await attachmentDirectory.exists()) {
      await for (final entity in attachmentDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = MessageAttachmentStorage.requireSafeRelativePath(
          p.relative(entity.path, from: attachmentDirectory.path)
              .replaceAll('\\', '/'),
        );
        observed.add(relative);
        actualBytes += await entity.length();
        final digest = await sha256.bind(entity.openRead()).first;
        if (digest.toString() != hashes[relative]) {
          throw FormatException('图片附件 SHA-256 校验失败：$relative');
        }
      }
    }
    if (observed.length != included.length || !observed.containsAll(included)) {
      throw const FormatException('状态包中的图片文件与清单不一致');
    }
    final declaredBytes = (manifest['attachment_bytes'] as num?)?.toInt();
    if (actualBytes != observedAttachmentBytes || declaredBytes != actualBytes) {
      throw const FormatException('图片附件总大小与清单不一致');
    }
  }

  static Future<void> _validateAlbumPayload({
    required Directory target,
    required Map<String, dynamic> manifest,
    required Map<String, dynamic> backup,
    required int protocolVersion,
    required int observedAlbumBytes,
  }) async {
    final expected = _expectedAlbumPaths(backup);
    if (protocolVersion < 4) {
      if (observedAlbumBytes != 0 || expected.isNotEmpty) {
        throw const FormatException('旧版状态包不能包含私人相册图片');
      }
      return;
    }

    final rawHashes = manifest['album_files'];
    final rawMissing = manifest['missing_album_files'];
    if (rawHashes is! Map || rawMissing is! List) {
      throw const FormatException('状态包缺少私人相册文件清单');
    }
    final hashes = <String, String>{};
    for (final entry in rawHashes.entries) {
      final relative = CompanionAlbumStorage.requireSafeRelativePath(
        entry.key.toString(),
      );
      final digest = entry.value?.toString() ?? '';
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
        throw FormatException('私人相册校验值无效：$relative');
      }
      hashes[relative] = digest;
    }
    final missing = <String>{
      for (final item in rawMissing)
        CompanionAlbumStorage.requireSafeRelativePath(item.toString()),
    };
    final included = hashes.keys.toSet();
    final declared = included.union(missing);
    if (included.intersection(missing).isNotEmpty ||
        declared.length != expected.length ||
        !declared.containsAll(expected)) {
      throw const FormatException('私人相册文件清单与数据库记录不一致');
    }

    final albumDirectory = Directory(p.join(target.path, 'album'));
    final observed = <String>{};
    var actualBytes = 0;
    if (await albumDirectory.exists()) {
      await for (final entity in albumDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final relative = CompanionAlbumStorage.requireSafeRelativePath(
          p.relative(entity.path, from: albumDirectory.path)
              .replaceAll('\\', '/'),
        );
        observed.add(relative);
        actualBytes += await entity.length();
        final digest = await sha256.bind(entity.openRead()).first;
        if (digest.toString() != hashes[relative]) {
          throw FormatException('私人相册 SHA-256 校验失败：$relative');
        }
      }
    }
    if (observed.length != included.length || !observed.containsAll(included)) {
      throw const FormatException('状态包中的私人相册文件与清单不一致');
    }
    final declaredBytes = (manifest['album_bytes'] as num?)?.toInt();
    if (actualBytes != observedAlbumBytes || declaredBytes != actualBytes) {
      throw const FormatException('私人相册总大小与清单不一致');
    }
  }

  static Set<String> _expectedAttachmentPaths(Map<String, dynamic> backup) {
    final tables = backup['tables'];
    if (tables is! Map) return const <String>{};
    final rows = tables['message_attachments'];
    if (rows is! List) return const <String>{};
    final result = <String>{};
    for (final raw in rows) {
      if (raw is! Map) throw const FormatException('图片附件数据库记录无效');
      for (final key in const ['original_path', 'thumbnail_path']) {
        final value = raw[key]?.toString() ?? '';
        result.add(MessageAttachmentStorage.requireSafeRelativePath(value));
      }
    }
    return result;
  }

  static Set<String> _expectedAlbumPaths(Map<String, dynamic> backup) {
    final tables = backup['tables'];
    if (tables is! Map) return const <String>{};
    final rows = tables['companion_album_candidates'];
    if (rows is! List) return const <String>{};
    final result = <String>{};
    for (final raw in rows) {
      if (raw is! Map) throw const FormatException('私人相册数据库记录无效');
      final lifecycle = raw['lifecycle_state']?.toString() ?? '';
      final nsfw = (raw['nsfw'] as num?)?.toInt() ?? 0;
      final value = raw['thumbnail_path']?.toString() ?? '';
      if ((lifecycle == 'saved' || lifecycle == 'soft_deleted') &&
          nsfw == 0 &&
          value.isNotEmpty) {
        result.add(CompanionAlbumStorage.requireSafeRelativePath(value));
      }
    }
    return result;
  }

  static String _settingFromBackup(Map<String, dynamic> backup, String key) {
    final tables = backup['tables'];
    if (tables is! Map) return '';
    final rows = tables['settings'];
    if (rows is! List) return '';
    for (final raw in rows) {
      if (raw is! Map) continue;
      if (raw['key'] == key) return raw['value']?.toString() ?? '';
    }
    return '';
  }

  static void _normalizeBackupRuntimeSettings(Map<String, Object?> backup) {
    final rawTables = backup['tables'];
    if (rawTables is! Map) {
      throw const FormatException('普通备份缺少 settings 表。');
    }
    final rows = rawTables['settings'];
    if (rows is! List) {
      throw const FormatException('普通备份缺少 settings 表。');
    }
    final replacements = <String, String>{
      ..._restoredRuntimeSettings,
      'active_brain': '1',
      'recovery_orchestrator_state': 'idle',
      'recovery_orchestrator_last_wake_reason': 'backup_export',
    };
    final normalizedRows = <Map<String, Object?>>[];
    final seen = <String>{};
    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = Map<String, Object?>.from(raw);
      final key = row['key']?.toString() ?? '';
      final value = replacements[key];
      if (value != null) {
        row['value'] = value;
        seen.add(key);
      }
      normalizedRows.add(row);
    }
    for (final entry in replacements.entries) {
      if (seen.contains(entry.key)) continue;
      normalizedRows.add(<String, Object?>{
        'key': entry.key,
        'value': entry.value,
      });
    }
    rawTables['settings'] = normalizedRows;
  }

  static const Map<String, String> _restoredRuntimeSettings = <String, String>{
    'transfer_lock': '0',
    'pending_outbound_snapshot_id': '',
    'pending_outbound_generation': '0',
    'pending_import_snapshot_id': '',
    'pending_import_lineage_id': '',
    'pending_import_source_device_id': '',
    'pending_import_generation': '0',
    'pending_import_state_sha256': '',
    'proactive_lease_until': '0',
    'memory_maintenance_lease_until': '0',
    'relationship_assimilation_lease_until': '0',
    'deferred_followup_lease_until': '0',
    'self_drive_lease_until': '0',
    'thought_lifecycle_lease_until': '0',
    'thought_consolidation_lease_until': '0',
    'ai_self_reflection_lease_until': '0',
    'conversation_summary_lease_until': '0',
    'long_running_maintenance_lease': '0',
    'post_turn_memory_lease': '0',
    'chat_turn_lease': '0',
    'recovery_orchestrator_lease_until': '0',
    'recovery_orchestrator_last_started_at': '0',
    'recovery_orchestrator_last_completed_at': '0',
    'recovery_orchestrator_cycle_count': '0',
    'recovery_orchestrator_last_proactive_reason': '',
    'recovery_orchestrator_next_wake_at': '0',
    'recovery_orchestrator_next_heartbeat_at': '0',
    'recovery_orchestrator_last_error': '',
    'last_perception_capture_at': '0',
    'last_perception_summary': '',
    'last_long_usage_thought_at': '0',
    'last_long_usage_package': '',
    'last_accessibility_thought_text': '',
    'last_accessibility_thought_at': '0',
  };
}
