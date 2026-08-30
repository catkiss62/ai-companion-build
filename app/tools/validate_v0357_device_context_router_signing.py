#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), f"{relative} is empty"
    return value


assert re.search(r"^version: (?:0\.35\.(?:7\+82|8\+83|9\+84)|0\.36\.(?:0\+85|1\+86|2\+87|3\+88)|0\.37\.0\+89|0\.37\.1\+90|0\.37\.2\+91|0\.37\.3\+92|0\.37\.4\+93|0\.37\.5\+94|0\.37\.6\+95|0\.37\.7\+96|0\.37\.8\+97|0\.37\.9\+98|0\.38\.0\+99|0\.38\.1\+100|0\.38\.2\+101|0\.38\.3\+102|0\.38\.4\+103|0\.38\.5\+104|0\.38\.6\+105|0\.38\.7\+106|0\.38\.8\+107|0\.38\.9\+108|0\.38\.10\+109|0\.38\.11\+110|0\.38\.12\+111|0\.38\.13\+112|0\.38\.14\+113|0\.38\.15\+114|0\.38\.16\+115|0\.38\.18\+117|0\.39\.0\+118|0\.39\.1\+119|0\.39\.2\+120|0\.39\.3\+121|0\.39\.4\+122|0\.39\.5\+123|0\.39\.6\+124|0\.39\.7\+125|0\.39\.8\+126|0\.39\.9\+127|0\.40\.0\+128|0\.40\.1\+129|0\.40\.2\+130|0\.40\.3\+(?:131|132)|0\.40\.4\+133|0\.40\.5\+134|0\.40\.6\+135|0\.40\.7\+136)$", read("pubspec.yaml"), re.MULTILINE) or "version: 0.40.9+138" in (Path(__file__).resolve().parents[1] / "pubspec.yaml").read_text()
assert "static const int schemaVersion = 26;" in read(
    "lib/core/database/app_database.dart"
)

planner = read("lib/core/agent/agent_tool_planner.dart")
generation = read("lib/core/ai/durable_generation_runner.dart")
bridge = read("lib/core/platform/android_bridge.dart")
context = read("lib/core/perception/current_device_context_refresher.dart")
interpreter = read("lib/core/perception/perception_interpreter.dart")
web = read("lib/core/autonomy/layered_public_web_provider.dart")
models = read("lib/core/models/public_web_candidate.dart")
tool_runner = read("lib/core/agent/agent_tool_runner.dart")
web_engine = read("lib/core/autonomy/public_web_discovery_engine.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
gradle = read("android/app/build.gradle.kts")
runtime = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt"
)
system = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
accessibility = read(
    "android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt"
)

for token in ("routeLocally", "nativeToolDefinitions", "explicit_request"):
    assert token in planner, token
assert "AgentToolPlanner.nativeToolDefinitions" in generation
assert "contextSource" in bridge and "currentAppSource" in interpreter
assert "deviceState.usageAccess || deviceState.accessibilityConnected" in context
for token in (
    "accessibility_window",
    "usage_events",
    "usage_stats_fallback",
    "queryUsageStats",
):
    assert token in system, token
assert "noteForegroundWindow" in accessibility or "noteForegroundApp" in accessibility
for token in (
    "foregroundWindowPackageHash",
    "currentAppFusionSource",
    "currentAppRawPackageIncluded",
):
    assert token in runtime, token
for token in (
    "compactionAttempted",
    "compactionSucceeded",
    "compactionFailureReason",
):
    assert token in web or token in models, token
assert "_recordCompactionTelemetry" in tool_runner
assert "_recordCompactionTelemetry" in web_engine
assert "publicWebCompaction" in diagnostics
assert "privateStableTest" in gradle

workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
    encoding="utf-8"
)
for token in (
    "Build AI Companion v0.35.7+82 APK",
    "validate_v0357_device_context_router_signing.py",
    "AI-Companion-v0.35.7-82-Device-Context-Router-APK.apk",
    "v0.35.7-device-context-router-test",
    ".ci/v0357-monitor.txt",
    "ai-companion-private-signing-v1",
    "AI_COMPANION_KEYSTORE_PATH",
    "verify --print-certs",
):
    assert token in workflow, token

print("v0.35.7 device context, fast router, compaction telemetry and signing validation passed")
