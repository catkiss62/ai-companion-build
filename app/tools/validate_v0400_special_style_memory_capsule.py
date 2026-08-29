#!/usr/bin/env python3
"""Static contracts for v0.40.0 special-style experience isolation."""

from hashlib import sha256
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


assert re.search(r"^version:\s*(?:0\.40\.[012]\+(?:128|129|130)|0\.40\.3\+(?:131|132)|0\.40\.4\+133)\s*$", read("pubspec.yaml"), re.M)
database = read("lib/core/database/app_database.dart")
assert "static const int schemaVersion = 37;" in database

special_source = read("lib/core/rules/rule_layer_content_v0400.dart")
parsed = {
    key: body
    for key, body in re.findall(
        r"const ruleContentV0400_(07_special_[A-Za-z0-9_]+) = r'''(.*?)''';",
        special_source,
        re.S,
    )
}
expected = {
    "07_special_yandere": "dfba40df574f92796a10b94dd340850b9aa8b76c1b52c91ecf0eec5fa4ccc4bd",
    "07_special_seductress": "016a289d90edf129c9edc2620aaf071481ce70dccca79c9f88ebf421dc7a869d",
    "07_special_highness": "ce35f5bfc021b875fbcab28744fa7fee04d9acf622595e81492f5e453ca30bd9",
    "07_special_slime": "d64ec6b77ed562771bfd1cfa3c508b5a3179e716225892a5b35d78060b9e51c2",
    "07_special_doll": "3f7f5799e1d652ec0dd13a650611e82d7f604aee44ba5efb305e3ec60b58d8fa",
    "07_special_sharp": "4bd4f9de456a73a900410bd0e8d8bea5dd965ef083261784b00e1f01bb53ed95",
    "07_special_ai": "ffa43761c5e65cd182207dbb96ed6fb0519ae5c1af7e0b8ccb804695203a8b8b",
    "07_special_uncanny": "8917ec20fd68c8e193fe916dc09efb88296058abee6086690d3915e22a317d7a",
}
assert set(expected).issubset(parsed)
for key, digest in expected.items():
    assert sha256(parsed[key].encode()).hexdigest() == digest, key
assert "主动下手，以玩弄为主" in parsed["07_special_seductress"]

catalog = read("lib/core/personality/personality_catalog.dart")
assert "specialSharedPrompt = ruleContentV0400_07_special_shared" in catalog
for key, label in (
    ("yandere", "病娇"),
    ("seductress", "痴女"),
    ("highness", "高岭之花"),
    ("slime", "史莱姆"),
    ("doll", "人偶执念"),
    ("sharp", "毒舌依赖"),
    ("ai", "AI模拟"),
    ("uncanny", "神人模式"),
):
    assert f"PersonalityOption('{key}', '{label}'" in catalog
for retired in ("zealot", "hunter", "double", "accomplice"):
    assert f"PersonalityOption('{retired}'" not in catalog
assert "if (style.key.isEmpty) return '';" in catalog
assert "知情并主动参与的一次临时特殊风格试穿" in special_source
assert "不主动播报风格名称、规则、选择过程" in special_source
assert "不得整理成永久 AI Self" in special_source

defaults = read("lib/core/rules/rule_layer_defaults.dart")
for key in expected:
    assert f"RuleLayerDefault('{key}'" in defaults
assert "retiredSpecialStyleKeysV0400" in defaults
assert "if (!layer.key.startsWith('07_special_'))" in defaults

for token in (
    "special_style_trial_id TEXT NOT NULL DEFAULT ''",
    "special_style_key TEXT NOT NULL DEFAULT ''",
    "special_style_binding TEXT NOT NULL DEFAULT 'inherit'",
    "specialStyleTrialAt(DateTime moment)",
    "'status': 'retired'",
):
    assert token in database, token

extractor = read("lib/core/ai/memory_extractor.dart")
for token in (
    "specialStyleTrialAt(user.createdAt)",
    "specialStyleKey: job.specialStyleKey",
    "[特殊风格体验·${style.label}]",
    "proposedKind == 'ai_self'",
    "'shared_experience'",
    "|special_style:${style.key}",
):
    assert token in extractor, token
runner = read("lib/core/ai/durable_generation_runner.dart")
chat_controller = read("lib/features/chat/chat_controller.dart")
for token in (
    "generationSpecialStyleTrialId = generationSpecialStyle?.id ?? ''",
    "specialStyleKeyOverride: generationSpecialStyleKey",
):
    assert token in runner, token
assert "specialStyleTrialId: result.specialStyleTrialId" in chat_controller

repository = read("lib/core/immersive/immersive_room_repository.dart")
controller = read("lib/core/immersive/immersive_room_controller.dart")
prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
for token in (
    "inheritActiveSpecialStyleIfNeeded",
    "pinCurrentSpecialStyle",
    "disableSpecialStyle",
    "special_style_binding': 'pinned'",
    "special_style_binding': 'disabled'",
):
    assert token in repository, token
assert "room.specialStyleKey" in prompt
assert "activeSpecialStyleTrial" not in prompt
assert "本房间固定的特殊风格试穿" in prompt
assert "repository.inheritActiveSpecialStyleIfNeeded(roomId)" in controller

capsule = read("lib/widgets/active_trial_capsule.dart")
chat = read("lib/features/chat/chat_page.dart")
immersive = read("lib/features/immersive/immersive_room_page.dart")
assert "StadiumBorder" in capsule
assert "maxWidth: MediaQuery.sizeOf(context).width * 0.62" in capsule
assert "ActiveTrialCapsule" in chat
assert "ActiveTrialCapsule" in immersive
assert immersive.index("child: _conversationPanel(room)") < immersive.index("child: ActiveTrialCapsule(")
assert "top: 8" in chat and "right: 12" in chat
assert "top: 8" in immersive and "right: 12" in immersive

workflow = read("../.github/workflows/build-apk.yml")
for token in (
    "agent/v0400-special-style-memory-capsule",
    "Build AI Companion v0.40.0+128 APK (Special Style Memory Capsule)",
    "python3 tools/validate_v0400_special_style_memory_capsule.py",
    "AI-Companion-v0.40.0-128-Special-Style-Memory-Capsule-APK",
    "v0.40.0-special-style-memory-capsule",
):
    assert token in workflow, token

print("v0.40.0 special-style, provenance, immersive pin and capsule contracts verified")
