#!/usr/bin/env python3
"""Static contracts for v0.41.27 unified lifelike/NSFW runtime."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


pubspec = read("pubspec.yaml")
self_reader = read("lib/core/agent/agent_self_reader.dart")
database = read("lib/core/database/app_database.dart")
defaults = read("lib/core/rules/rule_layer_defaults.dart")
sections = read("lib/core/rules/intimacy_prompt_sections.dart")
intimacy = read("lib/core/rules/rule_layer_content_v04127.dart")
immersive_rules = read("lib/core/rules/rule_layer_content_immersive.dart")
immersive_prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
immersive_router = read("lib/core/immersive/immersive_nsfw_router.dart")
controller = read("lib/core/immersive/immersive_room_controller.dart")
worldbook = read("lib/core/reference/world_book_presets.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)

assert "version: 0.41.27+166" in pubspec
assert "buildLabel = 'v0.41.27+166'" in self_reader
assert "static const int schemaVersion = 45" in database

for token in (
    "builtin.worldbook.daily_conversation",
    "name: '日常对话规则'",
    "【日常对话边界】",
    "【口语与心理边界】",
    "【幽默】",
    "【动作与神态】",
):
    assert token in worldbook, token
assert "behaviorWorldBook.contains('builtin.worldbook.daily_conversation')" in prompt
assert "worldbook_daily_bundle_v04127_applied" in database

for token in (
    "IntimacyPromptSections.parse",
    "latePrompt",
    "NSFW 末端静默校验",
    "小鲸鱼=她、用户=你",
):
    assert token in sections, token
assert "layerBundle.intimacyPreflight" in prompt
assert "legacyEditableRuleLayerSha256V04126ReviewedNsfw" in defaults
for token in (
    "没打算给任何人看的当下心声",
    "片段、跳念、突然联想、改口或没想完",
    "所以我应该怎样回复",
    "legacyEditableRuleLayerSha256V04126VisibleInnerVoice",
):
    assert token in (intimacy + prompt + defaults), token

for token in (
    "【高潮引导 · 跨轮同步状态机】",
    "我快射了",
    "只是用户的濒临宣言",
    "仍必须再次同步到达",
    "大量叠词",
    "龟头/顶端/柱身/囊袋/根部",
):
    assert token in intimacy, token

for key in (
    "'04_intimacy_core'",
    "'05_intimacy_rendering'",
    "'06_intimacy_reference'",
    "'immersive_07_nsfw_source'",
):
    assert key in immersive_prompt, key
assert "nsfwTurnDirective: route.turnDirective" in controller
assert "if (nsfwActive && intimacyPreflight.isNotEmpty)" in immersive_prompt

for token in (
    "ImmersiveClimaxEvent",
    "ai_release",
    "user_near",
    "user_release",
    "hold",
    "快射/要射",
    "fallbackClimaxEvent",
):
    assert token in immersive_router, token

for token in (
    ".replaceAll(r'\\n', '\\n')",
    "正文中 AI 只写“她”",
    "05 NSFW 状态机对本轮能否进阶拥有唯一裁决权",
    "已明确建立初次、疼痛或出血事实",
):
    assert token in immersive_rules, token

for token in (
    "Build AI Companion v0.41.27+166 APK (Unified Lifelike NSFW Runtime)",
    "agent/v04127-unified-lifelike-nsfw-runtime",
    "AI-Companion-v0.41.27-166-Unified-Lifelike-NSFW-Runtime-APK",
    "validate_v04127_unified_lifelike_nsfw_runtime.py",
    ".ci/v04127-monitor.txt",
):
    assert token in workflow, token

print("v0.41.27 unified lifelike/NSFW runtime validation passed")
