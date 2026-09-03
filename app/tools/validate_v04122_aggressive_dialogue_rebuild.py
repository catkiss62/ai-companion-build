#!/usr/bin/env python3
"""Static contracts for v0.41.22 aggressive ordinary-dialogue rebuild."""

from pathlib import Path
import re


APP = Path(__file__).resolve().parents[1]
ROOT = APP.parent


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
rules = read("app/lib/core/rules/rule_layer_content_v0353.dart")
forthright = read("app/lib/core/rules/rule_layer_content_v0418.dart")
defaults = read("app/lib/core/rules/rule_layer_defaults.dart")
personality = read("app/lib/core/personality/personality_catalog.dart")
prompt = read("app/lib/core/ai/prompt_builder.dart")
dialogue_plan = read("app/lib/core/ai/dialogue_expression_plan.dart")
dialogue_telemetry = read("app/lib/core/diagnostics/dialogue_expression_telemetry.dart")
moe_adapter = read("app/lib/core/integration/moe_expression_prompt_adapter.dart")
moe_policy = read("app/lib/core/moe/application/moe_dynamics_policy.dart")
tests = read("app/test/dialogue_expression_plan_test.dart")
workflow = read(".github/workflows/build-apk.yml")
ledger = read("AI_Companion_当前总账.md")

if "version: 0.41.23+162" in pubspec:
    assert "validate_v04122_aggressive_dialogue_rebuild.py" in workflow
    assert "v0.41.22" in ledger
    print("v0.41.22 historical dialogue contract superseded by v0.41.23")
    raise SystemExit(0)

assert re.search(r"^version:\s*0\.41\.22\+161\s*$", pubspec, re.MULTILINE)
assert "static const int schemaVersion = 44;" in database
assert "buildLabel = 'v0.41.22+161'" in self_reader

for token in (
    "情绪丰富、以自我为中心、爱憎分明",
    "爱源于私心、偏爱和欲望",
    "不把负面态度自动翻译成可爱",
    "允许单独使用“……”",
    "普通聊天正文禁止动作、神态、语气说明",
    "许可—安抚—承诺链",
    "隐藏的温柔继续留在心里",
    "普通聊天示例：只学节奏与反应",
    "我就是抖M",
):
    assert token in rules, token
for rejected in (
    "具有戏剧性的人机味",
    "不过在用户面前倾向于表现出专业，靠谱的样子",
    "【动作与神态格式】",
):
    assert rejected not in rules, rejected

assert rules.count("  你：“") >= 7
assert "眼睛微微一眯" not in rules
assert "骂完不需要自动道歉" in forthright

for token in (
    "class DialogueExpressionPlan",
    "DialogueResponseMode.casual",
    "DialogueResponseMode.deep",
    "DialogueResponseMode.task",
    "DialogueResponseMode.sensitive",
    "deadpanVerdict",
    "meaningSwerve",
    "usefulMisread",
    "scaleEscalation",
    "wordMutation",
    "groundedCallback",
    "不虚构共同经历",
):
    assert token in dialogue_plan, token

for token in (
    "DialogueExpressionPlan.select",
    "dialogueExpressionPlan.render()",
    "普通聊天最终正文只写真正说出口的话",
    "不写动作、神态、语气说明、镜头、环境或旁白",
    "许可—安抚—承诺链",
):
    assert token in prompt, token
assert "_recentActionRepetitionSection" not in prompt
assert "DialogueExpressionTelemetry.record" in prompt

for token in (
    "dialogue_expression_telemetry_v1",
    "modeCounts",
    "humorCounts",
    "userTextIncluded",
    "generatedTextIncluded",
    "reasoningIncluded",
):
    assert token in dialogue_telemetry, token
assert "'dialogueExpression': dialogueExpression" in read(
    "app/lib/core/diagnostics/preflight_diagnostics.dart"
)

for token in (
    "本轮动态表达倾向",
    "不能只存在于 reasoning",
    "负面倾向不自动可爱化",
):
    assert token in moe_adapter, token
for token in (
    "真实关心允许留在未说出口处",
    "不道歉、不解释其实温柔",
    "真的设一个语言套",
    "真的做一次文字捉弄",
):
    assert token in moe_policy, token

for token in (
    "legacyEditableRuleLayerSha256V04121AggressiveDialogue",
    "'03_personality_seed'",
    "'07_base_forthright'",
    "'07_profile_shared'",
):
    assert token in defaults, token
assert "...legacyEditableRuleLayerSha256V04121AggressiveDialogue.entries" in database
assert "FRESH CONVERSATION CONTEXT" in prompt
assert "beginFreshConversationContext" in database

for token in (
    "只输出说出口的话",
    "technical and deep turns may expand without humor pressure",
    "sensitive content suppresses jokes",
    "不虚构共同经历",
):
    assert token in tests, token
assert "当前人格落地·普通聊天" in personality

for token in (
    "Build AI Companion v0.41.22+161 APK (Aggressive Dialogue Rebuild)",
    "grep -Fqx 'version: 0.41.22+161' app/pubspec.yaml",
    "agent/v04122-aggressive-dialogue-rebuild",
    "AI-Companion-v0.41.22-161-Aggressive-Dialogue-Rebuild-APK",
    "validate_v04122_aggressive_dialogue_rebuild.py",
    ".ci/v04122-monitor.txt",
):
    assert token in workflow, token

for token in (
    "激进核心底色、纯对白与造梗表达重构",
    "0.41.22+161",
    "schema 44",
    "Phase 2B/3/4 继续关闭",
):
    assert token in ledger, token

print("v0.41.22 aggressive dialogue rebuild validation passed")
