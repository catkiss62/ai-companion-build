#!/usr/bin/env python3
"""Static contracts for v0.39.3 ordinary-chat presentation repairs."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
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

assert "version: 0.39.3+121" in pubspec
assert "static const int schemaVersion = 35;" in database

# Ordinary-chat body perspective is distinct from visible inner thought. The
# code-owned last-turn reminder applies even when editable Rule 06 is inactive
# or later third-person examples are present in the reference body.
for token in (
    "普通聊天正文的人称与可见 reasoning 分开",
    "禁止用“我”“她”",
    "只用第二人称“你”",
    "这不禁止对白中自然使用第一人称",
):
    assert token in prompt, token

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
assert "agent/v0393-ordinary-chat-presentation-hotfix" in workflow
assert "AI-Companion-v0.39.3-121-Ordinary-Chat-Presentation-Hotfix-APK" in workflow

print("v0.39.3 ordinary-chat presentation contracts passed")
