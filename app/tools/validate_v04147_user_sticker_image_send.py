#!/usr/bin/env python3
"""Structural, truth and privacy contracts for v0.41.47."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
labels = read("lib/core/stickers/sticker_pack.dart")
settings = read("lib/features/settings/sticker_settings_page.dart")
chat_page = read("lib/features/chat/chat_page.dart")
chat_controller = read("lib/features/chat/chat_controller.dart")
message = read("lib/core/models/chat_message.dart")
registry = read("lib/core/agent/agent_tool_registry.dart")
planner = read("lib/core/agent/agent_tool_planner.dart")
runner = read("lib/core/agent/agent_tool_runner.dart")
media = read("lib/core/media/assistant_image_attachment_service.dart")
downloader = read("lib/core/media/safe_public_image_downloader.dart")
durable = read("lib/core/ai/durable_generation_runner.dart")
guard = read("lib/core/grounding/operational_claim_grounding_guard.dart")
tests = "\n".join(
    read(path)
    for path in (
        "test/agent_tool_registry_test.dart",
        "test/agent_tool_planner_fast_route_test.dart",
        "test/sticker_expression_test.dart",
        "test/operational_claim_grounding_guard_test.dart",
    )
)
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert re.search(
    r"^version:\s*0\.41\.(?:47\+186|48\+187|49\+188|50\+189|51\+190|52\+191|53\+192|54\+193|55\+(?:195|196|197|198|199)|56\+200|57\+201|58\+202|59\+203|60\+204|61\+205|62\+206|63\+207|64\+208|65\+209|66\+210)$",
    pubspec,
    re.M,
)
assert re.search(r"static const int schemaVersion = (?:55|56|57|58|59|60|61);", database)
assert "agent/v04147-user-sticker-picker-image-send" in workflow
assert re.search(r"Build AI Companion v0\.41\.(?:47\+186|48\+187|49\+188) APK", workflow)
assert re.search(
    r"AI-Companion-v0\.41\.(?:47-186-User-Sticker-Image-Send|"
    r"48-187-Agent-Image-Reliability-Hotfix|"
    r"49-188-Subjective-Search-Humor-Restoration)-APK",
    workflow,
)

# Imported bytes and stable ids stay unchanged; aliases exist only at render sites.
for token in ("'personal-001' => '表情包A'", "'official-001' => '表情包B'", "tagName"):
    assert token in labels
assert "StickerDisplayLabels.packName" in settings
assert "manifest['name']" not in labels

# User sticker selection stages exactly one indexed item and bypasses vision.
for token in (
    "_SelectedUserSticker? _selectedUserSticker",
    "_StickerPickerSheet",
    "onLongPressStart",
    "onLongPressEnd",
    "_selectedUserSticker = null",
    "StickerDisplayLabels.tagName",
):
    assert token in chat_page
for token in (
    "source: 'user_sticker:",
    "visionModel: 'sticker_index'",
    "visionSummary: selectedRecord.caption",
    "attachments: preparedUserStickerAttachment",
):
    assert token in chat_controller
assert "for (final attachment in user.attachments)" in database
assert "isUser && item.source.startsWith('user_sticker:')" in message
assert "视觉模型观察" not in message[message.index("user_sticker:"):message.index("assistant_sticker:")]

# Both assistant image workflows are explicit proposal tools and real attachments.
for tool_id in ("image.web_send", "album.image_send"):
    assert f"id: '{tool_id}'" in registry
assert planner.index("_isExplicitAlbumImageSend") < planner.index("_isExplicitStickerSend")
assert "call.reasonTag == 'explicit_request'" in runner
assert "prepareWebCandidate" in runner and "prepareAlbumItem" in runner
assert runner.count("terminalCommitPending: true") >= 3
assert "attachments: preparedAgentAttachments" in durable
assert "if (!agentAttachmentsCommitted)" in durable
assert "deleteAttachmentFiles(attachment)" in durable

# Web bytes use an HTTPS/redirect/MIME/size boundary, then Qwen pixel matching.
for token in (
    "followRedirects = false",
    "unsafe_image_redirect",
    "MessageAttachmentStorage.maxImageBytes",
):
    assert token in media + downloader
for token in (
    "observation.requestMatch",
    "observation.requestMatchConfidence < 0.72",
    "source: 'assistant_web_image:",
):
    assert token in media
assert "source: 'assistant_album_image:" in media
assert "item.nsfw || item.lifecycle != CompanionAlbumItem.saved" in media
assert "ungrounded_image_send" in guard

for phrase in (
    "explicit web image send is distinct from saving to album",
    "explicit saved album image send stays local",
    "user sticker uses indexed meaning and never becomes vision input",
    "ordinary image send claims require a real current media result",
):
    assert phrase in tests

# Source control must never absorb imported packs or user-selected media.
private_media = [
    path
    for base in (ROOT / "lib" / "core" / "stickers", ROOT / "lib" / "core" / "media")
    for path in base.rglob("*")
    if path.is_file()
    and path.suffix.lower() in {".gif", ".jpg", ".jpeg", ".png", ".zip", ".aibackup"}
]
assert not private_media, private_media

print("v0.41.47 user sticker + image send validation passed")
