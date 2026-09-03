#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


database = read("lib/core/database/app_database.dart")
for token in (
    "static const int schemaVersion = 27;",
    "segments_json TEXT NOT NULL DEFAULT ''",
    "'personality_base_key': 'neutral'",
    "'personality_posture_key': 'equal'",
    "'tts_reading_scope': 'dialogue_only'",
    "Future<void> restoreNaturalPersonality()",
):
    assert token in database, token

catalog = read("lib/core/personality/personality_catalog.dart")
for token in (
    "'neutral'",
    "自然状态",
):
    assert token in catalog, token
assert (
    "不额外放大固定气质" in catalog
    or "不额外套一层温和或正常姿态" in catalog
)
assert catalog.index("'neutral'") < catalog.index("'outgoing'")

service = read("lib/core/rules/rule_layer_service.dart")
grouping = read("lib/core/rules/rule_layer_grouping.dart")
for token in (
    "selected.add(layer);",
    "03_personality_expression",
    "profileTrial?.baseKey ?? longTermBase",
):
    assert token in service, token
assert "layer.key == '03_personality_seed' && profileTrial != null" not in service
assert "'03_personality_expression': '03'" in grouping

rules = read("lib/core/rules/rule_layer_content_v0353.dart")
for token in (
    "# 01 · AI Companion Core",
    "不输出英文工具规划",
    "不加括号",
    "所有台词必须用「」包裹",
    "动作禁止写进「」内",
    "主动联系仍是一条完整消息",
):
    assert token in rules, token

segments = read("lib/core/models/chat_segment.dart")
message = read("lib/core/models/chat_message.dart")
for token in ("ChatSegmentKind", "parseAssistantText", "segments_json"):
    assert token in segments + message, token

runner = read("lib/core/ai/durable_generation_runner.dart")
for token in (
    "工具结果后的中文表达约束",
    "preserveProviderReasoning",
    "segments: ChatSegmentCodec.parseAssistantText(finalContent)",
):
    assert token in runner, token

proactive = read("lib/core/desire/proactive_engine.dart")
assert "isProactive: true" in proactive
assert "segments: ChatSegmentCodec.parseAssistantText(text)" in proactive
assert proactive.count("commitProactiveMessageIfCurrent(") == 1

tts = read("lib/core/tts/tts_text_processor.dart")
settings = "\n".join(
    read(path)
    for path in (
        "lib/features/settings/settings_page.dart",
        "lib/features/settings/settings_category_pages.dart",
        "lib/features/chat/chat_quick_settings_pages.dart",
    )
)
for token in (
    "dialogueOnly('dialogue_only'",
    "fullText('full_text'",
    "仅朗读对白（「」内）",
    "朗读全文（动作 + 对白）",
):
    assert token in tts, token
assert "labelText: '朗读范围'" in settings

print("current conversation/personality/TTS foundation validation passed")
