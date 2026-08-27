#!/usr/bin/env python3
"""Static contracts for v0.39.5 time, TTS cancellation and translation."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


assert "version: 0.39.5+123" in read("pubspec.yaml")
assert "static const int schemaVersion = 35;" in read(
    "lib/core/database/app_database.dart"
)

immersive_prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
for token in (
    "DateTime? now",
    "realityTimeSection(now ?? DateTime.now())",
    "【现实系统时间 / REAL-WORLD CLOCK】",
    "设备当地日期",
    "UTC offset",
    "现实钟表流逝不会自动推进、覆盖或重写虚构场景时间",
):
    assert token in immersive_prompt, token

translation = read("lib/core/ai/reasoning_translation.dart")
language = read("lib/core/diagnostics/visible_reasoning_language_telemetry.dart")
panel = read("lib/widgets/reasoning_panel.dart")
for token in (
    "ReasoningTranslationCoordinator",
    "DeepSeekModelProfile.flash",
    "thinking: false",
    "requestMessages(source)",
    "只输出译文本身",
    "GenerationCancellationToken",
    "_entries.clear()",
):
    assert token in translation, token
for token in (
    "shouldOfferTranslation",
    "VisibleReasoningLanguageStatus.mixed",
    "VisibleReasoningLanguageStatus.mainlyEnglish",
    "```[\\s\\S]*?```",
):
    assert token in language, token
for token in (
    "翻译成中文",
    "翻译中…",
    "翻译失败，点击重试",
    "Color(0xFF8B5CF6)",
    "TextDecoration.underline",
):
    assert token in panel, token

chat = read("lib/features/chat/chat_page.dart")
immersive_page = read("lib/features/immersive/immersive_room_page.dart")
for source in (chat, immersive_page):
    assert "TtsPlaybackPhase.idle" in source
    assert "onPressed: onPressed" in source
    assert "? '停止合成'" in source
    assert "onPressed: synthesizing ? null : onPressed" not in source
    assert "ReasoningTranslationCoordinator" in source
    assert "translationCoordinator:" in source

translation_test = read("test/reasoning_translation_test.dart")
time_test = read("test/immersive_reality_time_test.dart")
for token in (
    "translation is manual, cached for the page lifetime and toggleable",
    "Chinese-first reasoning never starts a translation request",
    "disposing a page cancels an unfinished translation",
    "underlined purple manual link",
):
    assert token in translation_test, token
assert "distinguishes the device clock from story time" in time_test

workflow = read("../.github/workflows/build-apk.yml")
assert "python3 tools/validate_v0395_time_tts_reasoning_translation.py" in workflow
assert "agent/v0395-time-tts-reasoning-translation" in workflow
assert "AI-Companion-v0.39.5-123-Time-TTS-Reasoning-Translation-APK" in workflow

print("v0.39.5 time/TTS/reasoning translation contracts passed")
