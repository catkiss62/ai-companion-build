#!/usr/bin/env python3
"""Validate v0.41.18 settings IA, save isolation and small presentation copy."""

from pathlib import Path
import re


APP = Path(__file__).resolve().parents[1]
ROOT = APP.parent


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
settings = read("app/lib/features/settings/settings_page.dart")
categories = read("app/lib/features/settings/settings_category_pages.dart")
quick = read("app/lib/features/chat/chat_quick_settings_pages.dart")
tint = read("app/lib/widgets/action_tint_text.dart")
intent = read("app/lib/core/models/proactive_intent.dart")
overlay = read(
    "app/android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
notification = read(
    "app/android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionNotification.kt"
)
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
workflow = read(".github/workflows/build-apk.yml")
docs = read("app/docs/SETTINGS_INFORMATION_ARCHITECTURE_v0.41.18.md")
doc_map = read("app/docs/DOCUMENTATION_MAP.md")
ledger = read("AI_Companion_当前总账.md")

assert re.search(r"^version:\s*0\.41\.(?:18\+157|19\+158)\s*$", pubspec, re.MULTILINE)
assert any(
    value in self_reader
    for value in ("buildLabel = 'v0.41.18+157'", "buildLabel = 'v0.41.19+158'")
)
assert any(
    value in database
    for value in (
        "static const int schemaVersion = 43;",
        "static const int schemaVersion = 44;",
    )
)

for title in (
    "模型与联网",
    "记忆与成长",
    "主动联系与感知",
    "语音与聊天呈现",
    "设备与数据",
    "诊断与开发",
):
    assert title in settings, title
assert "两处使用同一份设置" in settings
assert "Future<void> _save()" not in settings

for page in (
    "ModelNetworkSettingsPage",
    "MemoryGrowthSettingsPage",
    "ProactivePerceptionSettingsPage",
    "PresentationSettingsPage",
    "DeviceDataSettingsPage",
    "DiagnosticsDevelopmentSettingsPage",
):
    assert f"class {page}" in categories, page

for token in (
    "保存本小节",
    "保存视觉配置",
    "保存网页来源",
    "Endpoint 验证",
    "proactive_adaptation_enabled",
    "perception_enabled",
    "beginFreshConversationContext",
    "Active Brain",
    "快速自检与诊断报告",
    "内在状态开发工具",
):
    assert token in categories + quick + docs, token

for shared_page in (
    "ProactiveContactSettingsPage",
    "ChatVisualSettingsPage",
    "VoiceEmotionSettingsPage",
    "TextPerformanceSettingsPage",
):
    assert shared_page in categories, shared_page
assert "proactive_adaptation_enabled" in quick
for key in (
    "auto_tts",
    "tts_streaming_enabled",
    "tts_speed",
    "tts_volume",
    "tts_replacements_json",
):
    assert key in quick, key

assert "chatDialoguePurple = Color(0xFFD4BBFC)" in tint
assert overlay.count("Color.rgb(212, 187, 252)") >= 3
for source in (intent, overlay, notification):
    assert "想起之前的话" in source
    assert "想起刚才的话" not in source

for token in (
    "SETTINGS_INFORMATION_ARCHITECTURE_v0.41.18.md",
    "v0.41.18+157",
    "Phase 2A",
    "#D4BBFC",
):
    assert token in docs + doc_map + ledger, token

assert "validate_v04118_settings_information_architecture.py" in workflow
assert any(
    token in workflow
    for token in (
        "Build AI Companion v0.41.18+157 APK (Settings Information Architecture)",
        "Build AI Companion v0.41.19+158 APK (Phase 2A Stabilization)",
    )
)

print("v0.41.18 settings information architecture validation passed")
