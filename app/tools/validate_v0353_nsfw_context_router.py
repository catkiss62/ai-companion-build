#!/usr/bin/env python3
from pathlib import Path
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), f"{relative} is empty"
    return value


version = re.search(
    r"^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$",
    read("pubspec.yaml"),
    re.MULTILINE,
)
assert version and tuple(map(int, version.groups())) >= (0, 35, 3, 78)
assert "static const int schemaVersion = 26;" in read("lib/core/database/app_database.dart")

content_source = read("lib/core/rules/rule_layer_content_v0353.dart")
parsed = {
    key: body
    for key, body in re.findall(
        r"const ruleContentV0353_([A-Za-z0-9_]+) = r'''(.*?)''';",
        content_source,
        re.DOTALL,
    )
}
expected_hashes = {
    "01_core": "32903d851d7776e4e5e34e4e1273a65786171504cf5e4c1db866591687a4c0a1",
    "01_relationship": "ff49b2327826869e121616068720c087f00b1903508247a6b89ba609ab003d7f",
    "03_appearance_identity": "6250a50a97a5c19ad16f6fa78d4665e558236bd50a8494ef65f340113d19d6d1",
    "08_runtime_identity": "1dc62d223f9b5d82b2afb8423be970cc29304b042d0732105c611a29b8848d87",
    "02_daily": "4db97905f932b0d84c4fdc70f65a5895c7a5165faef23f24fa69153f1269a521",
    "03_behavior": "3f20bfe48e191ec386ae1ea9335bf9fd3ff69c8e38f749fff03cf8d2caf8a230",
    "08_proactive_turn": "f9e5b355b8a23eea1f4e3e1404c37c9199f935f5381b2ce8aaaa16868907e541",
    "08_visible_inner_voice": "ee097e66859815af94c04fb35c5fc33ba9e236d1d9254c45cc37cbb972c74549",
    "03_personality_seed": "38fe20355a17f1b5668e03a0a3793efde7b12c3b951ffcad90c408a9f0082505",
    "07_base_gentle": "99401bb89d573d26f43a2a2f885514c8706e211913bce8d3967b578ddb98dfc2",
    "07_base_outgoing": "e5937bf0d065d42f68683a8a82cd072ae0888e236009bde14c7f028937e2196b",
    "07_base_playful": "b72bcd5d3bfa69b6a924a8ec1a7157595e3cb96bf6b988f2a395df48e534b606",
    "07_base_reserved": "d841691e600fcdc6c95826fdf96bf08880358505d4b812826bd3ec8d91cd9dd3",
    "07_posture_equal": "0a3648f579798076ed75085dee158110f1df3360f2013d294f951c048b17056b",
    "07_posture_impish": "df8d4e6b85f61b3ca479204c1ab568e522457d64900dea43356be3ecd2ea34f3",
    "07_posture_older": "631bc46e0c5cc555bd95edf11fd7a286c9b0755b2c1376e07132046b83159559",
    "07_posture_younger": "cc0c1ee7d988dcca070676545157e6fd181889581832a7cbf9cd25142bd2956d",
    "07_profile_shared": "a53fd61edf178f4d52fea82e43d778b430af7d4899946bc20433cac22cc2744e",
    "07_special_accomplice": "bba48380bc6505cd9d4f7814c72eac0cdf360a18dd968dea1f094dbd28803fb9",
    "07_special_doll": "b1f4304a17babead15b2737ba66b0e29441ae8343be39ede4b1780642d9f0fec",
    "07_special_double": "9b30acdabcb8a03587990b672fe9842f0b373fc1548322ffc257050814227d06",
    "07_special_hunter": "c69d253b8cdf85f7b4414e4186d68b4b367cd57eae704304157c7a32c8f3b6d9",
    "07_special_seductress": "10eee7abb049a0b3b4a11354970a9afd08936b009461043c77726e73b4ee6ec6",
    "07_special_shared": "e385e54450ae6fba7a29b9f4bf3a8ba952c6ca063d44f7a936b6117c3baf9879",
    "07_special_sharp": "2bc68805705e839519de080b9036aff8d7af621512351e4717698a5f5a9f20cb",
    "07_special_yandere": "98710c6b8bf6a42124b772905aaed424008c73dbc19ca7fe33165865eb034a5c",
    "07_special_zealot": "3924e21435fbdf673eeb26968c514781182e4f71a0f15300059dc1b229ceaaf7",
    "04_memory_rules": "351444294710e7b8f2e48f348e650aa3048b3512b7e83a15a54a15efb09f4b21",
    "04_intimacy_core": "b15c9ca7fcd33f3b42116b881d7853b7ff86dd759fac929f52e38fe2893ddbc7",
    "05_intimacy_rendering": "b7b9a425b8a02c6f6a415c293a47922a329c9c7712840a7ef01a1f6e954ec460",
    "06_intimacy_reference": "dc0283f42fb1670d9a2ad3ab47a7ad225988c29dacc80cbe331fdd685bf226a3",
}
assert set(parsed) == set(expected_hashes), (set(parsed), set(expected_hashes))
for key, expected in expected_hashes.items():
    actual = hashlib.sha256(parsed[key].encode("utf-8")).hexdigest()
    assert actual == expected, f"user-authored prompt changed: {key} {actual}"

defaults = read("lib/core/rules/rule_layer_defaults.dart")
assert "_approvedRuleContentsV0354" in defaults
assert "legacyRuleLayerContentsV0352" in defaults

router = read("lib/core/ai/nsfw_context_router.dart")
for token in (
    '"mode":"daily|nsfw|nsfw_reference"',
    "Do not require a magic phrase",
    "Session is scene continuity, not permission",
    "seductressBias",
    "nsfw_manual_override",
    "fallback_daily",
):
    assert token in router, token

service = read("lib/core/rules/rule_layer_service.dart")
assert "_bootstrapIntimacy" not in service
assert "nsfw_reference_active" in service
assert "Session remains" in service

runner = read("lib/core/ai/durable_generation_runner.dart")
controller = read("lib/features/chat/chat_controller.dart")
chat_page = read("lib/features/chat/chat_page.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
for token in ("nsfwRouter.decide", "onNsfwRoute", "nsfwActive: nsfwRoute.active"):
    assert token in runner, token
for token in ("setNsfwActive", "nsfw_manual_override", "_applyNsfwRoute"):
    assert token in controller, token
for token in ("const Text('NSFW')", "colorScheme.primary", "Colors.white"):
    assert token in chat_page, token
for token in ("'nsfwRouting'", "'manualOverridePending'", "'promptBodiesIncluded': false"):
    assert token in diagnostics, token

client = read("lib/core/ai/deepseek_client.dart")
settings = read("lib/features/settings/settings_page.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
for source in (client, settings, runner, proactive, controller):
    assert "chat_temperature" not in source
    assert "chatTemperature" not in source
assert "double? temperature" not in client
assert "'temperature':" not in client
assert "聊天 Temperature" not in settings

rule_page = read("lib/features/settings/rule_layers_page.dart")
bridge = read("lib/core/platform/android_bridge.dart")
native = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt")
for token in ("savePromptPack", "openPromptPack"):
    assert token in rule_page and token in bridge and token in native, token
for token in ("Intent.ACTION_CREATE_DOCUMENT", "Intent.ACTION_OPEN_DOCUMENT", "prompt_pack_save_picker"):
    assert token in native, token
assert "Clipboard.setData" in rule_page and "Clipboard.getData" in rule_page

workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")
for token in (
    "Build AI Companion v0.35.4+79 APK",
    "validate_v0353_nsfw_context_router.py",
    "AI-Companion-v0.35.4-79-Prompt-Format-Chat-UI-APK.apk",
):
    assert token in workflow, token

print("v0.35.3+ NSFW context router and exact six-rule content validation passed")
