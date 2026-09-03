#!/usr/bin/env python3
"""Static contracts for v0.41.8 trial capsule and personality precedence."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
catalog = read("lib/core/personality/personality_catalog.dart")
content_v0417 = read("lib/core/rules/rule_layer_content_v0417.dart")
content_v0418 = read("lib/core/rules/rule_layer_content_v0418.dart")
defaults = read("lib/core/rules/rule_layer_defaults.dart")
service = read("lib/core/rules/rule_layer_service.dart")
builder = read("lib/core/ai/prompt_builder.dart")
capsule = read("lib/widgets/active_trial_capsule.dart")
chat = read("lib/features/chat/chat_page.dart")
immersive = read("lib/features/immersive/immersive_room_page.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
tests = read("test/personality_trial_test.dart") + read(
    "test/active_trial_capsule_test.dart"
)
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
ledger = (REPO / "AI_Companion_当前总账.md").read_text(encoding="utf-8")

# v0.41.8 remains a historical source contract after later version/schema
# advances; its exact tokens stay in the source for regression validation.
assert "version: 0.41.8+147" in pubspec
assert "static const int schemaVersion = 41;" in database

for token in (
    "ruleContentV0418_07_base_forthright",
    "自然说脏话的习惯",
    "粗口会直接进入你说出口的完整句子",
    "开放词例，不是封闭词库、固定轮播或每句配额",
    "多轮日常聊天里，这种语言习惯应当稳定可辨",
    "被善化成仅仅更活泼",
    "骂完不需要自动道歉",
    "只排除拿用户的真实创伤、身份和不可改变弱点",
):
    assert token in content_v0418 + catalog + tests, token

assert "ruleContentV0417_07_base_forthright" in content_v0417
assert "where: 'key = ? AND content = ?'" in database
assert "ruleContentV0418_07_base_forthright" in database
assert "ruleContentV0417_07_base_forthright" in database
assert "ruleContentV0418_07_base_forthright" in defaults

for token in (
    "static String executionAnchor(String baseKey)",
    "当前底色落地·直爽泼辣",
    "多轮盲测必须稳定辨认",
):
    assert token in catalog + tests, token
assert (
    "动态萌属性只能改变" in catalog + tests
    or "动态表达倾向只能改变" in catalog + tests
)
assert "personalityExecutionAnchor" in service
assert builder.count("layerBundle.personalityExecutionAnchor.isNotEmpty") == 3
assert builder.count("'content': layerBundle.personalityExecutionAnchor") == 3
assert builder.index("if (moeExpressionSection.isNotEmpty)") < builder.index(
    "layerBundle.personalityExecutionAnchor.isNotEmpty"
)

for token in (
    "activeTrialCapsuleLabels",
    "PersonalityCatalog.isKnownBase(personalityBaseKey)",
    "PersonalityCatalog.base(personalityBaseKey).label",
    "PersonalityCatalog.isKnownSpecial(specialStyleKey)",
):
    assert token in capsule, token
for page in (chat, immersive):
    assert "personalityBaseKey:" in page
    assert "_personalityTrial?.baseKey ?? ''" in page
    assert "specialStyleKey:" in page
    assert "activeTrialCapsuleLabels(" in page
assert "['直爽泼辣']" in tests
assert "['自然状态', '病娇']" in tests

for token in (
    "'effectiveBaseKey': effectiveBase",
    "'effectiveBaseFromTrial': profile != null",
    "'effectiveBaseTemplatePresent'",
    "'effectiveBaseExecutionAnchorPresent': anchorPresent",
    "'templateBodiesIncluded': false",
    "'executionAnchorBodyIncluded': false",
):
    assert token in database, token
for token in (
    "personalityTemplateBodiesIncluded': false",
    "personalityExecutionAnchorBodyIncluded': false",
):
    assert token in diagnostics, token

for token in (
    "Build AI Companion v0.41.8+147 APK (Personality Trial Strength Hotfix)",
    "agent/v0418-personality-trial-strength-hotfix",
    "AI-Companion-v0.41.8-147-Personality-Trial-Strength-Hotfix-APK",
    "v0.41.8-personality-trial-strength-hotfix-test",
    ".ci/v0418-monitor.txt",
    "python3 tools/validate_v0418_personality_trial_strength_hotfix.py",
):
    assert token in workflow, token

for token in (
    "v0.41.8 普通试穿胶囊与直爽泼辣强度热修",
    "agent/v0418-personality-trial-strength-hotfix",
    "0.41.8+147",
    "Memory Phase 1",
):
    assert token in ledger, token

print("v0.41.8 personality trial strength hotfix validation passed")
