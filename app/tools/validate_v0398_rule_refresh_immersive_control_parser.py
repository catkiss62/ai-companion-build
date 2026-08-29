#!/usr/bin/env python3
"""Static contracts for v0.39.8 rule refresh and narrative boundaries."""

from hashlib import sha256
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


assert re.search(r"^version:\s*(?:0\.39\.(?:8\+126|9\+127)|0\.40\.0\+128|0\.40\.1\+129|0\.40\.2\+130|0\.40\.3\+(?:131|132))\s*$", read("pubspec.yaml"), re.M)
database = read("lib/core/database/app_database.dart")
assert "static const int schemaVersion = 36;" in database
defaults = read("lib/core/rules/rule_layer_defaults.dart")

rules = read("lib/core/rules/rule_layer_content_v0353.dart")
parsed = {
    key: body
    for key, body in re.findall(
        r"const ruleContentV0353_([A-Za-z0-9_]+) = r'''(.*?)''';",
        rules,
        re.S,
    )
}
expected = {
    "02_daily": "e228e094fd200332c6095ac653718ce0d6c3e1e219ea6bb619a62b792a84cf11",
    "03_behavior": "0fa391f9ac0b216ef28ec70730d2d2b192073def66a224e69a086337ae136673",
    "08_proactive_turn": "f9e5b355b8a23eea1f4e3e1404c37c9199f935f5381b2ce8aaaa16868907e541",
    "08_visible_inner_voice": "7cb2eafe4c8b174656f60c554c6d00f28aae98d17d9ba8f763972a074e6eafec",
    "04_intimacy_core": "3ea48294f4646acf45eb449ddcad75366fd5a1278fa1667cf5fc3da17dced202",
    "05_intimacy_rendering": "ed1b5b73f0f35e7d8277a8a2f4c923fbde0092c095440cd91fda08d818ae4b86",
    "06_intimacy_reference": "88bd720f3e97769bdde8f01f4fb7c26cd334fd1368ed8ba6c62d9cb047c3d648",
}
for key, digest in expected.items():
    current_digest = sha256(parsed[key].encode()).hexdigest()
    assert current_digest == digest or digest in defaults, (key, digest)

immersive_rules = read("lib/core/rules/rule_layer_content_immersive.dart")
body = immersive_rules.split("const immersiveNsfwSource = r'''", 1)[1].split("''';", 1)[0]
assert sha256(body.encode()).hexdigest() == "88dfc6c0055b0cda50f459706f67bfc2e7c4e59054e337dc98fb9cfd114faffd"
assert "db84d6249f3ea32ae9e85920105ca0eb869894bd1c24a1a2c7948e9603108612" in defaults
for token in (
    "legacyImmersiveDefaultRoomNovelRulesV0397",
    "以AI角色为叙事焦点的第二人称互动视角",
    "可以充分描写AI角色行为直接造成的用户生理反应",
    "不生成或复述用户台词",
):
    assert token in immersive_rules, token

for token in (
    "legacyEditableRuleLayerSha256V0397",
    "8dc45274cb261a29ef86356ffd1553609aabbd7fe3534249a11115504cf88465",
    "250a89bd0bfe8d073c59e9b25c7168b83f867a5a0d8a3933411523a13d60117f",
    "7939af3d9dc5b8c702ae53685758d5c36e20366c689dc284c4d9f47e4b2fa4fc",
    "5916af04bb0f01ebd640218792844116ff997047712340a21107d6d97b22b643",
):
    assert token in defaults, token
for token in (
    "...legacyEditableRuleLayerSha256V0397.entries",
    "_migrateUntouchedImmersiveRoomNovelRules",
    "whereArgs: const [legacyImmersiveDefaultRoomNovelRulesV0397]",
):
    assert token in database, token

prompt = read("lib/core/ai/prompt_builder.dart")
assert "最终正文的动作、神态、旁白和台词只要提及用户，一律使用“你”" in prompt

immersive_prompt = read("lib/core/immersive/immersive_prompt_builder.dart")
for token in (
    "本锁高于前面规则中与视角、用户称呼或用户控制权冲突的表述",
    "正文提及用户时始终写“你”",
    "可以充分描写由AI角色当前行为直接造成的生理反应",
    "不生成或复述用户台词及有语义的用户发声",
    "续写仍使用“她/你”的第二人称互动视角",
):
    assert token in immersive_prompt, token

repository = read("lib/core/immersive/immersive_room_repository.dart")
controller = read("lib/core/immersive/immersive_room_controller.dart")
assert "message.isUser ? '用户输入' : 'AI正文'" in repository
assert "message.isUser ? '用户输入' : 'AI正文'" in controller
assert "摘要和现场账提及用户时统一写“用户”" in controller

segment = read("lib/core/models/chat_segment.dart")
for token in (
    "hasExplicitDialogueLine",
    "kind: hasExplicitDialogueLine",
    "A fully unquoted informational reply keeps the legacy dialogue",
):
    assert token in segment, token
assert "looksLikeLegacyAction" not in segment

for relative, tokens in {
    "test/chat_visuals_test.dart": (
        "standalone action after earlier dialogue never gains fake quotes",
        "stored standalone trailing action self-heals from mixed source",
    ),
    "test/tts_text_processor_test.dart": (
        "dialogue-only scope skips a standalone action after dialogue",
    ),
}.items():
    source = read(relative)
    for token in tokens:
        assert token in source, (relative, token)

workflow = read("../.github/workflows/build-apk.yml")
for token in (
    "python3 tools/validate_v0398_rule_refresh_immersive_control_parser.py",
    "agent/v0399-user-address-viewpoint",
    "AI-Companion-v0.39.9-127-User-Address-Viewpoint-APK",
):
    assert token in workflow, token

print("v0.39.8 rule refresh, immersive control and action parser validation passed")
