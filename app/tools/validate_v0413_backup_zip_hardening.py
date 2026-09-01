#!/usr/bin/env python3
"""Static contracts for v0.41.3 portable backup ZIP hardening."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
snapshot = read("lib/core/sync/snapshot_service.dart")
transfer = read("lib/features/transfer/transfer_page.dart")
system = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt")
verifier = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/PortableBackupZipVerifier.kt"
)
verifier_test = read(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/PortableBackupZipVerifierTest.kt"
)
ledger = (ROOT.parent / "AI_Companion_当前总账.md").read_text(encoding="utf-8")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert re.search(r"^version:\s*0\.41\.(?:3\+142|4\+143|5\+144|6\+145|7\+146|8\+147|9\+148|10\+149|11\+150|12\+151)\s*$", pubspec, re.M)

export = snapshot.split(
    "Future<SnapshotBundle> _exportBundle", 1
)[1].split("Future<SnapshotMetadata> inspectBundle", 1)[0]
for token in (
    "'zip_layout': 'files_only'",
    "attachmentFiles.keys.toList()..sort()",
    "albumFiles.keys.toList()..sort()",
    "await encoder.addFile(file, 'attachments/$relative')",
    "await encoder.addFile(file, 'album/$relative')",
):
    assert token in export, token
assert "encoder.addDirectory(" not in export

reader = snapshot.split("Future<_ValidatedSnapshot> _readValidatedBundle", 1)[1]
for token in (
    "final directoryEntries = <String>[]",
    "const maxArchiveEntries = 200000",
    "seen.length > maxArchiveEntries",
    "const legacyDirectoryEntries = <String>{",
    "if (!legacyDirectoryEntries.contains(name))",
    "name.contains('\\\\')",
    "if (entry.isSymbolicLink)",
    "!entry.isFile && !entry.isDirectory",
    "entry.isDirectory || name.endsWith('/')",
    "manifest['zip_layout']?.toString() ?? ''",
    "zipLayout != 'files_only'",
    "zipLayout == 'files_only' && directoryEntries.isNotEmpty",
    "files-only 状态包不能包含目录条目",
):
    assert token in reader, token

for token in (
    "object PortableBackupZipVerifier",
    "ZipFile(file).use",
    "CRC32()",
    "!entry.isDirectory",
    "isSafeFileName(name)",
    "isAllowedFileName(name)",
    "seen.add(name)",
    "actualSize == declaredSize",
    "crc.value == declaredCrc",
    '"state.json"',
    '"manifest.json"',
    "MAX_EXPANDED_BYTES",
):
    assert token in verifier, token

save = system.split('"plain_backup_save" ->', 1)[1].split(
    '"plain_backup_open" ->', 1
)[0]
for token in (
    "PortableBackupZipVerifier.verify(source)",
    "copyWithDigest(",
    "savedDigest == sourceDigest",
    '"zipVerified" to true',
    '"zipEntryCount" to portable.entryCount',
):
    assert token in save, token

for token in (
    "saved['verified'] != true || saved['zipVerified'] != true",
    "兼容性与完整性自动检查通过",
):
    assert token in transfer, token

for token in (
    "filesOnlyBackupIsReadAndCrcChecked",
    "directoryEntriesAreRejectedEvenWhenTheirZipEncodingIsValid",
    "unsafeUnexpectedAndMissingEntriesAreRejected",
    "storedEntryCrcTamperingIsRejected",
):
    assert token in verifier_test, token

for token in (
    "v0.41.3 单文件备份 ZIP 兼容性加固",
    "invalid compressed data to inflate",
    "agent/v0413-backup-zip-hardening",
):
    assert token in ledger, token

for token in (
    "Build AI Companion v0.41.4+143 APK (Personality Seed Backup Closure)",
    "agent/v0414-personality-seed-backup-closure",
    "AI-Companion-v0.41.4-143-Personality-Seed-Backup-Closure-APK",
    "python3 tools/validate_v0413_backup_zip_hardening.py",
    ".ci/v0414-monitor.txt",
):
    assert token in workflow, token

print("v0.41.3 backup ZIP hardening validation passed")
