#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
version = re.search(r"^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$", pubspec, re.MULTILINE)
assert version and tuple(map(int, version.groups())) >= (0, 35, 0, 75)

database = read("lib/core/database/app_database.dart")
for token in (
    "static const int schemaVersion = 26;",
    "CREATE TABLE IF NOT EXISTS personality_trials",
    "CREATE TABLE IF NOT EXISTS special_style_trials",
    "CREATE TABLE IF NOT EXISTS personality_profile_versions",
    "Future<PersonalityTrial> startPersonalityTrial",
    "Future<SpecialStyleTrial> startSpecialStyleTrial",
    "Future<bool> adoptPersonalityTrial",
    "_recordPersonalityTrialReplyInTransaction(txn, now)",
    "Desire baselines, AI Self and relationship memory are intentionally untouched",
    "'personality_trials'",
    "'special_style_trials'",
    "'personality_profile_versions'",
):
    assert token in database, token

model = read("lib/core/models/personality_trial.dart")
for token in ("Duration(hours: 6)", "effectiveTurns >= 20", "interactionWindows >= 2", "Duration(days: 7)"):
    assert token in model, token

catalog = read("lib/core/personality/personality_catalog.dart")
for token in (
    "元气外放", "清冷内敛", "温柔沉静", "慵懒调皮",
    "平等恋人", "妹系亲近", "姐系引导", "小恶魔主动",
    "病娇", "痴女", "狂信守护", "猎手型", "双面优等生", "毒舌依赖", "人偶执念", "共犯型",
    "不能真实阻止退出", "不得写入长期人格", "露骨成人表达只在",
):
    assert token in catalog, token

service = read("lib/core/rules/rule_layer_service.dart")
for token in ("activePersonalityTrial", "activeSpecialStyleTrial", "当前特殊表达与现实边界"):
    assert token in service, token

page = read("lib/features/personality/personality_lab_page.dart")
for token in ("性格试穿间", "重新计时", "延长24小时", "设为长期性格", "只试穿，不转正"):
    assert token in page, token

chat = read("lib/features/chat/chat_page.dart")
assert "试穿 ${_shortRemaining" in chat
assert "PersonalityLabPage" in chat

defaults = read("lib/core/rules/rule_layer_defaults.dart")
for token in ("先反应，再整理", "这条规则同样约束可见思考", "元气外放 × 平等恋人"):
    assert token in defaults, token

diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
assert "personalityTrialDiagnostics" in diagnostics
assert "'personalityTrials': personalityTrials" in diagnostics

ledger = read("docs/PROJECT_TASK_LEDGER.md")
assert "沉浸房间" in ledger
assert "长对话模式" in ledger

print("v0.35.0 personality trial system static validation passed")
