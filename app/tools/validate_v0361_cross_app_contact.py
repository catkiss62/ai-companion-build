from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


assert re.search(r"^version:\s*(?:0\.36\.(?:1\+86|2\+87|3\+88)|0\.37\.0\+89|0\.37\.1\+90|0\.37\.2\+91)\s*$", read("pubspec.yaml"), re.M)
assert "static const int schemaVersion = 26;" in read(
    "lib/core/database/app_database.dart"
)

notification = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionNotification.kt"
)
for token in (
    "CHANNEL_MESSAGES_CHIME",
    "CHANNEL_MESSAGES_SOFT",
    "CHANNEL_MESSAGES_SILENT",
    "IMPORTANCE_HIGH",
    "REMOTE_INPUT_REPLY",
    "companion_notification_posted",
):
    assert token in notification, token

receiver = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/DelayedProactiveTestReceiver.kt"
)
for token in (
    "setAndAllowWhileIdle",
    "CurrentAppResolver.resolveCurrentWithRetries",
    "memoryWritten\" to false",
    "modelCalled\" to false",
    "delayed_proactive_test_completed",
):
    assert token in receiver, token

resolver = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CurrentAppResolver.kt"
)
for token in (
    "accessibility_window",
    "accessibility_window",
    "usage_events",
    "usage_stats_fallback",
    "appLabel",
):
    assert token in resolver, token

manifest = read("android/app/src/main/AndroidManifest.xml")
assert "android.permission.QUERY_ALL_PACKAGES" in manifest
assert ".DelayedProactiveTestReceiver" in manifest

proactive = read("lib/core/desire/proactive_engine.dart")
assert "ProactivePopupMode.fromSetting" in proactive
assert "effectiveNotificationDelivery" in proactive
assert "soundKey: notificationSound.key" in proactive

settings = read("lib/features/settings/settings_page.dart")
for token in (
    "ProactivePopupMode.alwaysPopup",
    "测试当前弹窗与提示音",
):
    assert token in settings, token
notification_settings = read("lib/core/models/proactive_notification_settings.dart")
assert "始终弹窗" in notification_settings
assert "清脆双音" in notification_settings

diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
for token in (
    "currentAppFusion",
    "proactiveNotificationDelivery",
    "delayedProactiveTest",
    "rawAppIncluded': false",
):
    assert token in diagnostics, token

overlay = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
assert "StyleSpan(Typeface.ITALIC)" in overlay
assert "setLineSpacing(0f, 1.45f)" in overlay

for asset in (
    "android/app/src/main/res/raw/companion_chime.ogg",
    "android/app/src/main/res/raw/companion_soft.ogg",
):
    data = (ROOT / asset).read_bytes()
    assert len(data) > 2_000, asset
    assert data.startswith(b"OggS"), asset

print("v0.36.1 cross-App contact, popup sound and delayed probe validation passed")
