#!/usr/bin/env python3
"""Static contracts for v0.41.58 media-backup and Naiyou runtime hotfixes."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


assert "version: 0.41.59+203" in read("pubspec.yaml")
assert "static const buildLabel = 'v0.41.59+203';" in read(
    "lib/core/agent/agent_self_reader.dart"
)
assert "static const int schemaVersion = 59;" in read(
    "lib/core/database/app_database.dart"
)

backup = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/PortableBackupZipVerifier.kt"
)
backup_test = read(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/PortableBackupZipVerifierTest.kt"
)
assert 'name.startsWith("media/")' in backup
for token in (
    'Entry("media/originals/2b6bdd3d.jpg"',
    'Entry("media/thumbnails/2b6bdd3d.jpg"',
    'Entry("media/../escape.jpg"',
    "portable_backup_unsafe_entry",
    "portable_backup_unexpected_entry",
    "portable_backup_entry_crc_mismatch",
):
    assert token in backup + backup_test, token

sticker = read("lib/core/stickers/sticker_expression_service.dart")
sticker_ui = read("lib/features/settings/sticker_settings_page.dart")
for token in ("'low' => 0.12", "'frequent' => 0.42", "_ => 0.24"):
    assert token in sticker, token
for token in ("偶尔（12%）", "自然（24%）", "较多（42%）"):
    assert token in sticker_ui, token
for token in (
    "ordinaryReplySemanticContext",
    "latestUserText: latestUserText",
    "if (bestScore <= 0) return null;",
):
    assert token in sticker, token

segmenter = read("lib/core/tts/tts_sentence_segmenter.dart")
fixed = read("lib/core/tts/genie_fixed_text_segmenter.dart")
packer = read("lib/core/tts/tts_queued_segment_packer.dart")
queue = read("lib/core/tts/tts_playback_queue.dart")
player = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/WavAudioPlayer.kt"
)
assert "_buffer.substring(0, boundary.end).trim()" in segmenter
assert "_buffer.substring(0, boundary.start).trim()" not in segmenter
for token in (
    "splitFirstImmediate",
    "pieces.skip(1)",
    "TtsQueuedSegmentPacker.packPrefix",
    "session.rawUnitsSubmitted == 0",
    "await _generateAwaited",
    "!session.rawWorkerActive",
):
    assert token in fixed + packer + queue, token
assert "currentSpeed != 1.0f || currentPitch != 1.0f" in player
assert "PlaybackParams()" in player and ".setPitch(currentPitch)" in player

workflow = read("../.github/workflows/build-apk.yml")
for token in (
    "Build AI Companion v0.41.59+203 APK",
    "validate_v04158_backup_naiyou_runtime.py",
    "AI-Companion-v0.41.59-203-Tiandou-Pitch-Recovery-APK",
    "genie-tts-private-runtime-v0.6.4",
    "complete T2S and per-file integrity metadata",
):
    assert token in workflow, token

ledger = read("../AI_Companion_当前总账.md")
for token in (
    "v0.41.58+202 共享媒体备份",
    "1758ee687435922a43df7872c5e660e601754ea30cc248e38f84cd4480ac9812",
    "12%/24%/42%",
    "CI PENDING",
):
    assert token in ledger, token

print("v0.41.58 backup and Naiyou runtime hotfix contracts passed")
