#!/usr/bin/env python3
"""Structural and privacy contracts for v0.41.45 sticker expression."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
message = read("lib/core/models/chat_message.dart")
pack = read("lib/core/stickers/sticker_pack_storage.dart")
service = read("lib/core/stickers/sticker_expression_service.dart")
settings = read("lib/features/settings/sticker_settings_page.dart")
chat = read("lib/features/chat/chat_page.dart")
notice = read("docs/THIRD_PARTY_NOTICES.md")
design = read("docs/STICKER_EXPRESSION_v0.41.45.md")
test = read("test/sticker_expression_test.dart")
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert re.search(
    r"^version:\s*0\.41\.(?:45\+184|46\+185|47\+186|48\+187|49\+188|50\+189|51\+190|52\+191|53\+192|54\+193|55\+(?:195|196|197|198|199))$",
    pubspec,
    re.M,
)
assert re.search(r"static const int schemaVersion = (?:55|56|57);", database)
assert "agent/v04145-sticker-expression" in workflow
assert "Build AI Companion v0.41.45+184 APK" in workflow
assert "AI-Companion-v0.41.45-184-Sticker-Expression-APK" in workflow

for token in (
    "manifest.json",
    "index.db",
    "memes/",
    "maxArchiveBytes",
    "maxExpandedBytes",
    "entry.isSymbolicLink",
    "requireSafeArchivePath",
    "requireSafePackPath",
    "PreparedDirectorySwap.prepare",
    "tone_scope",
    "intensity",
    "enabled",
    "StickerImportBatchResult",
    "maxBundlePacks",
    "requireRootBundleZipNames",
    "组合包包含重复的表情包 ID",
    "_setPacksEnabled",
):
    assert token in pack

for mode, probability in (
    ("low", "0.12"),
    ("natural", "0.24"),
    ("frequent", "0.42"),
):
    assert f"'{mode}'" in service
    assert probability in service
for token in (
    "DialogueResponseMode.casual",
    "_eligibleSpeechActs",
    "_boldSpeechActs",
    "StickerAgencyPolicy.isAssistantSelectable",
    "take(18)",
    "assistant_sticker:",
    "visionModel: 'sticker_index'",
    "speechless",
):
    assert token in service

# This is an expression branch after ordinary generation, not a new autonomous
# candidate, desire state or external/model tool call.
for forbidden in (
    "DesireSnapshot",
    "ProactiveSelectionPolicy",
    "autonomous_behavior_events",
    "PublicWebDiscovery",
    "DeepSeekClient",
    "Qwen",
):
    assert forbidden not in service
assert "maybePrepareForOrdinaryReply" in runner
assert "if (agentToolResults.isEmpty)" in runner
assert runner.index("finalContent.trim().isEmpty") < runner.index(
    "maybePrepareForOrdinaryReply"
)
assert "completeGenerationJobIfCurrent" in runner
assert "deleteAttachmentFiles" in service
assert "for (final attachment in assistant.attachments)" in database
assert "for (final attachment in message.attachments)" in database

assert "[我发送了一张表情包" in message
assert "[我发送了一张图片；图片内容：" in message
assert "animatedSticker" in chat
assert "maxWidth: 180" in chat
assert "message.isUser" in chat
assert "图库只保存在内部目录" in settings
assert "不进入查手机相册或当前 AI Companion 备份" in settings
assert "当前 AI Companion 备份" in settings
assert "不改欲望、不增加主动消息、不另调模型" in settings
assert "CompanionAlbum" not in pack

for url in (
    "https://github.com/yyh-001/dsh-meme",
    "https://github.com/yyh-001/dsh-meme-packs",
    "https://github.com/nanbengxian-cyber/dafeiyu-qq-bot",
):
    assert url in notice
    assert url in design
assert "MIT" in notice
assert "Copyright 2026 Selfloom contributors" in notice
assert "does not bundle" in notice

for phrase in (
    "maps existing companion emotion keys to six local moods",
    "accepts upstream tags and fixes speechless locally",
    "rejects traversal, absolute and directory record paths",
    "assistant sticker history stays first-person",
    "accepts only root-level ZIP files in a multi-pack bundle",
    "assistant image history never loses first-person ownership",
):
    assert phrase in test

# The public change must not contain common private pack media extensions under
# the new sticker implementation tree.
new_media = [
    path
    for path in (ROOT / "lib/core/stickers").rglob("*")
    if path.suffix.lower() in {".jpg", ".jpeg", ".png", ".gif", ".webp"}
]
assert not new_media, new_media

print("v0.41.45 sticker expression validation passed")
