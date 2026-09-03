#!/usr/bin/env python3
"""Static contracts for v0.39.3 ordinary-chat presentation repairs."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


database = read("lib/core/database/app_database.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
rules = read("lib/core/rules/rule_layer_content_v0353.dart")
chat = read("lib/features/chat/chat_page.dart")
flutter_formatter = read("lib/widgets/action_tint_text.dart")
flutter_test = read("test/action_tint_text_test.dart")
native_formatter = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayDialogueFormatter.kt"
)
native_test = read(
    "android/app/src/test/kotlin/com/aicompanion/localfirst/OverlayDialogueFormatterTest.kt"
)
workflow = read("../.github/workflows/build-apk.yml")

assert "static const int schemaVersion = 35;" in database

# v0.39.4 supersedes the duplicated v0.39.3 code-owned person reminder. The
# complete subjectless format lives in editable Rule 02; internal Rule 08 only
# delegates to it and keeps visible-thought/body perspective distinct.
if "version: 0.41.22+161" in read("pubspec.yaml"):
    for token in (
        "普通聊天正文禁止动作、神态、语气说明",
        "普通聊天与沉浸分流",
        "普通聊天最终正文严格遵守规则02",
    ):
        assert token in rules, token
else:
    for token in (
        "不加括号并默认省略主语",
        "不使用“我/她/角色名”作动作主语",
        "省略主语的动作默认只描述自己",
        "不替用户编写动作、台词、内心或没有真实提供的反应",
        "严格遵守规则02【动作与神态格式】和【最终正文中的现实恋人称呼】",
    ):
        assert token in rules, token
for removed in (
    "普通聊天正文的人称与可见 reasoning 分开",
    "禁止用“我”“她”",
    "只用第二人称“你”",
):
    assert removed not in prompt, removed

# The left region retains row width for the emotion label, while Align keeps
# the actual InkWell limited to avatar + DeepSeek + emotion content.
top_bar = chat[chat.index("Widget _topBar"):chat.index("Widget _composer")]
assert "Expanded(" in top_bar
assert "alignment: Alignment.centerLeft" in top_bar
assert "mainAxisSize: MainAxisSize.min" in top_bar
assert "const Spacer()" not in top_bar
assert "_currentEmotionLabel" in top_bar

# Both Flutter and native overlay use balanced corner-quote depth rather than
# stopping at the first inner closing quote. Streaming keeps an unmatched
# outer quote tinted to the current end.
for source in (flutter_formatter, native_formatter):
    assert "depth" in source
    assert "reachedEnd" in source
assert "nested corner quotes keep the whole outer dialogue tinted" in flutter_test
assert "nested quote remains tinted while the outer quote is streaming" in flutter_test
assert "nested corner quotes keep the outer dialogue range intact" in native_test
assert "nested quote stays dialogue while outer quote is streaming" in native_test

assert "python3 tools/validate_v0393_ordinary_chat_presentation.py" in workflow
assert any(
    branch in workflow
    for branch in (
        "agent/v0395-meju-tts-runtime-upgrade",
        "agent/v0396-rule02-message-sound",
        "agent/v0397-reasoning-translation-dialogue-boundary",
    )
)
assert any(
    artifact in workflow
    for artifact in (
        "AI-Companion-v0.39.5-123-Meju-TTS-Runtime-Upgrade-APK",
        "AI-Companion-v0.39.6-124-Rule02-Notification-Sounds-APK",
        "AI-Companion-v0.39.7-125-Reasoning-Translation-Spoken-Line-APK",
    )
)

print("v0.39.3 ordinary-chat presentation contracts passed")
