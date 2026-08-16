import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../storage/message_attachment_storage.dart';
import 'transfer_identity.dart';

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
  final bool legacy;
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
  });

  final SnapshotMetadata metadata;
  final bool imported;
  final bool duplicate;
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

  Future<void> dispose() async {
    if (await workDirectory.exists()) {
      await workDirectory.delete(recursive: true);
    }
  }
}

class SnapshotService {
  SnapshotService(
    this.db, {
    MessageAttachmentStorage? attachmentStorage,
  }) : attachmentStorage = attachmentStorage ?? MessageAttachmentStorage();

  final AppDatabase db;
  final MessageAttachmentStorage attachmentStorage;
  final Uuid _uuid = const Uuid();

  Future<SnapshotBundle> exportBundle() async {
    final snapshotId = _uuid.v4();
    final identity = await db.reserveTransferSnapshot(snapshotId);
    final exported = await db.exportAll();
    final jsonBytes = utf8.encode(jsonEncode(exported));
    final digest = sha256.convert(jsonBytes).toString();
    final now = DateTime.now().toUtc();
    final temp = await getTemporaryDirectory();
    final stamp = now.toIso8601String().replaceAll(':', '-');
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final work = Directory(p.join(temp.path, 'companion_snapshot_work_$nonce'));
    final zipPath = p.join(temp.path, 'ai_companion_${stamp}_$nonce.zip');
    await work.create(recursive: true);

    final stateFile = File(p.join(work.path, 'state.json'));
    final manifestFile = File(p.join(work.path, 'manifest.json'));
    final attachmentExportDirectory = Directory(p.join(work.path, 'attachments'));
    try {
      final pendingSnapshotId = _settingFromBackup(exported, 'pending_outbound_snapshot_id');
      final pendingGeneration = int.tryParse(
            _settingFromBackup(exported, 'pending_outbound_generation'),
          ) ??
          -1;
      if (pendingSnapshotId != snapshotId || pendingGeneration != identity.generation) {
        throw StateError('冻结状态代次与导出内容不一致，已拒绝生成状态包。');
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
          p.join(attachmentExportDirectory.path, ...relative.split('/')),
        );
        await target.parent.create(recursive: true);
        await source.copy(target.path);
        attachmentFiles[relative] = sha256.convert(await target.readAsBytes()).toString();
      }
      final manifest = {
        'format': 'ai-companion-snapshot-zip',
        'protocol_version': 3,
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
        'encryption': 'nearby_transport_or_manual_aes_gcm',
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
        if (await attachmentExportDirectory.exists()) {
          await encoder.addDirectory(attachmentExportDirectory);
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
          protocolVersion: 2,
        ),
      );
    } finally {
      // state.json contains the full unencrypted relationship history. Keep the
      // transport ZIP only as long as Nearby/manual encryption needs it; never
      // leave the expanded plaintext workspace behind in cache.
      if (await work.exists()) await work.delete(recursive: true);
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
      return await _importValidatedBundle(
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
      await _installValidatedAttachments(validated);
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

    // Device identity and transport receipts are installation-local and must
    // never be overwritten by the source snapshot. Imported relationship state
    // remains frozen until an ACK-bound or explicit manual takeover succeeds.
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
    await _installValidatedAttachments(validated);
    return SnapshotImportResult(
      metadata: metadata,
      imported: true,
      duplicate: false,
    );
  }

  Future<void> _installValidatedAttachments(
    _ValidatedSnapshot validated,
  ) async {
    await attachmentStorage.installSnapshotAttachments(
      validated.attachmentsDirectory,
      _expectedAttachmentPaths(validated.backup),
    );
  }

  Future<_ValidatedSnapshot> _readValidatedBundle(
    String zipPath, {
    required bool allowLegacy,
  }) async {
    final source = File(zipPath);
    if (!await source.exists()) {
      throw const FormatException('状态包文件不存在');
    }
    const maxArchiveBytes = 768 * 1024 * 1024;
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
      const maxAttachmentBytes = 512 * 1024 * 1024;
      const maxExpandedBytes = 768 * 1024 * 1024;
      final seen = <String>{};
      var stateSize = 0;
      var manifestSize = 0;
      var attachmentSize = 0;
      var totalExpanded = 0;
      for (final entry in archive.files) {
        final name = entry.name.replaceAll('\\', '/');
        final isAttachment = name.startsWith('attachments/');
        if (name != 'state.json' && name != 'manifest.json' && !isAttachment) {
          throw FormatException('状态包含意外文件：$name');
        }
        if (isAttachment && !name.endsWith('/')) {
          MessageAttachmentStorage.requireSafeRelativePath(
            name.substring('attachments/'.length),
          );
        }
        if (!seen.add(name)) {
          throw FormatException('状态包包含重复文件：$name');
        }
        final size = entry.size;
        if (size < 0) throw const FormatException('状态包文件大小异常');
        totalExpanded += size;
        if (name == 'state.json') stateSize = size;
        if (name == 'manifest.json') manifestSize = size;
        if (isAttachment && !name.endsWith('/')) attachmentSize += size;
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
      if (attachmentSize > maxAttachmentBytes || totalExpanded > maxExpandedBytes) {
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
      await _validateAttachmentPayload(
        target: target,
        manifest: manifest,
        backup: backup,
        protocolVersion: protocolVersion,
        observedAttachmentBytes: attachmentSize,
      );
      if (protocolVersion >= 2) {
        final snapshotId = manifest['snapshot_id'] as String? ?? '';
        final lineageId = manifest['lineage_id'] as String? ?? '';
        final sourceDeviceId = manifest['source_device_id'] as String? ?? '';
        final sourceGeneration = (manifest['source_generation'] as num?)?.toInt() ?? 0;
        final targetActivationGeneration =
            (manifest['target_activation_generation'] as num?)?.toInt() ?? 0;
        if (snapshotId.isEmpty || lineageId.isEmpty || sourceDeviceId.isEmpty || sourceGeneration <= 0) {
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
        if (_settingFromBackup(backup, 'state_lineage_id') != lineageId ||
            int.tryParse(_settingFromBackup(backup, 'state_generation')) != sourceGeneration ||
            _settingFromBackup(backup, 'device_id') != sourceDeviceId ||
            _settingFromBackup(backup, 'pending_outbound_snapshot_id') != snapshotId ||
            int.tryParse(_settingFromBackup(backup, 'pending_outbound_generation')) != sourceGeneration) {
          throw const FormatException('状态包内部 settings 与 manifest 身份不一致');
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
        final bytes = await entity.readAsBytes();
        actualBytes += bytes.length;
        if (sha256.convert(bytes).toString() != hashes[relative]) {
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
}
