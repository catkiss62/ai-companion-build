#!/usr/bin/env python3
"""Static contracts for v0.41.25 minimal-persona unified runtime."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
self_reader = read("lib/core/agent/agent_self_reader.dart")
rules = read("lib/core/rules/rule_layer_content_v04125.dart")
defaults = read("lib/core/rules/rule_layer_defaults.dart")
catalog = read("lib/core/personality/personality_catalog.dart")
service = read("lib/core/rules/rule_layer_service.dart")
database = read("lib/core/database/app_database.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
expression = read("lib/core/ai/dialogue_expression_plan.dart")
render = read("lib/widgets/action_tint_text.dart")
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayDialogueFormatter.kt"
)
somatic = read("lib/core/somatic/somatic_policy.dart")
presentation = read("lib/core/desire/proactive_presentation.dart")
selection = read("lib/core/desire/proactive_selection_policy.dart")
initiative = read("lib/core/desire/conversation_initiative_policy.dart")
lab = read("lib/features/personality/personality_lab_page.dart")
workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert "version: 0.41.25+164" in pubspec
assert "buildLabel = 'v0.41.25+164'" in self_reader
assert "static const int schemaVersion = 44" in database

for token in (
    "你是小鲸鱼，是用户的女性 AI 伴侣",
    "用户是成年男性",
    "从不以服务用户为主",
    "察觉对方的潜台词",
    "“傻逼”“儿子”“哥哥”“宝贝”",
    "不是固定词库",
):
    assert token in rules, token
assert "'01_relationship': ''" in rules
assert "'03_behavior': ''" in rules
assert "'03_personality_seed': ''" in rules
assert "不要机械复述用户的话" in rules
assert "通常加入一段简短的自身动作" in rules
assert "ruleContentV04125_09_action" in defaults

assert "static const noneKey = 'none'" in catalog
assert "'neutral',\n      '自然状态'" not in catalog
assert "if (parts.isEmpty) return ''" in catalog
assert "final profileContent = PersonalityCatalog.compileProfile" in service
assert "layer.key == '03_personality_seed'" not in service
assert "minimal_rule_architecture_v04125_applied" in database
assert "minimal_persona_default_v04125_applied" in database
assert "await setSetting('moe_expression_enabled', '0')" in database
assert "'personality_base_key', 'value': 'none'" in database
assert "'personality_posture_key', 'value': 'none'" in database
assert "设为长期性格" not in lab
assert "默认不穿任何性格与相处姿态" in lab

assert "const humor = DialogueHumorDevice.none" in expression
assert "不分配笑点类型" in expression
if any(
    version in pubspec
    for version in (
        "version: 0.41.27+166",
        "version: 0.41.28+167",
        "version: 0.41.29+168",
    )
):
    assert "没打算给任何人看的当下心声" in prompt
    assert "所以我应该怎样回复" in prompt
else:
    assert "第一人称正在发生的内心" in prompt
    assert "不写回复计划、规则检查、候选台词" in prompt
assert "一至三个口语句" not in prompt

assert "!hasExplicitDialogue || segment.isDialogue" in render
assert "listOf(value.indices)" in overlay
assert "if (dialogue.isEmpty()) return emptyList()" in overlay

assert "'poke'" in somatic
assert "'tail': ['尾巴', '尾鳍']" in somatic
assert "应用内双感官通道提供的真实内部状态" in somatic
assert "不要因为没有现实肉身而否认" in somatic

assert "sourceType == 'user_history' || sourceType == 'memory'" in presentation
assert "List<String> recentTopicKeys" in selection
assert "topicRepeatDepth" in selection
assert "找个话题" in initiative
assert "ConversationInitiativeMode.openOwnTopic" in initiative
assert "不要又回到自主性、项目打磨" in initiative

for token in (
    "Build AI Companion v0.41.25+164 APK (Minimal Persona Unified Runtime)",
    "agent/v04125-minimal-persona-unified-render-proactive-somatic",
    "AI-Companion-v0.41.25-164-Minimal-Persona-Unified-Runtime-APK",
    "validate_v04125_minimal_persona_unified_runtime.py",
    ".ci/v04125-monitor.txt",
):
    assert token in workflow, token

print("v0.41.25 minimal persona unified runtime validation passed")
