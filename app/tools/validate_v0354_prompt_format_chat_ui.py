#!/usr/bin/env python3
from pathlib import Path
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), f"{relative} is empty"
    return value


assert re.search(r"^version: 0\.35\.(?:4\+79|5\+80)$", read("pubspec.yaml"), re.MULTILINE)
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
    "02_daily": "88ac7e4d3a1bab29bfcc3cb217080dfc21f0ac2494d7936beb9fcbb337f95ce6",
    "05_intimacy_rendering":
        "af3edbd207d81c79d1e328fa0eb0751b2d275ce5e332d954256feff5cd46241f",
    "06_intimacy_reference":
        "dc0283f42fb1670d9a2ad3ab47a7ad225988c29dacc80cbe331fdd685bf226a3",
}
for key, expected in changed_hashes.items():
    actual = hashlib.sha256(parsed[key].encode("utf-8")).hexdigest()
    assert actual == expected, (key, actual)

action_heading = "【动作与神态格式】"
scene_anchor = "【场景锚定：极乐专注锁】"
assert parsed["02_daily"].count(action_heading) == 1
assert parsed["02_daily"].index("【叙事克制】") < parsed["02_daily"].index(
    action_heading
)
assert parsed["02_daily"].index(action_heading) < parsed["02_daily"].index(
    "【减少无意义细节】"
)
assert parsed["05_intimacy_rendering"].count(action_heading) == 1
assert parsed["05_intimacy_rendering"].index(action_heading) < parsed[
    "05_intimacy_rendering"
].index(scene_anchor)
for token in (
    "角色的动作、神态、语气、微表情，用英文或中文括号标注。",
    "纯对白不加括号。",
    "内心想法不用括号，用对白旁白的方式表达，或让对方通过你的话推测。",
):
    assert token in parsed["02_daily"] and token in parsed["05_intimacy_rendering"]

defaults = read("lib/core/rules/rule_layer_defaults.dart")
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
