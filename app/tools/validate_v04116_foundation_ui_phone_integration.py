#!/usr/bin/env python3
"""Static contracts for v0.41.16 phone and UI integration."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
mood = read("app/lib/core/phone/mood_chart_layout.dart")
phone = read("app/lib/features/phone/simulated_phone_page.dart")
cart_generator = read("app/lib/core/phone/simulated_cart_generator.dart")
cart_repository = read("app/lib/core/phone/simulated_phone_repository.dart")
immersive = read("app/lib/features/immersive/immersive_room_page.dart")
quick_pages = read("app/lib/features/chat/chat_quick_settings_pages.dart")
chat = read("app/lib/features/chat/chat_page.dart")
theme = read("app/lib/core/presentation/app_theme.dart")
app = read("app/lib/app.dart")
main = read("app/lib/main.dart")
docs = read("app/docs/PHONE_UI_INTEGRATION_v0.41.16.md")
doc_map = read("app/docs/DOCUMENTATION_MAP.md")
ledger = read("AI_Companion_当前总账.md")
workflow = read(".github/workflows/build-apk.yml")

assert "version: 0.41.16+155" in pubspec
assert "static const int schemaVersion = 43;" in database
assert "buildLabel = 'v0.41.16+155'" in self_reader
assert "immersive_panel_fraction" in database

for token in (
    "class MoodChartLayout",
    "List<String>.generate(7",
    "dayFraction",
    "DateTime.utc",
):
    assert token in mood, token
assert "MoodChartLayout.build" in phone
assert (ROOT / "app/test/mood_chart_layout_v04116_test.dart").is_file()

for token in (
    "恰好 6 件",
    "normal或playful",
    "recentTitles.take(36)",
    "鲸鱼娘",
    "DeepSeekModelProfile.flash",
    ".timeout(const Duration(seconds: 18))",
):
    assert token in cart_generator, token
for token in (
    "_cartHistoryKey",
    "fallback_catalog",
    "_fallbackNormalCart",
    "_fallbackPlayfulCart",
    "existing.length == 6",
    "existing.every((entry) => entry.localDay == day)",
):
    assert token in cart_repository, token
assert cart_repository.count("SimulatedCartItem(title:") >= 36
for forbidden in (
    "loadDesire(",
    "currentThoughts",
    "memory_repository",
    "personality_candidate",
):
    assert forbidden not in cart_generator, forbidden
assert (ROOT / "app/test/simulated_cart_generator_v04116_test.dart").is_file()

for token in (
    "Matrix4.identity()",
    "rotateY(_rotation.value)",
    "math.pi * 2",
    "disableAnimations",
    "required this.active",
):
    assert token in phone, token

for token in (
    "immersive_panel_fraction",
    "_panelFraction",
    ".clamp(0.42, 0.94)",
    "onVerticalDragUpdate",
):
    assert token in immersive, token
assert "chat_panel_fraction" not in immersive

for token in (
    "class CompanionStateOverviewPage",
    "db.loadDesire()",
    "SqliteMoeRepository",
    "当前值 / 长期基线",
    "class ProactiveContactSettingsPage",
    "class ChatVisualSettingsPage",
    "class VoiceEmotionSettingsPage",
    "class TextPerformanceSettingsPage",
):
    assert token in quick_pages, token
for forbidden in ("advance(", "tick(", "force", "currentThoughts"):
    assert forbidden not in quick_pages, forbidden
for token in ("查手机", "沉浸房间", "她现在的状态", "全部设置"):
    assert token in chat, token

for token in ("secondaryText", "helperText", "listTileTheme"):
    assert token in theme, token
assert "CompanionAppTheme.dark()" in app
assert "CompanionAppTheme.dark()" in main

for token in (
    "PHONE_UI_INTEGRATION_v0.41.16.md",
    "Phase 2A",
    "第二步",
    "schema 43",
):
    assert token in docs + doc_map + ledger, token

for token in (
    "Build AI Companion v0.41.16+155 APK (Phone + UI Integration)",
    "agent/v04116-foundation-ui-phone-integration",
    "AI-Companion-v0.41.16-155-Phone-UI-Integration-APK",
    "v0.41.16-phone-ui-integration-test",
    "validate_v04116_foundation_ui_phone_integration.py",
):
    assert token in workflow, token

print("v0.41.16 phone and UI integration validation passed")
