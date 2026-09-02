from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


assert "version: 0.36.3+88" in read("pubspec.yaml")

resolver = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CurrentAppResolver.kt"
)
for token in (
    "current_app_tracker",
    "noteForegroundApp",
    "clearTrackedApp",
    "resolveCurrentWithRetries",
    "TRACKED_APP_MAX_AGE_MS",
    "currentAppWindowCandidateCount",
    "currentAppLastRetryResult",
    "currentAppTrackerRawPackageIncluded\" to false",
):
    assert token in resolver, token

accessibility = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt"
)
for token in (
    "TYPE_WINDOWS_CHANGED",
    "refreshForegroundWindowTracker",
    "AccessibilityWindowInfo.TYPE_APPLICATION",
    "interactive_window_selected",
):
    assert token in accessibility, token

accessibility_xml = read("android/app/src/main/res/xml/accessibility_service_config.xml")
assert "typeWindowsChanged" in accessibility_xml
assert "flagRetrieveInteractiveWindows" in accessibility_xml

notification = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionNotification.kt"
)
for token in (
    "CONVERSATION_NOTIFICATION_ID",
    "Notification.MessagingStyle",
    "acknowledgeMessages",
    "ACTION_CHANNEL_NOTIFICATION_SETTINGS",
    "companionNotificationStyle\" to \"messaging",
):
    assert token in notification, token

overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
assert 'acknowledgeMessages(this, "overlay_chat_opened")' in overlay
for token in (
    "OverlayDialogueFormatter.visibleText(value)",
    "OverlayDialogueFormatter.dialogueRanges(visible)",
):
    assert token in overlay, token
assert any(token in overlay for token in (
    "ForegroundColorSpan(Color.rgb(253, 230, 138))",
    "ForegroundColorSpan(dialogueTintColor())",
))
assert "Color.rgb(253, 230, 138)" in overlay
assert "Color.rgb(216, 177, 255)" not in overlay

controller = read("lib/features/chat/chat_controller.dart")
bridge = read("lib/core/platform/android_bridge.dart")
settings = "\n".join(
    read(path)
    for path in (
        "lib/features/settings/settings_page.dart",
        "lib/features/settings/settings_category_pages.dart",
        "lib/features/chat/chat_quick_settings_pages.dart",
    )
)
assert "acknowledgeCompanionNotifications" in controller
assert "openCompanionNotificationSettings" in bridge
assert "打开该频道的浮动通知设置" in settings

receiver = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/DelayedProactiveTestReceiver.kt"
)
assert "goAsync()" in receiver
assert "resolveCurrentWithRetries" in receiver
assert "appResolutionResult" in receiver
assert "appRetryCount" in receiver

diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
assert "currentAppTracker" in diagnostics
assert "delayed_proactive_notification" in diagnostics
assert "delayed_proactive_current_app" in diagnostics

print("v0.36.2 foreground tracker, conversation banner and tint validation passed")
