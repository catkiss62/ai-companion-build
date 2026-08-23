#!/usr/bin/env python3
from hashlib import sha256
from pathlib import Path
from struct import unpack

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
    "assets/lingchat/effects/",
    "assets/lingchat/NOTICE.md",
):
    assert token in pubspec, token

visuals = read("lib/core/presentation/chat_visuals.dart")
for token in (
    "enum ChatPortraitAnimation",
    "class ChatEmotionVisual",
    "class ChatVisualChunk",
    "static List<ChatVisualChunk> chunks",
    "ChatPortraitAnimation.happyBounce",
    "ChatPortraitAnimation.angryJump",
    "ChatPortraitAnimation.seriousThink",
    "ChatPortraitAnimation.heartBeat",
    "ChatPortraitAnimation.naughtyBounce",
    "ChatPortraitAnimation.embarrassedShake",
    "assets/lingchat/deepseek/excited.webp",
    "assets/lingchat/deepseek/disgust.webp",
    "assets/lingchat/deepseek/afraid.webp",
    "assets/lingchat/deepseek/tense.webp",
    "assets/lingchat/deepseek/ashamed.webp",
    "assets/lingchat/effects/dialogue.webp",
    "assets/lingchat/effects/heart.webp",
    "assets/lingchat/audio/disgust.wav",
    "assets/lingchat/audio/shock.wav",
    "assets/lingchat/audio/chat.wav",
    "assets/lingchat/audio/pleasant.wav",
):
    assert token in visuals, token
assert visuals.count("key: '") == 20
assert "AnimatedSwitcher" not in visuals

portrait_stage = read("lib/widgets/chat_portrait_stage.dart")
for token in (
    "class ChatPortraitStage",
    "class ChatPortraitTransformEditor",
    "gaplessPlayback: true",
    "SingleTickerProviderStateMixin",
    "ChatPortraitTransform.defaults",
    "单指拖动位置，双指缩放立绘",
    "label: const Text('还原')",
    "label: const Text('确定')",
):
    assert token in portrait_stage, token

chat = read("lib/features/chat/chat_page.dart")
for token in (
    "DeepSeek",
    "_openQuickPanel",
    "chat_panel_fraction",
    "chat_panel_opacity",
    "chat_portrait_scale",
    "chat_portrait_offset_x",
    "chat_portrait_offset_y",
    "ChatPortraitStage(",
    "ChatPortraitTransformEditor(",
    "自定义立绘",
    "_AssistantSegmentSequence",
    "_BubbleTailPainter",
    "message.isProactive && animateSegments",
    "情绪短音效",
    "主动消息提示音",
    "TTS 朗读内容",
    "选择后还需要在系统通知管理中允许对应频道的声音和横幅。",
    "只影响 App 内聊天；不改悬浮窗结构。",
):
    assert token in chat, token
assert "duration: const Duration(milliseconds: 240)" not in chat

contract = read("lib/core/emotion/emotion_contract.dart")
assert "'crying': '伤心'" in contract
for token in (
    "'哭泣': 'crying'",
    "'羞耻': 'embarrassed'",
    "'尴尬': 'embarrassed'",
    "'无语': 'helpless'",
    "'情动': 'affection'",
    "'慌乱': 'flustered'",
):
    assert token in contract, token

notice = read("assets/lingchat/NOTICE.md")
for token in (
    "https://github.com/SlimeBoyOwO/LingChat",
    "eae0d667413e490c3653488d43ce9b4464e07fda",
    "GNU AGPL v3",
    "21 DeepSeek portrait files",
    "all 16 upstream expression-effect WebP files",
    "all 23 upstream audio-effect files",
    "disabled by default",
):
    assert token in notice, token

expected_effects = {
    "ai_thinking.webp",
    "sigh.webp",
    "shy.webp",
    "noticed.webp",
    "heart.webp",
    "surprised.webp",
    "flustered.webp",
    "sweat.webp",
    "tears.webp",
    "angry.webp",
    "angry_alt.webp",
    "question.webp",
    "nervous.webp",
    "dialogue.webp",
    "embarrassed.webp",
    "happy.webp",
}
expected_audio = {
    "achievement_common.wav",
    "achievement_rare.wav",
    "sad.wav",
    "disgust.wav",
    "sigh.wav",
    "joy.wav",
    "affection.wav",
    "troubled.wav",
    "shy.wav",
    "noticed.wav",
    "dialogue.wav",
    "awkward.wav",
    "thinking.wav",
    "surprised.wav",
    "pleasant.wav",
    "speechless.wav",
    "sweat.wav",
    "angry.wav",
    "question.wav",
    "chat.wav",
    "role_volume_test.wav",
    "transition.wav",
    "shock.wav",
}
expected_portraits = {
    "avatar.webp",
    "normal.webp",
    "calm.webp",
    "happy.webp",
    "excited.webp",
    "playful.webp",
    "confident.webp",
    "serious.webp",
    "confused.webp",
    "helpless.webp",
    "worried.webp",
    "surprised.webp",
    "flustered.webp",
    "shy.webp",
    "affection.webp",
    "angry.webp",
    "sad.webp",
    "disgust.webp",
    "afraid.webp",
    "tense.webp",
    "ashamed.webp",
}
assert {p.name for p in (ROOT / "assets/lingchat/effects").iterdir()} == expected_effects
assert {p.name for p in (ROOT / "assets/lingchat/audio").iterdir()} == expected_audio
assert {p.name for p in (ROOT / "assets/lingchat/deepseek").iterdir()} == expected_portraits
assert {p.name for p in (ROOT / "assets/lingchat/background").iterdir()} == {
    "day.webp",
    "night.webp",
}

asset_files = [
    path
    for path in (ROOT / "assets/lingchat").rglob("*")
    if path.is_file() and path.name != "NOTICE.md"
]
assert len(asset_files) == 62, len(asset_files)
for path in asset_files:
    data = path.read_bytes()
    assert len(data) > 100, (path, len(data))
    assert not data.startswith(b"version https://git-lfs.github.com/spec"), path
    assert len(sha256(data).hexdigest()) == 64

fetcher = read("tools/fetch_lingchat_visual_assets.sh")
mapping_lines = [
    line for line in fetcher.splitlines()
    if line.startswith(("data/", "public/")) and "|" in line
]
assert len(mapping_lines) == 62, len(mapping_lines)
assert "(reused)" in fetcher

manifest = read("android/app/src/main/AndroidManifest.xml")
assert 'android:icon="@drawable/companion_launcher_icon"' in manifest
launcher = (ROOT / "android/app/src/main/res/drawable-nodpi/companion_launcher_icon.png").read_bytes()
assert launcher.startswith(b"\x89PNG\r\n\x1a\n")
assert unpack(">II", launcher[16:24]) == (512, 512)
assert sha256(launcher).hexdigest() == (
    "01b4ac59905ab303c6241ab24ab3d2f59b253510cbe2c1f5a3420e1a8568347e"
)

print("current App chat 19-expression visual parity validation passed")
