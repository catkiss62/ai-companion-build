#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
assert re.search(r"^version: (?:0\.35\.[2-9]\+\d+|0\.36\.(?:0\+85|1\+86|2\+87|3\+88)|0\.37\.0\+89|0\.37\.1\+90|0\.37\.2\+91|0\.37\.3\+92|0\.37\.4\+93|0\.37\.5\+94|0\.37\.6\+95|0\.37\.7\+96|0\.37\.8\+97|0\.37\.9\+98|0\.38\.0\+99|0\.38\.1\+100|0\.38\.2\+101|0\.38\.3\+102|0\.38\.4\+103|0\.38\.5\+104|0\.38\.6\+105|0\.38\.7\+106|0\.38\.8\+107|0\.38\.9\+108|0\.38\.10\+109|0\.38\.11\+110|0\.38\.12\+111|0\.38\.13\+112)$", pubspec, re.MULTILINE)
assert "flutter_localizations:" in pubspec

for relative in ("lib/app.dart", "lib/main.dart"):
    source = read(relative)
    for token in (
        "flutter_localizations/flutter_localizations.dart",
        "locale: const Locale('zh', 'CN')",
        "GlobalMaterialLocalizations.delegates",
    ):
        assert token in source, (relative, token)

page = read("lib/features/settings/rule_layers_page.dart")
for token in (
    "六大规则",
    "_composeGroup",
    "_parseGroup",
    "ai_companion_prompt_pack",
    "Clipboard.setData",
    "Clipboard.getData",
    "和她讨论",
    "revised_content",
    "必须由你点击保存",
    "expands: true",
    "minLines: null",
    "maxLines: null",
    "ClampingScrollPhysics",
):
    assert token in page, token
assert "contextMenuBuilder:" not in page
assert "minLines: 14" not in page
assert "maxLines: 28" not in page

defaults = read("lib/core/rules/rule_layer_defaults.dart")
for token in (
    "07_base_outgoing",
    "07_base_reserved",
    "07_base_gentle",
    "07_base_playful",
    "07_posture_equal",
    "07_posture_younger",
    "07_posture_older",
    "07_posture_impish",
    "07_special_yandere",
    "07_special_seductress",
    "07_special_accomplice",
    "07_profile_shared",
    "07_special_shared",
    "08_runtime_identity",
    "08_visible_inner_voice",
    "08_proactive_turn",
    "04_memory_rules",
    "load_policy=template",
):
    assert token in defaults, token

database = read("lib/core/database/app_database.dart")
assert "locked` now means protected/always enabled" in database
assert "_promptTemplateContents" in database

service = read("lib/core/rules/rule_layer_service.dart")
for token in (
    "item.loadPolicy == 'template'",
    "templates: templates",
    "PersonalityCatalog.compileProfile(",
    "PersonalityCatalog.compileSpecial(",
):
    assert token in service, token

catalog = read("lib/core/personality/personality_catalog.dart")
for token in (
    "Map<String, String> templates = const {}",
    "basePromptKey",
    "posturePromptKey",
    "specialPromptKey",
    "{{intimacy_state}}",
):
    assert token in catalog, token

prompt = read("lib/core/ai/prompt_builder.dart")
for token in (
    "08_runtime_identity",
    "08_visible_inner_voice",
    "08_proactive_turn",
    "{{turn_context}}",
):
    assert token in prompt, token

settings = read("lib/features/settings/settings_page.dart")
assert "模型思考模式" not in settings
assert "chat_thinking_enabled" not in settings
assert "thinking: true" in settings

proactive = read("lib/core/desire/proactive_engine.dart")
assert "chat_thinking_enabled" not in proactive
assert "thinking: true" in proactive

memory = read("lib/core/ai/memory_extractor.dart")
self_reflection = read("lib/core/self/ai_self_reflection_engine.dart")
for source in (memory, self_reflection):
    assert "04_memory_rules" in source
    assert "用户可编辑的 04 · 记忆规则" in source

tests = read("test/personality_trial_test.dart") + read("test/rule_layer_defaults_test.dart")
for token in (
    "workbench templates immediately override",
    "07_base_playful",
    "exactly six integrated rule groups",
):
    assert token in tests, token

docs = read("docs/PROMPT_WORKBENCH_v1.md")
for token in (
    "v0.35.2+77",
    "保护常驻",
    "ai_companion_prompt_pack",
    "模型不能静默修改自身设定",
):
    assert token in docs, token

print("v0.35.2 prompt workbench static validation passed")
