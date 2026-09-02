#!/usr/bin/env python3
"""Static contracts for v0.41.0 plain backup, overlay routing and Desire balance."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
transfer = read("lib/features/transfer/transfer_page.dart")
bridge = read("lib/core/platform/android_bridge.dart")
app = read("lib/app.dart")
chat = read("lib/features/chat/chat_controller.dart")
policy = read("lib/core/desire/desire_core_policy.dart")
extractor = read("lib/core/ai/memory_extractor.dart")
database = read("lib/core/database/app_database.dart")
presence = read("lib/core/presence/presence_intelligence.dart")
system = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt")
multipart = read("android/app/src/main/kotlin/com/aicompanion/localfirst/MultipartBackupArchive.kt")
manual_crypto = read("android/app/src/main/kotlin/com/aicompanion/localfirst/ManualSnapshotCrypto.kt")
multipart_test = read(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/MultipartBackupArchiveTest.kt"
)
desire_test = read("test/desire_core_policy_v031_test.dart")
architecture = read("docs/PHONE_PRIMARY_TABLET_COMPANION_ARCHITECTURE_v1.md")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert re.search(r"^version:\s*0\.41\.(?:0\+139|1\+140|2\+141|3\+142|4\+143|5\+144|6\+145|7\+146|8\+147|9\+148|10\+149|11\+150|12\+151|13\+152|14\+153|15\+154|16\+155|17\+156|18\+157|19\+158|20\+159)\s*$", pubspec, re.M)
simple_file_backup = re.search(r"^version:\s*0\.41\.(?:2\+141|3\+142|4\+143|5\+144|6\+145|7\+146|8\+147|9\+148|10\+149|11\+150|12\+151|13\+152|14\+153|15\+154|16\+155|17\+156|18\+157|19\+158|20\+159)\s*$", pubspec, re.M) is not None

if simple_file_backup:
    for token in (
        "保存备份",
        "恢复备份",
        "恢复旧版文件夹备份",
        "snapshots.exportBackupBundle()",
        "snapshots.restoreBackupBundle(",
    ):
        assert token in transfer, token
else:
    for token in (
        "完整备份",
        "创建完整备份",
        "恢复完整备份",
        "备份不设置口令、不加密",
        "每次创建独立存档文件夹",
        "snapshots.exportBackupBundle()",
        "snapshots.restoreBackupBundle(",
    ):
        assert token in transfer, token
assert "_askPassphrase('创建完整备份" not in transfer
assert "_askPassphrase('恢复完整备份" not in transfer

for token in ("saveMultipartBackup", "openMultipartBackup"):
    assert token in bridge and token in system, token
backup_bridge = bridge.split("Future<Map<String, Object?>?> saveMultipartBackup", 1)[1].split(
    "Future<Map<String, Object?>?> openMultipartBackup", 1
)[0]
assert "passphrase" not in backup_bridge
open_bridge = bridge.split("Future<Map<String, Object?>?> openMultipartBackup", 1)[1].split(
    "Future<", 1
)[0]
assert "passphrase" not in open_bridge

for token in (
    'FORMAT = "ai-companion-backup-parts"',
    "FORMAT_VERSION = 2",
    '.put("protection", "none")',
    '.put("archive_bytes"',
    'manifest.optString("protection") == "none"',
    "SplitPartOutputStream",
    "VerifiedPartInputStream",
    "backup_part_hash_mismatch",
    "backup_restore_space_insufficient",
    "DocumentsContract.deleteDocument",
):
    assert token in multipart, token
assert "ManualSnapshotCrypto.encrypt" not in multipart
assert "ManualSnapshotCrypto.decrypt" not in multipart
assert "AES/GCM/NoPadding" in manual_crypto
assert "manualTakeoverAesGcmEnvelopeRoundTripsAcrossParts" in multipart_test
assert "plainBackupManifestDeclaresNoProtectionAndRoundTrips" in multipart_test
assert "encryptedOrLegacyManifestIsRejectedByPlainBackupImporter" in multipart_test

open_chat = app.split("void _openChat()", 1)[1].split("@override", 1)[0]
assert "rootNavigator: true" in open_chat
assert "popUntil(" in open_chat
assert "route.isFirst" in open_chat
assert "index = 1" in open_chat
consume = app.split("Future<void> _consumeOpenChatLaunch()", 1)[1].split("@override", 1)[0]
assert "_openChat();" in consume

assert "ordinaryConversationPulses" in chat
assert "DriveKey.attachment: 0.018" not in chat
for token in (
    "postTurnPulseBudget = 0.055",
    "postTurnPulseCaps",
    "ordinaryConversationPulses",
    "normalizePostTurnPulses",
):
    assert token in policy, token
assert "DesireCorePolicy.normalizePostTurnPulses(pulses)" in extractor
assert "final normalizedPulses = DesireCorePolicy.normalizePostTurnPulses(pulses);" in database
assert "double baselineLearning = 0.002" in database
assert (
    "DriveKey.attachment: 0.002 + result.score * 0.004" in presence
    or (
        "drive: DriveKey.curiosity" in presence
        and "DriveKey.social: 0.001 + result.score * 0.002" in presence
        and "legacy.driveKey == DriveKey.attachment.name" in presence
    )
)
assert "post-turn model pulses have per-drive and whole-turn budgets" in desire_test
assert "rapid ordinary conversation does not mechanically pin attachment" in desire_test

for token in (
    "手机 App 是唯一主数据源、唯一 Active Brain",
    "平板安装同一套代码或兼容的伴随模式",
    "普通 `.aibackup`",
    "添加平板伴随端时绝不导入此备份",
    "端到端加密",
):
    assert token in architecture, token

assert "python3 tools/validate_v0410_plain_backup_overlay_desire.py" in workflow
assert (
    "Build AI Companion v0.41.0+139 APK (Plain Backup Overlay Desire)" in workflow
    or "Build AI Companion v0.41.1+140 APK (Backup Preflight & Screen Audit)" in workflow
    or "Build AI Companion v0.41.2+141 APK (Simple Backup File)" in workflow
)

print("v0.41.0 plain backup, overlay routing and Desire balance validation passed")
