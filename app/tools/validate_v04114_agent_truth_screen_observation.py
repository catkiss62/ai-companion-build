#!/usr/bin/env python3
"""Static contracts for v0.41.14 operation truth and one-time screen view."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


pubspec = read(APP / "pubspec.yaml")
database = read(APP / "lib/core/database/app_database.dart")
registry = read(APP / "lib/core/agent/agent_tool_registry.dart")
planner = read(APP / "lib/core/agent/agent_tool_planner.dart")
runner = read(APP / "lib/core/agent/agent_tool_runner.dart")
self_reader = read(APP / "lib/core/agent/agent_self_reader.dart")
prompt = read(APP / "lib/core/ai/prompt_builder.dart")
durable = read(APP / "lib/core/ai/durable_generation_runner.dart")
proactive = read(APP / "lib/core/desire/proactive_engine.dart")
guard = read(APP / "lib/core/grounding/operational_claim_grounding_guard.dart")
android_bridge = read(APP / "lib/core/platform/android_bridge.dart")
vision = read(APP / "lib/core/ai/qwen_vision_client.dart")
provider_health = read(APP / "lib/core/diagnostics/provider_health.dart")
provider_health_test = read(APP / "test/provider_health_v0402_test.dart")
accessibility = read(
    APP
    / "android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt"
)
privacy = read(
    APP / "android/app/src/main/kotlin/com/aicompanion/localfirst/PrivacyFilter.kt"
)
system_bridge = read(
    APP / "android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt"
)
overlay = read(
    APP / "android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt"
)
accessibility_config = read(APP / "android/app/src/main/res/xml/accessibility_service_config.xml")
docs = read(APP / "docs/AGENT_OPERATION_TRUTH_SCREEN_OBSERVATION_v0.41.14.md")
doc_map = read(APP / "docs/DOCUMENTATION_MAP.md")
ledger = read(ROOT / "AI_Companion_当前总账.md")
workflow = read(ROOT / ".github/workflows/build-apk.yml")

assert "version: 0.41.14+153" in pubspec
assert "static const int schemaVersion = 42;" in database
assert "buildLabel = 'v0.41.14+153'" in self_reader

screen_block = registry.split("static const screenObservation =", 1)[1].split(
    ");", 1
)[0]
for token in (
    "executable: true",
    "userTurnAvailable: true",
    "autonomousAvailable: false",
    "不保存截图",
):
    assert token in screen_block, token
for future_tool in ("videoUnderstanding", "reminderSchedule", "mcpInvoke"):
    block = registry.split(f"static const {future_tool} =", 1)[1].split(");", 1)[0]
    assert "executable: false" in block, future_tool

for token in (
    "explicitScreen",
    "AgentToolRegistry.screenObservation.id",
    "function selection is never treated as consent",
    ".where((tool) => tool.id != AgentToolRegistry.screenObservation.id)",
    "<String>['facts', 'outcomes', 'growth', 'all']",
):
    assert token in planner, token

for token in (
    "AgentSelfReadScope.growth",
    "personalityLearningDiagnosticStats",
    "phase=observation_only",
    "GROWTH_COUNTS",
    "candidateBodiesIncluded",
):
    assert token in self_reader or token in database, token
for forbidden in ("evidenceQuote", "proposition", "subject_key", "candidate_id"):
    growth_formatter = self_reader.split("final growthLines", 1)[1].split(
        "final sections", 1
    )[0]
    assert forbidden not in growth_formatter, forbidden

for token in (
    "OperationalClaimGroundingGuard.evaluate",
    "unsupported_operation_duration",
    "ungrounded_screen_observation",
    "ungrounded_system_read",
    "ungrounded_unimplemented_operation",
):
    assert token in guard or token in durable or token in proactive, token
assert "OperationalClaimGroundingGuard.evaluate" in durable
assert "OperationalClaimGroundingGuard.evaluate" in proactive
assert "TERMINAL OUTCOME REQUIRED" in prompt
assert "绝不能扩写成“看了一下午、研究了半天、花了几小时”" in prompt

for token in (
    "captureCurrentScreenOnce",
    "captureCurrentScreenOnce()",
    "readVisionApiKey",
    "observeBytes",
    "UNTRUSTED VISUAL DATA",
    "截图字节没有保存到附件、相册、记忆、诊断或备份",
    "agentToolOutcomeEventExists",
    "reserveOneTimeAgentToolOutcome",
    "ConflictAlgorithm.ignore",
    "SELECT changes()",
    "_noteScreenVision",
    "_reserveOneTimeScreenOutcome",
    "one_time_already_consumed",
    "one_time_reservation_failed",
):
    assert token in runner or token in android_bridge or token in vision or token in database, token
assert "'screen_observation'" in provider_health
assert "ProviderHealth.safeContext('screen_observation')" in provider_health_test

for token in (
    "Build.VERSION.SDK_INT < Build.VERSION_CODES.R",
    "keyguard.isDeviceLocked",
    "containsPasswordField",
    "allowScreenObservationPackage",
    "Build.VERSION.SDK_INT >= 34 && errorCode == 6",
    "decodeScreenshot",
    "captureInFlight.compareAndSet(false, true)",
    "takeScreenshot(",
    "bytes.size > 16 * 1024 * 1024",
):
    assert token in accessibility, token
for token in (
    '"bank"',
    '"wallet"',
    '"authenticator"',
    '"permissioncontroller"',
    '"documentsui"',
    '"settings"',
    "ApplicationInfo.CATEGORY_FINANCE",
):
    assert token in privacy, token
assert '"captureCurrentScreenOnce"' in system_bridge
assert 'smallButton("看屏幕")' in overlay
assert 'collapseChatOverlay("one_time_screen_observation")' in overlay
assert 'android:canTakeScreenshot="true"' in accessibility_config
for token in (
    "'implementationStatus': 'user_turn_only'",
    "'userTurnAvailable': true",
    "'oneTimeProviderAvailable': true",
    "'schedulerAvailable': false",
    "'providerAvailable': false",
):
    assert token in database, token

for test_file in (
    "test/operational_claim_grounding_guard_test.dart",
    "test/agent_self_reader_v0416_test.dart",
    "test/agent_tool_planner_fast_route_test.dart",
    "test/agent_tool_registry_test.dart",
    "test/image_vision_test.dart",
    "android/app/src/test/kotlin/com/aicompanion/localfirst/PrivacyFilterTest.kt",
):
    assert (APP / test_file).is_file(), test_file

for token in (
    "AGENT_OPERATION_TRUTH_SCREEN_OBSERVATION_v0.41.14.md",
    "自主截屏",
    "Phase 2/3/4",
):
    assert token in docs + doc_map, token
for token in (
    "### 19. 2026-09-01 · v0.41.14",
    "看了一下午",
    "main` 保持旧稳定集成检查点",
    "查手机 + 联网存图",
    "Phase 2",
    "Phase 3",
    "Phase 4",
):
    assert token in ledger, token
for token in (
    "Build AI Companion v0.41.14+153 APK (Agent Truth + One-Time Screen)",
    "agent/v04114-agent-truth-screen-observation",
    "AI-Companion-v0.41.14-153-Agent-Truth-One-Time-Screen-APK",
    "v0.41.14-agent-truth-one-time-screen-test",
    "validate_v04114_agent_truth_screen_observation.py",
):
    assert token in workflow, token

print("v0.41.14 Agent truth and one-time screen validation passed")
