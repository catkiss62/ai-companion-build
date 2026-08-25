#!/usr/bin/env python3
"""Validate v0.38.3 D3 expression, Chinese reasoning and normal/calm semantics."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
contract = read("lib/core/emotion/emotion_contract.dart")
classifier = read("lib/core/emotion/emotion_classifier_service.dart")
visuals = read("lib/core/presentation/chat_visuals.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
adapter = read("lib/core/integration/moe_expression_prompt_adapter.dart")
appearance = read("lib/features/self/personality_appearance_page.dart")
telemetry = read("lib/core/diagnostics/visible_reasoning_language_telemetry.dart")
preflight = read("lib/core/diagnostics/preflight_diagnostics.dart")
emotion_tests = read("test/emotion_contract_test.dart")
moe_tests = read("test/moe_expression_prompt_adapter_test.dart")
language_tests = read("test/visible_reasoning_language_telemetry_test.dart")
reminder_tests = read("test/prompt_generation_reminder_test.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert any(
    version in pubspec
    for version in ("version: 0.38.3+102", "version: 0.38.4+103")
)
assert "static const int schemaVersion = 32;" in database
assert "schemaVersion = 33" not in database

assert "static const String normalKey = 'normal';" in contract
assert "static const String normalLabel = '正常';" in contract
assert "labelsByKey" in contract
assert "key == normalKey ? normalLabel" in contract
assert "calm is reserved for an explicit tag or an actual calm cue" in classifier
assert "key: EmotionCatalog.normalKey" in classifier
assert "'calm': ['平静', '安静', '放松'" in classifier
assert "static const normal = ChatEmotionVisual" in visuals
assert "key: 'calm'" in visuals
assert "portraitAsset: 'assets/lingchat/deepseek/calm.webp'" in visuals

for token in (
    "class MoeExpressionPromptAdapter",
    "MoeExpressionPromptPresentation.render",
    "moe_expression_enabled",
    "final directives = plan.styleDirectives",
    ".take(2)",
    "不要说出任何属性、配方、档位、数值、阈值或系统机制",
):
    assert token in adapter, token
for forbidden in (
    "傲娇",
    "毒舌",
    "卖萌",
    "撒娇",
    "呆萌",
    "天然直球",
    "腹黑",
    "恶作剧",
):
    assert forbidden not in adapter, forbidden

assert "让萌属性影响对话表达" in appearance
assert "MoeExpressionMode.values" in appearance
assert "MoeExpressionMode.obvious" in appearance
assert "setExpressionMode" in appearance

for token in (
    "visibleChineseGenerationReminder",
    "自然简体中文",
    "没有清晰情绪色彩时用“正常”",
    "“平静”只用于明确安静",
):
    assert token in prompt, token
assert "<system-reminder>" not in prompt
assert "VisibleReasoningLanguageTelemetry.note" in runner
assert "VisibleReasoningLanguageTelemetry.note" in proactive
assert "PromptBuilder.visibleChineseGenerationReminder" in runner
assert "PromptBuilder.visibleChineseGenerationReminder" in proactive

for token in (
    "enum VisibleReasoningLanguageStatus",
    "chinese_first",
    "mainly_english",
    "reasoningTextIncluded': false",
    "matchedWordsIncluded': false",
):
    assert token in telemetry, token
assert "visibleReasoningLanguage" in preflight
assert "reasoningLanguageTextIncluded': false" in preflight

for title in (
    "normal is an explicit presentation token outside the 19 emotions",
    "missing tag without a cue uses normal while real calm stays calm",
):
    assert title in emotion_tests, title
assert "D3 never exposes recipe labels, axes, values or control abilities" in moe_tests
assert "reasoning language telemetry classifies shape without retaining text" in language_tests
assert "per-turn reminder prefers Chinese and separates normal from calm" in reminder_tests

for token in (
    "Build AI Companion v0.38.3+102 APK",
    "validate_v0383_moe_d3_reasoning_normal_emotion.py",
    "AI-Companion-v0.38.3-102-Moe-D3-Chinese-Reasoning-Normal-Emotion-APK",
    "v0.38.3-moe-d3-chinese-reasoning-normal-emotion-test",
    ".ci/v0383-monitor.txt",
):
    assert token in workflow, token

print("v0.38.3 Moe D3, Chinese reasoning and normal/calm validation passed")
