#!/usr/bin/env python3
"""Static contracts for v0.41.57 chat, media and expression fixes."""

from hashlib import sha256
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def dart_block(source: str, name: str) -> str:
    match = re.search(rf"const {name} = r?'''(.*?)''';", source, re.S)
    assert match, name
    return match.group(1)


assert "version: 0.41.57+201" in read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
assert "static const int schemaVersion = 58;" in database

worldbooks = read("lib/core/reference/world_book_content_v04156_user.dart")
natural = dart_block(worldbooks, "worldBookNaturalDialogueV04157")
assert len(natural) == 2242
assert sha256(natural.encode()).hexdigest() == (
    "13189a1fcb24f10eb071f455356ffd902d3eafa1abb8466a28580b768bf9a393"
)
assert "worldbook_natural_user_default_v04157_applied" in database
assert "399dbcade44c15ce4af3f215df27ed193de04991644371dbbd79f2caabed8f11" in database
assert "13189a1fcb24f10eb071f455356ffd902d3eafa1abb8466a28580b768bf9a393" in database
assert "'raw_content': worldBookNaturalDialogueV04157" in database
assert "content: worldBookNaturalDialogueV04157" in read(
    "lib/core/reference/world_book_presets.dart"
)

policy = read("lib/core/presentation/generation_presentation_policy.dart")
chat = read("lib/features/chat/chat_page.dart")
for token in (
    "required bool discoveredUser",
    "discoveredUser ||",
    "required bool discoveredAssistant",
):
    assert token in policy, token
for token in (
    "if (message.isUser)",
    "discoveredUser: discoveredUser",
    "if (discoveredUser)",
    "_followLatest = true;",
    "_anchorTimelineTail();",
):
    assert token in chat, token

presentation_tests = read("test/generation_presentation_policy_test.dart")
assert "TTS-only notifications never request a chat scroll" in presentation_tests
assert "a newly committed user message always returns chat to the bottom" in presentation_tests

immersive = read("lib/features/immersive/immersive_room_page.dart")
immersive_send = immersive[
    immersive.index("Future<void> _send() async") : immersive.index(
        "Future<void> _renameRoom", immersive.index("Future<void> _send() async")
    )
]
assert "_followLatest = true;" in immersive_send
assert "await controller.send(text);" in immersive_send
assert "_scheduleFollowLatest();" in immersive

overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
overlay_send = overlay[
    overlay.index("private fun sendFromOverlay()") : overlay.index(
        "private fun", overlay.index("private fun sendFromOverlay()") + 20
    )
]
assert "loadedMessages.add(optimistic)" in overlay_send
assert "scrollChatToBottom()" in overlay_send
tts_poll = overlay[
    overlay.index("private fun pollTtsState") : overlay.index(
        "private fun applyGenerationSnapshot"
    )
]
assert "scrollChatToBottom()" not in tts_poll

settings = read("lib/features/settings/settings_category_pages.dart")
cache = read("lib/features/settings/media_cache_page.dart")
for token in (
    "清理重复图片与表情包",
    "exact-SHA",
    "旧重复副本",
):
    assert token in settings + cache, token
for token in (
    "扫描旧重复副本",
    "确认清理",
    "final report = await _optimizer.scan()",
    "final result = await _optimizer.optimize()",
):
    assert token in cache, token

sticker = read("lib/core/stickers/sticker_expression_service.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
sticker_ui = read("lib/features/settings/sticker_settings_page.dart")
for token in (
    "'low' => 0.12",
    "'frequent' => 0.55",
    "_ => 0.36",
    "ordinaryReplySemanticContext",
    "ordinaryReplyCandidateScore",
    "latestUserText: latestUserText",
    "if (bestScore <= 0) return null;",
):
    assert token in sticker, token
assert "latestUserText: user.content" in runner
for token in ("偶尔（12%）", "自然（36%）", "较多（55%）"):
    assert token in sticker_ui, token

workflow = read("../.github/workflows/build-apk.yml")
for token in (
    "Build AI Companion v0.41.57+201 APK",
    "validate_v04157_chat_media_expression.py",
    "AI-Companion-v0.41.57-201-Chat-Media-Naiyou-APK",
    "genie-tts-private-runtime-v0.7.1-naiyou",
    "Genie-TTS-v0.7.1-Naiyou-Runtime.zip",
    "assets/benchmark_naiyou/*",
    "'naiyou_growth',   # candidate 3 -> daily",
    "'naiyou_hello',    # candidate 2 -> gentle",
    "'naiyou_dog',      # candidate 4 -> lively",
    "'naiyou_dynamic',  # candidate 1 -> cute",
    "removed candidate 5, Tiandou and external RoBERTa",
):
    assert token in workflow, token

runtime = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt"
)
catalog = read(
    "android/app/src/main/kotlin/com/catkiss62/geniettsbenchmark/VoiceProfileCatalog.kt"
)
service = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsIsolatedService.kt"
)
for token in (
    '"daily" to "naiyou_growth"',
    '"gentle" to "naiyou_hello"',
    '"lively" to "naiyou_dog"',
    '"cute" to "naiyou_dynamic"',
):
    assert token in runtime, token
for token in (
    '"naiyou_growth", "daily", "奶油候选 3 · 日常"',
    '"naiyou_hello", "gentle", "奶油候选 2 · 温柔"',
    '"naiyou_dog", "lively", "奶油候选 4 · 活泼"',
    '"naiyou_dynamic", "cute", "奶油候选 1 · 可爱"',
):
    assert token in catalog, token
for forbidden in ("naiyou_lesson", '"daily" to "ref01"', '"cute" to "ref06"'):
    assert forbidden not in runtime + catalog, forbidden
assert "奶油 V2" in service
assert "918a26bf55d7e06dffd08277c6a4bcb703f5b17b" in service

print("v0.41.57 chat, media and expression contracts passed")
