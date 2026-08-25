#!/usr/bin/env python3
from pathlib import Path
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), f"{relative} is empty"
    return value


assert re.search(r"^version: (?:0\.35\.(?:4\+79|5\+80|6\+81|7\+82|8\+83|9\+84)|0\.36\.(?:0\+85|1\+86|2\+87|3\+88)|0\.37\.0\+89|0\.37\.1\+90|0\.37\.2\+91|0\.37\.3\+92|0\.37\.4\+93|0\.37\.5\+94|0\.37\.6\+95|0\.37\.7\+96|0\.37\.8\+97|0\.37\.9\+98|0\.38\.0\+99|0\.38\.1\+100|0\.38\.2\+101|0\.38\.3\+102|0\.38\.4\+103|0\.38\.5\+104|0\.38\.6\+105|0\.38\.7\+106|0\.38\.8\+107)$", read("pubspec.yaml"), re.MULTILINE)
assert "static const int schemaVersion = 26;" in read(
    "lib/core/database/app_database.dart"
)

content_source = read("lib/core/rules/rule_layer_content_v0353.dart")
parsed = {
    key: body
    for key, body in re.findall(
        r"const ruleContentV0353_([A-Za-z0-9_]+) = r'''(.*?)''';",
        content_source,
        re.DOTALL,
    )
}
changed_hashes = {
    "02_daily": "4db97905f932b0d84c4fdc70f65a5895c7a5165faef23f24fa69153f1269a521",
    "05_intimacy_rendering":
        "b7b9a425b8a02c6f6a415c293a47922a329c9c7712840a7ef01a1f6e954ec460",
    "06_intimacy_reference":
        "dc0283f42fb1670d9a2ad3ab47a7ad225988c29dacc80cbe331fdd685bf226a3",
}
defaults = read("lib/core/rules/rule_layer_defaults.dart")
for key, expected in changed_hashes.items():
    actual = hashlib.sha256(parsed[key].encode("utf-8")).hexdigest()
    if actual != expected:
        assert f"'{key}': '{expected}'" in defaults, (key, actual)

action_heading = "【动作与神态格式】"
intimacy_action_heading = "【对白、动作与心理】"
assert parsed["02_daily"].count(action_heading) == 1
assert parsed["02_daily"].index("【成年恋爱与自然升温】") < parsed["02_daily"].index(
    action_heading
)
assert parsed["05_intimacy_rendering"].count(intimacy_action_heading) == 1
assert parsed["05_intimacy_rendering"].index("【节奏而非流程】") < parsed[
    "05_intimacy_rendering"
].index(intimacy_action_heading)
assert parsed["05_intimacy_rendering"].index(intimacy_action_heading) < parsed[
    "05_intimacy_rendering"
].index("【连续性与余韵】")
for token in (
    "全角括号“（）”",
    "括号块后空一行",
    "用「」或中文引号",
):
    assert token in parsed["02_daily"] and token in parsed["05_intimacy_rendering"]

database = read("lib/core/database/app_database.dart")
grouping = read("lib/core/rules/rule_layer_grouping.dart")
for token in (
    "legacyEditableRuleLayerSha256V0353",
    "f2edc5f4f0cbae257ddd063e5fd7c86fef1b534c5d7d5c9b547e6f71e71ae870",
    "343108532796cb68d586fca8cbe97e9d97bb5e5b1c82fba9dc33c1838a4a8cfe",
    "_approvedRuleContentsV0354",
):
    assert token in defaults, token
assert "...legacyEditableRuleLayerSha256V0353.entries" in database
for token in (
    "'05_intimacy_rendering': '06'",
    "'06_intimacy_reference': '06'",
):
    assert token in grouping, token

chat = read("lib/features/chat/chat_page.dart")
assert "_scrollToLatest();" in chat
assert "_scrollToLatest(animate: true);" in chat
assert "height: 24" in chat
assert "colorScheme.primary" in chat
assert "Colors.purpleAccent" not in chat
assert chat.index("'试穿 ${_shortRemaining") < chat.index("const Text('NSFW')")

overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
for token in (
    "chatRoot?.visibility = View.VISIBLE\n        scrollChatToBottom()",
    "ViewGroup.LayoutParams.MATCH_PARENT,\n                    dp(30)",
    "background = rounded(Color.rgb(44, 41, 50), 9f)",
):
    assert token in overlay, token

settings = read("lib/features/settings/settings_page.dart")
controller = read("lib/features/chat/chat_controller.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
for source in (settings, controller, proactive):
    assert "chatThinking" not in source
    assert "chat_thinking_enabled" not in source
assert "模型思考模式" not in settings
assert controller.count("thinking: true") >= 2
assert "thinking: true" in proactive
assert "thinking: true" in settings
assert "chat_temperature', 'chat_thinking_enabled" in database

workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)
for token in (
    "Build AI Companion v0.35.4+79 APK",
    "validate_v0354_prompt_format_chat_ui.py",
    "AI-Companion-v0.35.4-79-Prompt-Format-Chat-UI-APK.apk",
    ".ci/v0354-monitor.txt",
):
    assert token in workflow, token

print("v0.35.4 prompt format and chat UI validation passed")
