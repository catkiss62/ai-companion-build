#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), f"{relative} is empty"
    return value


assert re.search(r"^version: (?:0\.35\.(?:5\+80|6\+81|7\+82|8\+83|9\+84)|0\.36\.(?:0\+85|1\+86|2\+87|3\+88)|0\.37\.0\+89|0\.37\.1\+90|0\.37\.2\+91|0\.37\.3\+92|0\.37\.4\+93|0\.37\.5\+94|0\.37\.6\+95|0\.37\.7\+96|0\.37\.8\+97|0\.37\.9\+98|0\.38\.0\+99|0\.38\.1\+100|0\.38\.2\+101|0\.38\.3\+102|0\.38\.4\+103|0\.38\.5\+104|0\.38\.6\+105|0\.38\.7\+106|0\.38\.8\+107|0\.38\.9\+108|0\.38\.10\+109|0\.38\.11\+110)$", read("pubspec.yaml"), re.MULTILINE)
assert "static const int schemaVersion = 26;" in read(
    "lib/core/database/app_database.dart"
)

grounding = read("lib/core/grounding/grounding_snapshot.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
grounding_test = read("test/grounding_snapshot_test.dart")
for token in (
    "previousConversationAt",
    "currentTurnGapMinutes",
    "currentTurnCrossedCalendarDays",
    "currentTurnCrossedDay",
    "currentTurnHasLongGap",
):
    assert token in grounding, token
for token in (
    "不能称作“刚才/刚刚”",
    "不能默认仍是同一瞬间",
    "【反服务模板 / NATURAL RELATIONSHIP OUTPUT】",
):
    assert token in prompt, token
for token in ("2026, 8, 20, 21", "2026, 8, 21, 12", "15 * 60", "1"):
    assert token in grounding_test, token

system_bridge = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
runtime = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt"
)
accessibility_service = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt"
)
android_bridge = read("lib/core/platform/android_bridge.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
system_page = read("lib/features/system/system_page.dart")
for token in (
    "ComponentName.unflattenFromString",
    'accessibilityStatus["accessibilityComponentMatch"] == true',
    '"accessibilityComponentMatch"',
    '"accessibilityEnabledEntryCount"',
    '"accessibilityPackageEntryCount"',
    '"accessibilityStatusProbeAt"',
    '"appLabel"',
):
    assert token in system_bridge, token
assert 'accessibilityStatus["componentMatch"]' not in system_bridge
for token in (
    "KEY_ACCESSIBILITY_SERVICE_GENERATION",
    "KEY_ACCESSIBILITY_LAST_EVENT_PACKAGE_HASH",
    "noteAccessibilityEvent",
    "shortHash",
):
    assert token in runtime, token
for token in ("noteAccessibilityEvent", "AccessibilityEvent.eventTypeToString", "PrivacyFilter"):
    assert token in accessibility_service, token
for token in (
    "COMPONENT_MISMATCH",
    "PROCESS_RESTARTED",
    "ENABLED_NOT_CONNECTED",
    "CONNECTED_NO_EVENTS",
    "EVENT_STREAM_STALLED",
    "CONNECTED_EVENTS_OK",
):
    assert token in android_bridge and token in diagnostics, token
for token in ("轻视觉：系统", "轻视觉事件", "系统授权与实际连接是两件事"):
    assert token in system_page, token

perception = read("lib/core/perception/perception_interpreter.dart")
perception_test = read("test/perception_interpreter_v20_test.dart")
for token in ("currentAppLabel", "'current_app'", "当前打开的是 $currentApp"):
    assert token in perception, token
for token in ("原神", "支付宝", "com.example.secret.game", "com.example.wallet.private"):
    assert token in perception_test, token

guard = read("lib/core/grounding/service_template_guard.dart")
guard_test = read("test/service_template_guard_test.dart")
durable = read("lib/core/ai/durable_generation_runner.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
for token in (
    "permanent_standby",
    "obedient_withdrawal",
    "unconditional_surrender",
    "empty_reassurance",
    "ServiceTemplateGuardTelemetry",
    "removeTemplateSentences",
):
    assert token in guard, token
for token in ("我不催你", "你忙你的", "proactive: true", "fallback removes template tail"):
    assert token in guard_test, token
for token in ("ServiceTemplateGuard.evaluate", "action: 'rewrite'", "action: 'block'"):
    assert token in durable or token in proactive, token
for token in (
    "'serviceTemplateGuard'",
    "service_template_guard_match_count",
    "'matchedTextIncluded': false",
):
    assert token in diagnostics, token

workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)
for token in (
    "Build AI Companion v0.35.5+80 APK",
    "validate_v0355_time_perception_diagnostics.py",
    "AI-Companion-v0.35.5-80-Time-Perception-Diagnostics-APK.apk",
    "v0.35.5-time-perception-diagnostics-test",
    ".ci/v0355-monitor.txt",
):
    assert token in workflow, token

print("v0.35.5 time, perception and diagnostics validation passed")
