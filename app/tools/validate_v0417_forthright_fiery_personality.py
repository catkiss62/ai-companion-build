#!/usr/bin/env python3
"""Static contracts for the ordinary adoptable v0.41.7 personality base."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
catalog = read("lib/core/personality/personality_catalog.dart")
content = read("lib/core/rules/rule_layer_content_v0417.dart")
defaults = read("lib/core/rules/rule_layer_defaults.dart")
page = read("lib/features/personality/personality_lab_page.dart")
tests = read("test/personality_trial_test.dart") + read(
    "test/rule_layer_defaults_test.dart"
)
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
ledger = (REPO / "AI_Companion_当前总账.md").read_text(encoding="utf-8")

assert re.search(r"^version:\s*(?:0\.41\.7\+146|0\.41\.8\+147)\s*$", pubspec, re.M)
assert "static const int schemaVersion = 41;" in database
assert "if (oldVersion < 42)" not in database

for token in (
    "'forthright'",
    "'直爽泼辣'",
    "ruleContentV0417_07_base_forthright",
    "'07_base_forthright'",
):
    assert token in catalog + defaults + database, token

for token in (
    "自然说脏话的习惯",
    "傻逼、老子、操、艹、草、滚、爬、滚蛋、蠢货、笨比、白痴",
    "开放词例，不是封闭词库、轮播表或每句配额",
    "粗口可以表达惊讶、赞同、夸奖、催促",
    "不要求每次骂完立刻道歉",
    "爱你妈",
    "不改变女性 AI 身份",
    "不要模仿固定地域口音",
    "不能用玩梗代替答案",
):
    assert token in content + catalog + tests, token

for forbidden in (
    "东北女人就是",
    "川妹就是",
    "每句话必须",
    "固定轮播脏话",
):
    assert forbidden not in content, forbidden

assert "PersonalityCatalog.bases.map" in page
assert "adoptPersonalityTrial" in database
assert "Desire baselines, AI Self and relationship memory are intentionally untouched" in database
assert "07_base_forthright" in tests

for token in (
    "Build AI Companion v0.41.7+146 APK (Forthright Fiery Personality)",
    "agent/v0417-forthright-fiery-personality",
    "AI-Companion-v0.41.7-146-Forthright-Fiery-Personality-APK",
    "v0.41.7-forthright-fiery-personality-test",
    ".ci/v0417-monitor.txt",
    "python3 tools/validate_v0417_forthright_fiery_personality.py",
):
    assert token in workflow, token

for token in (
    "v0.41.7 直爽泼辣常规底色",
    "agent/v0417-forthright-fiery-personality",
    "0.41.7+146",
    "Memory Phase 1",
    "Bad state: No element",
):
    assert token in ledger, token

print("v0.41.7 forthright fiery personality validation passed")
