#!/usr/bin/env python3
"""Validate the v0.41.17 observation-compatible presentation hotfix."""

from pathlib import Path
import re


APP = Path(__file__).resolve().parents[1]
ROOT = APP.parent


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
chat = read("app/lib/features/chat/chat_page.dart")
immersive = read("app/lib/features/immersive/immersive_room_page.dart")
quick = read("app/lib/features/chat/chat_quick_settings_pages.dart")
tint = read("app/lib/widgets/action_tint_text.dart")
reasoning = read("app/lib/widgets/reasoning_panel.dart")
phone = read("app/lib/features/phone/simulated_phone_page.dart")
cart = read("app/lib/core/phone/simulated_cart_generator.dart")
bridge = read("app/lib/core/platform/android_bridge.dart")
system_bridge = read(
    "app/android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
overlay = read(
    "app/android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
workflow = read(".github/workflows/build-apk.yml")
docs = read("app/docs/CHAT_UI_MOOD_HOTFIX_v0.41.17.md")
doc_map = read("app/docs/DOCUMENTATION_MAP.md")
ledger = read("AI_Companion_当前总账.md")

assert re.search(
    r"^version:\s*0\.41\.(?:17\+156|18\+157|19\+158|20\+159|21\+160|22\+161|23\+162)\s*$",
    pubspec,
    re.MULTILINE,
)
assert any(schema in database for schema in (
    "static const int schemaVersion = 43;",
    "static const int schemaVersion = 44;",
))

assert (
    "chatDialoguePurple = Color(0xFFD2C3EB)" in tint
    or "chatDialoguePurple = Color(0xFFD4BBFC)" in tint
)
for token in (
    "chatDialogueGold = Color(0xFFFDE68A)",
    "chatDialoguePink = Color(0xFFF1B7C5)",
    "settingKey = 'chat_dialogue_color'",
    "ChatDialogueColorOption.purple",
    "ChatDialogueColorScope",
    "color: Colors.white",
):
    assert token in tint, token

for token in (
    "对白「」颜色",
    "ChatDialogueColorOption.values",
    "setOverlayDialogueColor",
):
    assert token in quick, token

for source in (chat, immersive):
    assert "ChatDialogueColorScope" in source
    assert "style: const TextStyle(color: Colors.white)" in source
assert chat.count("'DeepSeek'") >= 3
assert chat.count("color: Colors.white") >= 6
assert "_RelationshipDaysCard" in chat
assert "relationshipAge()" in chat
assert "认识第 ${age.dayNumber} 天" in chat
assert "她 · ${ProactiveIntentKind.fromKey" in chat

for token in (
    "'THINKING'",
    "Icons.arrow_right_rounded",
    "AnimatedRotation",
    "letterSpacing: 3.0",
):
    assert token in reasoning, token
assert "🧠 思考" not in reasoning
assert "▸  THINKING" in overlay and "▾  THINKING" in overlay

for token in ("SizedBox.expand", "LayoutBuilder", "width: double.infinity"):
    assert token in phone, token
assert "emoji" in cart and "_cleanEmoji" in cart

for token in ("setOverlayDialogueColor", "setDialogueColor"):
    assert token in bridge + system_bridge + overlay, token
assert (
    "Color.rgb(210, 195, 235)" in overlay
    or "Color.rgb(212, 187, 252)" in overlay
)
for token in (
    "KEY_DIALOGUE_COLOR",
    "Color.rgb(253, 230, 138)",
    "Color.rgb(241, 183, 197)",
):
    assert token in overlay, token

for token in (
    "CHAT_UI_MOOD_HOTFIX_v0.41.17.md",
    "v0.41.17+156",
    "Phase 2A",
    "relationshipAge()",
):
    assert token in docs + doc_map + ledger, token

for token in (
    "Build AI Companion v0.41.17+156 APK (Chat UI + Mood Hotfix)",
    "agent/v04117-chat-ui-mood-hotfix",
    "AI-Companion-v0.41.17-156-Chat-UI-Mood-Hotfix-APK",
    "v0.41.17-chat-ui-mood-hotfix-test",
    "validate_v04117_chat_ui_mood_hotfix.py",
):
    assert token in workflow, token

print("v0.41.17 chat UI and mood hotfix validation passed")
