#!/usr/bin/env python3
"""Static contract checks for v0.34.5 direct system-picker overlay recovery."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT.parent / ".github" / "workflows" / "build-apk.yml"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(text: str, tokens: list[str], label: str) -> None:
    missing = [token for token in tokens if token not in text]
    if missing:
        raise AssertionError(f"{label} missing: {missing}")


pubspec = read("pubspec.yaml")
chat = read("lib/features/chat/chat_page.dart")
android_bridge = read("lib/core/platform/android_bridge.dart")
system_bridge = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
ledger = (ROOT.parent / "AI_Companion_当前总账.md").read_text(encoding="utf-8")
handoff = ledger
workflow = WORKFLOW.read_text(encoding="utf-8")

assert "version: 0.34.7+72" in pubspec

require(android_bridge, [
    "beginSystemPickerOverlayGuard",
    "endSystemPickerOverlayGuard",
    "'beginSystemPickerOverlayGuard'",
    "'endSystemPickerOverlayGuard'",
    "on PlatformException",
    "on MissingPluginException",
], "best-effort Flutter picker bridge")

require(chat, [
    "final AndroidBridge _android = AndroidBridge.instance;",
    "flutter_image_picker_gallery",
    "flutter_image_picker_camera",
    "await _android.beginSystemPickerOverlayGuard(",
    "image = await _imagePicker.pickImage(",
    "await _android.endSystemPickerOverlayGuard(",
], "image picker direct cover guard")
assert "final AndroidBridge _android = AndroidBridge();" not in chat

begin = chat.index("await _android.beginSystemPickerOverlayGuard(")
pick = chat.index("image = await _imagePicker.pickImage(", begin)
end = chat.index("await _android.endSystemPickerOverlayGuard(", pick)
prepare = chat.index("await _prepareAndConfirmImage(", end)
assert begin < pick < end < prepare

require(system_bridge, [
    'private var directPickerGuardDepth = 0',
    '"beginSystemPickerOverlayGuard"',
    '"endSystemPickerOverlayGuard"',
    "OverlayBubbleService.notifySystemCoverEntered(",
    "OverlayBubbleService.notifySystemCoverExited(",
    '"direct_picker:${reason.take(80)}"',
    'beginDirectPickerOverlayGuard("diagnostic_export_picker")',
    'beginDirectPickerOverlayGuard("manual_snapshot_save_picker")',
    'beginDirectPickerOverlayGuard("manual_snapshot_open_picker")',
    'endDirectPickerOverlayGuard("diagnostic_export_picker_returned")',
    '"manual_snapshot_save_picker_returned"',
    '"manual_snapshot_open_picker_returned"',
], "native and Flutter picker direct cover guard")

diagnostic_result = system_bridge.index(
    'if (requestCode == REQUEST_DIAGNOSTIC_SAVE) {'
)
diagnostic_exit = system_bridge.index(
    'endDirectPickerOverlayGuard("diagnostic_export_picker_returned")',
    diagnostic_result,
)
diagnostic_state = system_bridge.index(
    "val result = reportDocumentResult ?: return",
    diagnostic_exit,
)
assert diagnostic_result < diagnostic_exit < diagnostic_state

require(overlay, [
    "private const val COVER_RECOVERY_MAX_ATTEMPTS = 3",
    "WindowManager.addView() returns before isAttachedToWindow becomes",
    "notifySystemCoverEntered",
    "notifySystemCoverExited",
], "bounded existing recovery remains authoritative")
assert "COVER_RECOVERY_MAX_ATTEMPTS = 4" not in overlay

require(ledger, [
    "v0.34.5+70",
    "直接选择器 guard",
    "冻结悬浮恢复",
], "task ledger")

require(handoff, [
    "v0.34.5+70",
    "direct picker",
    "不回滚 v0.34.4 settle",
], "handoff")

require(workflow, [
    "Build AI Companion v0.34.7+72 APK (Autonomous Action Foundation)",
    "python3 tools/validate_v0345_direct_picker_overlay_guard.py",
    "AI-Companion-v0.34.7-72-Autonomous-Action-Foundation-APK",
    "actions: read",
    "report-ci-failure:",
    "AI-Companion-v0.34.7-72-CI-Monitor.txt",
    "needs.build-apk.result != 'success'",
    "gh run view \"${GITHUB_RUN_ID}\"",
    "release_url=${RELEASE_URL}",
    "ci-monitor-v0345",
    ".ci/v0345-monitor.txt",
    "gh api --method PUT",
], "workflow")

print("v0.34.5 direct system-picker overlay guard validated")
