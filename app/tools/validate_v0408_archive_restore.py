#!/usr/bin/env python3
"""Static contracts for v0.40.8 complete archive restore correctness."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
snapshot = read("lib/core/sync/snapshot_service.dart")
swap = read("lib/core/storage/snapshot_directory_swap.dart")
transfer = read("lib/features/transfer/transfer_page.dart")
tests = read("test/snapshot_directory_swap_test.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert re.search(r"^version:\s*(?:0\.40\.(?:8\+137|9\+138)|0\.41\.(?:0\+139|1\+140|2\+141|3\+142|4\+143|5\+144|6\+145|7\+146|8\+147|9\+148|10\+149|11\+150))\s*$", pubspec, re.M)
assert "static const int schemaVersion = 40;" in database

export = database.split("Future<Map<String, Object?>> exportAll()", 1)[1].split(
    "Future<void> importAll(", 1
)[0]
import_all = database.split("Future<void> importAll(", 1)[1].split(
    "static String _bounded", 1
)[0]
pristine = database.split("Future<bool> isPristineForLineageAdoption()", 1)[1].split(
    "Future<int> activatePendingImportedBrain", 1
)[0]

state_tables = (
    "autonomous_action_runs",
    "public_web_candidates",
    "companion_browser_visits",
    "companion_album_candidates",
)
for table in state_tables:
    assert f"'{table}'" in export, table
    assert f"'{table}'" in import_all, table
    assert f"'{table}'" in pristine, table

for local_table in (
    "maintenance_runs",
    "provider_health_events",
    "proactive_policy_events",
    "memory_retrieval_audit",
    "transfer_receipts",
):
    assert f"'{local_table}'" not in export, local_table

assert import_all.index("'autonomous_action_runs'") < import_all.index(
    "'public_web_candidates'"
)
assert "Future<bool> cancelPreparedTransferSnapshot(String snapshotId)" in database
assert "'state_generation': '${current + 1}'" in database

assert "'protocol_version': 4" in snapshot or "'protocol_version': 5" in snapshot
assert "protocolVersion: 4" in snapshot or "protocolVersion: 5" in snapshot
assert "protocolVersion > 4" in snapshot or "protocolVersion > 5" in snapshot
for token in (
    "'album_files': albumFiles",
    "'missing_album_files': missingAlbumFiles",
    "'album_bytes': albumBytes",
    "_validateAlbumPayload(",
    "_normalizeArchiveStateDomains(backup, protocolVersion)",
    "final preparedFiles = await _prepareValidatedFiles(validated)",
    "await preparedFiles.activate()",
    "await db.importAll(",
    "await preparedFiles.rollback()",
    "await preparedFiles.commit()",
    "if (mayRepairPending)",
):
    assert token in snapshot, token

assert snapshot.index("await preparedFiles.activate()") < snapshot.index(
    "await db.importAll("
)
receipt_branch = snapshot.split("if (priorReceipt != null)", 1)[1].split(
    "if (metadata.lineageId", 1
)[0]
assert "_replaceValidatedFiles(validated)" in receipt_branch
assert "if (mayRepairPending)" in receipt_branch

for token in (
    "await targetDirectory.rename(backupDirectory.path)",
    "await stagedDirectory.rename(targetDirectory.path)",
    "await backupDirectory.rename(targetDirectory.path)",
):
    assert token in swap, token

for token in (
    "hasCompleteArchiveState",
    "这是旧版状态包",
    "不包含她的自主联网记录、查手机浏览器历史和私人相册",
    "cancelPreparedTransferSnapshot(bundle.metadata.snapshotId)",
    "invalidatePending: false",
):
    assert token in transfer, token

for token in (
    "rollback restores the exact previous live tree",
    "commit keeps only the complete incoming tree",
    "unsafe expected path aborts preparation without touching live tree",
):
    assert token in tests, token

assert "python3 tools/validate_v0408_archive_restore.py" in workflow
assert (
    "Build AI Companion v0.40.8+137 APK (Archive Restore Correctness)" in workflow
    or "Build AI Companion v0.40.9+138 APK (Nondestructive Backup)" in workflow
    or "Build AI Companion v0.41.0+139 APK (Plain Backup Overlay Desire)" in workflow
    or "Build AI Companion v0.41.1+140 APK (Backup Preflight & Screen Audit)" in workflow
    or "Build AI Companion v0.41.2+141 APK (Simple Backup File)" in workflow
)

print("v0.40.8 archive restore correctness validation passed")
