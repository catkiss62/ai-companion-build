#!/usr/bin/env python3
"""Structural contracts for the v0.41.48 Agent image reliability hotfix."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
self_reader = read("lib/core/agent/agent_self_reader.dart")
storage = read("lib/core/stickers/sticker_pack_storage.dart")
labels = read("lib/core/stickers/sticker_pack.dart")
worldbook = read("lib/core/reference/world_book_display_order.dart")
reference_ui = read("lib/features/reference/reference_library_page.dart")
segments = read("lib/core/models/chat_segment.dart")
chat_ui = read("lib/features/chat/chat_page.dart")
planner = read("lib/core/agent/agent_tool_planner.dart")
registry = read("lib/core/agent/agent_tool_registry.dart")
runner = read("lib/core/agent/agent_tool_runner.dart")
self_reader = read("lib/core/agent/agent_self_reader.dart")
sticker_service = read("lib/core/stickers/sticker_expression_service.dart")
guard = read("lib/core/grounding/operational_claim_grounding_guard.dart")
downloader = read("lib/core/media/safe_public_image_downloader.dart")
media = read("lib/core/media/assistant_image_attachment_service.dart")
discovery = read("lib/core/phone/companion_album_discovery_engine.dart")
web = read("lib/core/autonomy/layered_public_web_provider.dart")
wikimedia = read("lib/core/autonomy/wikimedia_public_web_provider.dart")
database = read("lib/core/database/app_database.dart")
durable = read("lib/core/ai/durable_generation_runner.dart")
tests = "\n".join(
    read(path)
    for path in (
        "test/sticker_expression_test.dart",
        "test/world_book_display_order_test.dart",
        "test/action_tint_text_test.dart",
        "test/chat_visuals_test.dart",
        "test/agent_tool_planner_fast_route_test.dart",
        "test/agent_tool_registry_test.dart",
        "test/operational_claim_grounding_guard_test.dart",
        "test/safe_public_image_downloader_test.dart",
        "test/wikimedia_public_web_provider_v0348_test.dart",
        "test/layered_public_web_provider_v0349_test.dart",
    )
)
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert re.search(
    r"^version:\s*0\.41\.(?:48\+187|49\+188|50\+189|51\+190|52\+191|53\+192|54\+193|55\+(?:195|196|197|198|199)|56\+200|57\+201)$",
    pubspec,
    re.M,
)
assert "buildLabel = 'v0.41.48+187'" in self_reader
assert "agent/v04148-agent-image-reliability-hotfix" in workflow
assert "Build AI Companion v0.41.48+187 APK" in workflow
assert "AI-Companion-v0.41.48-187-Agent-Image-Reliability-Hotfix-APK" in workflow

assert "packs.sort(StickerDisplayLabels.comparePacks)" in storage
assert "'personal-001': 0" in labels and "'official-001': 1" in labels
assert "class StickerAgencyPolicy" in labels
assert "StickerAgencyPolicy.isVisible" in chat_ui
assert "sticker agency exposes NSFW and dark humor but hides group-chat waste" in tests
assert "'nsfw' => '涩涩'" in labels
assert "static bool shouldUseStickerOnly" in sticker_service
assert "stickerBattle || explicitStickerTool" in sticker_service
assert "userStickerAttachments" in durable
assert "content: stickerOnly ? '' : baseAssistant.content" in durable
assert "用户只发表情包也会进入斗图回应" in self_reader
assert "自主让一张表情包承担整条回复" in self_reader
assert "lastPersonalityOrPosture + 1" in worldbook
assert "WorldBookDisplayOrder.arrange" in reference_ui

assert "ChatSegmentCodec.displayText(segments)" in chat_ui
assert "static String displayText" in segments
assert "proactive leading dialogue stays tinted" in tests

for phrase in ("查手机", "存起来", "任意安全图片"):
    assert phrase in planner
assert "userTurnModelCallable" in registry and "allowedForCurrentText" in planner
assert "latestUserText: user.content" in durable
assert "_isGenericAlbumImageRequest" in runner
assert "take(6)" in runner
assert "(传|贴)" in guard

for token in (
    "followRedirects = false",
    "detectSupportedMime",
    "unsupported_image_bytes",
):
    assert token in downloader
assert "MessageAttachmentStorage.maxImageBytes" in media
assert "SafePublicImageDownloader.download" in media
assert "SafePublicImageDownloader.download" in discovery
assert "_requiresImageCandidates" in web
assert "endsWith('.wikimedia.org')" in wikimedia
assert "lifecycle_state = 'expired'" in database

for phrase in (
    "natural 查手机 photo wording routes to a real album attachment",
    "存起来 is an explicit web image save command",
    "proposal tools are model-callable only for matching explicit text",
    "detects supported images from bytes instead of CDN MIME headers",
    "explicit image work always supplements brittle primary image URLs",
    "sticker battle and sticker-only wording route to real sticker tool",
    "real sticker actions may carry the whole reply without dialogue",
):
    assert phrase in tests

print("v0.41.48 Agent image reliability validation passed")
