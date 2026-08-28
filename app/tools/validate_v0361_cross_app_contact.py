from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


assert re.search(r"^version:\s*(?:0\.36\.(?:1\+86|2\+87|3\+88)|0\.37\.0\+89|0\.37\.1\+90|0\.37\.2\+91|0\.37\.3\+92|0\.37\.4\+93|0\.37\.5\+94|0\.37\.6\+95|0\.37\.7\+96|0\.37\.8\+97|0\.37\.9\+98|0\.38\.0\+99|0\.38\.1\+100|0\.38\.2\+101|0\.38\.3\+102|0\.38\.4\+103|0\.38\.5\+104|0\.38\.6\+105|0\.38\.7\+106|0\.38\.8\+107|0\.38\.9\+108|0\.38\.10\+109|0\.38\.11\+110|0\.38\.12\+111|0\.38\.13\+112|0\.38\.14\+113|0\.38\.15\+114|0\.38\.16\+115|0\.38\.18\+117|0\.39\.0\+118|0\.39\.1\+119|0\.39\.2\+120|0\.39\.3\+121|0\.39\.4\+122|0\.39\.5\+123|0\.39\.6\+124|0\.39\.7\+125|0\.39\.8\+126|0\.39\.9\+127|0\.40\.0\+128|0\.40\.1\+129|0\.40\.2\+130|0\.40\.3\+131)\s*$", read("pubspec.yaml"), re.M)
assert "static const int schemaVersion = 26;" in read(
    "lib/core/database/app_database.dart"
)

notification = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionNotification.kt"
)
for token in (
    "CHANNEL_MESSAGES_CHIME",
    "CHANNEL_MESSAGES_SOFT",
    "CHANNEL_MESSAGES_CHIME_V2",
    "CHANNEL_MESSAGES_SOFT_V2",
    "CHANNEL_MESSAGES_BUBBLE_V1",
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
    "试听当前声音",
    "测试系统弹窗",
):
    assert token in settings, token
notification_settings = read("lib/core/models/proactive_notification_settings.dart")
assert "始终弹窗" in notification_settings
assert "清脆三音" in notification_settings
assert "气泡轻弹" in notification_settings

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
assert "OverlayDialogueFormatter.visibleText(value)" in overlay
assert "ForegroundColorSpan(Color.rgb(253, 230, 138))" in overlay
assert "setLineSpacing(0f, 1.45f)" in overlay

for asset in (
    "android/app/src/main/res/raw/companion_chime.ogg",
    "android/app/src/main/res/raw/companion_soft.ogg",
):
    data = (ROOT / asset).read_bytes()
    assert len(data) > 2_000, asset
    assert data.startswith(b"OggS"), asset

for asset in (
    "android/app/src/main/res/raw/companion_chime_v2.wav",
    "android/app/src/main/res/raw/companion_soft_v2.wav",
    "android/app/src/main/res/raw/companion_bubble_v1.wav",
):
    data = (ROOT / asset).read_bytes()
    assert len(data) > 40_000, asset
    assert data.startswith(b"RIFF") and data[8:12] == b"WAVE", asset

print("v0.36.1 cross-App contact, popup sound and delayed probe validation passed")
