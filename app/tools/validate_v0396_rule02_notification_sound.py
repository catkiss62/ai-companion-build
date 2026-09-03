#!/usr/bin/env python3
from array import array
import hashlib
import math
from pathlib import Path
import re
import wave


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("pubspec.yaml")
assert re.search(r"^version:\s*(?:0\.39\.(?:6\+124|7\+125|8\+126|9\+127)|0\.40\.0\+128|0\.40\.1\+129|0\.40\.2\+130|0\.40\.3\+(?:131|132)|0\.40\.4\+133|0\.40\.5\+134|0\.40\.6\+135|0\.40\.7\+136)\s*$", pubspec, re.MULTILINE) or "version: 0.40.9+138" in (Path(__file__).resolve().parents[1] / "pubspec.yaml").read_text()
assert "static const int schemaVersion = 35;" in read(
    "lib/core/database/app_database.dart"
)

rules = read("lib/core/rules/rule_layer_content_v0353.dart")
pubspec = read("pubspec.yaml")
daily_match = re.search(
    r"const ruleContentV0353_02_daily = r'''(.*?)''';",
    rules,
    re.DOTALL,
)
assert daily_match is not None
daily = daily_match.group(1)
assert hashlib.sha256(daily.encode("utf-8")).hexdigest() in {
    "7b44d761ace955eed046e744a710d9b354a8377ba2372eb6cd21581db125b297",
    "8dc45274cb261a29ef86356ffd1553609aabbd7fe3534249a11115504cf88465",
    "e228e094fd200332c6095ac653718ce0d6c3e1e219ea6bb619a62b792a84cf11",
    "71636a48159cc3e4103289bff26a5ff8c0292dfde4272f9c7942da74a817a091",
    "e696505368a76c753ba0fd4cb747bc3819b79bbf1a36b3cfab84fb94a70f0444",
    "3a2e70a3627ff5ee6a782ee1d3f8ea577611e6f367162d59b685e2432dddbbd2",
    "a9178148ecf10bd017df69ee2a90ce83195a617964f25742c85ed0fb035f11f2",
    "e025e551a4328bdf49e27aeb9c2ffef131587dfd02203b6aadd289662af6a6da",
}
if any(version in pubspec for version in (
    "version: 0.41.23+162", "version: 0.41.24+163"
)):
    assert "独立动作神态实验规则" in daily
    assert "普通聊天与沉浸分流" in daily
elif "version: 0.41.22+161" in pubspec:
    assert "普通聊天正文禁止动作、神态、语气说明" in daily
    assert "普通聊天与沉浸分流" in daily
else:
    for token in ("说出口的话独占一行", "动作留在「」外", "动作不是装饰配额"):
        assert token in daily, token
    assert ("每轮对话至少要出现一次" in daily) != (
        "普通短回合可以完全不写动作" in daily
    )
    assert "允许纯对白" not in daily

defaults = read("lib/core/rules/rule_layer_defaults.dart")
database = read("lib/core/database/app_database.dart")
for legacy_hash in (
    "6b9db829f50484714894feac685edc640768596dbf6146a5f7489d3bcbf6daa9",
    "0cc47a4abb1e831333de488c54d0fca00282232b0348078bb353f7769cf951f3",
    "7c0e7ed0270de488f37205d4ba3732763f2728efa34ec117b468e21f8fc8db4e",
):
    assert legacy_hash in defaults, legacy_hash
for migration in (
    "legacyEditableRuleLayerSha256V0395.entries",
    "legacyEditableRuleLayerSha256V0395UserOnce.entries",
    "legacyEditableRuleLayerSha256V0395UserOnceWithoutPureDialogue.entries",
    "legacyEditableRuleLayerSha256V0396.entries",
):
    assert migration in database, migration

notification = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionNotification.kt"
)
preview = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/NotificationSoundPreview.kt"
)
system_bridge = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
flutter_bridge = read("lib/core/platform/android_bridge.dart")
settings = "\n".join(
    read(path)
    for path in (
        "lib/features/settings/settings_page.dart",
        "lib/features/settings/settings_category_pages.dart",
        "lib/features/chat/chat_quick_settings_pages.dart",
    )
)
sound_settings = read("lib/core/models/proactive_notification_settings.dart")

for token in (
    "companion_messages_chime_v2",
    "companion_messages_soft_v2",
    "companion_messages_bubble_v1",
    "R.raw.companion_chime_v2",
    "R.raw.companion_soft_v2",
    "R.raw.companion_bubble_v1",
):
    assert token in notification, token
assert '"bubble" -> CHANNEL_MESSAGES_BUBBLE_V1' in notification
assert "previewCompanionNotificationSound" in system_bridge
assert "previewCompanionNotificationSound" in flutter_bridge
assert "MediaPlayer.create" in preview
assert "USAGE_NOTIFICATION" in preview
for token in ("清脆三音", "柔和水滴", "气泡轻弹"):
    assert token in sound_settings, token
for token in ("试听当前声音", "测试系统弹窗", "这一步不经过系统通知频道"):
    assert token in settings, token

expected_audio = {
    "android/app/src/main/res/raw/companion_chime_v2.wav": (
        "ac4bbe754a60c23776bc3df878c739f852b28caeeb3a38c7821fe0b95f857333"
    ),
    "android/app/src/main/res/raw/companion_soft_v2.wav": (
        "bf73de615a434b313cadaf5211fac1d0879988f8ab26caf63f3dcd0a5e4df9c2"
    ),
    "android/app/src/main/res/raw/companion_bubble_v1.wav": (
        "eb470d68ef46895e244e5198ec3be528d43635ea0072d5575197a0ad64857b6c"
    ),
}
for relative, expected_hash in expected_audio.items():
    path = ROOT / relative
    payload = path.read_bytes()
    assert hashlib.sha256(payload).hexdigest() == expected_hash, relative
    with wave.open(str(path), "rb") as wav:
        assert wav.getnchannels() == 1, relative
        assert wav.getsampwidth() == 2, relative
        assert wav.getframerate() == 48_000, relative
        duration = wav.getnframes() / wav.getframerate()
        assert 0.45 <= duration <= 0.80, (relative, duration)
        samples = array("h", wav.readframes(wav.getnframes()))
    peak = max(abs(sample) for sample in samples)
    peak_dbfs = 20.0 * math.log10(peak / 32768.0)
    assert -8.0 <= peak_dbfs <= -3.0, (relative, peak_dbfs)

notice = read("docs/NOTIFICATION_SOUND_ASSETS.md")
for expected_hash in expected_audio.values():
    assert expected_hash in notice

workflow = read("../.github/workflows/build-apk.yml")
assert "python3 tools/validate_v0396_rule02_notification_sound.py" in workflow
assert any(branch in workflow for branch in (
    "agent/v0396-rule02-message-sound",
    "agent/v0397-reasoning-translation-dialogue-boundary",
))
assert any(name in workflow for name in (
    "Build AI Companion v0.39.6+124 APK (Rule02 and Notification Sounds)",
    "Build AI Companion v0.39.7+125 APK (Reasoning Translation and Spoken-Line Boundary)",
))
assert any(artifact in workflow for artifact in (
    "AI-Companion-v0.39.6-124-Rule02-Notification-Sounds-APK",
    "AI-Companion-v0.39.7-125-Reasoning-Translation-Spoken-Line-APK",
))
assert any(tag in workflow for tag in (
    "v0.39.6-rule02-notification-sounds",
    "v0.39.7-reasoning-translation-spoken-line",
))

print("v0.39.6 Rule02 quote boundary and notification sound validation passed")
