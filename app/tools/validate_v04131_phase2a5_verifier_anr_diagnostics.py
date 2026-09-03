#!/usr/bin/env python3
"""Static contracts for v0.41.31 verifier/closure/UI/ANR diagnostics."""

from pathlib import Path


APP = Path(__file__).resolve().parents[1]
ROOT = APP.parent


def read(relative: str) -> str:
    value = (ROOT / relative).read_text(encoding="utf-8")
    assert value.strip(), relative
    return value


pubspec = read("app/pubspec.yaml")
self_reader = read("app/lib/core/agent/agent_self_reader.dart")
initiative = read("app/lib/core/desire/conversation_initiative_policy.dart")
verifier = read("app/lib/core/desire/conversation_outcome_verifier.dart")
system_page = read("app/lib/features/system/system_page.dart")
preflight = read("app/lib/core/diagnostics/preflight_diagnostics.dart")
proactive_engine = read("app/lib/core/desire/proactive_engine.dart")
scene_policy = read(
    "app/lib/core/desire/proactive_scene_continuity_policy.dart"
)
scene_test = read("app/test/proactive_scene_continuity_v04131_test.dart")
system_bridge = read(
    "app/android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
sanitizer = read(
    "app/android/app/src/main/kotlin/com/aicompanion/localfirst/"
    "HistoricalAnrTraceSanitizer.kt"
)
sanitizer_test = read(
    "app/android/app/src/test/kotlin/com/aicompanion/localfirst/"
    "HistoricalAnrTraceSanitizerTest.kt"
)
accessibility_service = read(
    "app/android/app/src/main/kotlin/com/aicompanion/localfirst/"
    "AccessibilityBridgeService.kt"
)
accessibility_shedder = read(
    "app/android/app/src/main/kotlin/com/aicompanion/localfirst/"
    "AccessibilityEventLoadShedder.kt"
)
accessibility_shedder_test = read(
    "app/android/app/src/test/kotlin/com/aicompanion/localfirst/"
    "AccessibilityEventLoadShedderTest.kt"
)
runtime_state = read(
    "app/android/app/src/main/kotlin/com/aicompanion/localfirst/"
    "CompanionRuntimeState.kt"
)
agency_test = read("app/test/conversation_agency_phase2a5_test.dart")
responsibility_test = read(
    "app/test/conversation_responsibility_ablation_v04121_test.dart"
)
workflow = read(".github/workflows/build-apk.yml")
ledger = read("AI_Companion_当前总账.md")

assert "version: 0.41.31+170" in pubspec
assert "buildLabel = 'v0.41.31+170'" in self_reader

for token in ("'晚安'", "'我去睡'", "'去睡吧'", "'明天见'"):
    assert token in initiative, token
for token in ("'让我睡'", "'折腾我'", "'困意'", "'打哈欠'"):
    assert token in verifier, token
for token in (
    "an explicit goodnight closes before an older curiosity Thought",
    "asking whether she slept is still a real user question",
):
    assert token in agency_test, token
for token in (
    "embodied fatigue counts as expressing an own need",
    "a direct rest boundary counts without a magic template phrase",
):
    assert token in responsibility_test, token

repeated_note = (
    "只有你在悬浮聊天点“看屏幕”或明确提出同等请求时，才会截取一张当前屏幕；"
    "敏感页会阻止，截图不会保存。"
)
assert repeated_note not in system_page
assert "Accessibility 轻视觉" in system_page

for token in (
    "restClosureHold = Duration(minutes: 90)",
    "recent_mutual_rest_closure",
    "rest_closure_expired",
):
    assert token in scene_policy, token
for token in (
    "ProactiveSceneContinuityPolicy.evaluate",
    "scene_rest_hold",
    "proactive_scene_continuity_last_v1",
):
    assert token in proactive_engine, token
for token in (
    "mutual goodnight holds unrelated proactive curiosity for 90 minutes",
    "fresh topics are not permanently suppressed",
    "a later real user turn clears the closed rest scene",
):
    assert token in scene_test, token

for token in (
    "maxCharacters = 262_144",
    "maxAppFrames = 8",
    'symbol.startsWith("com.aicompanion.localfirst.")',
    '"historicalAnrRawTraceIncluded" to false',
    '"historicalAnrAppTopFrames"',
    '"historicalAnrFrameCategories"',
):
    assert token in sanitizer, token
for forbidden in ("readText", "readBytes", "printStackTrace"):
    assert forbidden not in sanitizer, forbidden
assert "HistoricalAnrTraceSanitizer.summarize" in system_bridge
assert "info.traceInputStream" in system_bridge
for token in (
    "historicalAnrTraceAvailable",
    "historicalAnrMainThreadState",
    "historicalAnrAppTopFrames",
    "historicalAnrFrameCategories",
    "historicalAnrRawTraceIncluded': false",
    "'anrContext'",
    "unattributed_multi_signal_snapshot",
    "accessibilityDeviceEventCoalescedProcessCount",
):
    assert token in preflight, token
for token in (
    "com.example.secret",
    "SystemBridge.kt",
    "private failure detail",
):
    assert token in sanitizer_test, token

for token in (
    "ordinaryMinIntervalMs: Long = 1_500L",
    "windowMinIntervalMs: Long = 400L",
    "duplicateQuietMs: Long = 5_000L",
):
    assert token in accessibility_shedder, token
for token in (
    "AccessibilityEventLoadShedder()",
    "ArrayBlockingQueue(32)",
    "accessibility-event-writer",
    "eventWriter.execute",
):
    assert token in accessibility_service, token
for token in (
    "accessibilityPendingEventCount",
    "flushAccessibilityEventTelemetry",
    "accessibilityDeviceEventCoalescedProcessCount",
):
    assert token in runtime_state, token
for token in (
    "ordinary content events are rate limited and duplicate suppressed",
    "window changes keep a faster but still bounded lane",
):
    assert token in accessibility_shedder_test, token

for token in (
    "Build AI Companion v0.41.31+170 APK (Phase 2A.5 Verifier + ANR Diagnostics)",
    "agent/v04131-phase2a5-verifier-closure-ui-cleanup",
    "AI-Companion-v0.41.31-170-Phase2A5-Verifier-ANR-Diagnostics-APK",
    "validate_v04131_phase2a5_verifier_anr_diagnostics.py",
    "HistoricalAnrTraceSanitizerTest",
    "AccessibilityEventLoadShedderTest",
    ".ci/v04131-monitor.txt",
):
    assert token in workflow, token
for token in (
    "v0.41.31 Phase 2A.5 验证器与收尾边界窄修",
    "importance 100 前台",
    "附件流水 `not_called`",
    "不做破坏性 Prompt 消融",
):
    assert token in ledger, token

print("v0.41.31 Phase 2A.5 verifier/ANR diagnostics validation passed")
