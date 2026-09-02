#!/usr/bin/env python3
"""Historical foundation contracts for v0.40.9 nondestructive backup."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
snapshot = read("lib/core/sync/snapshot_service.dart")
transfer = read("lib/features/transfer/transfer_page.dart")
bridge = read("lib/core/platform/android_bridge.dart")
system = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt")
multipart = read("android/app/src/main/kotlin/com/aicompanion/localfirst/MultipartBackupArchive.kt")
nearby = read("android/app/src/main/kotlin/com/aicompanion/localfirst/NearbyTransferManager.kt")
cleaner = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SnapshotCacheCleaner.kt")
dart_cleaner = read("lib/core/sync/snapshot_cache_janitor.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert re.search(r"^version:\s*(?:0\.40\.9\+138|0\.41\.(?:0\+139|1\+140|2\+141|3\+142|4\+143|5\+144|6\+145|7\+146|8\+147|9\+148|10\+149|11\+150|12\+151|13\+152|14\+153|15\+154|16\+155|17\+156|18\+157))\s*$", pubspec, re.M)

for token in (
    "enum SnapshotArchiveKind",
    "takeover('takeover')",
    "backup('backup')",
    "'protocol_version': 5",
    "'archive_kind': archiveKind.key",
    "Future<SnapshotBundle> exportBackupBundle()",
    "Future<SnapshotImportResult?> restoreBackupBundle(",
    "_normalizeBackupRuntimeSettings(exported)",
    "restoredFromBackup: true",
    "requiresManualTakeover: !sameInstallation",
    "'active_brain': sameInstallation ? '1' : '0'",
    "final preparedFiles = await _prepareValidatedFiles(validated)",
    "await preparedFiles.activate()",
    "await preparedFiles.rollback()",
):
    assert token in snapshot, token

assert snapshot.index("await preparedFiles.activate()", snapshot.index("_restoreValidatedBackup")) < snapshot.index(
    "await db.importAll(", snapshot.index("_restoreValidatedBackup")
)

for token in (
    "本机保持 Active",
    "512 MiB",
    "SnapshotCacheJanitor.clean()",
    "snapshots.exportBackupBundle()",
    "snapshots.restoreBackupBundle(",
):
    assert token in transfer, token

for token in ("saveMultipartBackup", "openMultipartBackup"):
    assert token in bridge and token in system, token

for token in (
    "DEFAULT_PART_BYTES = 192L * 1024L * 1024L",
    "SplitPartOutputStream",
    "VerifiedPartInputStream",
    "backup_manifest.json",
    "sha256",
    "backup_part_hash_mismatch",
    "DocumentsContract.deleteDocument",
    "backup_restore_space_insufficient",
    "StatFs(",
):
    assert token in multipart, token

assert "file.length() > MAX_NEARBY_PAYLOAD_BYTES" in nearby
assert nearby.index("file.length() > MAX_NEARBY_PAYLOAD_BYTES") < nearby.index("Payload.fromFile(file)")
assert "payload_too_large_use_multipart_backup" in nearby

for token in (
    "STALE_AFTER_MS = 24L * 60L * 60L * 1000L",
    "ai_companion_received_",
    "ai_companion_manual_",
    "ai_companion_backup_",
):
    assert token in cleaner, token
assert "static const Duration staleAfter = Duration(hours: 24)" in dart_cleaner
assert "activePaths" in cleaner and "activePaths" in dart_cleaner

assert "python3 tools/validate_v0409_nondestructive_backup.py" in workflow
assert (
    "Build AI Companion v0.40.9+138 APK (Nondestructive Backup)" in workflow
    or "Build AI Companion v0.41.0+139 APK (Plain Backup Overlay Desire)" in workflow
    or "Build AI Companion v0.41.1+140 APK (Backup Preflight & Screen Audit)" in workflow
    or "Build AI Companion v0.41.2+141 APK (Simple Backup File)" in workflow
)

print("v0.40.9 nondestructive backup validation passed")
