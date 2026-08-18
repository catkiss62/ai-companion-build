#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
version = re.search(r"^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$", pubspec, re.MULTILINE)
assert version and tuple(map(int, version.groups())) >= (0, 35, 1, 76)

database = read("lib/core/database/app_database.dart")
assert "static const int schemaVersion = 26;" in database
assert "locked` now means protected/always enabled" in database
assert "legacyEditableRuleLayerSha256V0350" in database

catalog = read("lib/core/personality/personality_catalog.dart")
for token in (
    "【内在反应】",
    "【表达过滤】",
    "可见思考默认用第一人称“我”",
    "他是平等的男朋友",
    "十成波澜收成两三成",
    "反咬一口",
    "抓住破绽追一下",
    "内心与说出口的话不必相同",
    "不要把“小鲸鱼”当作固定自称",
    "不要向他说明风格层",
):
    assert token in catalog, token
for forbidden in ("当前试穿性格", "双方知情的临时试穿"):
    assert forbidden not in catalog, forbidden

service = read("lib/core/rules/rule_layer_service.dart")
assert "PersonalityCatalog.compileProfile(" in service
assert "profileTrial.baseKey" in service
assert "profileTrial.content," not in service
assert "当前特殊表达与现实边界" in service

prompt = read("lib/core/ai/prompt_builder.dart")
for token in (
    "他是成年男性，是你的男朋友",
    "_visibleInnerVoiceContract(",
    "【可见思考与最终表达】",
    "不是工作记录",
    "内心可以比台词更乱",
    "_innerResidueSection",
    "情绪余波（由已持久化的 Desire/Thought 状态得出",
    "不能补写事实原因",
    "默认不把“小鲸鱼”当作自称",
):
    assert token in prompt, token
for forbidden in ("我需要回应用户", "保持角色一致", "现在扮演"):
    assert forbidden not in prompt, forbidden
assert prompt.index("_visibleInnerVoiceContract(") < prompt.index(
    "if (mode == PromptGenerationMode.proactive)"
)

proactive = read("lib/core/desire/proactive_engine.dart")
for token in (
    "当前“内在反应 + 表达过滤”仍完整生效",
    "正文停在最有性格的自然落点",
    "不要因为纠正事实边界就改成无个性的安慰或问候",
):
    assert token in proactive, token

defaults = read("lib/core/rules/rule_layer_defaults.dart")
for token in (
    "【先成为反应的原因】",
    "不是处理请求的工作记录",
    "【内在波澜与出口】",
    "【内心与台词】",
    "默认自称永远是自然的第一人称“我”",
    "不能成为每轮思考的身份开场",
):
    assert token in defaults, token
assert "legacyEditableRuleLayerSha256V0350" in defaults

diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
for token in (
    "first_person_reaction_expression_v2",
    "usesPersistedDesireAndThoughtMetadata",
    "storesRawReasoningAsMemory",
    "strongestResidueBand",
):
    assert token in diagnostics, token

docs = read("docs/PERSONALITY_INNER_VOICE_v2.md")
for token in (
    "像一个人，而不是装成一个人",
    "思考与台词可以不同",
    "不保存原始 reasoning",
    "v0.35.1+76",
):
    assert token in docs, token

handoff = read("docs/HANDOFF.md")
ledger = read("docs/PROJECT_TASK_LEDGER.md")
root_ledger = read("../AI_Companion_接班总账_v36_2026-08-17.md")
for text in (handoff, ledger, root_ledger):
    assert "v0.35.1+76" in text

print("v0.35.1 personality inner-voice static validation passed")
