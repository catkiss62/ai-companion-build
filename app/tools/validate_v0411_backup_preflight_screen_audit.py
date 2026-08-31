#!/usr/bin/env python3
"""Static contracts for v0.41.1 backup preflight and screen audit."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
snapshot = read("lib/core/sync/snapshot_service.dart")
transfer = read("lib/features/transfer/transfer_page.dart")
database = read("lib/core/database/app_database.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
coordinator = read("lib/core/autonomy/autonomous_action_coordinator.dart")
archive_test = read("test/snapshot_archive_contract_v0411_test.dart")
registry_test = read("test/agent_tool_registry_test.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert re.search(r"^version:\s*0\.41\.(?:1\+140|2\+141|3\+142|4\+143|5\+144|6\+145)\s*$", pubspec, re.M)
simple_file_backup = re.search(r"^version:\s*0\.41\.(?:2\+141|3\+142|4\+143|5\+144|6\+145)\s*$", pubspec, re.M) is not None
assert "static const int schemaVersion = 40;" in database

for token in (
    "bool acceptsSourceGeneration(int generation)",
    "SnapshotArchiveKind.takeover => generation > 0",
    "SnapshotArchiveKind.backup => generation >= 0",
    "!archiveKind.acceptsSourceGeneration(sourceGeneration)",
    "String get manifestEncryption",
    "SnapshotArchiveKind.backup => 'none'",
    "'encryption': archiveKind.manifestEncryption",
):
    assert token in snapshot, token
assert "manual_multipart_aes_256_gcm" not in snapshot

if simple_file_backup:
    assert "picker: android.openMultipartBackup" in transfer
    assert "恢复旧版文件夹备份" in transfer
    assert "检查完整备份（不覆盖）" not in transfer
    export = transfer.split("Future<void> _backupExport()", 1)[1].split(
        "Future<void> _backupImport()", 1
    )[0]
    assert "snapshots.inspectBundle(bundle.filePath)" in export
    assert "saved['verified'] != true" in export
else:
    verify = transfer.split("Future<void> _backupVerify()", 1)[1].split(
        "@override", 1
    )[0]
    for token in (
        "android.openMultipartBackup()",
        "snapshots.inspectBundle(checkedPath)",
        "metadata.isBackup",
        "没有覆盖或修改本机数据",
        "_deleteCachePath(checkedPath)",
    ):
        assert token in verify, token
    assert "transfer_lock" not in verify
    assert "检查完整备份（不覆盖）" in transfer

for token in (
    "'phase': 'public_web_scheduled_screen_foundation_only'",
    "'implementationStatus': 'not_implemented'",
    "'schedulerAvailable': false",
    "'providerAvailable': false",
    "'futureLimit': 6",
    "'remaining': null",
):
    assert token in database, token
assert "0 次不是低概率未命中" in diagnostics
assert "!registered.executable || !registered.autonomousAvailable" in coordinator

assert "backup.acceptsSourceGeneration(0), isTrue" in archive_test
assert "takeover.acceptsSourceGeneration(0), isFalse" in archive_test
assert "SnapshotArchiveKind.backup.manifestEncryption, 'none'" in archive_test
assert "expect(screen.executable, isFalse)" in registry_test

assert "python3 tools/validate_v0411_backup_preflight_screen_audit.py" in workflow
if simple_file_backup:
    for token in (
        "Build AI Companion v0.41.2+141 APK (Simple Backup File)",
        "agent/v0412-simple-backup-file",
        "AI-Companion-v0.41.2-141-Simple-Backup-File-APK",
    ):
        assert token in workflow, token
else:
    for token in (
        "Build AI Companion v0.41.1+140 APK (Backup Preflight & Screen Audit)",
        "agent/v0411-backup-preflight-screen-audit",
        "AI-Companion-v0.41.1-140-Backup-Preflight-Screen-Audit-APK",
    ):
        assert token in workflow, token

print("v0.41.1 backup preflight and screen audit validation passed")
