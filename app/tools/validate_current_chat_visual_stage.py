#!/usr/bin/env python3
from hashlib import sha256
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("pubspec.yaml")
for token in (
    "assets/lingchat/background/",
    "assets/lingchat/deepseek/",
    "assets/lingchat/audio/",
    "assets/lingchat/NOTICE.md",
):
    assert token in pubspec, token

visuals = read("lib/core/presentation/chat_visuals.dart")
for token in (
    "class ChatEmotionVisual",
    "class ChatVisualChunk",
    "static List<ChatVisualChunk> chunks",
    "assets/lingchat/deepseek/normal.webp",
    "assets/lingchat/audio/joy.wav",
):
    assert token in visuals, token

chat = read("lib/features/chat/chat_page.dart")
for token in (
    "DeepSeek",
    "_openQuickPanel",
    "chat_panel_fraction",
    "chat_panel_opacity",
    "_AssistantSegmentSequence",
    "_BubbleTailPainter",
    "!item.message!.isProactive",
    "情绪短音效",
    "只影响 App 内聊天；不改悬浮窗结构。",
):
    assert token in chat, token

database = read("lib/core/database/app_database.dart")
for token in (
    "'chat_visual_stage_enabled': '1'",
    "'chat_background_mode': 'auto'",
    "'chat_panel_opacity': '0.72'",
    "'chat_panel_fraction': '0.62'",
    "'chat_typewriter_enabled': '1'",
    "'emotion_sound_enabled': '0'",
):
    assert token in database, token

notice = read("assets/lingchat/NOTICE.md")
for token in (
    "https://github.com/SlimeBoyOwO/LingChat",
    "eae0d667413e490c3653488d43ce9b4464e07fda",
    "GNU AGPL v3",
    "disabled by default",
):
    assert token in notice, token

expected_minimum_sizes = {
    "assets/lingchat/background/day.webp": 100_000,
    "assets/lingchat/background/night.webp": 100_000,
    "assets/lingchat/deepseek/avatar.webp": 10_000,
    "assets/lingchat/deepseek/normal.webp": 100_000,
    "assets/lingchat/audio/joy.wav": 10_000,
}
for relative, minimum in expected_minimum_sizes.items():
    data = (ROOT / relative).read_bytes()
    assert len(data) >= minimum, (relative, len(data))
    assert not data.startswith(b"version https://git-lfs.github.com/spec"), relative
    assert len(sha256(data).hexdigest()) == 64

asset_files = [
    path
    for path in (ROOT / "assets/lingchat").rglob("*")
    if path.is_file() and path.name != "NOTICE.md"
]
assert len(asset_files) == 37, len(asset_files)

print("current App chat visual stage validation passed")
