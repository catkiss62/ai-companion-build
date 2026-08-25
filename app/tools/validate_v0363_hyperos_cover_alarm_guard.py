from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


assert "version: 0.36.3+88" in read("pubspec.yaml")

accessibility = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt"
)
assert 'p == "com.miui.securitycenter"' not in accessibility
assert "refreshForegroundWindowTracker" in accessibility
assert "flagRetrieveInteractiveWindows" in read(
    "android/app/src/main/res/xml/accessibility_service_config.xml"
)

receiver = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/DelayedProactiveTestReceiver.kt"
)
for token in (
    "expectedDueAt",
    '"stale_due_at"',
    '"delayed_proactive_test_cancel_rejected"',
    '"delayed_proactive_test_cancelled"',
    '"delayedProactiveTestCancelledAt"',
    '"delayedProactiveTestCancelRejectedReason"',
):
    assert token in receiver, token

bridge = read("lib/core/platform/android_bridge.dart")
system_page = read("lib/features/system/system_page.dart")
inner_page = read("lib/features/inner/inner_page.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
for token in ("expectedDueAt", "reason"):
    assert token in bridge, token
assert "取消5分钟测试？" in system_page
assert "system_page_confirmed" in system_page
assert "取消5分钟测试？" in inner_page
assert "inner_page_confirmed" in inner_page
assert "cancelRejectedReason" in diagnostics
assert "delayed_proactive_cancelled" in diagnostics

print("v0.36.3 HyperOS cover and delayed-test cancellation guard validation passed")
