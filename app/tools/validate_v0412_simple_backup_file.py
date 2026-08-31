#!/usr/bin/env python3
"""Static contracts for v0.41.2 simple single-file backup UX."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
transfer = read("lib/features/transfer/transfer_page.dart")
bridge = read("lib/core/platform/android_bridge.dart")
system = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt")
snapshot = read("lib/core/sync/snapshot_service.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert re.search(r"^version:\s*0\.41\.(?:2\+141|3\+142|4\+143|5\+144)\s*$", pubspec, re.M)

export = transfer.split("Future<void> _backupExport()", 1)[1].split(
    "Future<void> _backupImport()", 1
)[0]
for token in (
    "snapshots.exportBackupBundle()",
    "snapshots.inspectBundle(bundle.filePath)",
    "metadata.isBackup",
    "android.savePlainBackup(",
    "saved['verified'] != true",
):
    assert token in export, token
assert (
    "备份文件已保存并自动检查通过" in export
    or "兼容性与完整性自动检查通过" in export
)
assert "saveMultipartBackup" not in export

for token in (
    "picker: android.openPlainBackup",
    "picker: android.openMultipartBackup",
    "恢复旧版文件夹备份",
    "点击保存后会得到一个备份文件，并自动检查是否完整",
    "保存备份",
    "恢复备份",
):
    assert token in transfer, token
assert "检查完整备份（不覆盖）" not in transfer
assert "每次创建独立存档文件夹" not in transfer

for token in (
    "Future<Map<String, Object?>?> savePlainBackup",
    "'savePlainBackup'",
    "Future<Map<String, Object?>?> openPlainBackup",
    "'openPlainBackup'",
):
    assert token in bridge, token

for token in (
    '"savePlainBackup" -> startPlainBackupSave(',
    '"openPlainBackup" -> startPlainBackupOpen(result = result)',
    "Intent.ACTION_CREATE_DOCUMENT",
    "Intent.ACTION_OPEN_DOCUMENT",
    '"plain_backup_saved_hash_mismatch"',
    '"verified" to true',
    "REQUEST_PLAIN_BACKUP_SAVE = 4210",
    "REQUEST_PLAIN_BACKUP_OPEN = 4211",
    "MAX_PLAIN_BACKUP_BYTES = 8L * 1024L * 1024L * 1024L",
):
    assert token in system, token

assert "SnapshotArchiveKind.backup => generation >= 0" in snapshot
assert "SnapshotArchiveKind.takeover => generation > 0" in snapshot

for token in (
    "Build AI Companion v0.41.2+141 APK (Simple Backup File)",
    "agent/v0412-simple-backup-file",
    "AI-Companion-v0.41.2-141-Simple-Backup-File-APK",
    "python3 tools/validate_v0412_simple_backup_file.py",
    ".ci/v0412-monitor.txt",
):
    assert token in workflow, token

print("v0.41.2 simple backup file validation passed")
