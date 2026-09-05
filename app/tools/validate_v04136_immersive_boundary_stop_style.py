#!/usr/bin/env python3
"""Static contracts for v0.41.36 immersive boundary and stop style closeout."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("app/pubspec.yaml")
database = read("app/lib/core/database/app_database.dart")
controller = read("app/lib/core/immersive/immersive_room_controller.dart")
page = read("app/lib/features/immersive/immersive_room_page.dart")
overlay = read(
    "app/android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
workflow = read(".github/workflows/build-apk.yml")
ledger = read("AI_Companion_当前总账.md")

assert "version: 0.41.36+175" in pubspec
assert "static const int schemaVersion = 48;" in database
assert "buildLabel = 'v0.41.36+175'" in self_reader

for token in (
    "isReservedSystemInspectionCommand(text)",
    "rawText.trimLeft().startsWith('【检查系统】')",
    "notice = '请在普通聊天中检查系统'",
    "void dismissNotice()",
):
    assert token in controller, token

send_start = controller.index("Future<void> send(String rawText)")
boundary = controller.index("isReservedSystemInspectionCommand(text)", send_start)
api_key = controller.index("secureConfig.readApiKey()", send_start)
persist = controller.index("repository.addMessage(", send_start)
assert boundary < api_key < persist

for token in (
    "if (controller.notice != null)",
    "controller.dismissNotice",
    "请在普通聊天中检查系统",
    "textTheme.bodyMedium?.copyWith",
):
    assert token in page + controller, token

interrupted_color_start = overlay.index(
    'if (message.role == "interrupted_user")'
)
interrupted_color_block = overlay[interrupted_color_start:interrupted_color_start + 240]
assert "Color.rgb(169, 165, 179)" in interrupted_color_block

for token in (
    "agent/v04136-immersive-boundary-stop-style",
    "Build AI Companion v0.41.36+175 APK",
    "AI-Companion-v0.41.36-175-Immersive-Boundary-Stop-Style-APK",
    "validate_v04136_immersive_boundary_stop_style.py",
):
    assert token in workflow, token

for token in (
    "v0.41.36",
    "沉浸玩法边界",
    "请在普通聊天中检查系统",
    "中断灰显",
):
    assert token in ledger, token

print("v0.41.36 immersive boundary and stop style validation passed")
